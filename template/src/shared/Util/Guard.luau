--!strict
--[[
	Guard: validação de dados vindos do cliente. NUNCA confie em argumentos de
	RemoteEvent/RemoteFunction: o cliente pode enviar qualquer coisa (NaN, inf,
	strings gigantes, tabelas com metatables, Instances de outro jogador...).

	local check = Guard.tuple(
		Guard.string({ maxLength = 32 }),
		Guard.integer({ min = 1, max = 99 }),
		Guard.optional(Guard.vector3({ maxMagnitude = 5000 }))
	)
	local ok, err = check(...)

	Cada checker é uma função (value) -> (ok: boolean, err: string?).
]]

export type Check = (value: any) -> (boolean, string?)
export type TupleCheck = (...any) -> (boolean, string?)

local Guard = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Guard.any(): Check
	return function(value)
		if value == nil then
			return false, "valor ausente"
		end
		return true
	end
end

function Guard.boolean(): Check
	return function(value)
		if type(value) ~= "boolean" then
			return false, `esperava boolean, recebeu {typeof(value)}`
		end
		return true
	end
end

function Guard.number(options: { min: number?, max: number? }?): Check
	local min = options and options.min
	local max = options and options.max
	return function(value)
		if not isFiniteNumber(value) then
			return false, "esperava número finito"
		end
		if min and value < min then
			return false, `número menor que {min}`
		end
		if max and value > max then
			return false, `número maior que {max}`
		end
		return true
	end
end

function Guard.integer(options: { min: number?, max: number? }?): Check
	local numberCheck = Guard.number(options)
	return function(value)
		local ok, err = numberCheck(value)
		if not ok then
			return false, err
		end
		if value % 1 ~= 0 then
			return false, "esperava número inteiro"
		end
		return true
	end
end

function Guard.string(options: { minLength: number?, maxLength: number?, pattern: string? }?): Check
	local minLength = options and options.minLength or 0
	local maxLength = options and options.maxLength or 200
	local pattern = options and options.pattern
	return function(value)
		if type(value) ~= "string" then
			return false, `esperava string, recebeu {typeof(value)}`
		end
		if #value < minLength or #value > maxLength then
			return false, `tamanho da string fora de [{minLength}, {maxLength}]`
		end
		if not utf8.len(value) then
			return false, "string com UTF-8 inválido"
		end
		if pattern and not string.find(value, pattern) then
			return false, "string não corresponde ao padrão"
		end
		return true
	end
end

-- Aceita apenas um dos valores listados (ex.: ids de itens, nomes de ações).
function Guard.literal(...: any): Check
	local allowed = {}
	for _, v in { ... } do
		allowed[v] = true
	end
	return function(value)
		if value == nil or not allowed[value] then
			return false, "valor não permitido"
		end
		return true
	end
end

-- Aceita apenas chaves existentes em um dicionário (ex.: Guard.keyOf(Items)).
function Guard.keyOf(dictionary: { [any]: any }): Check
	return function(value)
		if (type(value) ~= "string" and type(value) ~= "number") or dictionary[value] == nil then
			return false, "chave desconhecida"
		end
		return true
	end
end

function Guard.vector3(options: { maxMagnitude: number? }?): Check
	local maxMagnitude = options and options.maxMagnitude
	return function(value)
		if typeof(value) ~= "Vector3" then
			return false, `esperava Vector3, recebeu {typeof(value)}`
		end
		if not (isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)) then
			return false, "Vector3 com NaN/inf"
		end
		if maxMagnitude and value.Magnitude > maxMagnitude then
			return false, "Vector3 grande demais"
		end
		return true
	end
end

function Guard.cframe(): Check
	return function(value)
		if typeof(value) ~= "CFrame" then
			return false, `esperava CFrame, recebeu {typeof(value)}`
		end
		for _, component in { value:GetComponents() } do
			if not isFiniteNumber(component) then
				return false, "CFrame com NaN/inf"
			end
		end
		return true
	end
end

-- Instance de uma classe (usa IsA). Lembre: o cliente pode enviar QUALQUER
-- Instance replicada; ainda verifique posse/distância no handler.
function Guard.instance(className: string?): Check
	return function(value)
		if typeof(value) ~= "Instance" then
			return false, `esperava Instance, recebeu {typeof(value)}`
		end
		if className and not value:IsA(className) then
			return false, `esperava {className}`
		end
		return true
	end
end

function Guard.optional(check: Check): Check
	return function(value)
		if value == nil then
			return true
		end
		return check(value)
	end
end

function Guard.array(check: Check, maxLength: number?): Check
	local limit = maxLength or 100
	return function(value)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			return false, "esperava array"
		end
		local count = 0
		for key in value do
			count += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "array com chave inválida"
			end
		end
		if count ~= #value then
			return false, "array com buracos"
		end
		if count > limit then
			return false, `array maior que {limit}`
		end
		for i, item in value do
			local ok, err = check(item)
			if not ok then
				return false, `[{i}]: {err}`
			end
		end
		return true
	end
end

-- Tabela com campos conhecidos. Campos extras são rejeitados.
function Guard.shape(fields: { [string]: Check }): Check
	return function(value)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			return false, "esperava tabela"
		end
		for key in value do
			if type(key) ~= "string" or fields[key] == nil then
				return false, `campo inesperado: {tostring(key)}`
			end
		end
		for key, check in fields do
			local ok, err = check(value[key])
			if not ok then
				return false, `{key}: {err}`
			end
		end
		return true
	end
end

-- Valida a lista de argumentos de um remote. Argumentos extras são rejeitados.
function Guard.tuple(...: Check): TupleCheck
	local checks = { ... }
	return function(...)
		local count = select("#", ...)
		if count > #checks then
			return false, `argumentos demais ({count} > {#checks})`
		end
		local args = { ... }
		for i, check in checks do
			local ok, err = check(args[i])
			if not ok then
				return false, `arg #{i}: {err}`
			end
		end
		return true
	end
end

return Guard
