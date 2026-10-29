--!strict
-- Tests for template/src/shared/Util. Run with Lune (https://lune-org.github.io):
--   lune run tests/luau/utils.spec.luau

local process = require("@lune/process")

-- Roblox exposes `task` as a global; Lune exposes it as a library.
(_G :: any).task = require("@lune/task")

local Guard = require("../../template/src/shared/Util/Guard")
local RateLimiter = require("../../template/src/shared/Util/RateLimiter")
local Signal = require("../../template/src/shared/Util/Signal")
local Trove = require("../../template/src/shared/Util/Trove")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`ok   {name}`)
	else
		failed += 1
		print(`FAIL {name}: {err}`)
	end
end

local function expect(cond: any, message: string?)
	if not cond then
		error(message or "expectation failed", 2)
	end
end

test("Guard.number rejects NaN, inf and out-of-range", function()
	local check = Guard.number({ min = 0, max = 10 })
	expect(check(5))
	expect(not check(0 / 0))
	expect(not check(math.huge))
	expect(not check(-1))
	expect(not check(11))
	expect(not check("5"))
end)

test("Guard.integer", function()
	local check = Guard.integer({ min = 1 })
	expect(check(3))
	expect(not check(3.5))
	expect(not check(0))
end)

test("Guard.string enforces length and pattern", function()
	local check = Guard.string({ maxLength = 5, pattern = "^%a+$" })
	expect(check("abc"))
	expect(not check("abcdef"))
	expect(not check("ab1"))
	expect(not check(nil))
end)

test("Guard.keyOf and literal", function()
	local items = { Sword = {}, Shield = {} }
	expect(Guard.keyOf(items)("Sword"))
	expect(not Guard.keyOf(items)("Bazooka"))
	expect(not Guard.keyOf(items)({}))
	expect(Guard.literal("a", "b")("b"))
	expect(not Guard.literal("a", "b")("c"))
end)

test("Guard.array and shape reject garbage", function()
	local arr = Guard.array(Guard.integer(), 3)
	expect(arr({ 1, 2, 3 }))
	expect(not arr({ 1, 2, 3, 4 }))
	expect(not arr({ 1, "x" }))
	expect(not arr({ [1] = 1, [3] = 3 }))
	expect(not arr(setmetatable({}, {})))
	local shape = Guard.shape({ id = Guard.string(), amount = Guard.optional(Guard.integer()) })
	expect(shape({ id = "a" }))
	expect(shape({ id = "a", amount = 2 }))
	expect(not shape({ id = "a", extra = true }))
	expect(not shape({ amount = 2 }))
end)

test("Guard.tuple checks count and each argument", function()
	local check = Guard.tuple(Guard.string(), Guard.optional(Guard.number()))
	expect(check("a"))
	expect(check("a", 1))
	expect(not check("a", 1, 2))
	expect(not check(1))
	expect(Guard.tuple()())
	expect(not Guard.tuple()(1))
end)

test("RateLimiter respects burst and refills", function()
	local now = 0
	local limiter = RateLimiter.new(2, 3, function()
		return now
	end)
	expect(limiter:Allow("p"))
	expect(limiter:Allow("p"))
	expect(limiter:Allow("p"))
	expect(not limiter:Allow("p"))
	expect(limiter:Allow("outro"), "keys are independent")
	now = 0.5 -- +1 token
	expect(limiter:Allow("p"))
	expect(not limiter:Allow("p"))
	limiter:Clear("p")
	expect(limiter:Allow("p"))
end)

test("Signal Connect/Fire/Disconnect/Once", function()
	local signal = Signal.new()
	local total = 0
	local conn = signal:Connect(function(n)
		total += n
	end)
	signal:Once(function(n)
		total += n * 100
	end)
	signal:Fire(1)
	signal:Fire(2)
	expect(total == 103, `total={total}`)
	conn:Disconnect()
	expect(not conn.Connected)
	signal:Fire(5)
	expect(total == 103)
end)

test("Signal: disconnecting during Fire is safe", function()
	local signal = Signal.new()
	local calls = 0
	local a
	a = signal:Connect(function()
		calls += 1
		a:Disconnect()
	end)
	signal:Connect(function()
		calls += 1
	end)
	signal:Fire()
	signal:Fire()
	expect(calls == 3, `calls={calls}`)
end)

test("Signal:Wait returns the arguments", function()
	local signal = Signal.new()
	local received
	task.spawn(function()
		received = table.pack(signal:Wait())
	end)
	signal:Fire("x", 2)
	task.wait()
	expect(received and received[1] == "x" and received[2] == 2)
end)

test("Trove cleans functions, objects and threads in reverse order", function()
	local trove = Trove.new()
	local order = {}
	trove:Add(function()
		table.insert(order, "first")
	end)
	trove:Add({
		Destroy = function()
			table.insert(order, "second")
		end,
	})
	local signal = Signal.new()
	local fired = 0
	trove:Connect(signal, function()
		fired += 1
	end)
	local ran = false
	trove:Add(task.delay(0.05, function()
		ran = true
	end))
	trove:Clean()
	signal:Fire()
	task.wait(0.1)
	expect(order[1] == "second" and order[2] == "first", table.concat(order, ","))
	expect(fired == 0, "connection should be disconnected")
	expect(not ran, "thread should have been cancelled")
	-- Reusable after Clean
	local again = false
	trove:Add(function()
		again = true
	end)
	trove:Clean()
	expect(again)
end)

test("Trove:Remove cleans only that object", function()
	local trove = Trove.new()
	local a, b = false, false
	local fa = function()
		a = true
	end
	trove:Add(fa)
	trove:Add(function()
		b = true
	end)
	expect(trove:Remove(fa))
	expect(a and not b)
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
