-- DataService: loads/saves player progress and replicates it to the owning client.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
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

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		Data = Knit.CreateProperty(nil),
	},
	PlayerLoaded = Signal.new(),
})

local profiles: { [Player]: Data } = {}
local unsavable: { [Player]: boolean } = {} -- load failed: never overwrite their real save
local store: DataStore? = nil

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

function DataService:_sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Coins") :: IntValue).Value = data.Coins;
		(stats:FindFirstChild("Layers") :: IntValue).Value = data.Layers;
		(stats:FindFirstChild("👑") :: IntValue).Value = data.GoldenOnions
	end
	local snapshot = table.clone(data)
	snapshot.Skills = table.clone(data.Skills)
	self.Client.Data:SetFor(player, snapshot)
end

function DataService:_load(player: Player)
	local ds = store
	local loader = if ds
		then Promise.retryWithDelay(function()
			return Promise.new(function(resolve, reject)
				local ok, result = pcall(ds.GetAsync, ds, tostring(player.UserId))
				if ok then
					resolve(result)
				else
					reject(result)
				end
			end)
		end, 3, 2)
		else Promise.resolve(nil)

	return loader
		:catch(function(err)
			warn("[DataService] Load failed for", player.Name, err)
			unsavable[player] = true
			return nil
		end)
		:andThen(function(saved)
			local data = defaultData()
			if type(saved) == "table" then
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

			self:_sync(player)
			self.PlayerLoaded:Fire(player)
		end)
end

function DataService:Save(player: Player)
	local data = profiles[player]
	local ds = store
	if not data or not ds or unsavable[player] then
		return
	end
	local ok, err = pcall(ds.SetAsync, ds, tostring(player.UserId), data)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end

function DataService:Get(player: Player): Data?
	return profiles[player]
end

function DataService:GetSkill(player: Player, id: string): number
	local data = profiles[player]
	return if data then skill(data, id) else 0
end

function DataService:IsBagFull(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and data.Peels >= capacity(data)
end

-- Adds peels up to bag capacity. Returns how many fit and whether the bag is now full.
function DataService:AddPeels(player: Player, amount: number): (number, boolean)
	local data = profiles[player]
	if not data then
		return 0, false
	end
	local cap = capacity(data)
	local added = math.clamp(amount, 0, cap - data.Peels)
	data.Peels += added
	self:_sync(player)
	return added, data.Peels >= cap
end

function DataService:Sell(player: Player): (number, number)
	local data = profiles[player]
	if not data or data.Peels <= 0 then
		return 0, 0
	end
	local peels = data.Peels
	local coins = math.floor(peels * Config.GetSellPrice(skill(data, "Haggler")))
	data.Peels = 0
	data.Coins += coins
	self:_sync(player)
	return peels, coins
end

local function addField(self, player: Player, field: string, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	(data :: any)[field] += amount
	self:_sync(player)
end

function DataService:AddCoins(player: Player, amount: number)
	addField(self, player, "Coins", amount)
end

function DataService:AddSkillPoints(player: Player, amount: number)
	addField(self, player, "SkillPoints", amount)
end

function DataService:AddLayer(player: Player)
	addField(self, player, "Layers", 1)
end

function DataService:AddGoldenOnion(player: Player)
	addField(self, player, "GoldenOnions", 1)
end

function DataService:BuyNextTier(player: Player, kind: string): (boolean, string?)
	local data = profiles[player]
	if not data or (kind ~= "Knife" and kind ~= "Bag") then
		return false, "Invalid"
	end
	local list = if kind == "Knife" then Config.Knives else Config.Bags
	local nextIndex = (data :: any)[kind] + 1
	local def = list[nextIndex]
	if not def then
		return false, "Maxed out"
	end
	if data.Coins < def.Cost then
		return false, "Not enough coins"
	end
	data.Coins -= def.Cost;
	(data :: any)[kind] = nextIndex
	self:_sync(player)
	return true, nil
end

function DataService:UpgradeSkill(player: Player, id: string): (boolean, string?)
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
	self:_sync(player)
	return true, nil
end

function DataService:KnitInit()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "OnionPeel_v2")
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable – progress will not be saved:", result)
	end
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_load(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		profiles[player] = nil
		unsavable[player] = nil
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(self.Save, self, player)
		end
		task.wait(2)
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for player in profiles do
				task.spawn(self.Save, self, player)
			end
		end
	end)
end

return DataService
