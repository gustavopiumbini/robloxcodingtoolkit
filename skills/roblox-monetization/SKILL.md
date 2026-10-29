---
name: roblox-monetization
description: Monetização no Roblox - Game Passes, Developer Products, ProcessReceipt idempotente, Premium, assinaturas e prompts de compra. Use ao implementar lojas com Robux, VIP, itens pagos, moedas compradas ou ao depurar compras que não entregam.
---

# Monetização

## Game Pass (compra única, permanente)

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local VIP_PASS_ID = 0 -- substitua pelo id real (Creator Hub > Monetização > Passes)

local function ownsPass(player: Player, passId: number): boolean
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns
end

-- Ao entrar: aplicar benefícios (faça cache por jogador)
-- Compra durante a sessão:
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == VIP_PASS_ID then
		-- aplicar benefício imediatamente
	end
end)
```

Cliente abre o prompt: `MarketplaceService:PromptGamePassPurchase(player, passId)`. O benefício é sempre aplicado pelo servidor.

## Developer Product (consumível: moedas, revives)

Regras do `ProcessReceipt` (callback ÚNICO por jogo, defina em um só lugar, no servidor):

1. Pode ser chamado mais de uma vez para a mesma compra: seja **idempotente** usando `receiptInfo.PurchaseId`.
2. Retorne `Enum.ProductPurchaseDecision.PurchaseGranted` SOMENTE depois de entregar E salvar.
3. Se o jogador saiu, os dados não carregaram, ou o save falhou: retorne `NotProcessedYet` (o Roblox tenta de novo depois).
4. Nunca dê `error` sem tratamento dentro do callback.

```lua
local PRODUCTS: { [number]: (Player) -> () } = {
	[0000000] = function(player) -- 100 moedas
		DataService:Update(player, function(d) d.Coins += 100 end)
	end,
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService:Get(player)
	local grant = PRODUCTS[receiptInfo.ProductId]
	if not data or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Purchases = data.Purchases or {} -- adicione Purchases = {} ao DataTemplate
	if data.Purchases[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- já entregue antes
	end
	local ok = pcall(grant, player)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService:Update(player, function(d) d.Purchases[receiptInfo.PurchaseId] = os.time() end)
	-- Idealmente force um save aqui antes de retornar Granted.
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

Mantenha o histórico `Purchases` limitado (ex.: últimos 50 ids) para não estourar a chave.

## Outros

- Premium: `player.MembershipType == Enum.MembershipType.Premium`; `Players.PlayerMembershipChanged`. Premium Payouts são automáticos por tempo de jogo.
- Preços: `MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)` em pcall, faça cache; não hardcode o preço exibido.
- Testes no Studio: compras são simuladas (não cobram). Teste o fluxo inteiro incluindo sair durante a compra.
- Políticas: `PolicyService:GetPolicyInfoForPlayerAsync` para paid random items (loot boxes) que são proibidos em alguns países (`ArePaidRandomItemsRestricted`).
