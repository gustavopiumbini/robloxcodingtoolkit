--!strict
--[[
	RateLimiter: token bucket per key (e.g. per player).

	local limiter = RateLimiter.new(5, 10) -- 5 req/s, bursts up to 10
	if not limiter:Allow(player) then return end

	Call limiter:Clear(player) on PlayerRemoving
	(Net.onServerEvent does this automatically).
]]

export type RateLimiter = {
	Allow: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Clear: (self: RateLimiter, key: any) -> (),
	ClearAll: (self: RateLimiter) -> (),
}

type Bucket = { tokens: number, updated: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond: number, burst: number?, clock: (() -> number)?): RateLimiter
	assert(ratePerSecond > 0, "ratePerSecond must be > 0")
	local capacity = burst or ratePerSecond
	assert(capacity >= 1, "burst must be >= 1")
	local self = setmetatable({
		_rate = ratePerSecond,
		_capacity = capacity,
		_clock = clock or os.clock,
		_buckets = {} :: { [any]: Bucket },
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

function RateLimiter.Allow(self: any, key: any, cost: number?): boolean
	local amount = cost or 1
	local now = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, updated = now }
		self._buckets[key] = bucket
	else
		local elapsed = now - bucket.updated
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._rate)
		bucket.updated = now
	end
	if bucket.tokens >= amount then
		bucket.tokens -= amount
		return true
	end
	return false
end

function RateLimiter.Clear(self: any, key: any)
	self._buckets[key] = nil
end

function RateLimiter.ClearAll(self: any)
	table.clear(self._buckets)
end

return RateLimiter
