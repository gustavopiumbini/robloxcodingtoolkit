--!strict
--[[
	Bootstrap do servidor. Carrega todos os ModuleScripts em Services/ e chama:
	  1. Service:Init()  - em ordem alfabética, síncrono (prepare estado, crie remotes)
	  2. Service:Start() - em paralelo, depois que TODOS os Init terminaram

	Para criar um serviço: node tools/rbxkit.mjs new service NomeDoServico
]]

local servicesFolder = script:WaitForChild("Services")

local modules: { ModuleScript } = {}
for _, child in servicesFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
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
		warn(`[Server] Falha ao carregar {module.Name}: {result}`)
	end
end

for _, entry in services do
	if type(entry.service.Init) == "function" then
		local ok, err = pcall(entry.service.Init, entry.service)
		if not ok then
			warn(`[Server] {entry.name}:Init falhou: {err}`)
		end
	end
end

for _, entry in services do
	if type(entry.service.Start) == "function" then
		task.spawn(entry.service.Start, entry.service)
	end
end

print(`[Server] {#services} serviços iniciados`)
