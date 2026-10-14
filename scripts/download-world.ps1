# Downloads the world prop 3D models (eggs, crystals, chest, tree, merchant) into the "world-models" folder.
# Usage (PowerShell, in the roblox folder):  powershell -ExecutionPolicy Bypass -File scripts\download-world.ps1

Set-Location (Split-Path $PSScriptRoot -Parent)
$out = "world-models"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ProgressPreference = "SilentlyContinue"
$models = [ordered]@{
    "MeadowEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195757_60e19d0a-318b-400e-b931-f72dde449de3.glb"
    "EmberEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_200129_5d0e2628-ea15-40a2-ac7e-951c0a6b7b8d.glb"
    "FrostEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195815_2294f10c-c00c-4a94-b620-80c771964de8.glb"
    "SkyEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195800_9a9948c8-2fad-4450-bb8d-0c6ddfeebb79.glb"
    "ChampionEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195801_acf55f42-f3f9-47ac-8891-44956d630a47.glb"
    "MeadowCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195802_69456b91-7a08-4d07-88f5-5697322a69d3.glb"
    "EmberCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195803_c2988a59-36cb-4c0c-8060-dd731e765b3f.glb"
    "FrostCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195805_679dd176-85aa-43ba-b6a3-5bd1d8a60d29.glb"
    "SkyCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195816_03d8f104-d738-4ab2-bbfe-12f2bbaddf9d.glb"
    "ManaChest" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195817_afb64682-f37c-48e2-9869-3020e9b82f45.glb"
    "MagicTree" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195806_00114dae-20c2-4644-bd48-1e1fd4c2d472.glb"
    "MerchantStall" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_200801_7cf01a57-dc5a-4263-8203-2d83221abbed.glb"
    "MerchantTent" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_200802_63cfd9f7-3dd7-4a70-8806-b9ee08a1395a.glb"
}
$ok = 0
foreach ($id in $models.Keys) {
    $file = Join-Path $out "$id.glb"
    try {
        Invoke-WebRequest -Uri $models[$id] -OutFile $file -UseBasicParsing
        Write-Host "  downloaded $id" -ForegroundColor Green
        $ok++
    } catch {
        Write-Host "  FAILED $id : $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "$ok of $($models.Count) models saved in $out\" -ForegroundColor Cyan
Write-Host "Next: in Studio, File > Import 3D, select them all, then press Play (see docs/WORLD_MESHES.md)."
