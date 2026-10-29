--!strict
-- Tests for studio/ServerStorage/DevTools/Lint.luau, plus a lint pass over every
-- studio/ script (the toolkit must pass its own lint).
--   lune run tests/luau/lint.spec.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local load = require("./loader")

local Lint = load("studio/ServerStorage/DevTools/Lint.luau", {})

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

local function rules(source: string, side: string?): string
	local ids = {}
	for _, f in Lint.checkSource("--!strict\n" .. source, side or "shared") do
		table.insert(ids, f.rule)
	end
	return table.concat(ids, ",")
end
local function eq(actual: string, expected: string)
	if actual ~= expected then
		error(`expected "{expected}", got "{actual}"`, 2)
	end
end

test("mask keeps length and lines, blanks comments and strings", function()
	local src = 'local a = "wait(1)" -- wait(2)\n--[[ spawn(f)\n]] local b = [==[ delay() ]==]\nlocal c = `x {wait(3)} y`'
	local masked = Lint.mask(src)
	assert(#masked == #src, "same length")
	assert(not string.find(masked, "wait(1)", 1, true) and not string.find(masked, "wait(2)", 1, true))
	assert(not string.find(masked, "spawn", 1, true) and not string.find(masked, "delay", 1, true))
	assert(string.find(masked, "wait(3)", 1, true), "interpolated expressions are code")
end)

test("deprecated APIs", function()
	eq(rules("wait(1)"), "deprecated-wait")
	eq(rules("spawn(f)"), "deprecated-spawn")
	eq(rules("delay(1, f)"), "deprecated-delay")
	eq(rules("part.Touched:connect(f)"), "lowercase-connect")
	eq(rules("model:SetPrimaryPartCFrame(cf)"), "set-primary-part-cframe")
	eq(rules("humanoid:LoadAnimation(anim)"), "humanoid-load-animation")
	eq(rules('local v = Instance.new("BodyVelocity")'), "body-movers")
	eq(rules('local p = Instance.new("Part", workspace)'), "instance-new-parent")
end)

test("modern code and text in strings/comments are clean", function()
	eq(rules("task.wait(1)\ntask.spawn(f)\ntask.delay(1, f)\nsignal:Wait()"), "")
	eq(rules('print("wait(1)") -- spawn(f)'), "")
	eq(rules('local p = Instance.new("Part")\np.Parent = workspace'), "")
	eq(rules('local s = game:GetService("Players")'), "")
end)

test("security rules", function()
	eq(rules("require(123456)"), "require-asset-id")
	eq(rules("loadstring(code)()"), "loadstring")
	eq(rules("remote:InvokeClient(player)"), "invoke-client")
	eq(rules("remote:FireServer(player, 1)"), "fireserver-player-arg")
	eq(rules("local p = Players.LocalPlayer", "server"), "localplayer-on-server")
	eq(rules("local p = Players.LocalPlayer", "client"), "")
	eq(rules('local d = game:GetService("DataStoreService")', "client"), "server-api-on-client")
	eq(rules("RunService.RenderStepped:Connect(f)", "server"), "render-on-server")
end)

test("remote handlers must validate", function()
	eq(rules("remote.OnServerEvent:Connect(function(player, amount)\n\tcoins += amount\nend)"), "remote-without-validation")
	eq(rules('remote.OnServerEvent:Connect(function(player, amount)\n\tif typeof(amount) ~= "number" then return end\nend)'), "")
	eq(rules("remote.OnServerEvent:Connect(function(player)\n\tprint(player)\nend)"), "")
end)

test("while true and DataStore checks", function()
	eq(rules("while true do\n\tx += 1\nend"), "while-true-no-yield")
	eq(rules("while true do\n\ttask.wait(1)\nend"), "")
	eq(rules("local v = store:GetAsync(key)"), "datastore-no-pcall")
	eq(rules("local ok, v = pcall(function()\n\treturn store:GetAsync(key)\nend)"), "")
end)

test("suppression comments and missing --!strict", function()
	eq(rules("wait(1) -- rbxkit-ignore"), "")
	eq(rules("wait(1) -- rbxkit-ignore: deprecated-wait"), "")
	eq(rules("wait(1) -- rbxkit-ignore: other-rule"), "deprecated-wait")
	eq(rules("-- rbxkit-ignore-next-line\nwait(1)"), "")
	local ids = {}
	for _, f in Lint.checkSource("local x = 1", "shared") do
		table.insert(ids, f.rule)
	end
	eq(table.concat(ids, ","), "missing-strict")
end)

test("summary is short and sorted", function()
	local report = { scripts = 2, findings = {
		{ path = "B", line = 3, rule = "x", severity = "warning", message = "w" },
		{ path = "A", line = 9, rule = "y", severity = "error", message = "e" },
		{ path = "A", line = 1, rule = "z", severity = "info", message = "i" },
	} }
	local text = Lint.summary(report)
	assert(string.find(text, "^2 scripts: 1 error%(s%), 1 warning%(s%), 1 info"), text)
	assert(string.find(text, "A:9 error y: e\nB:3 warning x: w", 1, true), text)
	assert(not string.find(text, "A:1", 1, true), "info hidden by default")
end)

-- The toolkit's own Studio code must be clean.
local function walk(dir: string, files: { string })
	for _, name in fs.readDir(dir) do
		local full = `{dir}/{name}`
		if fs.isDir(full) then
			walk(full, files)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(files, full)
		end
	end
end

test("every studio/ script passes Lint", function()
	local files = {}
	walk("studio", files)
	assert(#files >= 10, "found studio scripts")
	local problems = {}
	for _, file in files do
		local side = if string.find(file, "^studio/ServerScriptService") or string.find(file, "^studio/ServerStorage")
			then "server"
			elseif string.find(file, "^studio/StarterPlayer") then "client"
			else "shared"
		for _, f in Lint.checkSource(fs.readFile(file), side, file) do
			table.insert(problems, `{f.path}:{f.line} {f.rule}`)
		end
	end
	assert(#problems == 0, table.concat(problems, "; "))
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
