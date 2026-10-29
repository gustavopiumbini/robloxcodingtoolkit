--!strict
--[[
	Trove: tracks objects and cleans them all at once (prevents memory leaks).

	local trove = Trove.new()
	trove:Add(part)                                   -- Instance -> :Destroy()
	trove:Connect(part.Touched, onTouched)            -- RBXScriptConnection -> :Disconnect()
	trove:Add(function() print("cleaned") end)        -- function -> called
	trove:Add(task.delay(5, fn))                      -- thread -> task.cancel()
	trove:Clean()                                     -- cleans everything (reusable)

	Use one Trove per lifetime: per player, per character, per round, per UI.
]]

export type Trove = {
	Add: <T>(self: Trove, object: T, cleanupMethod: string?) -> T,
	Connect: (self: Trove, signal: any, handler: (...any) -> ()) -> any,
	Extend: (self: Trove) -> Trove,
	Remove: (self: Trove, object: any) -> boolean,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

type Entry = { object: any, method: string? }

local Trove = {}
Trove.__index = Trove

local function cleanup(entry: Entry)
	local object = entry.object
	local kind = typeof(object)
	if entry.method then
		object[entry.method](object)
	elseif kind == "function" then
		object()
	elseif kind == "thread" then
		if coroutine.status(object) ~= "dead" then
			pcall(task.cancel, object)
		end
	elseif kind == "RBXScriptConnection" then
		object:Disconnect()
	elseif kind == "Instance" then
		object:Destroy()
	elseif kind == "table" then
		if type(object.Destroy) == "function" then
			object:Destroy()
		elseif type(object.Disconnect) == "function" then
			object:Disconnect()
		else
			error("Trove: table has no Destroy/Disconnect method")
		end
	else
		error(`Trove: cannot clean an object of type {kind}`)
	end
end

function Trove.new(): Trove
	local self = setmetatable({ _entries = {} :: { Entry }, _cleaning = false }, Trove)
	return (self :: any) :: Trove
end

function Trove.Add(self: any, object: any, cleanupMethod: string?): any
	if self._cleaning then
		error("Trove: cannot Add during Clean()")
	end
	table.insert(self._entries, { object = object, method = cleanupMethod })
	return object
end

function Trove.Connect(self: any, signal: any, handler: (...any) -> ()): any
	return self:Add(signal:Connect(handler))
end

function Trove.Extend(self: any): Trove
	return self:Add(Trove.new())
end

function Trove.Remove(self: any, object: any): boolean
	for i, entry in self._entries do
		if entry.object == object then
			table.remove(self._entries, i)
			cleanup(entry)
			return true
		end
	end
	return false
end

function Trove.Clean(self: any)
	if self._cleaning then
		return
	end
	self._cleaning = true
	-- Reverse order: last created is destroyed first.
	local entries = self._entries
	self._entries = {}
	for i = #entries, 1, -1 do
		cleanup(entries[i])
	end
	self._cleaning = false
end

Trove.Destroy = Trove.Clean

return Trove
