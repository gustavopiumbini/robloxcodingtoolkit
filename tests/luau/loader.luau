--!strict
-- Loads a template module with Roblox-style globals injected, since Lune only
-- exposes `task`, Instances and datatypes as libraries (`@lune/task`, `@lune/roblox`).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

return function(path: string, globals: { [string]: any }): any
	local source = fs.readFile(path)
	local chunk = luau.load(source, { debugName = path, environment = globals })
	return chunk()
end
