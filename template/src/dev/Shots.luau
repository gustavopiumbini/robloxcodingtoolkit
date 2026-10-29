--!strict
--[[
	DevTools/Shots: point the Studio edit camera at a build so `screen_capture` shows it well.

	local Shots = require(game:GetService("ServerStorage").DevTools.Shots)
	Shots.frame(workspace.House, "iso")    -- then call the MCP screen_capture tool
	Shots.frame(workspace.House, "front")
	Shots.restore()                         -- put the user's camera back

	Views: front, back, left, right, top, iso, iso_back, low (hero shot), close (detail).
	"front" is the side the model's pivot LookVector points to.
]]

local Shots = {}

export type View = "front" | "back" | "left" | "right" | "top" | "iso" | "iso_back" | "low" | "close"

local saved: CFrame? = nil

local function bounds(target: Instance): (CFrame, Vector3)
	if target:IsA("Model") then
		return target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		return target.CFrame, target.Size
	end
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size.Magnitude / 2
			minV = minV:Min(d.Position - Vector3.one * half)
			maxV = maxV:Max(d.Position + Vector3.one * half)
		end
	end
	assert(minV.X < math.huge, "Shots.frame: target has no parts")
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

local function direction(cf: CFrame, view: View): Vector3
	local look, right, up = cf.LookVector, cf.RightVector, cf.UpVector
	if view == "front" then
		return look + up * 0.15
	elseif view == "back" then
		return -look + up * 0.15
	elseif view == "left" then
		return -right + up * 0.15
	elseif view == "right" then
		return right + up * 0.15
	elseif view == "top" then
		return up + look * 0.02
	elseif view == "iso_back" then
		return -look - right + up * 0.9
	elseif view == "low" then
		return look + right * 0.6 - up * 0.05
	end
	return look + right + up * 0.9 -- iso / close
end

-- Frames the target and returns a one-line description (cheap to log).
function Shots.frame(target: Instance, view: View?, padding: number?): string
	local camera = workspace.CurrentCamera
	if not saved then
		saved = camera.CFrame
	end
	local chosen: View = view or "iso"
	local cf, size = bounds(target)
	local radius = size.Magnitude / 2
	local fov = math.rad(camera.FieldOfView)
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then math.min(viewport.X / viewport.Y, 1) else 1
	local halfFov = math.atan(math.tan(fov / 2) * aspect) -- narrowest half-angle of the view
	local distance = radius / math.sin(halfFov) * (padding or 1.05)
	if chosen == "close" then
		distance *= 0.45
	end
	local focus = cf.Position
	if chosen == "low" then
		focus -= Vector3.yAxis * (size.Y * 0.2)
	end
	local eye = focus + direction(cf, chosen).Unit * distance
	camera.CFrame = CFrame.lookAt(eye, focus, if chosen == "top" then cf.LookVector else Vector3.yAxis)
	camera.Focus = CFrame.new(focus)
	return `{target.Name}: view={chosen} size={math.round(size.X)}x{math.round(size.Y)}x{math.round(size.Z)} distance={math.round(distance)}`
end

-- Puts the camera back where the user had it.
function Shots.restore()
	if saved then
		workspace.CurrentCamera.CFrame = saved
		saved = nil
	end
end

return Shots
