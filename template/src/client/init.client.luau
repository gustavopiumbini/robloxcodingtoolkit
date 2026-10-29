--!strict
--[[
	Client bootstrap. Requires every ModuleScript in Controllers/ and calls
	Controller:Init() (alphabetical), then Controller:Start() (in parallel).

	New controller: node tools/rbxkit.mjs new controller Name
]]

local controllersFolder = script:WaitForChild("Controllers")

local modules: { ModuleScript } = {}
for _, child in controllersFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	end
end
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local controllers: { { name: string, controller: any } } = {}
for _, module in modules do
	local ok, result = pcall(require, module)
	if ok then
		table.insert(controllers, { name = module.Name, controller = result })
	else
		warn(`[Client] Failed to load {module.Name}: {result}`)
	end
end

for _, entry in controllers do
	if type(entry.controller.Init) == "function" then
		local ok, err = pcall(entry.controller.Init, entry.controller)
		if not ok then
			warn(`[Client] {entry.name}:Init failed: {err}`)
		end
	end
end

for _, entry in controllers do
	if type(entry.controller.Start) == "function" then
		task.spawn(entry.controller.Start, entry.controller)
	end
end
