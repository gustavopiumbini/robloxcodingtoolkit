--!strict
--[[
	Net: create and use remotes with built-in validation and rate limiting.

	The SERVER creates remotes in ReplicatedStorage.Remotes; CLIENTS wait for them.
	Always use Net.Names to avoid typos.

	-- Server (add BuyItem = "BuyItem" to Net.Names first)
	Net.onServerEvent(Net.Names.BuyItem, {
		check = Guard.tuple(Guard.keyOf(Items)),
		rate = 2, burst = 4,
	}, function(player, itemId)
		...
	end)

	-- Client
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

-- Register EVERY remote in the game here.
Net.Names = table.freeze({
	Notify = "Notify", -- generic server -> client message (e.g. toasts)
})

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	local result: Folder
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			result = existing
		else
			result = Instance.new("Folder")
			result.Name = FOLDER_NAME
			result.Parent = ReplicatedStorage
		end
	else
		local found = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
		assert(found and found:IsA("Folder"), "Net: Remotes folder not found (did the server load?)")
		result = found
	end
	folder = result
	return result
end

local function getRemote(name: string, className: string): any
	local parent = getFolder()
	local remote: Instance?
	if IS_SERVER then
		remote = parent:FindFirstChild(name)
		if remote == nil then
			local created: any = Instance.new(className :: any)
			created.Name = name
			created.Parent = parent
			remote = created
		end
	else
		remote = parent:WaitForChild(name, WAIT_TIMEOUT)
	end
	assert(remote and remote:IsA(className), `Net: remote {name} missing or not a {className}`)
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
	assert(IS_SERVER, "Net: server handlers can only be created on the server")
	assert(type(options.check) == "function", `Net: {name} needs options.check (use Guard.tuple)`)
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
			warn(`[Net] {player.Name} sent invalid arguments to {name}: {err}`)
			return false
		end
		return true
	end
end

-- Connects a RemoteEvent handler with rate limiting + validation.
function Net.onServerEvent(name: string, options: HandlerOptions, handler: (Player, ...any) -> ()): RBXScriptConnection
	local gate = makeGate(name, options)
	local remote: any = if options.unreliable then Net.unreliable(name) else Net.event(name)
	-- rbxkit-ignore-next-line: remote-without-validation (validated by gate)
	return remote.OnServerEvent:Connect(function(player: Player, ...)
		if gate(player, ...) then
			handler(player, ...)
		end
	end)
end

-- Sets a RemoteFunction callback with rate limiting + validation.
-- Returns nil for rejected requests. Never use InvokeClient on the server.
function Net.onServerInvoke(name: string, options: HandlerOptions, handler: (Player, ...any) -> ...any)
	local gate = makeGate(name, options)
	-- rbxkit-ignore-next-line: remote-without-validation (validated by gate)
	Net.func(name).OnServerInvoke = function(player: Player, ...)
		if gate(player, ...) then
			return handler(player, ...)
		end
		return nil
	end
end

return Net
