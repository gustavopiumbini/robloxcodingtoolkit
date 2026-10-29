--!strict
--[[
	Guard: validates data coming from clients. NEVER trust RemoteEvent/RemoteFunction
	arguments: a client can send anything (NaN, inf, huge strings, tables with
	metatables, another player's Instances...).

	local check = Guard.tuple(
		Guard.string({ maxLength = 32 }),
		Guard.integer({ min = 1, max = 99 }),
		Guard.optional(Guard.vector3({ maxMagnitude = 5000 }))
	)
	local ok, err = check(...)

	Each checker is a function (value) -> (ok: boolean, err: string?).
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
			return false, "missing value"
		end
		return true
	end
end

function Guard.boolean(): Check
	return function(value)
		if type(value) ~= "boolean" then
			return false, `expected boolean, got {typeof(value)}`
		end
		return true
	end
end

function Guard.number(options: { min: number?, max: number? }?): Check
	local min = options and options.min
	local max = options and options.max
	return function(value)
		if not isFiniteNumber(value) then
			return false, "expected a finite number"
		end
		if min and value < min then
			return false, `number below {min}`
		end
		if max and value > max then
			return false, `number above {max}`
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
			return false, "expected an integer"
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
			return false, `expected string, got {typeof(value)}`
		end
		if #value < minLength or #value > maxLength then
			return false, `string length outside [{minLength}, {maxLength}]`
		end
		if not utf8.len(value) then
			return false, "invalid UTF-8 string"
		end
		if pattern and not string.find(value, pattern) then
			return false, "string does not match pattern"
		end
		return true
	end
end

-- Accepts only one of the listed values (e.g. item ids, action names).
function Guard.literal(...: any): Check
	local allowed = {}
	for _, v in { ... } do
		allowed[v] = true
	end
	return function(value)
		if value == nil or not allowed[value] then
			return false, "value not allowed"
		end
		return true
	end
end

-- Accepts only keys that exist in a dictionary (e.g. Guard.keyOf(Items)).
function Guard.keyOf(dictionary: { [any]: any }): Check
	return function(value)
		if (type(value) ~= "string" and type(value) ~= "number") or dictionary[value] == nil then
			return false, "unknown key"
		end
		return true
	end
end

function Guard.vector3(options: { maxMagnitude: number? }?): Check
	local maxMagnitude = options and options.maxMagnitude
	return function(value)
		if typeof(value) ~= "Vector3" then
			return false, `expected Vector3, got {typeof(value)}`
		end
		if not (isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)) then
			return false, "Vector3 with NaN/inf"
		end
		if maxMagnitude and value.Magnitude > maxMagnitude then
			return false, "Vector3 too large"
		end
		return true
	end
end

function Guard.cframe(): Check
	return function(value)
		if typeof(value) ~= "CFrame" then
			return false, `expected CFrame, got {typeof(value)}`
		end
		for _, component in { value:GetComponents() } do
			if not isFiniteNumber(component) then
				return false, "CFrame with NaN/inf"
			end
		end
		return true
	end
end

-- Instance of a class (IsA). A client can send ANY replicated Instance:
-- still check ownership/distance in the handler.
function Guard.instance(className: string?): Check
	return function(value)
		if typeof(value) ~= "Instance" then
			return false, `expected Instance, got {typeof(value)}`
		end
		if className and not value:IsA(className) then
			return false, `expected {className}`
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
			return false, "expected array"
		end
		local count = 0
		for key in value do
			count += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "array with invalid key"
			end
		end
		if count ~= #value then
			return false, "array with holes"
		end
		if count > limit then
			return false, `array longer than {limit}`
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

-- Table with known fields. Extra fields are rejected.
function Guard.shape(fields: { [string]: Check }): Check
	return function(value)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			return false, "expected table"
		end
		for key in value do
			if type(key) ~= "string" or fields[key] == nil then
				return false, `unexpected field: {tostring(key)}`
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

-- Validates a remote's argument list. Extra arguments are rejected.
function Guard.tuple(...: Check): TupleCheck
	local checks = { ... }
	return function(...)
		local count = select("#", ...)
		if count > #checks then
			return false, `too many arguments ({count} > {#checks})`
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
