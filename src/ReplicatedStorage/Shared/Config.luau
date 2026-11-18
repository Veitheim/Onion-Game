-- Shared game values for server and client.
-- Tweak balancing here without touching the logic.

export type KnifeDef = {
	Name: string,
	Icon: string,
	Damage: number,
	Cost: number,
	Color: Color3,
	Material: Enum.Material,
}

export type BagDef = {
	Name: string,
	Icon: string,
	Capacity: number,
	Cost: number,
}

export type SkillDef = {
	Name: string,
	Icon: string,
	Desc: string,
	Branch: number,
	Row: number,
	Max: number,
	Requires: string?,
}

export type PrizeDef = {
	Id: string,
	DisplayName: string,
	Weight: number,
	Coins: number,
	SkillPoints: number,
	Color: Color3,
	Golden: boolean?,
}

local Config = {}

-- Onion
Config.LayerCount = 12
Config.OuterRadius = 40
Config.InnerRadius = 6
Config.OnionPosition = Vector3.new(0, 0, 0) -- only X/Z are used
Config.GroundY = 2 -- top of the cutting board

-- Layer health
Config.BaseLayerHP = 30
Config.LayerHPGrowth = 1.28 -- inner layers are thicker
Config.OnionHPGrowth = 1.2 -- every new onion is thicker
Config.PlayerHPFactor = 0.6 -- more players = more HP

-- Rules
Config.MaxPeelDistance = 35 -- studs from the surface
Config.BaseSwingInterval = 0.16 -- seconds between peels at Quick Hands 0
Config.CoreRevealTime = 1.5
Config.RespawnDelay = 8
Config.ChunkCount = 18
Config.ChunkLifetime = 25
Config.ChunkPeelShare = 0.6 -- share of a layer's HP dropped as collectible peels
Config.SkillPointsPerLayer = 1

Config.Faces = { "🙂", "😐", "😕", "😟", "😢", "😭", "😱", "💀" }

Config.Knives = {
	{ Name = "Butter Knife", Icon = "🧈", Damage = 1, Cost = 0, Color = Color3.fromRGB(205, 205, 215), Material = Enum.Material.Metal },
	{ Name = "Potato Peeler", Icon = "🥔", Damage = 3, Cost = 150, Color = Color3.fromRGB(230, 120, 60), Material = Enum.Material.SmoothPlastic },
	{ Name = "Kitchen Knife", Icon = "🔪", Damage = 8, Cost = 1_000, Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Metal },
	{ Name = "Chef's Knife", Icon = "👨‍🍳", Damage = 20, Cost = 6_000, Color = Color3.fromRGB(170, 190, 210), Material = Enum.Material.Metal },
	{ Name = "Meat Cleaver", Icon = "🪓", Damage = 50, Cost = 30_000, Color = Color3.fromRGB(120, 130, 145), Material = Enum.Material.DiamondPlate },
	{ Name = "Katana", Icon = "⚔️", Damage = 120, Cost = 150_000, Color = Color3.fromRGB(235, 240, 255), Material = Enum.Material.Glass },
	{ Name = "Golden Knife", Icon = "👑", Damage = 300, Cost = 750_000, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil },
	{ Name = "Laser Knife", Icon = "⚡", Damage = 800, Cost = 4_000_000, Color = Color3.fromRGB(255, 60, 220), Material = Enum.Material.Neon },
} :: { KnifeDef }

Config.Bags = {
	{ Name = "Paper Bag", Icon = "🛍️", Capacity = 25, Cost = 0 },
	{ Name = "Basket", Icon = "🧺", Capacity = 100, Cost = 250 },
	{ Name = "Bucket", Icon = "🪣", Capacity = 400, Cost = 2_000 },
	{ Name = "Backpack", Icon = "🎒", Capacity = 1_500, Cost = 12_000 },
	{ Name = "Barrel", Icon = "🛢️", Capacity = 6_000, Cost = 80_000 },
	{ Name = "Dumpster", Icon = "🗑️", Capacity = 25_000, Cost = 500_000 },
	{ Name = "Black Hole", Icon = "🌀", Capacity = 150_000, Cost = 3_500_000 },
} :: { BagDef }

Config.Branches = {
	{ Name = "POWER", Color = Color3.fromRGB(255, 130, 50) },
	{ Name = "ECONOMY", Color = Color3.fromRGB(70, 210, 110) },
	{ Name = "LUCK", Color = Color3.fromRGB(180, 100, 255) },
}

Config.Skills = {
	Sharp = { Name = "Sharp Edge", Icon = "🗡️", Desc = "+25% peel damage per level", Branch = 1, Row = 1, Max = 5 },
	Quick = { Name = "Quick Hands", Icon = "⚡", Desc = "+10% peel speed per level", Branch = 1, Row = 2, Max = 5, Requires = "Sharp" },
	Crit = { Name = "Critical Peel", Icon = "💥", Desc = "+5% chance per level to deal 3x damage", Branch = 1, Row = 3, Max = 5, Requires = "Quick" },
	Pockets = { Name = "Deep Pockets", Icon = "👖", Desc = "+20% bag capacity per level", Branch = 2, Row = 1, Max = 5 },
	Haggler = { Name = "Haggler", Icon = "🤝", Desc = "+15% sell price per level", Branch = 2, Row = 2, Max = 5, Requires = "Pockets" },
	Magnet = { Name = "Peel Magnet", Icon = "🧲", Desc = "+6 studs peel pickup range per level", Branch = 2, Row = 3, Max = 3, Requires = "Haggler" },
	ThickSkin = { Name = "Thick Skin", Icon = "🥽", Desc = "-30% onion tears per level", Branch = 3, Row = 1, Max = 3 },
	Lucky = { Name = "Lucky Core", Icon = "🍀", Desc = "Rare core prizes +25% more likely per level", Branch = 3, Row = 2, Max = 5, Requires = "ThickSkin" },
	GoldTouch = { Name = "Golden Touch", Icon = "✨", Desc = "+2% chance per level for 10x golden peels", Branch = 3, Row = 3, Max = 3, Requires = "Lucky" },
} :: { [string]: SkillDef }

Config.Prizes = {
	{ Id = "Rings", DisplayName = "Onion Rings 🍩", Weight = 60, Coins = 150, SkillPoints = 0, Color = Color3.fromRGB(240, 200, 130) },
	{ Id = "Garlic", DisplayName = "...Garlic?! 🧄", Weight = 25, Coins = 300, SkillPoints = 1, Color = Color3.fromRGB(235, 235, 220) },
	{ Id = "Diamond", DisplayName = "DIAMOND ONION 💎", Weight = 12, Coins = 1_200, SkillPoints = 2, Color = Color3.fromRGB(120, 230, 255) },
	{ Id = "Golden", DisplayName = "GOLDEN ONION 👑", Weight = 3, Coins = 5_000, SkillPoints = 3, Color = Color3.fromRGB(255, 205, 40), Golden = true },
} :: { PrizeDef }

---------------------------------------------------------------- Formulas

function Config.GetSkillCost(currentLevel: number): number
	return currentLevel + 1
end

function Config.GetDamage(knifeIndex: number, sharp: number): number
	local knife = Config.Knives[knifeIndex] or Config.Knives[1]
	return math.max(1, math.floor(knife.Damage * (1 + 0.25 * sharp)))
end

function Config.GetSwingInterval(quick: number): number
	return Config.BaseSwingInterval / (1 + 0.1 * quick)
end

function Config.GetCritChance(crit: number): number
	return 0.05 * crit
end

function Config.GetCapacity(bagIndex: number, pockets: number): number
	local bag = Config.Bags[bagIndex] or Config.Bags[1]
	return math.floor(bag.Capacity * (1 + 0.2 * pockets))
end

function Config.GetSellPrice(haggler: number): number
	return 1 + 0.15 * haggler
end

function Config.GetPickupRange(magnet: number): number
	return 9 + 6 * magnet
end

function Config.GetTearMultiplier(thickSkin: number): number
	return math.max(0, 1 - 0.3 * thickSkin)
end

function Config.GetGoldenChance(goldTouch: number): number
	return 0.02 * goldTouch
end

function Config.GetPrizeWeight(prize: PrizeDef, lucky: number): number
	if prize.Id == "Rings" then
		return prize.Weight
	end
	return prize.Weight * (1 + 0.25 * lucky)
end

function Config.GetLayerColor(index: number): Color3
	if index == 1 then
		return Color3.fromRGB(186, 118, 84) -- dry skin
	end
	local t = (index - 2) / math.max(Config.LayerCount - 2, 1)
	return Color3.fromRGB(150, 45, 115):Lerp(Color3.fromRGB(245, 225, 240), t)
end

function Config.FormatNumber(n: number): string
	local suffixes = { "", "K", "M", "B", "T", "Qd" }
	local idx = 1
	while math.abs(n) >= 1000 and idx < #suffixes do
		n /= 1000
		idx += 1
	end
	if idx == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, suffixes[idx])
end

return Config
