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

Write-Host "Tip: don't click inside this window - Windows pauses it (title starts with 'Select'). Press Esc to resume." -ForegroundColor Yellow
Write-Host "Now on: $(git log -1 --pretty=format:'%h %s')"

try {
    while ($true) {
        Start-Sleep -Seconds $Interval
        git fetch --quiet origin $Branch 2>&1 | Out-Null
        $local = git rev-parse HEAD
        $remote = git rev-parse "origin/$Branch"
        if ($local -ne $remote) {
            Write-Host "$(Get-Date -Format HH:mm:ss) New changes found - pulling..." -ForegroundColor Green
            $result = git pull --ff-only origin $Branch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Update FAILED:" -ForegroundColor Red
                $result | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
                Write-Host "  Copy the red text above and send it to Claude." -ForegroundColor Red
            } else {
                Write-Host "  Updated to: $(git log -1 --pretty=format:'%h %s')" -ForegroundColor Green
            }
        }
        if ($rojo.HasExited) {
            Write-Host "Rojo stopped! Close this window and run the sync script again." -ForegroundColor Red
            break
        }
    }
}
finally {
    if ($rojo -and -not $rojo.HasExited) { Stop-Process -Id $rojo.Id }
}
