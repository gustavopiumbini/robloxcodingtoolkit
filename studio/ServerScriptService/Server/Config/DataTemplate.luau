--!strict
-- Saved data shape for each player. New fields added here are filled into
-- existing profiles automatically (reconcile in DataService).

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
