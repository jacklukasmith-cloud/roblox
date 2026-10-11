# Live-sync Mythic Tamers into Roblox Studio (Windows).
# Usage (PowerShell, from the repo folder):   .\scripts\sync.ps1
# Then in Studio: Rojo plugin -> Connect. Leave this window open while you work.

$Branch = "claude/roblox-monetizable-ideas-5xrrhu"
$Interval = 15 # seconds between checks for new changes

Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
    Write-Host "Rojo isn't installed. Run 'rokit install' in this folder first (see README)." -ForegroundColor Red
    exit 1
}

git fetch origin $Branch
git checkout $Branch
git pull --ff-only origin $Branch

Write-Host "Starting Rojo... In Studio open the Rojo plugin and click Connect." -ForegroundColor Cyan
$rojo = Start-Process rojo -ArgumentList "serve" -NoNewWindow -PassThru

try {
    while ($true) {
        Start-Sleep -Seconds $Interval
        git fetch --quiet origin $Branch
        $local = git rev-parse HEAD
        $remote = git rev-parse "origin/$Branch"
        if ($local -ne $remote) {
            Write-Host "$(Get-Date -Format HH:mm:ss) New changes found - pulling..." -ForegroundColor Green
            git pull --ff-only --quiet origin $Branch
            git log -1 --pretty=format:"  -> %s" ; Write-Host ""
        }
    }
}
finally {
    if ($rojo -and -not $rojo.HasExited) { Stop-Process -Id $rojo.Id }
}
