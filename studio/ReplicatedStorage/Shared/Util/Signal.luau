--!strict
--[[
	Signal: lightweight pure-Luau event (BindableEvent replacement).

	local changed = Signal.new()
	local conn = changed:Connect(function(value) print(value) end)
	changed:Fire(10)
	conn:Disconnect()

	Each handler runs in its own thread (task.spawn), so an error in one
	handler doesn't stop the others.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Handler = (...any) -> ()

type ConnectionImpl = Connection & {
	_handler: Handler,
	_signal: any,
}

export type Signal = {
	Connect: (self: Signal, handler: Handler) -> Connection,
	Once: (self: Signal, handler: Handler) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._handlers
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

function Signal.new(): Signal
	local self = setmetatable({ _handlers = {} :: { ConnectionImpl } }, Signal)
	return (self :: any) :: Signal
end

function Signal.Connect(self: any, handler: Handler): Connection
	local connection = setmetatable({
		Connected = true,
		_handler = handler,
		_signal = self,
	}, Connection)
	table.insert(self._handlers, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, handler: Handler): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Fire(self: any, ...: any)
	-- Snapshot so connecting/disconnecting during Fire is safe.
	local snapshot: { any } = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
