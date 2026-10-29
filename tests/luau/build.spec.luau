--!strict
-- Tests for studio/ServerStorage/DevTools/Build.luau using Lune's Roblox datatypes and Instances.
--   lune run tests/luau/build.spec.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any
local load = require("./loader")

-- Roblox globals Build.luau expects. Paths are relative to the repository root.
local B = load("studio/ServerStorage/DevTools/Build.luau", {
	task = require("@lune/task"),
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	game = roblox.Instance.new("DataModel"),
})

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
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

local function parts(root: any): { any }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

test("part applies quality defaults", function()
	local root = roblox.Instance.new("Folder")
	local p = B.part(root, { name = "Floor", size = roblox.Vector3.new(10, 1, 10), color = "#FF0000" })
	expect(p.Name == "Floor")
	expect(p.Anchored == true and p.CanCollide == true)
	expect(p.TopSurface == roblox.Enum.SurfaceType.Smooth)
	expect(p.Color:ToHex():lower() == "ff0000")
	local d = B.part(root, { size = roblox.Vector3.new(0.5, 0.5, 0.5), decor = true })
	expect(d.CanCollide == false and d.CanTouch == false and d.CanQuery == false)
	expect(d.CastShadow == false, "small decor casts no shadow")
end)

test("model replaces an existing build with the same name", function()
	local root = roblox.Instance.new("Folder")
	B.model("House", root)
	B.model("House", root)
	expect(#root:GetChildren() == 1)
end)

test("wall with door and window: segments cover the wall exactly", function()
	local root = roblox.Instance.new("Folder")
	local wall = B.wall(root, {
		from = roblox.Vector3.new(0, 0, 0),
		to = roblox.Vector3.new(20, 0, 0),
		height = 10,
		openings = {
			{ offset = 15, width = 4, height = 4, bottom = 3 }, -- window (unsorted on purpose)
			{ offset = 5, width = 4, height = 7 }, -- door
		},
	})
	local area = 0
	for _, p in parts(wall) do
		area += p.Size.X * p.Size.Y
		expect(near(p.Size.Z, 1), "default thickness 1")
		expect(p.CFrame.Position.Y >= 0 and p.CFrame.Position.Y <= 10)
	end
	local expected = 20 * 10 - 4 * 7 - 4 * 4
	expect(near(area, expected), `wall area {area} ~= {expected}`)
	expect(#B.audit(wall).zFighting == 0, "clean wall has no z-fighting")
end)

test("wall trims add frames without z-fighting", function()
	local root = roblox.Instance.new("Folder")
	local wall = B.wall(root, {
		from = roblox.Vector3.new(0, 0, 0),
		to = roblox.Vector3.new(0, 0, 12), -- along Z
		height = 10,
		color = "#EEEEEE",
		trim = "#552200",
		openings = { { offset = 6, width = 4, height = 4, bottom = 3 } },
	})
	local trims = 0
	for _, p in parts(wall) do
		if p.Name:find("Jamb") or p.Name:find("Head") or p.Name:find("Sill") then
			trims += 1
			expect(p.CanCollide == false, "trims are decor")
		end
	end
	expect(trims == 4, `expected 4 trims, got {trims}`)
	local report = B.audit(wall)
	expect(#report.zFighting == 0, table.concat(report.zFighting, "; "))
end)

test("stairs climb along LookVector with solid steps", function()
	local root = roblox.Instance.new("Folder")
	local stairs = B.stairs(root, { cf = roblox.CFrame.new(0, 0, 0), steps = 4, width = 6 })
	local list = parts(stairs)
	expect(#list == 4)
	for _, p in list do
		local i = tonumber(p.Name:match("%d+")) :: number
		expect(near(p.Size.Y, i), "solid step height = rise * index")
		expect(p.CFrame.Position.Z < 0, "climbs toward -Z (LookVector)")
	end
end)

test("audit flags coplanar overlapping faces with different looks", function()
	local root = roblox.Instance.new("Folder")
	B.part(root, { name = "Floor", size = roblox.Vector3.new(10, 1, 10), pos = roblox.Vector3.new(0, 0.5, 0), color = "#808080" })
	B.part(root, { name = "Tile", size = roblox.Vector3.new(2, 0.5, 2), pos = roblox.Vector3.new(0, 0.75, 0), color = "#FFFFFF" })
	local report = B.audit(root)
	expect(#report.zFighting == 1, `expected 1 z-fight, got {#report.zFighting}`)
	expect(report.parts == 2)
	-- Raised by 0.02: fixed.
	local tile = root:FindFirstChild("Tile") :: any
	tile.CFrame = roblox.CFrame.new(0, 0.77, 0)
	expect(#B.audit(root).zFighting == 0)
end)

test("summary is short text", function()
	local root = roblox.Instance.new("Folder")
	B.part(root, { size = roblox.Vector3.new(1, 0.01, 1) })
	local text = B.summary(B.audit(root))
	expect(text:find("parts=1") ~= nil)
	expect(text:find("tiny") ~= nil)
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
