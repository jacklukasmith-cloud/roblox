--[[
	Sounds. Uses Config.Sounds (built-in Roblox sounds by default) and plays little
	melodies by re-pitching one chime, so milestones feel special without any uploads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.BloomShared.Config)

local Sfx = {}

local group = Instance.new("SoundGroup")
group.Name = "BloomSfx"
group.Volume = 0.8
group.Parent = SoundService

local VOLUMES = { Pop = 0.12, Click = 0.3, Tap = 0.22, Burst = 0.35 }

local templates = {}
for key, volume in VOLUMES do
	local id = Config.Sounds[key]
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.Name = key
		s.SoundId = id
		s.Volume = volume
		s.SoundGroup = group
		s.Parent = SoundService
		templates[key] = s
	end
end

function Sfx.Play(key: string, pitch: number?, volumeScale: number?)
	local t = templates[key]
	if not t then
		return
	end
	local s = t:Clone()
	s.PlaybackSpeed = pitch or 1
	s.Volume = t.Volume * (volumeScale or 1)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(4, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Semitone offsets from the chime's base pitch
local MELODIES = {
	Milestone = { 0, 4, 7, 12 },
	Win = { 0, 4, 7, 11, 12, 16 },
	Lose = { 7, 4, 0 },
	Replant = { 0, 7, 12, 7, 12, 19 },
	Gate = { 0, 5, 9 },
}

function Sfx.Melody(name: string)
	local notes = MELODIES[name]
	if not notes then
		return
	end
	task.spawn(function()
		for _, n in notes do
			Sfx.Play("Burst", 0.7 * 2 ^ (n / 12), 0.8)
			task.wait(0.11)
		end
	end)
end

if Config.Sounds.Music and Config.Sounds.Music ~= "" then
	local music = Instance.new("Sound")
	music.Name = "BloomMusic"
	music.SoundId = Config.Sounds.Music
	music.Looped = true
	music.Volume = 0.3
	music.Parent = SoundService
	music:Play()
end

return Sfx
