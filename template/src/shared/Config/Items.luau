--!strict
-- Item catalog shared by client and server.
-- The server is the source of truth for prices: the client only sends the id.

export type Item = {
	name: string,
	price: number,
}

local Items: { [string]: Item } = {
	Sword = { name = "Sword", price = 50 },
	Shield = { name = "Shield", price = 75 },
	SpeedCoil = { name = "Speed Coil", price = 120 },
}

return table.freeze(Items)
