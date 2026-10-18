--[[
	All game audio (client side).

	Each sound key resolves, in order, to:
	  1. a Sound named after the key in ReplicatedStorage.GameSounds (drop your own in!)
	  2. an asset id in Config.Sounds
	  3. a sound that ships with Roblox (so the game is never silent)

	Jingles (hatch reveals, unlocks, Mana Surge) are played as little melodies by
	re-pitching one chime, and realms without a music track get a generated "music box".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Sound = {}

local FALLBACK: { [string]: { Id: string, Volume: number } } = {
	Hit = { Id = "rbxasset://sounds/snap.wav", Volume = 0.3 },
	Break = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.45 },
	ChestBreak = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.8 },
	Orb = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.22 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.35 },
	EggShake = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3 },
	Reveal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4 },
	Chime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 },
}

local group = Instance.new("SoundGroup")
group.Name = "SFX"
group.Volume = 1
group.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 0.5
musicGroup.Parent = SoundService

local templates: { [string]: Sound } = {}

local function customSound(key: string): Sound?
	local folder = ReplicatedStorage:FindFirstChild("GameSounds")
	local s = folder and folder:FindFirstChild(key)
	return if s and s:IsA("Sound") then s else nil
end

local function configId(key: string): string?
	local id = (Config.Sounds :: any)[key]
	if type(id) == "number" then
		return "rbxassetid://" .. id
	elseif type(id) == "string" and id ~= "" then
		return if string.find(id, "://", 1, true) then id else "rbxassetid://" .. id
	end
	return nil
end

-- Returns a Sound to clone for this key (cached), or nil if there's nothing to play.
local function template(key: string): Sound?
	local custom = customSound(key)
	if custom then
		return custom
	end
	if templates[key] then
		return templates[key]
	end
	local fallback = FALLBACK[key]
	local id = configId(key) or (fallback and fallback.Id)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Volume = if fallback then fallback.Volume else 0.5
	templates[key] = s
	return s
end

local lastPlayed: { [string]: number } = {}

-- Plays a one-shot sound. pitch defaults to 1; minGap throttles rapid repeats.
function Sound.Play(key: string, pitch: number?, volumeScale: number?, minGap: number?)
	if State.SfxMuted then
		return
	end
	local now = os.clock()
	if minGap and now - (lastPlayed[key] or 0) < minGap then
		return
	end
	lastPlayed[key] = now
	local t = template(key)
	if not t then
		return
	end
	local s = t:Clone()
	s.PlaybackSpeed = (pitch or 1) * t.PlaybackSpeed
	s.Volume = t.Volume * (volumeScale or 1)
	s.SoundGroup = group
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Built-in sounds get re-pitched for variety; your own sounds keep their natural pitch
-- (with just a touch of variation so repeats don't sound robotic).
function Sound.Pitch(key: string, builtInPitch: number): number
	if customSound(key) or configId(key) then
		return 0.95 + math.random() * 0.1
	end
	return builtInPitch
end

-- Semitones -> playback speed
local function note(semitones: number): number
	return 2 ^ (semitones / 12)
end

local JINGLES: { [string]: { { number } } } = {
	-- { delay, semitones, volume }
	Common = { { 0, 0, 1 }, { 0.09, 4, 1 }, { 0.18, 7, 1 } },
	Rare = { { 0, 0, 1 }, { 0.08, 4, 1 }, { 0.16, 7, 1 }, { 0.26, 12, 1.2 } },
	Legendary = {
		{ 0, 0, 1 },
		{ 0.07, 4, 1 },
		{ 0.14, 7, 1 },
		{ 0.21, 11, 1 },
		{ 0.28, 12, 1.2 },
		{ 0.42, 16, 1.4 },
		{ 0.42, 19, 1.2 },
	},
	Unlock = { { 0, 0, 1 }, { 0.12, 7, 1 }, { 0.24, 12, 1.3 } },
	Surge = { { 0, -12, 1.4 }, { 0.15, -5, 1.2 }, { 0.3, 0, 1.2 }, { 0.45, 7, 1.3 }, { 0.6, 12, 1.5 } },
	Rebirth = {
		{ 0, 12, 1 },
		{ 0.1, 7, 1 },
		{ 0.2, 4, 1 },
		{ 0.3, 0, 1 },
		{ 0.5, 12, 1.3 },
		{ 0.5, 16, 1.2 },
		{ 0.5, 19, 1.2 },
	},
}

local function hasCustom(key: string): boolean
	return customSound(key) ~= nil or configId(key) ~= nil
end

local FANFARE_PITCH = { Surge = 1, Unlock = 1.1, Rebirth = 0.9 }

function Sound.Jingle(name: string)
	-- A real "Fanfare" sound replaces the built-in ping melodies
	if FANFARE_PITCH[name] and hasCustom("Fanfare") then
		Sound.Play("Fanfare", FANFARE_PITCH[name])
		return
	end
	local jingle = JINGLES[name]
	if not jingle then
		return
	end
	for _, step in jingle do
		task.delay(step[1], function()
			Sound.Play("Chime", note(step[2]), step[3])
		end)
	end
end

-- Hatch reveal: a custom "Reveal" sound if provided, plus a jingle that grows with rarity
function Sound.Reveal(rarityOrder: number)
	local rare = rarityOrder >= 5
	if rare and hasCustom("RareReveal") then
		Sound.Play("RareReveal")
		return
	end
	if hasCustom("Reveal") then
		Sound.Play("Reveal", if rare then 1.1 else 1)
		return
	end
	Sound.Play("Reveal", 1, 0.8)
	Sound.Jingle(if rare then "Legendary" elseif rarityOrder >= 3 then "Rare" else "Common")
end

-- Music ------------------------------------------------------------------------------------
-- Which realm the local player is standing in (0 = hub); matches WorldBuilder's layout.
local HUB_END, ZONE_LENGTH = 50 * 1.35, 130 * 1.35 -- must match WorldBuilder (SPREAD)
local MUSIC_KEYS =
	{ [0] = "MusicHub", "MusicMeadow", "MusicEmber", "MusicFrost", "MusicSky", "MusicStarfall", "MusicVoid" }

-- Music box settings per realm: scale (semitones), base pitch, seconds per beat
local MUSIC_BOX = {
	[0] = { Scale = { 0, 2, 4, 7, 9 }, Base = 0, Beat = 0.42 }, -- hub: major pentatonic
	{ Scale = { 0, 2, 4, 7, 9 }, Base = 2, Beat = 0.38 }, -- meadow: bright & bouncy
	{ Scale = { 0, 3, 5, 7, 10 }, Base = -3, Beat = 0.34 }, -- ember: minor pentatonic, driving
	{ Scale = { 0, 2, 3, 7, 8 }, Base = 5, Beat = 0.55 }, -- frost: slow, icy
	{ Scale = { 0, 2, 4, 6, 9 }, Base = 7, Beat = 0.46 }, -- sky: lydian, airy
}

local function currentArea(): number
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end
	local z = root.Position.Z
	if z < HUB_END then
		return 0
	end
	return math.clamp(math.floor((z - HUB_END) / ZONE_LENGTH) + 1, 1, 4)
end

local track: Sound? = nil
local trackKey: string? = nil

local function stopTrack()
	if track then
		local old = track
		track = nil
		trackKey = nil
		task.spawn(function()
			for i = 10, 0, -1 do
				old.Volume = old.Volume * (i / 10)
				task.wait(0.08)
			end
			old:Destroy()
		end)
	end
end

local function playTrack(key: string): boolean
	if trackKey == key then
		return true
	end
	local source = customSound(key)
	local id = configId(key)
	if not source and not id then
		stopTrack()
		return false
	end
	stopTrack()
	local s: Sound
	if source then
		s = source:Clone()
	else
		s = Instance.new("Sound")
		s.SoundId = id :: string
	end
	local target = if source then source.Volume else 0.4
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	track, trackKey = s, key
	task.spawn(function()
		for i = 1, 10 do
			if track ~= s then
				return
			end
			s.Volume = target * i / 10
			task.wait(0.1)
		end
	end)
	return true
end

local function musicNote(semis: number, volume: number)
	local t = template("Chime")
	if not t or State.MusicMuted then
		return
	end
	local s = t:Clone()
	s.PlaybackSpeed = note(semis)
	s.Volume = volume
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
end

local function musicBoxStep(area: number, beat: number, degree: number): number
	local box = MUSIC_BOX[area] or MUSIC_BOX[0]
	local scale = box.Scale
	-- Gentle random walk through the scale = a wandering melody
	degree = math.clamp(degree + math.random(-2, 2), 1, #scale * 2)
	local octave = (degree - 1) // #scale
	local semis = box.Base + scale[((degree - 1) % #scale) + 1] + octave * 12
	if beat % 8 == 0 then
		musicNote(box.Base - 12, 0.16) -- bass note on every bar
	end
	if math.random() < 0.8 then
		musicNote(semis, 0.11)
	end
	return degree
end

-- The realm's own track, else the hub track, else any track at all
local function musicKeyFor(area: number): string
	local preferred = { MUSIC_KEYS[area], "MusicHub", "MusicMeadow", "MusicEmber", "MusicFrost", "MusicSky" }
	for _, key in preferred do
		if customSound(key) or configId(key) then
			return key
		end
	end
	return MUSIC_KEYS[area]
end

function Sound.Start()
	task.spawn(function()
		local beat, degree = 0, 5
		while true do
			local area = currentArea()
			local key = musicKeyFor(area)
			local hasTrack = not State.MusicMuted and playTrack(key)
			if State.MusicMuted then
				stopTrack()
			end
			local box = MUSIC_BOX[area] or MUSIC_BOX[0]
			if not hasTrack and not State.MusicMuted and Config.MusicBox then
				degree = musicBoxStep(area, beat, degree)
				beat += 1
			end
			task.wait(box.Beat)
		end
	end)
end

return Sound
