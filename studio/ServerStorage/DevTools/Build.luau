--!strict
--[[
	DevTools/Build: build clean, well-proportioned geometry from code.
	Meant for the Studio command bar or the Studio MCP `execute_luau` tool (edit mode).
	Lives in ServerStorage: never replicated, never runs in live servers.

	local B = require(game:GetService("ServerStorage").DevTools.Build)
	B.undoable("Build house", function()
		local house = B.model("House", workspace)              -- replaces an old "House"
		local pal = B.palettes.cottage
		B.part(house, { name = "Floor", size = Vector3.new(24, 1, 18), pos = Vector3.new(0, 0.5, 0),
			color = pal.wood, material = Enum.Material.WoodPlanks })
		B.wall(house, { from = Vector3.new(-12, 1, -9), to = Vector3.new(12, 1, -9), height = 12,
			color = pal.wall, material = Enum.Material.Plaster, trim = pal.trim,
			openings = { { offset = 12, width = 4, height = 7.5 }, { offset = 5, width = 4, height = 4, bottom = 3 } } })
		B.finalize(house)
	end)
	return B.summary(B.audit(workspace.House))                  -- short text report

	Every created part is anchored, smooth-surfaced and named. Decor parts (`decor = true`)
	don't collide, touch or query, and small decor casts no shadow.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Build = {}

export type Shape = "Block" | "Cylinder" | "Ball" | "Wedge" | "CornerWedge"

export type PartProps = {
	name: string?,
	shape: Shape?,
	size: Vector3?,
	cf: CFrame?, -- center of the part (takes precedence over pos)
	pos: Vector3?,
	color: (Color3 | string)?, -- Color3 or "#RRGGBB"
	material: Enum.Material?,
	materialVariant: string?,
	transparency: number?,
	reflectance: number?,
	anchored: boolean?, -- default true
	collide: boolean?, -- default true (false when decor)
	decor: boolean?, -- purely visual: no collide/touch/query
	shadow: boolean?, -- default true (false for small decor)
	attributes: { [string]: any }?,
	tags: { string }?,
}

export type Opening = {
	offset: number, -- distance from the wall start to the opening center
	width: number,
	height: number,
	bottom: number?, -- height of the sill above the wall base (0 = door)
}

export type WallProps = PartProps & {
	from: Vector3, -- start point; its Y is the wall base
	to: Vector3, -- end point (Y ignored)
	height: number,
	thickness: number?, -- default 1
	openings: { Opening }?,
	trim: (Color3 | string)?, -- adds frames around openings in this color
	trimWidth: number?, -- default 0.4
}

export type StairsProps = PartProps & {
	cf: CFrame, -- bottom of the first step, at its front edge center; stairs climb along LookVector
	steps: number,
	width: number,
	rise: number?, -- default 1 (comfortable for Humanoids)
	run: number?, -- default 1.5
	solid: boolean?, -- default true (fills below each step)
}

export type Report = {
	parts: number,
	meshParts: number,
	unanchored: number,
	collidable: number,
	materials: number,
	colors: number,
	tiny: { string },
	zFighting: { string },
	notes: { string },
}

-- Cohesive palettes: 1 base, 1-2 secondaries, 1 accent, light/dark. Mixing palettes looks noisy.
Build.palettes = table.freeze({
	cottage = table.freeze({
		wall = Color3.fromHex("#E8DCC4"),
		wood = Color3.fromHex("#8B5A3C"),
		trim = Color3.fromHex("#5A3A28"),
		roof = Color3.fromHex("#9C3D2E"),
		stone = Color3.fromHex("#8D8A84"),
		accent = Color3.fromHex("#3F6E5A"),
	}),
	modern = table.freeze({
		wall = Color3.fromHex("#F2F2EF"),
		concrete = Color3.fromHex("#A7A9AC"),
		dark = Color3.fromHex("#2B2D31"),
		wood = Color3.fromHex("#B58A62"),
		glass = Color3.fromHex("#9FC6D9"),
		accent = Color3.fromHex("#E0A030"),
	}),
	medieval = table.freeze({
		stone = Color3.fromHex("#7D7A73"),
		darkStone = Color3.fromHex("#55524D"),
		wood = Color3.fromHex("#6B4630"),
		plaster = Color3.fromHex("#D9CDB4"),
		roof = Color3.fromHex("#4A5560"),
		accent = Color3.fromHex("#A3832E"),
	}),
	scifi = table.freeze({
		hull = Color3.fromHex("#C9CED6"),
		panel = Color3.fromHex("#8E96A3"),
		dark = Color3.fromHex("#1E232B"),
		glow = Color3.fromHex("#38D9F5"),
		warning = Color3.fromHex("#F2B33D"),
		accent = Color3.fromHex("#E2504C"),
	}),
	nature = table.freeze({
		grass = Color3.fromHex("#5E8C3A"),
		leaf = Color3.fromHex("#3F7A35"),
		bark = Color3.fromHex("#5C4033"),
		rock = Color3.fromHex("#8A8580"),
		sand = Color3.fromHex("#D8C38E"),
		water = Color3.fromHex("#3E7FA6"),
	}),
	candy = table.freeze({
		pink = Color3.fromHex("#FF8FB8"),
		mint = Color3.fromHex("#7FE0C2"),
		lemon = Color3.fromHex("#FFE27A"),
		lilac = Color3.fromHex("#B79CFF"),
		cream = Color3.fromHex("#FFF4E6"),
		accent = Color3.fromHex("#FF5A5F"),
	}),
})

local function toColor(value: Color3 | string): Color3
	if typeof(value) == "Color3" then
		return value
	end
	return Color3.fromHex(value :: string)
end

local function apply(part: BasePart, props: PartProps)
	part.Name = props.name or part.Name
	if props.size then
		part.Size = props.size
	end
	if props.cf then
		part.CFrame = props.cf
	elseif props.pos then
		part.CFrame = CFrame.new(props.pos)
	end
	if props.color then
		part.Color = toColor(props.color)
	end
	part.Material = props.material or Enum.Material.SmoothPlastic
	if props.materialVariant then
		part.MaterialVariant = props.materialVariant
	end
	part.Transparency = props.transparency or 0
	part.Reflectance = props.reflectance or 0
	part.Anchored = if props.anchored == nil then true else props.anchored
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.decor then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = if props.shadow == nil then part.Size.Magnitude > 4 else props.shadow
	else
		part.CanCollide = if props.collide == nil then true else props.collide
		part.CastShadow = if props.shadow == nil then true else props.shadow
	end
	if props.attributes then
		for key, value in props.attributes do
			part:SetAttribute(key, value)
		end
	end
	if props.tags then
		for _, tag in props.tags do
			part:AddTag(tag)
		end
	end
end

-- Creates a Model (replacing an existing child with the same name, so builds are re-runnable).
function Build.model(name: string, parent: Instance, replace: boolean?): Model
	if replace ~= false then
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.part(parent: Instance, props: PartProps): BasePart
	local shape: Shape = props.shape or "Block"
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif shape == "CornerWedge" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = if shape == "Cylinder"
			then Enum.PartType.Cylinder
			elseif shape == "Ball" then Enum.PartType.Ball
			else Enum.PartType.Block
		part = p
	end
	part.Name = shape
	apply(part, props)
	part.Parent = parent
	return part
end

-- Cylinder standing along `axis` (default "Y"); Roblox cylinders are natively along X.
function Build.cylinder(parent: Instance, props: PartProps & { radius: number, height: number, axis: ("X" | "Y" | "Z")? }): BasePart
	local center = props.cf or CFrame.new(props.pos or Vector3.zero)
	local axis = props.axis or "Y"
	local rotation = if axis == "Y"
		then CFrame.Angles(0, 0, math.pi / 2)
		elseif axis == "Z" then CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.identity
	local merged: PartProps = table.clone(props) :: any
	merged.shape = "Cylinder"
	merged.size = Vector3.new(props.height, props.radius * 2, props.radius * 2)
	merged.cf = center * rotation
	return Build.part(parent, merged)
end

-- Straight wall with door/window openings cut out, built from clean non-overlapping segments.
function Build.wall(parent: Instance, props: WallProps): Model
	local flat = Vector3.new(props.to.X - props.from.X, 0, props.to.Z - props.from.Z)
	local length = flat.Magnitude
	assert(length > 0.05, "Build.wall: from and to are too close")
	local thickness = props.thickness or 1
	local along = flat.Unit
	local basis = CFrame.fromMatrix(props.from, along, Vector3.yAxis)
	local model = Build.model(props.name or "Wall", parent, false)

	local function piece(name: string, x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.01 or y1 - y0 < 0.01 then
			return
		end
		local segment: PartProps = table.clone(props) :: any
		segment.name = name
		segment.size = Vector3.new(x1 - x0, y1 - y0, thickness)
		segment.cf = basis * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0)
		Build.part(model, segment)
	end

	local openings: { Opening } = table.clone(props.openings or {})
	table.sort(openings, function(a: Opening, b: Opening)
		return a.offset < b.offset
	end)

	local cursor = 0
	for i, opening in openings do
		local left = math.max(opening.offset - opening.width / 2, cursor)
		local right = math.min(opening.offset + opening.width / 2, length)
		local bottom = opening.bottom or 0
		local top = math.min(bottom + opening.height, props.height)
		piece(`Segment{i}`, cursor, left, 0, props.height)
		piece(`Below{i}`, left, right, 0, bottom)
		piece(`Above{i}`, left, right, top, props.height)

		if props.trim then
			local w = props.trimWidth or 0.4
			local depth = thickness + 0.2
			local function trim(name: string, x0: number, x1: number, y0: number, y1: number)
				Build.part(model, {
					name = name,
					size = Vector3.new(x1 - x0, y1 - y0, depth),
					cf = basis * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
					color = props.trim,
					material = props.material,
					decor = true,
				})
			end
			-- Frames sit inside the opening so they never overlap the wall faces (no z-fighting).
			trim(`JambL{i}`, left, left + w, bottom, top)
			trim(`JambR{i}`, right - w, right, bottom, top)
			trim(`Head{i}`, left + w, right - w, top - w, top)
			if bottom > 0 then
				trim(`Sill{i}`, left + w, right - w, bottom, bottom + w)
			end
		end
		cursor = right
	end
	piece("SegmentEnd", cursor, length, 0, props.height)
	return model
end

-- Straight staircase; each step is one clean part (solid by default).
function Build.stairs(parent: Instance, props: StairsProps): Model
	local rise = props.rise or 1
	local run = props.run or 1.5
	local solid = props.solid ~= false
	local model = Build.model(props.name or "Stairs", parent, false)
	for i = 0, props.steps - 1 do
		local height = if solid then rise * (i + 1) else rise
		local y = if solid then height / 2 else rise * i + rise / 2
		local step: PartProps = table.clone(props) :: any
		step.name = `Step{i + 1}`
		step.size = Vector3.new(props.width, height, run)
		step.cf = props.cf * CFrame.new(0, y, -(run * i + run / 2))
		Build.part(model, step)
	end
	return model
end

-- Repeats `make(i, cframe)` along a line: count copies spaced by `offset` (local to `origin`).
function Build.array(count: number, origin: CFrame, offset: Vector3, make: (index: number, cf: CFrame) -> ())
	for i = 0, count - 1 do
		make(i + 1, origin * CFrame.new(offset * i))
	end
end

-- Repeats `make(i, cframe)` around a circle; each cframe faces outward.
function Build.ring(count: number, center: CFrame, radius: number, make: (index: number, cf: CFrame) -> ())
	for i = 0, count - 1 do
		local angle = (i / count) * math.pi * 2
		make(i + 1, center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius))
	end
end

-- Sets PrimaryPart (largest part unless given) and moves the pivot to the bottom center.
function Build.finalize(model: Model, primary: BasePart?): Model
	local best: BasePart? = primary
	if not best then
		local bestVolume = -1
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local volume = d.Size.X * d.Size.Y * d.Size.Z
				if volume > bestVolume then
					best, bestVolume = d, volume
				end
			end
		end
	end
	if best then
		model.PrimaryPart = best
		local boxCf, boxSize = model:GetBoundingBox()
		model.WorldPivot = boxCf * CFrame.new(0, -boxSize.Y / 2, 0)
	end
	return model
end

-- Wraps a build in one undo step (Ctrl+Z undoes the whole build). Errors cancel the recording.
function Build.undoable(name: string, fn: () -> ())
	local okBegin, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording(name)
	end)
	local result = table.pack(pcall(fn))
	local ok, err = result[1], result[2]
	if okBegin and recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	if not ok then
		error(err, 0)
	end
end

local EPS = 0.002
local MAX_PAIR_PARTS = 1500
local MAX_LISTED = 8

local function isAxisAligned(cf: CFrame): boolean
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	for _, v in { r00, r01, r02, r10, r11, r12, r20, r21, r22 } do
		local a = math.abs(v)
		if a > EPS and math.abs(a - 1) > EPS then
			return false
		end
	end
	return true
end

type Box = { part: BasePart, min: Vector3, max: Vector3 }

local function worldBox(part: BasePart): Box
	local cf, size = part.CFrame, part.Size
	local half = (cf.RightVector * size.X):Abs() / 2 + (cf.UpVector * size.Y):Abs() / 2 + (cf.LookVector * size.Z):Abs() / 2
	return { part = part, min = cf.Position - half, max = cf.Position + half }
end

local function overlap(aMin: number, aMax: number, bMin: number, bMax: number): number
	return math.min(aMax, bMax) - math.max(aMin, bMin)
end

local function sameLook(a: BasePart, b: BasePart): boolean
	return a.Color == b.Color and a.Material == b.Material and a.MaterialVariant == b.MaterialVariant
end

-- Two coplanar faces pointing the same way and overlapping = flickering (z-fighting).
local function zFights(a: Box, b: Box): boolean
	local axes = { "X", "Y", "Z" }
	for i, axis in axes do
		local o1, o2 = axes[(i % 3) + 1], axes[((i + 1) % 3) + 1]
		local aMin, aMax = (a.min :: any)[axis], (a.max :: any)[axis]
		local bMin, bMax = (b.min :: any)[axis], (b.max :: any)[axis]
		if math.abs(aMax - bMax) < EPS or math.abs(aMin - bMin) < EPS then
			local w = overlap((a.min :: any)[o1], (a.max :: any)[o1], (b.min :: any)[o1], (b.max :: any)[o1])
			local h = overlap((a.min :: any)[o2], (a.max :: any)[o2], (b.min :: any)[o2], (b.max :: any)[o2])
			if w > 0.05 and h > 0.05 then
				return true
			end
		end
	end
	return false
end

-- Cheap text-only quality check (use before spending tokens on screenshots).
function Build.audit(root: Instance): Report
	local report: Report = {
		parts = 0,
		meshParts = 0,
		unanchored = 0,
		collidable = 0,
		materials = 0,
		colors = 0,
		tiny = {},
		zFighting = {},
		notes = {},
	}
	local materials, colors = {}, {}
	local boxes: { Box } = {}
	local descendants = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(descendants, root)
	end
	for _, d in descendants do
		if not d:IsA("BasePart") then
			continue
		end
		report.parts += 1
		if d:IsA("MeshPart") then
			report.meshParts += 1
		end
		if not d.Anchored then
			report.unanchored += 1
		end
		if d.CanCollide then
			report.collidable += 1
		end
		materials[d.Material] = true
		colors[d.Color:ToHex()] = true
		if math.min(d.Size.X, d.Size.Y, d.Size.Z) < 0.05 and #report.tiny < MAX_LISTED then
			table.insert(report.tiny, d:GetFullName())
		end
		if d.Transparency < 1 and isAxisAligned(d.CFrame) then
			table.insert(boxes, worldBox(d))
		end
	end
	for _ in materials do
		report.materials += 1
	end
	for _ in colors do
		report.colors += 1
	end

	if #boxes <= MAX_PAIR_PARTS then
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				local a, b = boxes[i], boxes[j]
				if not sameLook(a.part, b.part) and zFights(a, b) then
					if #report.zFighting < MAX_LISTED then
						table.insert(report.zFighting, `{a.part:GetFullName()} <> {b.part:GetFullName()}`)
					end
				end
			end
		end
	else
		table.insert(report.notes, `z-fighting check skipped ({#boxes} parts > {MAX_PAIR_PARTS}); audit sub-models`)
	end

	if report.colors > 10 then
		table.insert(report.notes, `{report.colors} distinct colors: palette may look noisy (aim for 3-6 + accents)`)
	end
	if report.parts > 800 and report.meshParts == 0 then
		table.insert(report.notes, "many parts and no MeshParts: consider meshes for repeated complex props")
	end
	return report
end

function Build.summary(report: Report): string
	local lines = {
		`parts={report.parts} meshParts={report.meshParts} unanchored={report.unanchored} collidable={report.collidable} materials={report.materials} colors={report.colors}`,
	}
	if #report.zFighting > 0 then
		table.insert(lines, "z-fighting: " .. table.concat(report.zFighting, "; "))
	end
	if #report.tiny > 0 then
		table.insert(lines, "tiny (<0.05 stud): " .. table.concat(report.tiny, "; "))
	end
	for _, note in report.notes do
		table.insert(lines, "note: " .. note)
	end
	return table.concat(lines, "\n")
end

return Build
