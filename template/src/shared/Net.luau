--!strict
--[[
	Net: criação e uso de remotes com validação e rate limit embutidos.

	O SERVIDOR cria os remotes em ReplicatedStorage.Remotes; o CLIENTE espera
	por eles. Use sempre os nomes de Net.Names para evitar typos.

	-- Servidor
	Net.onServerEvent(Net.Names.BuyItem, {
		check = Guard.tuple(Guard.keyOf(Items)),
		rate = 2, burst = 4,
	}, function(player, itemId)
		...
	end)

	-- Cliente
	Net.event(Net.Names.BuyItem):FireServer("Sword")
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guard = require(script.Parent.Util.Guard)
local RateLimiter = require(script.Parent.Util.RateLimiter)

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 30

local Net = {}

-- Registre aqui TODOS os remotes do jogo.
Net.Names = table.freeze({
	BuyItem = "BuyItem",
	Notify = "Notify",
	GetShopData = "GetShopData",
})

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			created.Parent = ReplicatedStorage
			folder = created
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT) :: Folder
		assert(folder, "Net: pasta Remotes não encontrada (o servidor carregou?)")
	end
	return folder :: Folder
end

local function getRemote(name: string, className: string): any
	local parent = getFolder()
	if IS_SERVER then
		local remote = parent:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = parent
		end
		assert(remote:IsA(className), `Net: {name} já existe como {remote.ClassName}`)
		return remote
	end
	local remote = parent:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Net: remote {name} não encontrado`)
	return remote
end

function Net.event(name: string): RemoteEvent
	return getRemote(name, "RemoteEvent")
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return getRemote(name, "UnreliableRemoteEvent")
end

function Net.func(name: string): RemoteFunction
	return getRemote(name, "RemoteFunction")
end

export type HandlerOptions = {
	check: Guard.TupleCheck,
	rate: number?,
	burst: number?,
	unreliable: boolean?,
}

local function makeGate(name: string, options: HandlerOptions)
	assert(IS_SERVER, "Net: handlers de servidor só podem ser criados no servidor")
	assert(type(options.check) == "function", `Net: {name} precisa de options.check (use Guard.tuple)`)
	local limiter = RateLimiter.new(options.rate or 10, options.burst)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Clear(player)
	end)
	return function(player: Player, ...: any): boolean
		if not limiter:Allow(player) then
			return false
		end
		local ok, err = options.check(...)
		if not ok then
			warn(`[Net] {player.Name} enviou argumentos inválidos para {name}: {err}`)
			return false
		end
		return true
	end
end

-- Conecta um handler de RemoteEvent com rate limit + validação.
function Net.onServerEvent(name: string, options: HandlerOptions, handler: (Player, ...any) -> ()): RBXScriptConnection
	local gate = makeGate(name, options)
	local remote: any = if options.unreliable then Net.unreliable(name) else Net.event(name)
	-- rbxkit-ignore-next-line: remote-without-validation (validado por gate)
	return remote.OnServerEvent:Connect(function(player: Player, ...)
		if gate(player, ...) then
			handler(player, ...)
		end
	end)
end

-- Define o callback de um RemoteFunction com rate limit + validação.
-- Retorna nil para requisições rejeitadas. Nunca use InvokeClient no servidor.
function Net.onServerInvoke(name: string, options: HandlerOptions, handler: (Player, ...any) -> ...any)
	local gate = makeGate(name, options)
	-- rbxkit-ignore-next-line: remote-without-validation (validado por gate)
	Net.func(name).OnServerInvoke = function(player: Player, ...)
		if gate(player, ...) then
			return handler(player, ...)
		end
		return nil
	end
end

return Net
