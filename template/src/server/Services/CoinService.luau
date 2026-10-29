--!strict
-- Example: awards coins for play time and mirrors the balance to leaderstats and
-- a Player attribute (the client reads the attribute to update the HUD).

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local REWARD_INTERVAL = 60
local REWARD_AMOUNT = 10

local CoinService = {}

local function syncCoins(player: Player, coins: number)
	player:SetAttribute("Coins", coins)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Coins")
	if value and value:IsA("IntValue") then
		value.Value = coins
	end
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

function CoinService:Add(player: Player, amount: number): boolean
	return DataService:Update(player, function(data)
		data.Coins += amount
	end)
end

-- Spends only if the balance allows. Returns true if spent.
function CoinService:TrySpend(player: Player, amount: number): boolean
	local data = DataService:Get(player)
	if not data or data.Coins < amount then
		return false
	end
	return DataService:Update(player, function(d)
		d.Coins -= amount
	end)
end

function CoinService:Init()
	-- Connect in Init so no Loaded event is missed before Start.
	DataService.Loaded:Connect(function(player, data)
		createLeaderstats(player)
		syncCoins(player, data.Coins)
	end)
	DataService.Changed:Connect(function(player, data)
		syncCoins(player, data.Coins)
	end)
end

function CoinService:Start()
	while true do
		task.wait(REWARD_INTERVAL)
		for _, player in Players:GetPlayers() do
			if DataService:Get(player) then
				self:Add(player, REWARD_AMOUNT)
				DataService:Update(player, function(data)
					data.Stats.PlayTime += REWARD_INTERVAL
				end)
			end
		end
	end
end

return CoinService
