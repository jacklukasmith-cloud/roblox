--[[
	Builds stylised 3D creature models out of primitive parts, with simple procedural
	animation (wing flaps, tail wags, paddling legs, serpent waves).

	Used by:
	  - client Followers (creatures floating behind players)
	  - UI previews (ViewportFrames in the inventory, bestiary and hatch screen)
	  - server WorldBuilder (statues, egg display previews)

	Every part is anchored and positioned from a "rig" each frame:
	  final CFrame = root * piece.Hinge * animation * piece.Local
	Facing: the creature looks down -Z (same as a CFrame's LookVector).
]]

local Creatures = require(script.Parent.Creatures)

local CreatureModels = {}

export type Piece = {
	Part: BasePart,
	Hinge: CFrame,
	Local: CFrame,
	Static: CFrame,
	Anim: string?,
	Param: number,
	Side: number,
	Amp: number,
	Tint: boolean, -- recoloured for Rainbow variants
}

export type Rig = {
	Model: Model,
	Pieces: { Piece },
	Parts: { BasePart },
	CFrames: { CFrame },
	Radius: number,
	Rainbow: boolean,
	LastTint: number,
}

-- Per-creature body plans ---------------------------------------------------------------
-- Type: Quadruped | Bird | Sprite | Serpent
local PLANS: { [string]: { [string]: any } } = {
	GlowSprite = { Type = "Sprite", Glow = true, Wings = "Bug", Antennae = true, WispTail = true },
	MossToad = {
		Type = "Quadruped",
		Low = true,
		BigEyes = true,
		Ears = "None",
		Tail = "None",
		Snout = "Flat",
		Spots = true,
	},
	PixieMoth = { Type = "Sprite", Wings = "BigBug", Antennae = true, Fluff = true },
	MoonRabbit = { Type = "Quadruped", Ears = "Long", Tail = "Puff", Snout = "Short", Glow = true },
	FaeDragonling = {
		Type = "Quadruped",
		Ears = "None",
		Horn = "Pair",
		Wings = "Bug",
		Tail = "Long",
		Snout = "Long",
		Spikes = true,
	},

	CinderImp = { Type = "Sprite", Imp = true, Wings = "Bat", Horn = "Pair", Tail = "Stinger" },
	LavaSalamander = {
		Type = "Quadruped",
		Low = true,
		Ears = "None",
		Tail = "Long",
		Snout = "Long",
		Spikes = true,
		Spots = true,
	},
	EmberFox = { Type = "Quadruped", Ears = "Pointy", Tail = "Bushy", Snout = "Long", Fire = "Tail" },
	FlameDrake = {
		Type = "Quadruped",
		Ears = "None",
		Horn = "Pair",
		Wings = "Bat",
		Tail = "Long",
		Snout = "Long",
		Spikes = true,
		Fire = "Tail",
	},
	Phoenix = { Type = "Bird", Crest = true, LongTail = true, Fire = "Body" },

	FrostPup = { Type = "Quadruped", Ears = "Pointy", Tail = "Bushy", Snout = "Short" },
	IceWisp = { Type = "Sprite", Glow = true, Orbiters = true, Shards = true, WispTail = true },
	CrystalStag = {
		Type = "Quadruped",
		Horse = true,
		Ears = "Pointy",
		Horn = "Antlers",
		Tail = "Short",
		Snout = "Long",
	},
	FrostWyrm = { Type = "Serpent", Horn = "Pair", Fins = true, Segments = 8 },
	GlacialGriffin = { Type = "Quadruped", Ears = "Tufts", Wings = "Feather", Snout = "Beak", Tail = "Puff" },
	AuroraKirin = {
		Type = "Quadruped",
		Horse = true,
		Ears = "Pointy",
		Horn = "Single",
		Mane = true,
		Tail = "Bushy",
		Snout = "Long",
		Aura = true,
	},

	NebulaKitsune = {
		Type = "Quadruped",
		Ears = "Pointy",
		Tail = "Bushy",
		Snout = "Long",
		Mane = true,
		Fire = "Tail",
		Aura = true,
	},

	StormOwl = { Type = "Bird", Ears = "Tufts", FaceDisc = true },
	CloudSerpent = { Type = "Serpent", Horn = "Pair", Whiskers = true, Mane = true, Segments = 9 },
	ThunderGriffin = { Type = "Quadruped", Ears = "Tufts", Wings = "Feather", Snout = "Beak", Tail = "Long" },
	CelestialPegasus = {
		Type = "Quadruped",
		Horse = true,
		Ears = "Pointy",
		Wings = "Feather",
		Mane = true,
		Tail = "Bushy",
		Snout = "Long",
	},
	StarDragon = {
		Type = "Quadruped",
		Ears = "None",
		Horn = "Pair",
		Wings = "Bat",
		Tail = "Long",
		Snout = "Long",
		Spikes = true,
		Aura = true,
	},
	VoidLeviathan = { Type = "Serpent", Horn = "Pair", Fins = true, Whiskers = true, Segments = 10, Aura = true },

	-- Starfall Desert
	DuneScarab = { Type = "Quadruped", Low = true, Ears = "None", Tail = "Short", Snout = "Flat", Antennae = true },
	MirageJackal = { Type = "Quadruped", Ears = "Pointy", Tail = "Long", Snout = "Long", Glow = true },
	SandWyrm = { Type = "Serpent", Horn = "Single", Segments = 8, Spikes = true },
	CometHawk = { Type = "Bird", Crest = true, LongTail = true, Fire = "Tail" },
	SphinxGuardian = {
		Type = "Quadruped",
		Ears = "Pointy",
		Wings = "Feather",
		Tail = "Long",
		Snout = "Short",
		Mane = true,
		Aura = true,
	},
	StarfallColossus = {
		Type = "Quadruped",
		Ears = "None",
		Horn = "Pair",
		Tail = "Short",
		Snout = "Flat",
		Spikes = true,
		Glow = true,
		Aura = true,
	},
	-- Void Abyss
	VoidMoth = { Type = "Sprite", Wings = "BigBug", Antennae = true, Fluff = true, Glow = true },
	ShadowLynx = { Type = "Quadruped", Ears = "Tufts", Tail = "Short", Snout = "Short", Glow = true },
	EclipseRaven = { Type = "Bird", Crest = true, LongTail = true, Aura = true },
	NetherWyvern = {
		Type = "Quadruped",
		Ears = "None",
		Horn = "Pair",
		Wings = "Bat",
		Tail = "Stinger",
		Snout = "Long",
		Spikes = true,
	},
	AbyssalKraken = { Type = "Serpent", Horn = "Pair", Fins = true, Whiskers = true, Segments = 12, Glow = true },
	EternityPhoenix = { Type = "Bird", Crest = true, LongTail = true, Fire = "Body", Aura = true },

	ArenaBasilisk = {
		Type = "Quadruped",
		Low = true,
		Ears = "None",
		Tail = "Long",
		Snout = "Long",
		Spikes = true,
		Horn = "Pair",
	},
	GladiatorManticore = {
		Type = "Quadruped",
		Ears = "Round",
		LionMane = true,
		Wings = "Bat",
		Tail = "Stinger",
		Snout = "Short",
	},
	TitanUnicorn = {
		Type = "Quadruped",
		Horse = true,
		Ears = "Pointy",
		Horn = "Single",
		Mane = true,
		Tail = "Bushy",
		Snout = "Long",
		Wings = "Feather",
		Aura = true,
	},
}

-- Part helpers ---------------------------------------------------------------------------

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 215, 90)

type Ctx = {
	Model: Model,
	Pieces: { Piece },
	S: number,
	Body: Color3,
	Accent: Color3,
	Belly: Color3,
	Dark: Color3,
	AccentMaterial: Enum.Material,
	Reflectance: number,
	HeadTop: CFrame?,
	Root: BasePart?,
}

local function makePart(kind: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Size = size
	if kind == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	return p
end

type AddOpts = {
	Material: Enum.Material?,
	Transparency: number?,
	Hinge: CFrame?, -- if set, cf is relative to the hinge
	Anim: string?,
	Param: number?,
	Side: number?,
	Tint: boolean?,
	Name: string?,
}

local function add(ctx: Ctx, kind: string, size: Vector3, cf: CFrame, color: Color3, opts: AddOpts?): BasePart
	local o: AddOpts = opts or {}
	local part = makePart(kind, size, color, o.Material)
	part.Transparency = o.Transparency or 0
	if o.Material == nil and ctx.Reflectance > 0 then
		part.Reflectance = ctx.Reflectance
	end
	if o.Name then
		part.Name = o.Name
	end
	local hinge = o.Hinge or cf
	local localCf = if o.Hinge then cf else CFrame.identity
	table.insert(ctx.Pieces, {
		Part = part,
		Hinge = hinge,
		Local = localCf,
		Static = hinge * localCf,
		Anim = o.Anim,
		Param = o.Param or 0,
		Side = o.Side or 1,
		Amp = ctx.S,
		Tint = if o.Tint == nil then color == ctx.Body else o.Tint,
	})
	part.Parent = ctx.Model
	if not ctx.Root then
		ctx.Root = part
	end
	return part
end

-- A tapered spike/horn made of shrinking cylinders. Returns the tip position.
local function taper(
	ctx: Ctx,
	from: Vector3,
	dir: Vector3,
	length: number,
	baseDia: number,
	color: Color3,
	segments: number?,
	opts: AddOpts?
): Vector3
	local n = segments or 3
	local d = dir.Unit
	local up = if math.abs(d.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local segLen = length / n
	for i = 0, n - 1 do
		local center = from + d * (segLen * (i + 0.5))
		local dia = baseDia * (1 - (i / n) * 0.75)
		-- Cylinders run along X; rotate X onto the direction
		local cf = CFrame.lookAt(center, center + d, up) * CFrame.Angles(0, math.pi / 2, 0)
		add(ctx, "Cylinder", Vector3.new(segLen * 1.05, dia, dia), cf, color, opts)
	end
	return from + d * length
end

local function eyes(ctx: Ctx, head: CFrame, spread: number, height: number, depth: number, size: number)
	local S = ctx.S
	for _, side in { -1, 1 } do
		local eyeCf = head * CFrame.new(side * spread, height, depth)
		add(ctx, "Ball", Vector3.one * size, eyeCf, Color3.fromRGB(20, 18, 30), { Tint = false })
		add(
			ctx,
			"Ball",
			Vector3.one * size * 0.38,
			eyeCf * CFrame.new(side * size * 0.12 + 0.02 * S, size * 0.2, -size * 0.32),
			WHITE,
			{ Material = Enum.Material.Neon, Tint = false }
		)
	end
end

-- Wings: hinge sits on the body, the wing extends along +/-X and flaps around Z.
local function wings(ctx: Ctx, style: string, hingePos: Vector3, span: number)
	local S = ctx.S
	for _, side in { -1, 1 } do
		-- Tilt the wing plane so its surface (not its edge) faces forward/up
		local hinge = CFrame.new(hingePos.X * side, hingePos.Y, hingePos.Z) * CFrame.Angles(-0.45, 0, 0)
		local base = { Hinge = hinge, Anim = "Flap", Side = side, Param = 0 }
		local function opts(extra: { [string]: any }?): AddOpts
			local o = table.clone(base)
			for k, v in extra or {} do
				o[k] = v
			end
			return o :: any
		end
		if style == "Feather" then
			local lengths = { 1.0, 0.82, 0.62 }
			for k, len in lengths do
				local l = len * span * S
				local color = if k == 1 then ctx.Body else ctx.Accent
				add(
					ctx,
					"Ellipsoid",
					Vector3.new(l, 0.09 * S, 0.34 * S),
					CFrame.new(side * l / 2, -0.03 * S * k, (k - 1) * 0.17 * S)
						* CFrame.Angles(0, side * (k - 1) * -0.18, 0),
					color,
					opts({ Material = if k == 1 then nil else ctx.AccentMaterial, Tint = k == 1 })
				)
			end
		elseif style == "Bat" then
			local l = span * S
			add(
				ctx,
				"Cylinder",
				Vector3.new(l, 0.09 * S, 0.09 * S),
				CFrame.new(side * l / 2, 0.02 * S, -0.05 * S),
				ctx.Dark,
				opts({ Tint = false })
			)
			-- membrane with scalloped trailing edge
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(l * 0.95, 0.04 * S, 0.85 * S),
				CFrame.new(side * l * 0.48, -0.03 * S, 0.34 * S),
				ctx.Accent,
				opts({ Material = ctx.AccentMaterial, Transparency = 0.1 })
			)
			add(
				ctx,
				"Wedge",
				Vector3.new(0.05 * S, 0.16 * S, 0.14 * S),
				CFrame.new(side * l, 0.06 * S, -0.05 * S),
				ctx.Dark,
				opts({ Tint = false })
			)
		elseif style == "Bug" or style == "BigBug" then
			local big = if style == "BigBug" then 1.6 else 1
			local wingOpts = opts({ Material = Enum.Material.Glass, Transparency = 0.35, Tint = false })
			wingOpts.Param = 0.4
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.75 * big * S, 0.03 * S, 0.5 * big * S),
				CFrame.new(side * 0.36 * big * S, 0.05 * S, -0.08 * S) * CFrame.Angles(0, side * 0.35, 0),
				ctx.Accent,
				wingOpts
			)
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.55 * big * S, 0.03 * S, 0.38 * big * S),
				CFrame.new(side * 0.26 * big * S, 0, 0.26 * S) * CFrame.Angles(0, side * -0.35, 0),
				ctx.Body:Lerp(WHITE, 0.4),
				wingOpts
			)
		end
	end
end

local function crown(ctx: Ctx)
	if not ctx.HeadTop then
		return
	end
	local S = ctx.S
	local top = ctx.HeadTop :: CFrame
	add(
		ctx,
		"Cylinder",
		Vector3.new(0.12 * S, 0.42 * S, 0.42 * S),
		top * CFrame.new(0, 0.06 * S, 0) * CFrame.Angles(0, 0, math.pi / 2),
		GOLD,
		{ Material = Enum.Material.Neon, Tint = false }
	)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		add(
			ctx,
			"Wedge",
			Vector3.new(0.05 * S, 0.16 * S, 0.1 * S),
			top
				* CFrame.new(math.cos(a) * 0.18 * S, 0.19 * S, math.sin(a) * 0.18 * S)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			GOLD,
			{ Material = Enum.Material.Neon, Tint = false }
		)
	end
end

-- Body plans -------------------------------------------------------------------------------

local function horns(ctx: Ctx, head: CFrame, hh: number, hd: number, style: string?)
	local S = ctx.S
	local color = ctx.Accent
	local o = { Material = ctx.AccentMaterial, Tint = false }
	if style == "Single" then
		taper(
			ctx,
			(head * CFrame.new(0, hh / 2 - 0.04 * S, -hd * 0.22)).Position,
			head:VectorToWorldSpace(Vector3.new(0, 1, -0.55)),
			0.62 * S,
			0.14 * S,
			GOLD:Lerp(color, 0.3),
			4,
			o
		)
	elseif style == "Pair" then
		for _, side in { -1, 1 } do
			local from = (head * CFrame.new(side * 0.17 * S, hh / 2 - 0.06 * S, 0.06 * S)).Position
			taper(
				ctx,
				from,
				head:VectorToWorldSpace(Vector3.new(side * 0.35, 0.8, 0.5)),
				0.42 * S,
				0.11 * S,
				color,
				3,
				o
			)
		end
	elseif style == "Antlers" then
		for _, side in { -1, 1 } do
			local from = (head * CFrame.new(side * 0.14 * S, hh / 2 - 0.03 * S, 0.05 * S)).Position
			local mainDir = head:VectorToWorldSpace(Vector3.new(side * 0.5, 1, 0.25))
			local tip = taper(ctx, from, mainDir, 0.62 * S, 0.08 * S, color, 3, o)
			local mid = from:Lerp(tip, 0.45)
			taper(ctx, mid, head:VectorToWorldSpace(Vector3.new(side * 0.1, 1, -0.5)), 0.3 * S, 0.06 * S, color, 2, o)
			local high = from:Lerp(tip, 0.8)
			taper(ctx, high, head:VectorToWorldSpace(Vector3.new(side * 1, 0.5, 0)), 0.26 * S, 0.05 * S, color, 2, o)
		end
	end
end

local function ears(ctx: Ctx, head: CFrame, hh: number, style: string?)
	local S = ctx.S
	for _, side in { -1, 1 } do
		if style == "Pointy" then
			local base = head
				* CFrame.new(side * 0.2 * S, hh / 2 + 0.06 * S, 0.04 * S)
				* CFrame.Angles(0, side * math.pi / 2, side * -0.15)
			add(ctx, "Wedge", Vector3.new(0.07 * S, 0.34 * S, 0.24 * S), base, ctx.Body)
			add(
				ctx,
				"Wedge",
				Vector3.new(0.03 * S, 0.22 * S, 0.14 * S),
				base * CFrame.new(side * 0.03 * S, -0.04 * S, 0.01 * S),
				ctx.Accent,
				{ Tint = false }
			)
		elseif style == "Long" then
			local base = head
				* CFrame.new(side * 0.13 * S, hh / 2 + 0.26 * S, 0.06 * S)
				* CFrame.Angles(0.15, 0, -side * 0.16)
			add(ctx, "Ellipsoid", Vector3.new(0.17 * S, 0.66 * S, 0.1 * S), base, ctx.Body)
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.09 * S, 0.5 * S, 0.06 * S),
				base * CFrame.new(0, -0.02 * S, -0.03 * S),
				ctx.Accent,
				{ Tint = false }
			)
		elseif style == "Round" then
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.24 * S, 0.24 * S, 0.08 * S),
				head * CFrame.new(side * 0.26 * S, hh / 2 - 0.02 * S, 0.02 * S),
				ctx.Body
			)
		elseif style == "Tufts" then
			add(
				ctx,
				"Wedge",
				Vector3.new(0.05 * S, 0.24 * S, 0.14 * S),
				head
					* CFrame.new(side * 0.2 * S, hh / 2 + 0.06 * S, 0.06 * S)
					* CFrame.Angles(0, side * math.pi / 2, side * -0.4),
				ctx.Accent,
				{ Tint = false }
			)
		end
	end
end

local function tail(ctx: Ctx, rear: Vector3, style: string?, low: boolean?)
	local S = ctx.S
	local hinge = CFrame.new(rear)
	local wag = { Hinge = hinge, Anim = "Wag" }
	if style == "Bushy" then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.34 * S, 0.34 * S, 0.8 * S),
			CFrame.Angles(-0.65, 0, 0) * CFrame.new(0, 0, 0.36 * S),
			ctx.Body,
			wag
		)
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.27 * S, 0.27 * S, 0.32 * S),
			CFrame.Angles(-0.65, 0, 0) * CFrame.new(0, 0, 0.72 * S),
			ctx.Accent,
			{ Hinge = hinge, Anim = "Wag", Tint = false }
		)
	elseif style == "Long" then
		local tilt = if low then -0.05 else -0.25
		for i = 0, 3 do
			local w = (0.26 - i * 0.05) * S
			local color = if i == 3 then ctx.Accent else ctx.Body
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(w, w, 0.42 * S),
				CFrame.Angles(tilt + i * 0.12, 0, 0) * CFrame.new(0, 0, 0.18 * S + i * 0.34 * S),
				color,
				{ Hinge = hinge, Anim = "Wag", Param = i * 0.35, Tint = i < 3 }
			)
		end
	elseif style == "Puff" then
		add(
			ctx,
			"Ball",
			Vector3.one * 0.34 * S,
			CFrame.new(rear + Vector3.new(0, 0.04 * S, 0.1 * S)),
			ctx.Belly,
			{ Tint = false }
		)
	elseif style == "Short" then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.18 * S, 0.2 * S, 0.26 * S),
			CFrame.new(rear + Vector3.new(0, 0.08 * S, 0.08 * S)),
			ctx.Body
		)
	elseif style == "Stinger" then
		local p = rear
		for i = 0, 4 do
			local phi = 0.5 + i * 0.5 -- sweep from "backwards" to "up and over"
			local dir = Vector3.new(0, math.sin(phi), math.cos(phi))
			local center = p + dir * 0.15 * S
			add(ctx, "Ball", Vector3.one * (0.24 - i * 0.025) * S, CFrame.new(center), ctx.Body, { Tint = true })
			p += dir * 0.26 * S
		end
		taper(
			ctx,
			p,
			Vector3.new(0, -0.3, -1),
			0.28 * S,
			0.12 * S,
			Color3.fromRGB(255, 60, 70),
			3,
			{ Material = Enum.Material.Neon, Tint = false }
		)
	end
end

local function quadruped(ctx: Ctx, o: { [string]: any })
	local S = ctx.S
	local low, horse = o.Low, o.Horse
	local bw, bh, bl = 0.82 * S, (if low then 0.55 else 0.74) * S, (if low then 1.45 else 1.22) * S
	if horse then
		bw, bh, bl = 0.72 * S, 0.72 * S, 1.3 * S
	end
	add(ctx, "Ellipsoid", Vector3.new(bw, bh, bl), CFrame.identity, ctx.Body, { Name = "Body" })
	add(
		ctx,
		"Ellipsoid",
		Vector3.new(bw * 0.82, bh * 0.7, bl * 0.8),
		CFrame.new(0, -bh * 0.18, -0.04 * S),
		ctx.Belly,
		{ Tint = false }
	)

	-- Head (+ neck for horses)
	local head: CFrame
	local hw, hh, hd = 0.7 * S, 0.64 * S, 0.66 * S
	if horse then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.38 * S, 0.85 * S, 0.42 * S),
			CFrame.new(0, 0.42 * S, -0.48 * S) * CFrame.Angles(-0.45, 0, 0),
			ctx.Body
		)
		hw, hh, hd = 0.44 * S, 0.46 * S, 0.62 * S
		head = CFrame.new(0, 0.86 * S, -0.72 * S) * CFrame.Angles(-0.25, 0, 0)
	elseif low then
		head = CFrame.new(0, 0.1 * S, -0.88 * S)
		hw, hh, hd = 0.62 * S, 0.44 * S, 0.62 * S
	else
		head = CFrame.new(0, 0.4 * S, -0.7 * S)
	end
	add(ctx, "Ellipsoid", Vector3.new(hw, hh, hd), head, ctx.Body, { Name = "Head" })
	ctx.HeadTop = head * CFrame.new(0, hh / 2, 0)

	-- Snout / beak
	local snout = o.Snout
	if snout == "Beak" then
		add(
			ctx,
			"Wedge",
			Vector3.new(0.22 * S, 0.22 * S, 0.34 * S),
			head * CFrame.new(0, -0.04 * S, -hd / 2 - 0.08 * S),
			GOLD:Lerp(ctx.Accent, 0.3),
			{ Tint = false }
		)
	elseif snout == "Long" then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(hw * 0.5, hh * 0.5, hd * 0.75),
			head * CFrame.new(0, -hh * 0.18, -hd * 0.45),
			ctx.Belly,
			{ Tint = false }
		)
		add(
			ctx,
			"Ball",
			Vector3.one * 0.1 * S,
			head * CFrame.new(0, -hh * 0.08, -hd * 0.82),
			ctx.Dark,
			{ Tint = false }
		)
	elseif snout == "Short" then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(hw * 0.5, hh * 0.42, hd * 0.4),
			head * CFrame.new(0, -hh * 0.2, -hd * 0.38),
			ctx.Belly,
			{ Tint = false }
		)
		add(
			ctx,
			"Ball",
			Vector3.one * 0.09 * S,
			head * CFrame.new(0, -hh * 0.06, -hd * 0.56),
			ctx.Dark,
			{ Tint = false }
		)
	elseif snout == "Flat" then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(hw * 0.85, hh * 0.25, hd * 0.5),
			head * CFrame.new(0, -hh * 0.25, -hd * 0.3),
			ctx.Belly,
			{ Tint = false }
		)
	end

	-- Eyes
	if o.BigEyes then
		eyes(ctx, head, hw * 0.3, hh * 0.45, -hd * 0.22, 0.27 * S)
	elseif horse then
		eyes(ctx, head, hw * 0.4, hh * 0.12, -hd * 0.18, 0.13 * S)
	else
		eyes(ctx, head, hw * 0.25, hh * 0.1, -hd * 0.4, 0.17 * S)
	end

	ears(ctx, head, hh, o.Ears)
	horns(ctx, head, hh, hd, o.Horn)

	-- Mane along the neck / back
	if o.Mane then
		local from = (head * CFrame.new(0, hh / 2, hd * 0.25)).Position
		local to = Vector3.new(0, bh * 0.45, -bl * 0.15)
		for i = 0, 4 do
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.2 * S, 0.3 * S, 0.26 * S),
				CFrame.new(from:Lerp(to, i / 4)),
				ctx.Accent,
				{ Material = ctx.AccentMaterial, Tint = false }
			)
		end
	end

	if o.LionMane then
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.3 * S, 0.3 * S, 0.22 * S),
				head * CFrame.new(math.cos(a) * hw * 0.55, math.sin(a) * hh * 0.6, hd * 0.12),
				ctx.Accent,
				{ Material = ctx.AccentMaterial, Tint = false }
			)
		end
	end

	-- Back spikes
	if o.Spikes then
		for i = 0, 3 do
			local z = -bl * 0.32 + i * bl * 0.22
			add(
				ctx,
				"Wedge",
				Vector3.new(0.06 * S, 0.22 * S, 0.24 * S),
				CFrame.new(0, bh / 2 - 0.02 * S, z),
				ctx.Accent,
				{ Material = ctx.AccentMaterial, Tint = false }
			)
		end
	end

	-- Spots
	if o.Spots then
		for i = 0, 4 do
			local a = i * 1.3
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.16 * S, 0.06 * S, 0.16 * S),
				CFrame.new(math.sin(a) * bw * 0.25, bh * 0.47, math.cos(a) * bl * 0.3),
				ctx.Accent,
				{ Tint = false }
			)
		end
	end

	-- Legs (paddle in the air while floating)
	local legLen = (if low then 0.34 elseif horse then 0.7 else 0.48) * S
	local legDia = (if horse then 0.16 else 0.2) * S
	local top = -bh * 0.22
	for i, pos in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = pos[1] * bw * 0.3, pos[2] * bl * 0.3
		local hinge = CFrame.new(x, top, z)
		local phase = if i == 1 or i == 4 then 0 else math.pi
		add(
			ctx,
			"Cylinder",
			Vector3.new(legLen, legDia, legDia),
			CFrame.new(0, -legLen / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			ctx.Body,
			{
				Hinge = hinge,
				Anim = "Leg",
				Param = phase,
			}
		)
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(legDia * 1.25, legDia * 0.7, legDia * 1.45),
			CFrame.new(0, -legLen, -legDia * 0.15),
			if horse then ctx.Dark else ctx.Belly,
			{
				Hinge = hinge,
				Anim = "Leg",
				Param = phase,
				Tint = false,
			}
		)
	end

	tail(ctx, Vector3.new(0, bh * 0.12, bl / 2 - 0.04 * S), o.Tail, low)

	if o.Wings then
		wings(ctx, o.Wings, Vector3.new(bw * 0.32, bh * 0.38, -0.12 * S), if o.Wings == "Bat" then 1.05 else 1.1)
	end
end

local function bird(ctx: Ctx, o: { [string]: any })
	local S = ctx.S
	add(ctx, "Ellipsoid", Vector3.new(0.8 * S, 0.86 * S, 0.88 * S), CFrame.identity, ctx.Body, { Name = "Body" })
	add(
		ctx,
		"Ellipsoid",
		Vector3.new(0.6 * S, 0.66 * S, 0.5 * S),
		CFrame.new(0, -0.08 * S, -0.22 * S),
		ctx.Belly,
		{ Tint = false }
	)
	local head = CFrame.new(0, 0.5 * S, -0.18 * S)
	local hh = 0.62 * S
	add(ctx, "Ball", Vector3.one * 0.62 * S, head, ctx.Body, { Name = "Head" })
	ctx.HeadTop = head * CFrame.new(0, hh / 2, 0)
	if o.FaceDisc then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.5 * S, 0.44 * S, 0.12 * S),
			head * CFrame.new(0, -0.02 * S, -0.26 * S),
			ctx.Belly,
			{ Tint = false }
		)
	end
	eyes(ctx, head, 0.13 * S, 0.04 * S, -0.27 * S, 0.17 * S)
	add(
		ctx,
		"Wedge",
		Vector3.new(0.14 * S, 0.14 * S, 0.22 * S),
		head * CFrame.new(0, -0.1 * S, -0.36 * S) * CFrame.Angles(0.5, 0, 0),
		GOLD,
		{ Tint = false }
	)
	ears(ctx, head, hh, o.Ears)
	if o.Crest then
		for i = -1, 1 do
			taper(
				ctx,
				(head * CFrame.new(i * 0.08 * S, hh / 2 - 0.05 * S, 0)).Position,
				Vector3.new(i * 0.25, 1, 0.7),
				0.4 * S,
				0.08 * S,
				ctx.Accent,
				3,
				{ Material = ctx.AccentMaterial, Tint = false }
			)
		end
	end
	-- Tail feathers
	local length = if o.LongTail then 1.3 else 0.6
	for i = -1, 1 do
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.16 * S, 0.06 * S, length * S),
			CFrame.new(i * 0.1 * S, -0.1 * S, 0.4 * S)
				* CFrame.Angles(0.35, i * 0.3, 0)
				* CFrame.new(0, 0, length * S / 2),
			if i == 0 then ctx.Accent else ctx.Body,
			{ Material = if i == 0 then ctx.AccentMaterial else nil, Hinge = CFrame.identity, Anim = "Wag", Param = i }
		)
	end
	-- Feet
	for _, side in { -1, 1 } do
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.14 * S, 0.06 * S, 0.2 * S),
			CFrame.new(side * 0.16 * S, -0.46 * S, -0.06 * S),
			GOLD,
			{ Tint = false }
		)
	end
	wings(ctx, "Feather", Vector3.new(0.34 * S, 0.12 * S, 0), 1.15)
end

local function sprite(ctx: Ctx, o: { [string]: any })
	local S = ctx.S
	local head: CFrame
	if o.Imp then
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.56 * S, 0.62 * S, 0.5 * S),
			CFrame.new(0, -0.18 * S, 0),
			ctx.Body,
			{ Name = "Body" }
		)
		head = CFrame.new(0, 0.32 * S, -0.04 * S)
		add(ctx, "Ball", Vector3.one * 0.62 * S, head, ctx.Body, { Name = "Head" })
		for _, side in { -1, 1 } do
			add(
				ctx,
				"Cylinder",
				Vector3.new(0.34 * S, 0.12 * S, 0.12 * S),
				CFrame.new(side * 0.3 * S, -0.12 * S, -0.06 * S) * CFrame.Angles(0, 0, side * 0.9),
				ctx.Body
			)
			add(
				ctx,
				"Cylinder",
				Vector3.new(0.3 * S, 0.14 * S, 0.14 * S),
				CFrame.new(side * 0.13 * S, -0.55 * S, 0) * CFrame.Angles(0, 0, math.pi / 2),
				ctx.Dark,
				{ Tint = false }
			)
		end
	else
		head = CFrame.identity
		local coreColor = if o.Glow then ctx.Body else ctx.Body
		add(
			ctx,
			"Ball",
			Vector3.one * 0.72 * S,
			head,
			coreColor,
			{ Name = "Body", Material = if o.Glow then Enum.Material.Neon else nil }
		)
		if o.Glow then
			add(
				ctx,
				"Ball",
				Vector3.one * 0.98 * S,
				head,
				ctx.Accent,
				{ Material = Enum.Material.Glass, Transparency = 0.65, Tint = false }
			)
		end
		if o.Fluff then
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.6 * S, 0.3 * S, 0.5 * S),
				CFrame.new(0, -0.22 * S, 0.05 * S),
				ctx.Belly,
				{ Tint = false }
			)
			add(ctx, "Ellipsoid", Vector3.new(0.4 * S, 0.5 * S, 0.7 * S), CFrame.new(0, -0.35 * S, 0.35 * S), ctx.Body)
		end
	end
	ctx.HeadTop = head * CFrame.new(0, 0.33 * S, 0)
	eyes(ctx, head, 0.14 * S, 0.06 * S, -0.27 * S, 0.17 * S)
	horns(ctx, head, 0.62 * S, 0.62 * S, o.Horn)
	if o.Antennae then
		for _, side in { -1, 1 } do
			local tip = taper(
				ctx,
				(head * CFrame.new(side * 0.1 * S, 0.3 * S, -0.05 * S)).Position,
				Vector3.new(side * 0.4, 1, -0.3),
				0.4 * S,
				0.04 * S,
				ctx.Dark,
				2,
				{ Tint = false }
			)
			add(
				ctx,
				"Ball",
				Vector3.one * 0.12 * S,
				CFrame.new(tip),
				ctx.Accent,
				{ Material = Enum.Material.Neon, Tint = false }
			)
		end
	end
	if o.Wings then
		wings(ctx, o.Wings, Vector3.new(0.2 * S, 0.1 * S, 0.18 * S), if o.Wings == "Bat" then 0.8 else 1)
	end
	if o.Tail then
		tail(ctx, Vector3.new(0, -0.4 * S, 0.2 * S), o.Tail, false)
	end
	if o.WispTail then
		for i = 1, 4 do
			local size = (0.5 - i * 0.09) * S
			add(ctx, "Ball", Vector3.one * size, CFrame.new(0, 0.05 * S * i, 0.22 * S + i * 0.22 * S), ctx.Accent, {
				Hinge = CFrame.identity,
				Anim = "Wave",
				Param = i,
				Material = Enum.Material.Neon,
				Transparency = 0.25 + i * 0.1,
				Tint = false,
			})
		end
	end
	if o.Shards then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local dir = Vector3.new(math.cos(a), math.sin(a) * 0.8, 0.25)
			taper(
				ctx,
				dir.Unit * 0.38 * S,
				dir,
				0.42 * S,
				0.14 * S,
				ctx.Accent:Lerp(WHITE, 0.3),
				3,
				{ Material = Enum.Material.Glass, Tint = false }
			)
		end
	end
	if o.Orbiters then
		for i = 0, 2 do
			add(ctx, "Ball", Vector3.one * 0.16 * S, CFrame.new(0.75 * S, (i - 1) * 0.15 * S, 0), ctx.Accent, {
				Material = Enum.Material.Neon,
				Hinge = CFrame.identity,
				Anim = "Orbit",
				Param = i * math.pi * 2 / 3,
				Tint = false,
			})
		end
	end
end

local function serpent(ctx: Ctx, o: { [string]: any })
	local S = ctx.S
	local n = o.Segments or 7
	local spacing = 0.3 * S
	local head = CFrame.new(0, 0.15 * S, -0.5 * S)
	-- everything on the head shares its hinge so it moves with the wave
	local function headOpts(extra: { [string]: any }?): AddOpts
		local t: { [string]: any } = { Hinge = head, Anim = "Wave", Param = 0 }
		for k, v in extra or {} do
			t[k] = v
		end
		return t :: any
	end
	add(
		ctx,
		"Ellipsoid",
		Vector3.new(0.72 * S, 0.6 * S, 0.8 * S),
		CFrame.identity,
		ctx.Body,
		headOpts({ Name = "Head" })
	)
	ctx.HeadTop = head * CFrame.new(0, 0.3 * S, 0.05 * S)
	-- Long dragon snout with a lighter jaw and nostrils
	add(
		ctx,
		"Ellipsoid",
		Vector3.new(0.48 * S, 0.34 * S, 0.62 * S),
		CFrame.new(0, -0.04 * S, -0.48 * S),
		ctx.Body,
		headOpts()
	)
	add(
		ctx,
		"Ellipsoid",
		Vector3.new(0.42 * S, 0.18 * S, 0.56 * S),
		CFrame.new(0, -0.17 * S, -0.42 * S),
		ctx.Belly,
		headOpts({ Tint = false })
	)
	for _, side in { -1, 1 } do
		add(
			ctx,
			"Ball",
			Vector3.one * 0.07 * S,
			CFrame.new(side * 0.1 * S, 0.06 * S, -0.76 * S),
			ctx.Dark,
			headOpts({ Tint = false })
		)
		-- Eyes on the sides of the head, with a brow ridge
		add(
			ctx,
			"Ball",
			Vector3.one * 0.2 * S,
			CFrame.new(side * 0.27 * S, 0.1 * S, -0.16 * S),
			Color3.fromRGB(20, 18, 30),
			headOpts({ Tint = false })
		)
		add(
			ctx,
			"Ball",
			Vector3.one * 0.08 * S,
			CFrame.new(side * 0.33 * S, 0.15 * S, -0.22 * S),
			WHITE,
			headOpts({ Material = Enum.Material.Neon, Tint = false })
		)
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(0.22 * S, 0.08 * S, 0.3 * S),
			CFrame.new(side * 0.24 * S, 0.23 * S, -0.14 * S) * CFrame.Angles(0, 0, side * 0.3),
			ctx.Dark,
			headOpts({ Tint = false })
		)
		if o.Horn then
			-- Swept-back horns, built as tapered segments in head space
			local hornBase = Vector3.new(side * 0.18 * S, 0.24 * S, 0.12 * S)
			local dir = Vector3.new(side * 0.35, 0.55, 1).Unit
			local segLen = 0.2 * S
			for i = 0, 2 do
				local center = hornBase + dir * segLen * (i + 0.5)
				local dia = 0.13 * S * (1 - i * 0.28)
				local cf = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.pi / 2, 0)
				add(
					ctx,
					"Cylinder",
					Vector3.new(segLen * 1.05, dia, dia),
					cf,
					ctx.Accent,
					headOpts({ Material = ctx.AccentMaterial, Tint = false })
				)
			end
		end
		if o.Whiskers then
			for i = 0, 2 do
				local dir = Vector3.new(side, -0.25 - i * 0.2, 0.15 * i).Unit
				local from = Vector3.new(side * 0.2 * S, -0.08 * S, -0.62 * S)
				local center = from + dir * (0.18 + i * 0.1) * S
				local cf = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.pi / 2, 0)
				add(
					ctx,
					"Cylinder",
					Vector3.new((0.36 + i * 0.2) * S, 0.035 * S, 0.035 * S),
					cf,
					ctx.Accent,
					headOpts({ Tint = false })
				)
			end
		end
		if o.Fins then
			add(
				ctx,
				"Wedge",
				Vector3.new(0.04 * S, 0.3 * S, 0.34 * S),
				CFrame.new(side * 0.34 * S, 0.02 * S, 0.12 * S) * CFrame.Angles(0, side * math.pi / 2, side * -0.9),
				ctx.Accent,
				headOpts({ Material = ctx.AccentMaterial, Tint = false })
			)
		end
	end
	-- Body: segments that taper towards the tail, with a lighter belly plate on each
	for i = 1, n do
		local f = (i - 1) / math.max(n - 1, 1)
		local size = (0.62 - f * 0.42) * S
		local hinge = CFrame.new(0, 0, -0.1 * S + i * spacing)
		local function segOpts(extra: { [string]: any }?): AddOpts
			local t: { [string]: any } = { Hinge = hinge, Anim = "Wave", Param = i }
			for k, v in extra or {} do
				t[k] = v
			end
			return t :: any
		end
		add(ctx, "Ball", Vector3.one * size, CFrame.identity, ctx.Body, segOpts({ Tint = true }))
		add(
			ctx,
			"Ellipsoid",
			Vector3.new(size * 0.8, size * 0.5, size * 0.9),
			CFrame.new(0, -size * 0.22, 0),
			ctx.Belly,
			segOpts({ Tint = false })
		)
		if o.Fins and i % 2 == 1 and i < n then
			add(
				ctx,
				"Wedge",
				Vector3.new(0.05 * S, size * 0.65, size * 0.75),
				CFrame.new(0, size * 0.48, 0),
				ctx.Accent,
				segOpts({ Material = ctx.AccentMaterial, Tint = false })
			)
		end
		if o.Mane and i <= 4 then
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.16 * S, 0.34 * S, 0.26 * S),
				CFrame.new(0, size * 0.5, 0) * CFrame.Angles(0.5, 0, 0),
				ctx.Accent,
				segOpts({ Material = ctx.AccentMaterial, Tint = false })
			)
		end
		if i == n then
			-- Tail tip: a fluke
			add(
				ctx,
				"Ellipsoid",
				Vector3.new(0.7 * S, 0.06 * S, 0.34 * S),
				CFrame.new(0, 0, size * 0.6),
				ctx.Accent,
				segOpts({ Material = ctx.AccentMaterial, Tint = false })
			)
		end
	end
end

-- Effects ----------------------------------------------------------------------------------

local function effects(ctx: Ctx, def: Creatures.CreatureDef, variant: string, plan: { [string]: any }, order: number)
	local root = ctx.Root :: BasePart
	if order >= 4 or plan.Glow then
		local light = Instance.new("PointLight")
		light.Color = def.Accent
		light.Range = 5 + order
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = root
	end
	if plan.Fire then
		local target = root
		if plan.Fire == "Tail" then
			-- attach to the last tail piece
			for i = #ctx.Pieces, 1, -1 do
				if ctx.Pieces[i].Anim == "Wag" then
					target = ctx.Pieces[i].Part
					break
				end
			end
		end
		local fire = Instance.new("Fire")
		fire.Color = def.Accent
		fire.SecondaryColor = def.Color
		fire.Size = 2 * ctx.S
		fire.Heat = 4
		fire.Parent = target
	end
	if plan.Aura or order >= 6 then
		local aura = Instance.new("ParticleEmitter")
		aura.Rate = 10
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(0.4, 1.2)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * ctx.S), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.2, 1)
		aura.LightEmission = 1
		aura.Color = ColorSequence.new(def.Accent, def.Color)
		aura.Parent = root
	end
	if variant ~= "Normal" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "VariantSparkle"
		sparkle.Rate = if variant == "Rainbow" or variant == "Huge" then 14 else 7
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22 * ctx.S), NumberSequenceKeypoint.new(1, 0) })
		sparkle.LightEmission = 1
		sparkle.Color = if variant == "Rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
			})
			else ColorSequence.new(Color3.fromRGB(255, 235, 140))
		sparkle.Parent = root
	end
end

-- Imported meshes ----------------------------------------------------------------------------
--[[
	If ReplicatedStorage.CreatureMeshes contains a Model (or MeshPart) named after a creature Id
	(e.g. "EmberFox"), that mesh is used instead of the procedural body. Import the Higgsfield GLB
	files with Studio's 3D Importer - see docs/CREATURE_MESHES.md.

	Optional attributes on the imported model:
	  Yaw   (number, degrees)  rotate so the creature faces Roblox's front (-Z)
	  Scale (number)           extra size multiplier
	  Lift  (number, studs)    move the model up/down relative to its centre
]]

local function getMeshTemplate(id: string): Instance?
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:FindFirstChild("CreatureMeshes")
	local template = folder and folder:FindFirstChild(id)
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		return template
	end
	return nil
end

local announced: { [string]: boolean } = {}

local function buildFromMesh(
	template: Instance,
	def: Creatures.CreatureDef,
	variant: string,
	plan: { [string]: any },
	scale: number?
): Rig
	if not announced[def.Id] then
		announced[def.Id] = true
		print(`[Mythic Tamers] {def.Id} is using your imported 3D model`)
	end
	local rarity = Creatures.Rarities[def.Rarity]
	local model: Model
	if template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		template:Clone().Parent = model
	end
	model.Name = def.Id

	-- Normalise size: the longest side matches the procedural body length for this rarity
	local S = rarity.Size * 0.72 * (scale or 1) * (tonumber(template:GetAttribute("Scale")) or 1)
	local _, extents = model:GetBoundingBox()
	local longest = math.max(extents.X, extents.Y, extents.Z, 0.01)
	model:ScaleTo(model:GetScale() * (2.3 * S) / longest)

	local boxCf, size = model:GetBoundingBox()
	local yaw = math.rad(tonumber(template:GetAttribute("Yaw")) or 0)
	local lift = tonumber(template:GetAttribute("Lift")) or 0
	-- Pieces are stored relative to the box centre, so the creature hovers around its middle
	local origin = CFrame.new(boxCf.Position + Vector3.new(0, -lift, 0))
	local spin = CFrame.Angles(0, yaw, 0)

	local pieces: { Piece } = {}
	local root: BasePart? = nil
	local biggest = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			if variant == "Shiny" then
				d.Reflectance = 0.25
			end
			local static = spin * origin:Inverse() * d.CFrame
			table.insert(pieces, {
				Part = d,
				Hinge = CFrame.identity,
				Local = static,
				Static = static,
				Anim = "Sway",
				Param = 0,
				Side = 1,
				Amp = S,
				Tint = false,
			})
			local volume = d.Size.X * d.Size.Y * d.Size.Z
			if volume > biggest then
				biggest, root = volume, d
			end
		end
	end
	assert(root, "Creature mesh " .. def.Id .. " has no parts")

	local ctx: Ctx = {
		Model = model,
		Pieces = pieces,
		S = S,
		Body = def.Color,
		Accent = def.Accent,
		Belly = def.Color,
		Dark = def.Color,
		AccentMaterial = Enum.Material.Neon,
		Reflectance = 0,
		HeadTop = nil,
		Root = root,
	}
	effects(ctx, def, variant, plan, rarity.Order)
	if variant == "Rainbow" then
		-- Meshes keep their texture, so Rainbow gets a colour-cycling glow instead (see Pose)
		local glow = Instance.new("Highlight")
		glow.Name = "RainbowGlow"
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.FillTransparency = 0.75
		glow.OutlineTransparency = 0.2
		glow.Parent = model
	end

	local parts, cframes = {}, {}
	for i, piece in pieces do
		parts[i] = piece.Part
		cframes[i] = piece.Static
		piece.Part.CFrame = piece.Static
	end
	model.PrimaryPart = root
	return {
		Model = model,
		Pieces = pieces,
		Parts = parts,
		CFrames = cframes,
		Radius = size.Magnitude / 2,
		Rainbow = variant == "Rainbow",
		LastTint = -1,
	}
end

-- Public API -------------------------------------------------------------------------------

-- scale multiplies the rarity-based size (1 = follower size)
function CreatureModels.Build(id: string, variant: string?, scale: number?): Rig
	local def = Creatures.Get(id) :: Creatures.CreatureDef
	assert(def, "Unknown creature " .. tostring(id))
	local v = variant or "Normal"
	-- HUGE pets are drawn much bigger
	local vdef = Creatures.Variants[v]
	if vdef and vdef.Scale then
		scale = (scale or 1) * vdef.Scale
	end
	local plan = PLANS[id] or { Type = "Quadruped", Ears = "Pointy", Tail = "Bushy", Snout = "Short" }
	local template = getMeshTemplate(id)
	if template then
		return buildFromMesh(template, def, v, plan, scale)
	end
	local rarity = Creatures.Rarities[def.Rarity]
	local order = rarity.Order

	local body, accent = def.Color, def.Accent
	local reflectance = 0
	if v == "Shiny" then
		body = body:Lerp(GOLD, 0.45)
		accent = accent:Lerp(WHITE, 0.25)
		reflectance = 0.25
	elseif v == "Huge" then
		reflectance = 0.1
	end

	local model = Instance.new("Model")
	model.Name = id
	local ctx: Ctx = {
		Model = model,
		Pieces = {},
		S = rarity.Size * 0.72 * (scale or 1),
		Body = body,
		Accent = accent,
		Belly = body:Lerp(WHITE, 0.45),
		Dark = body:Lerp(BLACK, 0.5),
		AccentMaterial = if order >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Reflectance = reflectance,
		HeadTop = nil,
		Root = nil,
	}

	if plan.Type == "Bird" then
		bird(ctx, plan)
	elseif plan.Type == "Sprite" then
		sprite(ctx, plan)
	elseif plan.Type == "Serpent" then
		serpent(ctx, plan)
	else
		quadruped(ctx, plan)
	end
	if def.Rarity == "Champion" then
		crown(ctx)
	end
	effects(ctx, def, v, plan, order)

	local radius = 0
	local parts, cframes = {}, {}
	for i, piece in ctx.Pieces do
		parts[i] = piece.Part
		cframes[i] = piece.Static
		piece.Part.CFrame = piece.Static
		local reach = piece.Static.Position.Magnitude + piece.Part.Size.Magnitude / 2
		radius = math.max(radius, reach)
	end
	model.PrimaryPart = ctx.Root

	return {
		Model = model,
		Pieces = ctx.Pieces,
		Parts = parts,
		CFrames = cframes,
		Radius = radius,
		Rainbow = v == "Rainbow",
		LastTint = -1,
	}
end

-- Computes every part's CFrame for this frame into rig.CFrames (does not move parts).
function CreatureModels.Pose(rig: Rig, root: CFrame, t: number)
	local cframes = rig.CFrames
	for i, p in rig.Pieces do
		local anim = p.Anim
		if anim == nil then
			cframes[i] = root * p.Static
		else
			local a: CFrame
			if anim == "Flap" then
				a = CFrame.Angles(0, 0, p.Side * (math.sin(t * 9 + p.Param) * 0.45 + 0.45))
			elseif anim == "Wag" then
				a = CFrame.Angles(0, math.sin(t * 4 - p.Param) * 0.35, 0)
			elseif anim == "Leg" then
				a = CFrame.Angles(math.sin(t * 5 + p.Param) * 0.35, 0, 0)
			elseif anim == "Wave" then
				a = CFrame.new(
					math.sin(t * 2 - p.Param * 0.6) * 0.12 * p.Amp,
					math.sin(t * 3 - p.Param * 0.8) * 0.16 * p.Amp,
					0
				)
			elseif anim == "Sway" then
				a = CFrame.Angles(math.sin(t * 2.2) * 0.07, math.sin(t * 1.3) * 0.08, math.sin(t * 1.7) * 0.05)
			elseif anim == "Orbit" then
				a = CFrame.Angles(0, t * 2.5 + p.Param, 0)
			else
				a = CFrame.identity
			end
			cframes[i] = root * p.Hinge * a * p.Local
		end
	end
	-- Rainbow variants slowly cycle through the colour wheel
	if rig.Rainbow and t - rig.LastTint > 0.1 then
		rig.LastTint = t
		local glow = rig.Model:FindFirstChild("RainbowGlow") :: Highlight?
		if glow then
			local hue = Color3.fromHSV((t * 0.15) % 1, 0.7, 1)
			glow.FillColor = hue
			glow.OutlineColor = hue
		end
		for i, p in rig.Pieces do
			if p.Tint then
				p.Part.Color = Color3.fromHSV((t * 0.15 + i * 0.03) % 1, 0.55, 1)
			end
		end
	end
end

-- Positions parts directly (for ViewportFrames / statues, which aren't animated every frame).
function CreatureModels.Place(rig: Rig, root: CFrame, t: number?)
	CreatureModels.Pose(rig, root, t or 0.35)
	for i, part in rig.Parts do
		part.CFrame = rig.CFrames[i]
	end
end

-- A ViewportFrame showing the creature from a flattering 3/4 front angle.
function CreatureModels.Viewport(id: string, variant: string?, props: { [string]: any }?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 190)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	for k, v in props or {} do
		(viewport :: any)[k] = v
	end
	local rig = CreatureModels.Build(id, variant)
	CreatureModels.Place(rig, CFrame.identity)
	-- Static viewports can't animate the rainbow, so give rainbow creatures a fixed spread of hues
	if rig.Rainbow then
		for i, p in rig.Pieces do
			if p.Tint then
				p.Part.Color = Color3.fromHSV((i * 0.09) % 1, 0.55, 1)
			end
		end
	end
	rig.Model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local r = rig.Radius
	local distance = r / math.tan(math.rad(15)) * 1.05
	local dir = Vector3.new(0.55, 0.35, -1).Unit
	camera.CFrame = CFrame.lookAt(dir * distance, Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

function CreatureModels.HasMesh(id: string): boolean
	return getMeshTemplate(id) ~= nil
end

function CreatureModels.HasPlan(id: string): boolean
	return PLANS[id] ~= nil
end

return CreatureModels
