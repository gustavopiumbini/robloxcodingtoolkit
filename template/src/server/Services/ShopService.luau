--!strict
-- Secure remote example: the client sends ONLY the item id. Price, balance and
-- delivery are decided on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Util.Guard)
local Items = require(Shared.Config.Items)
local DataService = require(script.Parent.DataService)
local CoinService = require(script.Parent.CoinService)

local ShopService = {}

function ShopService:Init()
	-- Create remotes in Init so they exist before any client asks.
	Net.event(Net.Names.Notify)

	Net.onServerEvent(Net.Names.BuyItem, {
		check = Guard.tuple(Guard.keyOf(Items)),
		rate = 2,
		burst = 4,
	}, function(player, itemId: string)
		local item = Items[itemId]
		if not CoinService:TrySpend(player, item.price) then
			Net.event(Net.Names.Notify):FireClient(player, "Not enough coins!")
			return
		end
		DataService:Update(player, function(data)
			data.Inventory[itemId] = (data.Inventory[itemId] or 0) + 1
		end)
		Net.event(Net.Names.Notify):FireClient(player, `You bought {item.name}!`)
	end)

	Net.onServerInvoke(Net.Names.GetShopData, {
		check = Guard.tuple(),
		rate = 1,
		burst = 3,
	}, function(player)
		local data = DataService:Get(player)
		return if data then table.clone(data.Inventory) else {}
	end)
end

return ShopService
