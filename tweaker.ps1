[CmdletBinding()]
param(
    [ValidateSet('Tui','Inspect','Plan','Apply','Revert')][string]$Mode='Tui',
    [string]$Profile,
    [string]$Snapshot,
    [switch]$NoRestorePoint,
    [switch]$NoElevation
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'src\Tweaker.psd1') -Force
if($Mode -in @('Tui','Apply','Revert') -and -not $NoElevation){
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        $hostExe=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
        $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Mode',$Mode)
        if($Profile){$arguments+=@('-Profile',"`"$Profile`"")};if($Snapshot){$arguments+=@('-Snapshot',"`"$Snapshot`"")};if($NoRestorePoint){$arguments+='-NoRestorePoint'}
        Start-Process $hostExe -ArgumentList ($arguments -join ' ') -Verb RunAs;exit
    }
}
switch($Mode){
    'Tui' {Start-TweakerTui}
    'Inspect' {Get-TweakerState|Format-Table -AutoSize}
    'Plan' {if(-not $Profile){throw '-Profile is required'};$p=New-TweakerPlan -Profile $Profile;$p.Actions|ForEach-Object {[pscustomobject]@{Id=$_.Tweak.Id;Action=$_.Action;Before=$_.Before}}|Format-Table -AutoSize}
    'Apply' {if(-not $Profile){throw '-Profile is required'};Invoke-TweakerPlan (New-TweakerPlan -Profile $Profile) -NoRestorePoint:$NoRestorePoint}
    'Revert' {if(-not $Snapshot){throw '-Snapshot is required'};Restore-TweakerSnapshot -Snapshot $Snapshot}
}