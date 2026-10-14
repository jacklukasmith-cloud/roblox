@echo off
rem Double-click this file to download every world 3D model into the "world-models" folder,
rem already named the way the game expects (MeadowEgg.glb, SnowyPine.glb, ...).
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\download-world.ps1"
echo.
echo Opening the folder...
start "" "world-models"
pause
