---
name: roblox-monetization
description: Game Passes, Developer Products, idempotent ProcessReceipt, Premium, purchase prompts and policy checks. Use for Robux shops, VIP, paid items/currency, or purchases that don't deliver.
---

# Monetization

## Game Pass (one-time, permanent)

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local VIP_PASS_ID = 0 -- real id from Creator Hub > Monetization > Passes

local function ownsPass(player: Player, passId: number): boolean
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == VIP_PASS_ID then
		-- apply the benefit now (also check ownsPass on join, cached)
	end
end)
```

Client prompts with `MarketplaceService:PromptGamePassPurchase(player, passId)`; the server applies benefits.

## Developer Product (consumable)

`ProcessReceipt` (one callback per game, server):
1. May run more than once per purchase → idempotent via `receiptInfo.PurchaseId`.
2. Return `PurchaseGranted` only after granting **and** saving.
3. Player gone, data not loaded, or save failed → `NotProcessedYet` (Roblox retries).
4. Never let it error.

```lua
local PRODUCTS: { [number]: (Player) -> () } = {
	[0000000] = function(player) DataService:Update(player, function(d) d.Coins += 100 end) end,
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local data = player and DataService:Get(player)
	local grant = PRODUCTS[receiptInfo.ProductId]
	if not (player and data and grant) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- add `Purchases: { [string]: number }` to DataTemplate; keep only the last ~50 ids
	if data.Purchases[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not pcall(grant, player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService:Update(player, function(d) d.Purchases[receiptInfo.PurchaseId] = os.time() end)
	-- ideally force a save before returning Granted
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

## Other

- Premium: `player.MembershipType == Enum.MembershipType.Premium`, `Players.PlayerMembershipChanged`.
- Prices: `MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)` in pcall, cached; don't hardcode displayed prices.
- Studio purchases are simulated: test the full flow, including leaving mid-purchase.
- Paid random items (loot boxes) are restricted in some countries: `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted`.
