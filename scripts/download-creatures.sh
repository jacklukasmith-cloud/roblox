#!/usr/bin/env bash
# Downloads all 26 creature 3D models into ./creature-models, named for the game.
# Usage (in the roblox folder): ./scripts/download-creatures.sh
set -u
cd "$(dirname "$0")/.."
mkdir -p creature-models
ok=0
while read -r id url; do
	if curl -fsSL "$url" -o "creature-models/$id.glb"; then echo "  downloaded $id"; ok=$((ok+1)); else echo "  FAILED $id"; fi
done <<EOF
GlowSprite https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163649_2712d2ee-dc37-43af-952e-3041be3048c5.glb
MossToad https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163650_9ddf08cb-8171-4aea-b6a9-c0cff7c5a9a2.glb
PixieMoth https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163651_63617028-6368-4ca0-a285-687f1235d036.glb
MoonRabbit https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163653_bd1f5ed1-6057-4693-9391-ba5b45c425aa.glb
FaeDragonling https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163654_cf814705-7dc6-415b-a96b-dcf8b3ce6057.glb
CinderImp https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163902_e3eef3cd-00d4-4fc2-a0ac-48faf02af0eb.glb
LavaSalamander https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163656_758edf90-3381-46d3-9f6e-61af9f9de3c1.glb
EmberFox https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163455_06ab3120-9411-4e73-b438-e248161a36e2.glb
FlameDrake https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163657_fb7072de-2c95-4078-bbc0-124d83958a03.glb
Phoenix https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163700_7c2bf8f2-0c7e-461b-8430-c33e280079b3.glb
FrostPup https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163701_fcdc2a14-73ec-4e9a-b21b-145327776f2c.glb
IceWisp https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163703_f788bf8d-1579-410c-ac3e-3bbe4712ef40.glb
CrystalStag https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163704_38c19341-17c2-4dc3-901f-4b6cb06425c0.glb
FrostWyrm https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163705_9d37e1c4-e934-4420-970f-871940067e63.glb
GlacialGriffin https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163707_ff68c27b-5a63-4cc1-9846-be5890e02110.glb
AuroraKirin https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163708_06291f38-0d0e-44a2-9c5c-b3325ec9c69c.glb
StormOwl https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163710_b15fd1c9-f95a-42b5-bd38-92b0bfbbfa9f.glb
CloudSerpent https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163713_592c45cc-fae5-4542-860b-b96ad7f6c83c.glb
ThunderGriffin https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163714_ca788d0f-975c-4213-919e-8efd18e7c8f4.glb
CelestialPegasus https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163716_7884971c-5718-492e-9752-0dbae3a7dd02.glb
StarDragon https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163717_2fbd7872-cc05-4a51-b186-c017b0621dbe.glb
VoidLeviathan https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163718_9c3e40d0-79c6-4d1b-a00f-09583cccb9e7.glb
ArenaBasilisk https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163720_2e2193ea-3bd8-4e70-b241-6a6f9881253c.glb
GladiatorManticore https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163721_e2691e5b-f061-478d-9571-ad450cd64007.glb
TitanUnicorn https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261011_163722_e9c5774e-d70c-4d4b-a472-96cbc520c09b.glb
NebulaKitsune https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261014_235137_102618db-162b-4e59-8fb1-73f7be6b06f8.glb
EOF
echo "$ok of 26 models saved to $(pwd)/creature-models"
echo "Next: in Studio use Import 3D and select all the .glb files in that folder."
