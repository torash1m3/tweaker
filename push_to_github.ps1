[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Message)
$ErrorActionPreference='Stop'
$env:PATH="C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;"+$env:PATH
if(-not(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git is not installed'}
git status --short
if($LASTEXITCODE -ne 0){throw 'git status failed'}
$answer=Read-Host 'Stage all files shown above? Type YES'
if($answer -cne 'YES'){Write-Host 'Cancelled.';exit}
git add --all
git diff --cached --check
if($LASTEXITCODE -ne 0){throw 'Staged diff validation failed'}
git commit -m $Message
if($LASTEXITCODE -ne 0){throw 'Commit failed'}
git push -u origin main
if($LASTEXITCODE -ne 0){throw 'Push failed'}
