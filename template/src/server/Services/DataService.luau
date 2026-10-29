--!strict
--[[
	DataService: carrega/salva os dados do jogador com DataStoreService.

	- UpdateAsync com session lock (evita duplicação de itens entre servidores)
	- Retry com backoff, autosave, save no PlayerRemoving e no BindToClose
	- Reconcile: campos novos do DataTemplate aparecem em perfis antigos

	API:
	  DataService:Get(player) -> PlayerData?        (nil se ainda não carregou)
	  DataService:Update(player, function(data) ... end) -> boolean
	  DataService:WaitForData(player) -> PlayerData?
	  DataService.Loaded:Connect(function(player, data) end)

	Para jogos grandes considere ProfileStore (https://github.com/MadStudioRoblox/ProfileStore).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local DataTemplate = require(script.Parent.Parent.Config.DataTemplate)

type PlayerData = DataTemplate.PlayerData

type StoredRecord = {
	data: any,
	lock: { jobId: string, time: number }?,
}

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_EXPIRE = 30 * 60 -- lock de servidor que caiu expira após 30 min
local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3

-- Em Studio sem "Enable Studio Access to API Services" o DataStore falha:
-- os dados ficam só em memória.
local JOB_ID = if RunService:IsStudio() then "studio-" .. HttpService:GenerateGUID(false) else game.JobId

local DataService = {}
DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, data)

local store: DataStore? = nil
local profiles: { [Player]: PlayerData } = {}
local loading: { [Player]: boolean } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function withRetries(attempts: number, fn: () -> any): (boolean, any)
	local lastError
	for attempt = 1, attempts do
		local result = table.pack(pcall(fn))
		if result[1] then
			return true, table.unpack(result, 2, result.n)
		end
		lastError = result[2]
		warn(`[DataService] tentativa {attempt}/{attempts} falhou: {lastError}`)
		task.wait(2 ^ attempt)
	end
	return false, lastError
end

local function load(player: Player): PlayerData?
	if not store then
		local data = deepCopy(DataTemplate)
		return data
	end
	local activeStore = store
	for _ = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local ok, record = withRetries(SAVE_ATTEMPTS, function()
			return activeStore:UpdateAsync(keyFor(player), function(old: StoredRecord?)
				lockedByOther = false -- o Roblox pode chamar esta função mais de uma vez
				local now = os.time()
				if old and old.lock and old.lock.jobId ~= JOB_ID and now - old.lock.time < LOCK_EXPIRE then
					lockedByOther = true
					return nil -- cancela a escrita
				end
				local record: StoredRecord = {
					data = if old then old.data else deepCopy(DataTemplate),
					lock = { jobId = JOB_ID, time = now },
				}
				return record
			end)
		end)
		if not ok then
			return nil
		end
		if not lockedByOther and record then
			local data = (record :: StoredRecord).data
			reconcile(data, DataTemplate :: any)
			return data
		end
		-- Outro servidor ainda está salvando (jogador trocou de servidor rápido).
		task.wait(5)
		if not player.Parent then
			return nil
		end
	end
	return nil
end

local function save(player: Player, data: PlayerData, release: boolean): boolean
	if not store then
		return true
	end
	local activeStore = store
	local ok = withRetries(SAVE_ATTEMPTS, function()
		return activeStore:UpdateAsync(keyFor(player), function(old: StoredRecord?)
			if old and old.lock and old.lock.jobId ~= JOB_ID then
				return nil -- perdemos o lock: não sobrescreva dados de outro servidor
			end
			local record: StoredRecord = {
				data = data,
				lock = if release then nil else { jobId = JOB_ID, time = os.time() },
			}
			return record
		end)
	end)
	return ok
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local data = load(player)
	loading[player] = nil
	if not player.Parent then
		if data then
			save(player, data, true)
		end
		return
	end
	if not data then
		player:Kick("Não foi possível carregar seus dados. Tente entrar novamente.")
		return
	end
	data.Stats.Logins += 1
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	-- Espera o load terminar para não perder o save.
	while loading[player] do
		task.wait(0.5)
	end
	local data = profiles[player]
	if data then
		profiles[player] = nil
		save(player, data, true)
	end
end

function DataService:Get(player: Player): PlayerData?
	return profiles[player]
end

function DataService:WaitForData(player: Player): PlayerData?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Única forma recomendada de mudar dados: centraliza escrita e notificações.
function DataService:Update(player: Player, mutator: (PlayerData) -> ()): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	mutator(data)
	DataService.Changed:Fire(player, data)
	return true
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn(`[DataService] DataStore indisponível, usando memória: {result}`)
		return
	end
	if RunService:IsStudio() then
		-- Sem "Enable Studio Access to API Services" qualquer chamada falha.
		local accessOk, accessErr = pcall(function()
			return result:GetAsync("__studio_access_check")
		end)
		if not accessOk then
			warn(`[DataService] Sem acesso a API Services no Studio, dados ficam em memória: {accessErr}`)
			return
		end
	end
	store = result
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, data in profiles do
				task.spawn(save, player, data, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				onPlayerRemoving(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
