function Get-RegistryValueSnapshot($Operation) {
    $exists=Test-Path $Operation.Path; $valueExists=$false; $value=$null; $type=$null
    if($exists){$key=Get-Item $Operation.Path -ErrorAction Stop;if($key.GetValueNames() -contains $Operation.Name){$valueExists=$true;$value=$key.GetValue($Operation.Name,$null,'DoNotExpandEnvironmentNames');$type=[string]$key.GetValueKind($Operation.Name)}}
    [pscustomobject]@{Path=$Operation.Path;Name=$Operation.Name;KeyExisted=$exists;ValueExisted=$valueExists;Value=$value;Type=$type}
}
function Get-ProviderState($Tweak) {
    try { switch($Tweak.Provider){
        'Registry' {$matched=0;foreach($op in $Tweak.Operations){$s=Get-RegistryValueSnapshot $op;if($s.ValueExisted -and ([string]$s.Value -ceq [string]$op.Value)){$matched++}};if($matched -eq @($Tweak.Operations).Count){'Applied'}elseif($matched){'Partial'}else{'NotApplied'}}
        'RegistryKey' {if((@($Tweak.Operations|Where-Object {Test-Path $_.Path})).Count -eq @($Tweak.Operations).Count){'Applied'}else{'NotApplied'}}
        'Appx' {$left=@($Tweak.Packages|ForEach-Object {Get-AppxPackage -Name $_ -ErrorAction SilentlyContinue});if($left.Count){'NotApplied'}else{'Applied'}}
        'UnblockFiles' {'NotApplied'} default {'Unknown'}
    }} catch {'Unknown'}
}
function Get-ProviderSnapshot($Tweak) {
    switch($Tweak.Provider){
        'Registry' {,@($Tweak.Operations|ForEach-Object {Get-RegistryValueSnapshot $_})}
        'RegistryKey' {,@($Tweak.Operations|ForEach-Object {[pscustomobject]@{Path=$_.Path;KeyExisted=(Test-Path $_.Path)}})}
        default {$null}
    }
}
function Set-RegistryOperation($Operation) {
    if(-not(Test-Path $Operation.Path)){New-Item $Operation.Path -Force -ErrorAction Stop|Out-Null}
    New-ItemProperty -Path $Operation.Path -Name $Operation.Name -Value $Operation.Value -PropertyType $Operation.Type -Force -ErrorAction Stop|Out-Null
}
function Invoke-ProviderApply($Tweak) {
    switch($Tweak.Provider){
        'Registry' {foreach($op in $Tweak.Operations){Set-RegistryOperation $op};[pscustomobject]@{Success=$true;Message='Registry values applied'}}
        'RegistryKey' {foreach($op in $Tweak.Operations){New-Item $op.Path -Force -ErrorAction Stop|Out-Null};[pscustomobject]@{Success=$true;Message='Registry keys applied'}}
        'Appx' {foreach($pattern in $Tweak.Packages){Get-AppxPackage -Name $pattern -ErrorAction Stop|Remove-AppxPackage -ErrorAction Stop};[pscustomobject]@{Success=$true;Message='Appx packages removed'}}
        'UnblockFiles' {$path=[Environment]::ExpandEnvironmentVariables($Tweak.Path);Get-ChildItem $path -Recurse -File -ErrorAction Stop|Unblock-File -ErrorAction Stop;[pscustomobject]@{Success=$true;Message='Files unblocked'}}
        default {throw "Unknown provider: $($Tweak.Provider)"}
    }
}
function Restore-ProviderSnapshot($Provider,$Data) {
    switch($Provider){
        'Registry' {foreach($item in @($Data)){if($item.ValueExisted){if(-not(Test-Path $item.Path)){New-Item $item.Path -Force|Out-Null};New-ItemProperty $item.Path $item.Name $item.Value -PropertyType $item.Type -Force -ErrorAction Stop|Out-Null}else{Remove-ItemProperty $item.Path $item.Name -ErrorAction SilentlyContinue;if(-not $item.KeyExisted -and (Test-Path $item.Path)){if(@((Get-Item $item.Path).GetValueNames()).Count -eq 0){Remove-Item $item.Path -Force -ErrorAction SilentlyContinue}}}}}
        'RegistryKey' {foreach($item in @($Data)){if(-not $item.KeyExisted){Remove-Item $item.Path -Recurse -Force -ErrorAction SilentlyContinue}}}
        default {throw "Provider $Provider is not reversible"}
    }
}
function Install-TweakerPackage([string]$Id) {
    $app=$script:Apps|Where-Object Id -eq $Id|Select-Object -First 1;if(-not $app){return [pscustomobject]@{Id=$Id;Action='Install';Success=$false;Message='Unknown package'}}
    if(-not(Get-Command winget -ErrorAction SilentlyContinue)){return [pscustomobject]@{Id=$Id;Action='Install';Success=$false;Message='winget not found'}}
    & winget list --id $Id -e --accept-source-agreements *> $null;if($LASTEXITCODE -eq 0){return [pscustomobject]@{Id=$Id;Action='Install';Success=$true;Message='Already installed'}}
    $output=& winget install --id $Id -e --silent --accept-source-agreements --accept-package-agreements 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Id=$Id;Action='Install';Success=($code -eq 0);Message=if($code -eq 0){'Installed'}else{"winget exit $code`: $($output -join ' ')"}}
}
function New-TweakerRestorePoint([string]$Description='Tweaker_AutoBackup') {
    try {if(-not(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore')){New-Item 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Force|Out-Null};New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0 -PropertyType DWord -Force|Out-Null;Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue;Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop;[pscustomobject]@{Success=$true;Message='Restore point created'}}catch{[pscustomobject]@{Success=$false;Message=$_.Exception.Message}}
}