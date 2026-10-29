--!strict
-- Runs the generated Studio installers (rbxkit init → install/*.luau) inside a Lune
-- DataModel and checks the tree they build.
--   node tools/rbxkit.mjs init /tmp/agent && lune run tests/luau/install.spec.luau /tmp/agent/install

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any

local dir = process.args[1]
assert(dir, "usage: lune run tests/luau/install.spec.luau <install dir>")

local game = roblox.Instance.new("DataModel")
local globals = { game = game, Instance = roblox.Instance, Enum = roblox.Enum }

local function runInstaller(file: string, force: boolean?): string
	local source = fs.readFile(`{dir}/{file}`)
	if force then
		source = string.gsub(source, "local FORCE = false", "local FORCE = true", 1)
	end
	return luau.load(source, { debugName = file, environment = globals })()
end

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

local files = fs.readDir(dir)
table.sort(files)

test("every installer runs and reports", function()
	assert(#files == 5, `expected 5 installers, got {#files}`)
	for _, file in files do
		local message = runInstaller(file)
		assert(string.find(message, "created %d+"), message)
		print(`     {message}`)
	end
end)

local function at(path: string): any
	local node: any = game
	for _, name in string.split(path, ".") do
		node = if node == game then game:GetService(name) else node:FindFirstChild(name)
		assert(node, `missing {path} (at {name})`)
	end
	return node
end

test("tree mirrors studio/", function()
	assert(at("ServerScriptService.Server").ClassName == "Script")
	assert(at("ServerScriptService.Server.Services.DataService").ClassName == "ModuleScript")
	assert(at("ServerScriptService.Server.Config.DataTemplate").ClassName == "ModuleScript")
	assert(at("ReplicatedStorage.Shared.Net").ClassName == "ModuleScript")
	assert(at("ReplicatedStorage.Shared.Util.Guard").ClassName == "ModuleScript")
	assert(at("StarterPlayer.StarterPlayerScripts.Client").ClassName == "LocalScript")
	assert(at("StarterPlayer.StarterPlayerScripts.Client.Controllers").ClassName == "Folder")
	for _, name in { "Build", "Shots", "Lint" } do
		assert(at("ServerStorage.DevTools." .. name).ClassName == "ModuleScript")
	end
	local source = at("ReplicatedStorage.Shared.Util.Guard").Source
	assert(string.sub(source, 1, 9) == "--!strict", "source starts with --!strict")
	assert(string.find(source, "function Guard.tuple", 1, true), "full source installed")
end)

test("re-running keeps existing scripts; FORCE updates them", function()
	local marker = "-- user edit"
	local guard = at("ReplicatedStorage.Shared.Util.Guard")
	guard.Source = guard.Source .. marker
	assert(string.find(runInstaller(files[1]), "updated 0", 1, true))
	assert(string.find(guard.Source, marker, 1, true), "user edit kept")
	assert(string.find(runInstaller(files[1], true), "updated [1-9]"))
	assert(not string.find(guard.Source, marker, 1, true), "FORCE replaced the source")
end)

test("installed code passes the installed Lint", function()
	local source = at("ServerStorage.DevTools.Lint").Source
	local Lint = luau.load(source, { debugName = "Lint", environment = globals })()
	local report = Lint.run()
	local text = Lint.summary(report)
	print(`     {string.split(text, "\n")[1]}`)
	assert(report.scripts >= 10, text)
	assert(string.find(text, "0 error%(s%), 0 warning%(s%)"), text)
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
