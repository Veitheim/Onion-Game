-- Player progress: load/save, leaderstats, bag, shop purchases and skill tree.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Data = {
	Coins: number,
	Peels: number,
	Layers: number,
	GoldenOnions: number,
	SkillPoints: number,
	Knife: number,
	Bag: number,
	Skills: { [string]: number },
}

local PlayerData = {}

local profiles: { [Player]: Data } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("OnionPeel_v2")
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable – progress will not be saved:", result)
	end
end

local function defaultData(): Data
	local skills = {}
	for id in Config.Skills do
		skills[id] = 0
	end
	return { Coins = 0, Peels = 0, Layers = 0, GoldenOnions = 0, SkillPoints = 0, Knife = 1, Bag = 1, Skills = skills }
end

local function skill(data: Data, id: string): number
	return data.Skills[id] or 0
end

local function capacity(data: Data): number
	return Config.GetCapacity(data.Bag, skill(data, "Pockets"))
end

local function sync(player: Player, data: Data)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Coins") :: IntValue).Value = data.Coins;
		(stats:FindFirstChild("Layers") :: IntValue).Value = data.Layers;
		(stats:FindFirstChild("👑") :: IntValue).Value = data.GoldenOnions
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Peels", data.Peels)
	player:SetAttribute("Capacity", capacity(data))
	player:SetAttribute("SkillPoints", data.SkillPoints)
	player:SetAttribute("Knife", data.Knife)
	player:SetAttribute("Bag", data.Bag)
	for id in Config.Skills do
		player:SetAttribute("Skill_" .. id, skill(data, id))
	end
end

function PlayerData.Load(player: Player)
	local data = defaultData()
	local ds = store
	if ds then
		local ok, saved = pcall(function()
			return ds:GetAsync(tostring(player.UserId))
		end)
		if ok and type(saved) == "table" then
			data.Coins = tonumber(saved.Coins) or 0
			data.Peels = tonumber(saved.Peels) or 0
			data.Layers = tonumber(saved.Layers) or 0
			data.GoldenOnions = tonumber(saved.GoldenOnions) or 0
			data.SkillPoints = tonumber(saved.SkillPoints) or 0
			data.Knife = math.clamp(tonumber(saved.Knife) or 1, 1, #Config.Knives)
			data.Bag = math.clamp(tonumber(saved.Bag) or 1, 1, #Config.Bags)
			if type(saved.Skills) == "table" then
				for id, def in Config.Skills do
					data.Skills[id] = math.clamp(tonumber(saved.Skills[id]) or 0, 0, def.Max)
				end
			end
		elseif not ok then
			warn("[PlayerData] Load failed for", player.Name, saved)
		end
	end

	if not player.Parent then
		return
	end
	profiles[player] = data

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Layers", "👑" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	sync(player, data)
end

function PlayerData.Save(player: Player)
	local data = profiles[player]
	local ds = store
	if not data or not ds then
		return
	end
	local ok, err = pcall(function()
		ds:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("[PlayerData] Save failed for", player.Name, err)
	end
end

function PlayerData.Release(player: Player)
	PlayerData.Save(player)
	profiles[player] = nil
end

function PlayerData.SaveAll()
	for player in profiles do
		task.spawn(PlayerData.Save, player)
	end
end

function PlayerData.Get(player: Player): Data?
	return profiles[player]
end

function PlayerData.GetSkill(player: Player, id: string): number
	local data = profiles[player]
	return data and skill(data, id) or 0
end

-- Adds peels up to the bag capacity. Returns how many fit and whether the bag is now full.
function PlayerData.AddPeels(player: Player, amount: number): (number, boolean)
	local data = profiles[player]
	if not data then
		return 0, false
	end
	local cap = capacity(data)
	local added = math.clamp(amount, 0, cap - data.Peels)
	data.Peels += added
	sync(player, data)
	return added, data.Peels >= cap
end

function PlayerData.IsBagFull(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and data.Peels >= capacity(data)
end

-- Sells everything in the bag. Returns peels sold and coins earned.
function PlayerData.Sell(player: Player): (number, number)
	local data = profiles[player]
	if not data or data.Peels <= 0 then
		return 0, 0
	end
	local peels = data.Peels
	local coins = math.floor(peels * Config.GetSellPrice(skill(data, "Haggler")))
	data.Peels = 0
	data.Coins += coins
	sync(player, data)
	return peels, coins
end

function PlayerData.AddCoins(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.Coins += amount
	sync(player, data)
end

function PlayerData.AddSkillPoints(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.SkillPoints += amount
	sync(player, data)
end

function PlayerData.AddLayer(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	data.Layers += 1
	sync(player, data)
end

function PlayerData.AddGoldenOnion(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	data.GoldenOnions += 1
	sync(player, data)
end

-- Knives and bags are bought in order: you can only buy the next tier.
function PlayerData.BuyNextTier(player: Player, kind: "Knife" | "Bag"): (boolean, string?)
	local data = profiles[player]
	if not data then
		return false, "Not loaded"
	end
	local list = if kind == "Knife" then Config.Knives else Config.Bags
	local nextIndex = data[kind] + 1
	local def = list[nextIndex]
	if not def then
		return false, "Maxed out"
	end
	if data.Coins < def.Cost then
		return false, "Not enough coins"
	end
	data.Coins -= def.Cost
	data[kind] = nextIndex
	sync(player, data)
	return true, nil
end

function PlayerData.UpgradeSkill(player: Player, id: string): (boolean, string?)
	local data = profiles[player]
	local def = Config.Skills[id]
	if not data or not def then
		return false, "Unknown skill"
	end
	local level = skill(data, id)
	if level >= def.Max then
		return false, "Maxed out"
	end
	if def.Requires and skill(data, def.Requires) < 1 then
		return false, "Locked"
	end
	local cost = Config.GetSkillCost(level)
	if data.SkillPoints < cost then
		return false, "Not enough skill points"
	end
	data.SkillPoints -= cost
	data.Skills[id] = level + 1
	sync(player, data)
	return true, nil
end

return PlayerData
