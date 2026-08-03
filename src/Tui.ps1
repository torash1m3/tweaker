function Start-TweakerTui {
    $selections=@{};$packages=New-Object System.Collections.Generic.List[string]
    while($true){
        Clear-Host;Write-Host "WIN11 TWEAKER v$($script:Config.Version)" -ForegroundColor Cyan
        Write-Host '[1] Profile  [2] Tweaks  [3] Packages  [4] Review/execute  [5] Inspect  [R] Restore  [Q] Quit'
        Write-Host "Selected tweaks: $($selections.Count) | packages: $($packages.Count)" -ForegroundColor DarkGray
        $key=[Console]::ReadKey($true).KeyChar
        switch([string]$key){
            '1' {$profiles=@($script:Profiles);for($i=0;$i-lt$profiles.Count;$i++){Write-Host "[$($i+1)] $($profiles[$i].Name) - $($profiles[$i].Description)"};$n=Read-Host 'Profile number';if($n -as [int]){$p=Resolve-TweakerProfile $profiles[[int]$n-1].Name;$selections=$p.Tweaks;$packages=New-Object System.Collections.Generic.List[string];foreach($id in $p.Packages){$packages.Add($id)}}}
            '2' {Select-TweakerTuiTweaks $selections}
            '3' {Select-TweakerTuiPackages $packages}
            '4' {$plan=New-TweakerPlan -Selections $selections -Packages @($packages);Show-TweakerPlan $plan;if((Read-Host 'Type APPLY to execute') -ceq 'APPLY'){$result=Invoke-TweakerPlan $plan;$result.Results|Format-Table Id,Action,Success,Message -AutoSize;Read-Host 'Enter to continue'|Out-Null}}
            '5' {Get-TweakerState|Format-Table Id,State,Reversible,Restart -AutoSize;Read-Host 'Enter to continue'|Out-Null}
            {$_ -in @('r','R')} {$files=@(Get-ChildItem (Get-SnapshotDirectory) -Filter '*.json' -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending);for($i=0;$i-lt$files.Count;$i++){Write-Host "[$($i+1)] $($files[$i].BaseName)"};$n=Read-Host 'Snapshot number';if($n -as [int]){Restore-TweakerSnapshot $files[[int]$n-1].FullName|Format-List;Read-Host 'Enter to continue'|Out-Null}}
            {$_ -in @('q','Q')} {return}
        }
    }
}
function Select-TweakerTuiTweaks([hashtable]$Selections){
    $items=@($script:Catalog);while($true){Clear-Host;for($i=0;$i-lt$items.Count;$i++){$mark=if($Selections.ContainsKey($items[$i].Id)){$Selections[$items[$i].Id]}else{'Skip'};Write-Host ('[{0,2}] [{1,-6}] {2} / {3}' -f ($i+1),$mark,$items[$i].Category,$items[$i].Title)};$raw=Read-Host 'Number toggles Skip -> Apply -> Revert (B back)';if($raw -in @('b','B')){return};$n=0;if([int]::TryParse($raw,[ref]$n)-and$n-ge1-and$n-le$items.Count){$id=$items[$n-1].Id;$current=if($Selections.ContainsKey($id)){$Selections[$id]}else{'Skip'};if($current-eq'Skip'){$Selections[$id]='Apply'}elseif($current-eq'Apply' -and $items[$n-1].Reversible){$Selections[$id]='Revert'}else{$Selections.Remove($id)}}}
}
function Select-TweakerTuiPackages($Packages){
    while($true){Clear-Host;for($i=0;$i-lt$script:Apps.Count;$i++){$mark=if($Packages.Contains($script:Apps[$i].Id)){'X'}else{' '};Write-Host "[$($i+1)] [$mark] $($script:Apps[$i].Name)"};$raw=Read-Host 'Number toggles package (B back)';if($raw-in@('b','B')){return};$n=0;if([int]::TryParse($raw,[ref]$n)-and$n-ge1-and$n-le$script:Apps.Count){$id=$script:Apps[$n-1].Id;if($Packages.Contains($id)){$Packages.Remove($id)}else{$Packages.Add($id)}}}
}
function Show-TweakerPlan($Plan){Clear-Host;Write-Host "PLAN $($Plan.Id)" -ForegroundColor Cyan;$Plan.Actions|ForEach-Object {[pscustomobject]@{Action=$_.Action;Id=$_.Tweak.Id;Before=$_.Before;Reversible=$_.Tweak.Reversible;Restart=$_.Tweak.Restart}}|Format-Table -AutoSize;if($Plan.Packages){Write-Host "Packages: $($Plan.Packages -join ', ')"}}