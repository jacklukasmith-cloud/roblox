# Downloads the world prop 3D models (eggs, crystals, chest, merchant, trees and decorations) into the "world-models" folder.
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
    "StarfallEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_135125_855168bd-20ed-44b3-8779-8866f5163fb2.glb"
    "VoidEgg" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_135127_0b8a648b-5c1d-4133-a935-411706b915da.glb"
    "StarfallCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_135129_dc25a401-edfb-46e9-b278-3ecd560f9ad1.glb"
    "VoidCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_135131_3ef7da71-2e6d-4da9-b713-fc65d3fd77d4.glb"
    "SkyCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195816_03d8f104-d738-4ab2-bbfe-12f2bbaddf9d.glb"
    "ManaChest" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195817_afb64682-f37c-48e2-9869-3020e9b82f45.glb"
    "MagicTree" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195806_00114dae-20c2-4644-bd48-1e1fd4c2d472.glb"
    "MerchantStall" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_200801_7cf01a57-dc5a-4263-8203-2d83221abbed.glb"
    "HubLamp" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203654_e5c83505-e269-481e-86ee-9b141e7b135c.glb"
    "PickaxeWooden" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_005703_d8621ce8-6ee8-480f-be94-61fdc28eece6.glb"
    "PickaxeStone" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175004_a3d68378-cf47-4849-96f9-72d2b1ad4f43.glb"
    "PickaxeIron" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175008_64f68bae-ff32-4335-9ce2-a663ab3278b2.glb"
    "PickaxeCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175009_30f9adbf-0c92-4547-9275-401d1eb841bf.glb"
    "PickaxeMythic" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175010_f1c13ee5-4e58-4140-95e8-ee03668bffc7.glb"
    "PickaxeGolden" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175012_e0b67f2e-83bf-406f-aa71-dc6150023e2c.glb"
    "PickaxeCopper" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_175006_59efa1e0-1d61-4398-a57e-c561bc3fc491.glb"
    "PickaxeFrost" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_171238_5997e48f-8afb-4ca3-9a83-8303c0c93660.glb"
    "PickaxeEmber" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_171239_6b0ef948-ff65-4534-92f2-d4fbda59ec8b.glb"
    "PickaxeEmerald" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_171240_f9f0230a-b01e-4d64-8223-07c8555f33fb.glb"
    "PickaxeVoid" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_171243_2ee30e0e-592f-4cd2-adee-3acc91013798.glb"
    "PickaxeCelestial" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261015_171244_b91f331a-b419-4520-9441-e0d024069c2f.glb"
    "FlowerPlanter" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203656_a9cd57aa-b829-415b-bc2f-efd752530e7a.glb"
    "Bench" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203657_bc48931b-c4c5-4dbf-a2d6-3f8c08c36020.glb"
    "HubBanner" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203659_c57b547d-5147-4998-aa97-399be85181d5.glb"
    "GiantMushroom" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203700_661a3966-5d83-48d8-af55-4585350d5ba3.glb"
    "FlowerBush" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203701_1e462185-708c-4764-9538-53b12abb9c85.glb"
    "MossRock" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203834_fc48ecf3-a24b-4076-a3e4-1f423415b347.glb"
    "LavaRock" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203704_ca9cf642-bbb4-45fa-9b26-8901439b081c.glb"
    "CharredTree" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203707_369c04ce-5e83-427b-aef5-793b023b88d0.glb"
    "FireBrazier" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203925_105be5b3-d0f6-411d-9ed7-e0f73a2d2706.glb"
    "SnowyPine" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203710_dc8a36bc-690c-4c0e-926e-187499efabbc.glb"
    "IceRock" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203712_5828abd4-cb9c-4e97-91ad-8b8160809db6.glb"
    "Snowman" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203713_d7d366dc-8d3b-4e0e-8d08-3fc0b13751dd.glb"
    "FloatingIsland" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203714_b668cb0e-fc5c-48b8-b5b9-809a5039b85c.glb"
    "RuinedColumn" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203716_3424e4bf-5868-4b99-97a8-38861620cb8b.glb"
    "StarLantern" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_203717_046700b4-5a99-4829-92ce-31e6de5aa90d.glb"
    "AlchemyCauldron" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261017_201330_a94f052f-aa33-4a7a-93d7-f451a20de906.glb"
    "PrismheartCrystal" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261017_235559_8b4caf86-2343-4101-8b9a-b6b467841730.glb"
    "VehicleMossBoard" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_001114_1d4fcdc2-cfd9-42e0-a14b-7c9bf4e2f074.glb"
    "VehicleCrystalBoard" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_001115_f8b35508-1898-4e42-93da-f68501074a75.glb"
    "VehicleMushroomKart" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_084558_91a8fa54-b4c4-43e8-ba7c-757632da1874.glb"
    "IslandChest" = "https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261018_084559_a0037d6b-a20f-49c1-9ae3-3662c0b07d4b.glb"
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
