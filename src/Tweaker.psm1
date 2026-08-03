$script:Root = Split-Path $PSScriptRoot -Parent
@('Core.ps1','Providers.ps1','Tui.ps1') | ForEach-Object { . (Join-Path $PSScriptRoot $_) }
Initialize-Tweaker
Export-ModuleMember -Function Get-TweakerCatalog,Get-TweakerProfiles,Test-TweakerCatalog,Get-TweakerState,New-TweakerPlan,Invoke-TweakerPlan,Restore-TweakerSnapshot,Start-TweakerTui,New-TweakerRestorePoint