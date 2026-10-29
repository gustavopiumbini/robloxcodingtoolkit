--!strict
--[[
	Server bootstrap. Requires every ModuleScript in Services/ and calls:
	  1. Service:Init()  - alphabetical, synchronous (prepare state, create remotes)
	  2. Service:Start() - in parallel, after ALL Init calls finished

	New service: add a ModuleScript to Services (see the roblox-architecture skill).
]]

local servicesFolder = script:FindFirstChild("Services")

local modules: { ModuleScript } = {}
if servicesFolder then
	for _, child in servicesFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
end
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local services: { { name: string, service: any } } = {}
for _, module in modules do
	local ok, result = pcall(require, module)
	if ok then
		table.insert(services, { name = module.Name, service = result })
	else
		warn(`[Server] Failed to load {module.Name}: {result}`)
	end
end

for _, entry in services do
	if type(entry.service.Init) == "function" then
		local ok, err = pcall(entry.service.Init, entry.service)
		if not ok then
			warn(`[Server] {entry.name}:Init failed: {err}`)
		end
	end
end

for _, entry in services do
	if type(entry.service.Start) == "function" then
		task.spawn(entry.service.Start, entry.service)
	end
end

print(`[Server] {#services} services started`)
