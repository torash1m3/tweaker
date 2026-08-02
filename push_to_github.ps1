$env:PATH = "C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;" + $env:PATH
Write-Host "Configuring Git identity..." -ForegroundColor Cyan
git config user.name "torash1m3"
git config user.email "torash1m3@users.noreply.github.com"
git branch -M main

Write-Host "Adding files and committing..." -ForegroundColor Cyan
git add .
git commit -m "Update configuration and documentation URLs" 2>$null

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main
