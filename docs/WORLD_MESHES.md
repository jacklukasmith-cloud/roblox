# World 3D models (Higgsfield)

Eggs, crystals, the Mana Chest and the Meadow trees can use 3D models instead of the built-in
block versions. Any prop without a model keeps its built-in look, so you can add them one by one.

| Model name | Replaces | Preview image |
|---|---|---|
| `MeadowEgg` | Enchanted Meadow egg | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195725_d86aa413-a3f1-43a2-8ab4-ad725e39e035.png) |
| `EmberEgg` | Ember Rift egg | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_200107_90afa4d1-b2df-4e2d-a3cb-384127a49c9f.png) |
| `FrostEgg` | Frostpeak egg | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195751_9d04f9b4-3f41-4620-bdcd-8866c5f33462.png) |
| `SkyEgg` | Sky Sanctum egg | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195724_93ad102b-194b-4e81-a2a2-4999558398bf.png) |
| `ChampionEgg` | Champion egg (hub) | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195724_af975e50-403f-4851-b15c-2a34458dd3aa.png) |
| `MeadowCrystal` | Meadow crystals | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195724_2ab79892-5936-4121-98c4-f9342fdfcd31.png) |
| `EmberCrystal` | Ember crystals | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195723_b0a134b6-39ca-4c35-8146-3c9dc31244db.png) |
| `FrostCrystal` | Frostpeak crystals | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195723_721664e2-b21f-4b95-95e3-927fcd28f7d0.png) |
| `SkyCrystal` | Sky crystals | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195751_46686232-b2c9-4972-94c7-5443c8b1ebe4.png) |
| `ManaChest` | Mana Chests (every realm) | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195752_35745698-a1cc-414f-8a28-93f2b1e5e3ab.png) |
| `MagicTree` | Enchanted Meadow trees | [image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_195724_f6fd17c2-1b47-42ec-8ae8-2039d243e983.png) |

`MerchantStall` is also supported (the 3D conversion failed for it, so the stall keeps its
built-in look; drop in any model named `MerchantStall` to replace it).

## Add them to the game

1. Run `powershell -ExecutionPolicy Bypass -File scripts\download-world.ps1` in the roblox
   folder. It saves the models in `world-models\`.
2. In Studio: **File → Import 3D**, select all the `.glb` files, and import them into Workspace.
   Keep the file names (e.g. `MeadowEgg`) as the model names.
3. Press **Play**. The server moves them into `ReplicatedStorage.WorldMeshes` and builds the world
   with them. The Output shows `World 3D models ready: 11/12`.
4. That's it: leave them in Workspace. Every time the game starts they are picked up
   automatically (or drag them into `ReplicatedStorage > WorldMeshes` yourself, same result).

Each model is scaled automatically (eggs ~6.8 studs tall, crystals ~6.5, chest ~9.5 wide, trees
12-16 tall). To tweak one, add attributes to its model in WorldMeshes: **Scale** (e.g. `1.2`) and
**Yaw** (degrees to turn it).
