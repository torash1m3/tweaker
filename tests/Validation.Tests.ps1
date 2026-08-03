#requires -Version 5.1
<#
.SYNOPSIS
Read-only structural validation for the modular Tweaker project (no Pester required).

.DESCRIPTION
Parses every PowerShell source file, imports the module, and validates the public
catalog/profile contract.  It never invokes Apply/Revert operations.  A failed
check is printed to stderr and the process exits with code 1.
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Failures = 0

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

function Invoke-Check {
    param([Parameter(Mandatory = $true)][string] $Name,
          [Parameter(Mandatory = $true)][scriptblock] $Body)
    try {
        & $Body
        Write-Host ("[PASS] {0}" -f $Name) -ForegroundColor Green
    }
    catch {
        $script:Failures++
        [Console]::Error.WriteLine(("[FAIL] {0}: {1}" -f $Name, $_.Exception.Message))
    }
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Get-PropertyValue {
    param($InputObject, [string[]] $Names)
    if ($null -eq $InputObject) { return $null }
    foreach ($name in $Names) {
        if ($InputObject -is [Collections.IDictionary] -and $InputObject.Contains($name)) { return $InputObject[$name] }
        $property = $InputObject.PSObject.Properties[$name]
        if ($null -ne $property) { return $property.Value }
    }
    return $null
}

$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
Assert-True (Test-Path -LiteralPath $ProjectRoot -PathType Container) "Project root does not exist: $ProjectRoot"

$sourceFiles = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') -and $_.FullName -notmatch '[\\/]\.git[\\/]' })
Invoke-Check 'PowerShell source files were found' {
    Assert-True ($sourceFiles.Count -gt 0) 'No ps1, psm1, or psd1 files were found'
}

foreach ($file in $sourceFiles) {
    Invoke-Check ("Syntax: {0}" -f $file.FullName.Substring($ProjectRoot.Length).TrimStart([char[]]@('\', '/'))) {
        $tokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) {
            throw (($parseErrors | ForEach-Object { "line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message }) -join '; ')
        }
    }
}

# Prefer the module manifest nearest the repository root. Test-ModuleManifest also
# catches invalid RootModule/FilesToProcess/export declarations.
$manifests = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -Filter '*.psd1' -File |
    Where-Object {
        if ($_.FullName -match '[\\/](tests?|testdata)[\\/]') { return $false }
        try {
            $data = Import-PowerShellDataFile -LiteralPath $_.FullName -ErrorAction Stop
            return -not [string]::IsNullOrWhiteSpace([string]$data.RootModule)
        } catch { return $false }
    } |
    Sort-Object @{ Expression = { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } }, FullName)
Assert-True ($manifests.Count -gt 0) 'No module manifest (.psd1) was found'
$manifestPath = $manifests[0].FullName

Invoke-Check 'Module manifest is valid' { [void](Test-ModuleManifest -Path $manifestPath -ErrorAction Stop) }
$script:ModuleUnderTest = $null
Invoke-Check 'Module imports successfully' {
    $script:ModuleUnderTest = Import-Module -Name $manifestPath -Force -PassThru -ErrorAction Stop
    Assert-True ($null -ne $script:ModuleUnderTest) 'Import-Module returned no module'
}
$module = $script:ModuleUnderTest

$requiredCommands = @('Get-TweakerCatalog', 'Get-TweakerProfiles', 'Test-TweakerCatalog')
Invoke-Check 'Planned public commands are exported' {
    $missing = @($requiredCommands | Where-Object { -not (Get-Command -Name $_ -Module $module.Name -ErrorAction SilentlyContinue) })
    Assert-True ($missing.Count -eq 0) ("Missing command(s): " + ($missing -join ', '))
}

$script:CatalogUnderTest = @()
Invoke-Check 'Catalog can be read' {
    $script:CatalogUnderTest = @(& (Get-Command Get-TweakerCatalog -Module $module.Name))
    Assert-True ($script:CatalogUnderTest.Count -gt 0) 'Catalog is empty'
}
$catalog = $script:CatalogUnderTest

$catalogIds = @($catalog | ForEach-Object { [string](Get-PropertyValue $_ @('Id', 'ID', 'TweakId')) })
Invoke-Check 'Every tweak has a non-empty, unique ID' {
    $empty = @($catalogIds | Where-Object { [string]::IsNullOrWhiteSpace($_) })
    Assert-True ($empty.Count -eq 0) 'One or more catalog entries have no Id'
    $duplicates = @($catalogIds | Group-Object | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
    Assert-True ($duplicates.Count -eq 0) ("Duplicate tweak ID(s): " + ($duplicates -join ', '))
}

$script:ProfilesUnderTest = @()
Invoke-Check 'Profiles can be read' {
    $script:ProfilesUnderTest = @(& (Get-Command Get-TweakerProfiles -Module $module.Name))
    Assert-True ($script:ProfilesUnderTest.Count -gt 0) 'No profiles were returned'
}
$profiles = $script:ProfilesUnderTest

Invoke-Check 'Profile names, actions, and catalog references are valid' {
    $names = @()
    $allowedStates = @('ENABLE', 'REVERT', 'SKIP', 'Apply', 'Revert', 'Skip')
    foreach ($profile in $profiles) {
        $name = [string](Get-PropertyValue $profile @('Name', 'ProfileName', 'PresetName', 'Id'))
        Assert-True (-not [string]::IsNullOrWhiteSpace($name)) 'A profile has no name'
        $names += $name
        $actions = Get-PropertyValue $profile @('Actions', 'Tweaks', 'Settings')
        Assert-True ($null -ne $actions) "Profile '$name' has no Actions/Tweaks collection"
        $references = @()
        foreach ($action in @($actions)) {
            if ($actions -is [Collections.IDictionary]) {
                $references = @($actions.Keys | ForEach-Object { [pscustomobject]@{ Id = [string]$_; State = [string]$actions[$_] } })
                break
            }
            $references = @($actions | ForEach-Object {
                [pscustomobject]@{ Id = [string](Get-PropertyValue $_ @('Id','TweakId','Name')); State = [string](Get-PropertyValue $_ @('State','Action','Mode')) }
            })
            break
        }
        foreach ($reference in $references) {
            Assert-True ($catalogIds -contains $reference.Id) "Profile '$name' references unknown tweak '$($reference.Id)'"
            if (-not [string]::IsNullOrWhiteSpace($reference.State)) {
                Assert-True ($allowedStates -contains $reference.State) "Profile '$name' uses invalid state '$($reference.State)'"
            }
        }
    }
    $duplicateNames = @($names | Group-Object | Where-Object Count -gt 1)
    Assert-True ($duplicateNames.Count -eq 0) 'Profile names are not unique'
}

Invoke-Check 'Built-in catalog validator succeeds' {
    $result = & (Get-Command Test-TweakerCatalog -Module $module.Name)
    if ($result -is [bool]) { Assert-True $result 'Test-TweakerCatalog returned false'; return }
    $valid = Get-PropertyValue $result @('IsValid', 'Valid', 'Success')
    Assert-True ($null -ne $valid) 'Validator returned neither Boolean nor an IsValid/Valid/Success property'
    Assert-True ([bool]$valid) 'Test-TweakerCatalog reported validation errors'
}

if ($null -ne $module) { Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue }
Write-Host ("Validation completed: {0} failure(s)." -f $script:Failures)
if ($script:Failures -gt 0) { exit 1 }
exit 0