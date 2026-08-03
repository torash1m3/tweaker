$script:Config = $null
$script:Catalog = @()
$script:Profiles = @()
$script:Apps = @()

function Initialize-Tweaker {
    $configPath = Join-Path $script:Root 'config.json'
    $script:Config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $script:Catalog = @(Get-ChildItem (Join-Path $script:Root 'tweaks') -Filter '*.psd1' | Sort-Object Name | ForEach-Object {
        $data = Import-PowerShellDataFile $_.FullName
        @($data.Tweaks)
    })
    $script:Profiles = @(Get-ChildItem (Join-Path $script:Root 'profiles') -Filter '*.psd1' | Sort-Object Name | ForEach-Object { Import-PowerShellDataFile $_.FullName })
    $script:Apps = @((Import-PowerShellDataFile (Join-Path $script:Root 'data\winget-apps.psd1')).Apps)
    $validation = Test-TweakerCatalog
    if (-not $validation.Valid) { throw ($validation.Errors -join [Environment]::NewLine) }
}

function Get-TweakerCatalog { @($script:Catalog) }
function Get-TweakerProfiles { @($script:Profiles) }

function Test-TweakerCatalog {
    $errors = New-Object System.Collections.Generic.List[string]
    $knownProviders = @('Registry','RegistryKey','Appx','UnblockFiles')
    $ids = @{}
    foreach ($tweak in $script:Catalog) {
        foreach ($field in @('Id','Category','Title','Provider')) { if (-not $tweak.ContainsKey($field) -or -not $tweak[$field]) { $errors.Add("Tweak is missing $field") } }
        if ($ids.ContainsKey($tweak.Id)) { $errors.Add("Duplicate tweak id: $($tweak.Id)") } else { $ids[$tweak.Id] = $true }
        if ($tweak.Provider -notin $knownProviders) { $errors.Add("Unknown provider '$($tweak.Provider)' for $($tweak.Id)") }
        if ($tweak.Provider -in @('Registry','RegistryKey') -and @($tweak.Operations).Count -eq 0) { $errors.Add("No operations for $($tweak.Id)") }
    }
    $appIds = @{}; foreach ($app in $script:Apps) { $appIds[$app.Id] = $true }
    foreach ($profile in $script:Profiles) {
        if (-not $profile.Name) { $errors.Add('Profile without Name'); continue }
        foreach ($id in $profile.Tweaks.Keys) { if (-not $ids.ContainsKey($id)) { $errors.Add("Profile '$($profile.Name)' references unknown tweak '$id'") } }
        foreach ($id in @($profile.Packages)) { if (-not $appIds.ContainsKey($id)) { $errors.Add("Profile '$($profile.Name)' references unknown package '$id'") } }
    }
    [pscustomobject]@{ Valid = ($errors.Count -eq 0); Errors = @($errors) }
}

function Get-TweakerState {
    [CmdletBinding()] param([string[]]$Id)
    $items = if ($Id) { @($script:Catalog | Where-Object { $_.Id -in $Id }) } else { $script:Catalog }
    foreach ($tweak in $items) {
        $state = Get-ProviderState $tweak
        [pscustomobject]@{Id=$tweak.Id;Category=$tweak.Category;Title=$tweak.Title;State=$state;Reversible=[bool]$tweak.Reversible;Restart=$tweak.Restart}
    }
}

function Resolve-TweakerProfile {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$Stack=@())
    if ($Name -in $Stack) { throw "Cyclic profile inheritance: $($Stack + $Name -join ' -> ')" }
    $profile = $script:Profiles | Where-Object Name -eq $Name | Select-Object -First 1
    if (-not $profile) { throw "Unknown profile: $Name" }
    $tweaks = @{}; $packages = New-Object System.Collections.Generic.List[string]
    foreach ($parent in @($profile.Extends)) {
        $resolved = Resolve-TweakerProfile $parent ($Stack + $Name)
        foreach ($key in $resolved.Tweaks.Keys) { $tweaks[$key] = $resolved.Tweaks[$key] }
        foreach ($package in $resolved.Packages) { if (-not $packages.Contains($package)) { $packages.Add($package) } }
    }
    foreach ($key in $profile.Tweaks.Keys) { $tweaks[$key] = $profile.Tweaks[$key] }
    foreach ($package in @($profile.Packages)) { if (-not $packages.Contains($package)) { $packages.Add($package) } }
    [pscustomobject]@{Name=$profile.Name;Description=$profile.Description;Tweaks=$tweaks;Packages=@($packages)}
}

function New-TweakerPlan {
    [CmdletBinding()] param([string]$Profile,[hashtable]$Selections,[string[]]$Packages)
    if ($Profile) { $resolved=Resolve-TweakerProfile $Profile; $Selections=$resolved.Tweaks; $Packages=$resolved.Packages }
    if (-not $Selections) { $Selections=@{} }
    $actions = foreach ($id in $Selections.Keys) {
        $tweak=$script:Catalog|Where-Object Id -eq $id|Select-Object -First 1
        if (-not $tweak) { throw "Unknown tweak: $id" }
        [pscustomobject]@{Tweak=$tweak;Action=$Selections[$id];Before=(Get-ProviderState $tweak)}
    }
    [pscustomobject]@{Id=(Get-Date -Format 'yyyy-MM-dd_HHmmss');Profile=$Profile;Actions=@($actions);Packages=@($Packages)}
}

function Invoke-TweakerPlan {
    [CmdletBinding(SupportsShouldProcess=$true)] param([Parameter(Mandatory=$true)]$Plan,[switch]$NoRestorePoint)
    Assert-TweakerAdministrator
    $snapshot=[ordered]@{Id=$Plan.Id;Created=(Get-Date).ToString('o');Machine=$env:COMPUTERNAME;Entries=@()}
    $results=New-Object System.Collections.Generic.List[object]; $restartExplorer=$false
    if (-not $NoRestorePoint -and $script:Config.AutoCreateRestorePoint) { $null=New-TweakerRestorePoint "Tweaker_$($Plan.Id)" }
    foreach ($entry in $Plan.Actions) {
        if ($entry.Action -eq 'Skip') { continue }
        try {
            if ($entry.Action -eq 'Revert') { $result=Restore-TweakerById $entry.Tweak.Id }
            else {
                $snap=Get-ProviderSnapshot $entry.Tweak
                if ($null -ne $snap) {
                    $snapshot.Entries += [pscustomobject]@{TweakId=$entry.Tweak.Id;Provider=$entry.Tweak.Provider;Data=$snap}
                    Save-TweakerSnapshot $snapshot
                }
                $result=Invoke-ProviderApply $entry.Tweak
                if ($result.Success -and (Get-ProviderState $entry.Tweak) -ne 'Applied') { throw 'Post-apply validation failed' }
            }
            $results.Add([pscustomobject]@{Id=$entry.Tweak.Id;Action=$entry.Action;Success=$result.Success;Message=$result.Message})
            if ($result.Success -and $entry.Tweak.Restart -eq 'Explorer') { $restartExplorer=$true }
        } catch { $results.Add([pscustomobject]@{Id=$entry.Tweak.Id;Action=$entry.Action;Success=$false;Message=$_.Exception.Message}) }
    }
    Save-TweakerSnapshot $snapshot
    foreach ($package in @($Plan.Packages)) { $results.Add((Install-TweakerPackage $package)) }
    if ($restartExplorer -and $script:Config.RestartExplorer) { Stop-Process explorer -Force -ErrorAction SilentlyContinue; Start-Process explorer.exe }
    $execution=[pscustomobject]@{Id=$Plan.Id;Profile=$Plan.Profile;Results=@($results);Snapshot=(Get-SnapshotPath $Plan.Id)}
    Save-TweakerLog $execution
    $execution
}

function Assert-TweakerAdministrator {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator privileges are required for Apply/Revert.' }
}

function Get-SnapshotDirectory { Join-Path $script:Root ([string]$script:Config.StateDirectory) }
function Get-SnapshotPath([string]$Id) { Join-Path (Get-SnapshotDirectory) "$Id.json" }
function Save-TweakerSnapshot($Snapshot) { if (@($Snapshot.Entries).Count -gt 0) { New-Item (Get-SnapshotDirectory) -ItemType Directory -Force|Out-Null; $Snapshot|ConvertTo-Json -Depth 12|Set-Content (Get-SnapshotPath $Snapshot.Id) -Encoding UTF8 } }
function Get-LatestSnapshotForTweak([string]$Id) { Get-ChildItem (Get-SnapshotDirectory) -Filter '*.json' -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|ForEach-Object {$s=Get-Content $_.FullName -Raw|ConvertFrom-Json;if ($s.Entries|Where-Object TweakId -eq $Id){return $s}}|Select-Object -First 1 }
function Restore-TweakerById([string]$Id) { $s=Get-LatestSnapshotForTweak $Id;if(-not $s){throw "No snapshot found for $Id"};Restore-TweakerSnapshot -Snapshot $s -TweakId $Id }
function Restore-TweakerSnapshot { [CmdletBinding()]param([Parameter(Mandatory=$true)]$Snapshot,[string]$TweakId);Assert-TweakerAdministrator;if($Snapshot -is [string]){$Snapshot=Get-Content $Snapshot -Raw|ConvertFrom-Json};$entries=@($Snapshot.Entries);if($TweakId){$entries=@($entries|Where-Object TweakId -eq $TweakId)};foreach($e in $entries){Restore-ProviderSnapshot $e.Provider $e.Data};[pscustomobject]@{Success=$true;Message="Restored $($entries.Count) snapshot entries"} }
function Save-TweakerLog($Execution) { $dir=Join-Path $script:Root ([string]$script:Config.LogDirectory);New-Item $dir -ItemType Directory -Force|Out-Null;$Execution|ConvertTo-Json -Depth 8|Set-Content (Join-Path $dir "$($Execution.Id).json") -Encoding UTF8 }