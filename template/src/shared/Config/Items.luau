--!strict
-- Catálogo de itens compartilhado por cliente e servidor.
-- O servidor é a fonte da verdade para preços: o cliente só envia o id.

export type Item = {
	name: string,
	price: number,
}

local Items: { [string]: Item } = {
	Sword = { name = "Espada", price = 50 },
	Shield = { name = "Escudo", price = 75 },
	SpeedCoil = { name = "Bobina de Velocidade", price = 120 },
}

return table.freeze(Items)
