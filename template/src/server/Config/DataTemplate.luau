--!strict
-- Formato dos dados salvos de cada jogador. Campos novos adicionados aqui são
-- preenchidos automaticamente em perfis antigos (reconcile no DataService).

export type PlayerData = {
	Coins: number,
	Inventory: { [string]: number },
	Stats: {
		PlayTime: number,
		Logins: number,
	},
}

local DataTemplate: PlayerData = {
	Coins = 100,
	Inventory = {},
	Stats = {
		PlayTime = 0,
		Logins = 0,
	},
}

return DataTemplate
