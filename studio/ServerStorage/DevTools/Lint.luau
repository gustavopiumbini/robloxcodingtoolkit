--!strict
--[[
	DevTools/Lint: Roblox-specific lint over the scripts in this place.
	Run it in Studio (MCP `execute_luau` or the command bar) and read the short report.

	local Lint = require(game:GetService("ServerStorage").DevTools.Lint)
	return Lint.summary(Lint.run())                                 -- whole game
	return Lint.summary(Lint.run(game.ServerScriptService.Server))  -- one subtree

	Silence a line with `-- rbxkit-ignore: rule-id`, or the next line with
	`-- rbxkit-ignore-next-line`.
]]

local Lint = {}

export type Severity = "error" | "warning" | "info"
export type Side = "server" | "client" | "shared"
export type Finding = {
	path: string,
	line: number,
	rule: string,
	severity: Severity,
	message: string,
}
export type Report = { scripts: number, findings: { Finding } }

type Context = { line: string, raw: string, side: Side, masked: { string }, index: number }
type Rule = { id: string, severity: Severity, test: (Context) -> string? }

-- Blanks comments and string contents (keeping newlines and positions) so rules only see code.
function Lint.mask(src: string): string
	local n = #src
	local out = table.create(n)
	for i = 1, n do
		out[i] = string.sub(src, i, i)
	end
	local function blank(a: number, b: number)
		for k = a, math.min(b, n) do
			if out[k] ~= "\n" then
				out[k] = " "
			end
		end
	end
	local function longLevel(pos: number): number
		if string.sub(src, pos, pos) ~= "[" then
			return -1
		end
		local j, level = pos + 1, 0
		while string.sub(src, j, j) == "=" do
			level += 1
			j += 1
		end
		return if string.sub(src, j, j) == "[" then level else -1
	end
	local function longClose(from: number, level: number): number
		local _, e = string.find(src, "]" .. string.rep("=", level) .. "]", from, true)
		return if e then e + 1 else n + 1
	end

	local depth: { number } = {} -- one entry per open `interpolated string`
	local function scanTemplate(j: number): number
		local start = j
		while j <= n do
			local c = string.sub(src, j, j)
			if c == "`" then
				break
			elseif c == "\\" then
				j += 2
			elseif c == "{" then
				blank(start, j - 1)
				table.insert(depth, 0)
				return j + 1
			else
				j += 1
			end
		end
		blank(start, j - 1)
		return j + 1
	end

	local i = 1
	while i <= n do
		local c = string.sub(src, i, i)
		if c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			local level = longLevel(i + 2)
			local stop
			if level >= 0 then
				stop = longClose(i + 4 + level, level)
			else
				stop = string.find(src, "\n", i, true) or n + 1
			end
			blank(i, stop - 1)
			i = stop
		elseif c == "[" and longLevel(i) >= 0 then
			local level = longLevel(i)
			local stop = longClose(i + level + 2, level)
			blank(i + level + 2, stop - level - 3)
			i = stop
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = string.sub(src, j, j)
				if d == c or d == "\n" then
					break
				end
				if d == "\\" then
					j += 1
				end
				j += 1
			end
			blank(i + 1, j - 1)
			i = j + 1
		elseif c == "`" then
			i = scanTemplate(i + 1)
		elseif #depth > 0 and c == "{" then
			depth[#depth] += 1
			i += 1
		elseif #depth > 0 and c == "}" then
			if depth[#depth] == 0 then
				table.remove(depth)
				i = scanTemplate(i + 1)
			else
				depth[#depth] -= 1
				i += 1
			end
		else
			i += 1
		end
	end
	return table.concat(out)
end

local function splitLines(text: string): { string }
	local lines = string.split(text, "\n")
	for k, line in lines do
		if string.sub(line, -1) == "\r" then
			lines[k] = string.sub(line, 1, -2)
		end
	end
	return lines
end

-- `name(` not preceded by an identifier char, `.` or `:` (a global call).
local function bareCall(line: string, name: string): boolean
	local init = 1
	while true do
		local s, e = string.find(line, name .. "%s*%(", init)
		if not s then
			return false
		end
		local prev = if s > 1 then string.sub(line, s - 1, s - 1) else ""
		if not string.find(prev, "[%w_%.:]") then
			return true
		end
		init = (e :: number) + 1
	end
end

local function hasWord(text: string, word: string): boolean
	return string.find(" " .. text .. " ", "[^%w_]" .. word .. "[^%w_]") ~= nil
end

local function indentOf(text: string): number
	local width = 0
	for k = 1, #text do
		local c = string.sub(text, k, k)
		if c == "\t" then
			width += 4
		elseif c == " " then
			width += 1
		else
			break
		end
	end
	return width
end

-- Following lines indented deeper than line `start` (the block body).
local function blockBody(masked: { string }, start: number, maxLines: number?): string
	local base = indentOf(masked[start])
	local body = {}
	for j = start + 1, math.min(#masked, start + (maxLines or 80)) do
		local text = masked[j]
		if string.find(text, "%S") then
			if indentOf(text) <= base then
				break
			end
			table.insert(body, text)
		end
	end
	return table.concat(body, "\n")
end

local SERVER_ONLY_SERVICES = { "DataStoreService", "ServerStorage", "ServerScriptService", "MessagingService", "MemoryStoreService" }
local DIRECT_SERVICES = {
	"Players", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "Lighting", "TweenService", "RunService",
	"UserInputService", "DataStoreService", "HttpService", "SoundService", "Teams", "StarterGui", "StarterPack",
	"StarterPlayer", "MarketplaceService", "CollectionService", "Debris",
}
local DATASTORE_CALLS = { "GetAsync", "SetAsync", "UpdateAsync", "RemoveAsync", "IncrementAsync", "GetSortedAsync" }
local BODY_MOVERS = { BodyVelocity = true, BodyPosition = true, BodyGyro = true, BodyForce = true, BodyAngularVelocity = true, BodyThrust = true }
local PLAYER_ARGS = { player = true, plr = true, localPlayer = true, LocalPlayer = true, ["Players.LocalPlayer"] = true, ["game.Players.LocalPlayer"] = true }

local RULES: { Rule } = {
	{ id = "deprecated-wait", severity = "error", test = function(c)
		return if bareCall(c.line, "wait") then "wait() is deprecated: use task.wait()" else nil
	end },
	{ id = "deprecated-spawn", severity = "error", test = function(c)
		return if bareCall(c.line, "spawn") then "spawn() is deprecated: use task.spawn()" else nil
	end },
	{ id = "deprecated-delay", severity = "error", test = function(c)
		return if bareCall(c.line, "delay") then "delay() is deprecated: use task.delay()" else nil
	end },
	{ id = "lowercase-connect", severity = "error", test = function(c)
		return if string.find(c.line, ":connect%s*%(") then ":connect() is deprecated: use :Connect()" else nil
	end },
	{ id = "loadstring", severity = "error", test = function(c)
		return if bareCall(c.line, "loadstring") then "loadstring is unsafe and disabled by default" else nil
	end },
	{ id = "require-asset-id", severity = "error", test = function(c)
		return if string.find(c.line, "require%s*%(%s*%d") then "require(id) loads external code: backdoor risk" else nil
	end },
	{ id = "invoke-client", severity = "error", test = function(c)
		return if string.find(c.line, ":InvokeClient%s*%(")
			then "InvokeClient can hang the server (the client may never reply): use a RemoteEvent"
			else nil
	end },
	{ id = "localplayer-on-server", severity = "error", test = function(c)
		return if c.side == "server" and string.find(c.line .. " ", "%.LocalPlayer[^%w_]")
			then "LocalPlayer is nil on the server: use the player from the event"
			else nil
	end },
	{ id = "server-api-on-client", severity = "error", test = function(c)
		if c.side ~= "client" or not string.find(c.line, "GetService%s*%(") then
			return nil
		end
		for _, name in SERVER_ONLY_SERVICES do
			if string.find(c.raw, "GetService%s*%(%s*[\"'`]" .. name .. "[\"'`]") then
				return `{name} is not accessible from the client`
			end
		end
		return nil
	end },
	{ id = "render-on-server", severity = "error", test = function(c)
		return if c.side == "server" and (hasWord(c.line, "RenderStepped") or hasWord(c.line, "BindToRenderStep"))
			then "RenderStepped only exists on the client: use Heartbeat"
			else nil
	end },
	{ id = "instance-new-parent", severity = "warning", test = function(c)
		return if string.find(c.line, "Instance%.new%s*%(%s*[\"'][^\"']*[\"']%s*,")
			then "don't pass Parent to Instance.new: set properties, then Parent last"
			else nil
	end },
	{ id = "fireserver-player-arg", severity = "warning", test = function(c)
		local arg = string.match(c.line, ":FireServer%s*%(%s*([%w_%.]+)%s*[,)]")
		return if arg and PLAYER_ARGS[arg]
			then "the server receives the player automatically: don't send it in FireServer"
			else nil
	end },
	{ id = "set-primary-part-cframe", severity = "warning", test = function(c)
		return if string.find(c.line, ":SetPrimaryPartCFrame%s*%(") then "SetPrimaryPartCFrame is deprecated: use :PivotTo()" else nil
	end },
	{ id = "get-primary-part-cframe", severity = "warning", test = function(c)
		return if string.find(c.line, ":GetPrimaryPartCFrame%s*%(") or string.find(c.line, ":GetModelCFrame%s*%(")
			then "use :GetPivot()"
			else nil
	end },
	{ id = "humanoid-load-animation", severity = "warning", test = function(c)
		return if string.find(c.line, "[Hh]umanoid[%w_]*%s*:%s*LoadAnimation%s*%(")
			then "Humanoid:LoadAnimation is deprecated: use Animator:LoadAnimation"
			else nil
	end },
	{ id = "body-movers", severity = "warning", test = function(c)
		if not string.find(c.line, "Instance%.new") then
			return nil
		end
		local class = string.match(c.raw, "Instance%.new%s*%(%s*[\"'](Body%a+)[\"']")
		return if class and BODY_MOVERS[class]
			then "Body movers are deprecated: use LinearVelocity, AlignPosition, AlignOrientation or VectorForce"
			else nil
	end },
	{ id = "find-part-on-ray", severity = "warning", test = function(c)
		return if string.find(c.line, "FindPartOnRay[%w_]*%s*%(") then "FindPartOnRay is deprecated: use workspace:Raycast" else nil
	end },
	{ id = "fenv", severity = "warning", test = function(c)
		return if bareCall(c.line, "getfenv") or bareCall(c.line, "setfenv") then "getfenv/setfenv disable Luau optimizations" else nil
	end },
	{ id = "table-getn", severity = "warning", test = function(c)
		return if string.find(c.line, "table%.getn%s*%(") then "table.getn is deprecated: use #t" else nil
	end },
	{ id = "datastore-no-pcall", severity = "warning", test = function(c)
		local found = false
		for _, name in DATASTORE_CALLS do
			if string.find(c.line, ":" .. name .. "%s*%(") then
				found = true
				break
			end
		end
		if not found then
			return nil
		end
		local context = table.concat(c.masked, "\n", math.max(1, c.index - 3), c.index)
		for _, word in { "pcall", "retry", "retries", "Retry", "Retries", "Promise" } do
			if string.find(context, word, 1, true) then
				return nil
			end
		end
		return "DataStore call without pcall/retry: it can fail at any time"
	end },
	{ id = "prefer-update-async", severity = "info", test = function(c)
		return if string.find(c.line, ":SetAsync%s*%(") then "prefer UpdateAsync (SetAsync overwrites other servers' data)" else nil
	end },
	{ id = "direct-service-index", severity = "info", test = function(c)
		for _, name in DIRECT_SERVICES do
			if string.find(c.line .. " ", "game%." .. name .. "[^%w_]") then
				return `use game:GetService("{name}") instead of game.{name}`
			end
		end
		return nil
	end },
	{ id = "global-unpack", severity = "info", test = function(c)
		return if bareCall(c.line, "unpack") then "use table.unpack" else nil
	end },
	{ id = "while-true-no-yield", severity = "error", test = function(c)
		local s, e = string.find(c.line, "while%s+true%s+do")
		if not s then
			return nil
		end
		local body = string.sub(c.line, (e :: number) + 1) .. "\n" .. blockBody(c.masked, c.index)
		for _, word in { "wait", "Wait", "yield", "Yield" } do
			if string.find(body, word, 1, true) then
				return nil
			end
		end
		if hasWord(body, "break") or hasWord(body, "return") then
			return nil
		end
		return "while true without a yield (task.wait) freezes the game"
	end },
	{ id = "remote-without-validation", severity = "warning", test = function(c)
		if not (string.find(c.line, "%.OnServerEvent%s*:%s*Connect") or string.find(c.line, "%.OnServerInvoke%s*=")) then
			return nil
		end
		local params = string.match(c.line, "function%s*%(([^)]*)%)")
		if not params then
			return nil -- named handler: can't inspect from here
		end
		local count = 0
		for _, p in string.split(params, ",") do
			if string.find(p, "%S") then
				count += 1
			end
		end
		if count <= 1 then
			return nil
		end
		local body = blockBody(c.masked, c.index)
		for _, pattern in { "typeof%s*%(", "type%s*%(", "Guard", "assert%s*%(", "tonumber", "IsA%s*%(", "valid", "check", "Check" } do
			if string.find(body, pattern) then
				return nil
			end
		end
		return "remote handler doesn't seem to validate client arguments (use Net.onServerEvent + Guard)"
	end },
}

local function suppressed(rawLines: { string }, index: number, ruleId: string): boolean
	local function matches(text: string?, marker: string): boolean
		if not text then
			return false
		end
		local s, e = string.find(text, marker, 1, true)
		if not s then
			return false
		end
		local rest = string.sub(text, (e :: number) + 1)
		if marker == "rbxkit-ignore" and string.sub(rest, 1, 10) == "-next-line" then
			return false
		end
		local list = string.match(rest, "^%s*:%s*([%w%-, ]+)")
		if not list then
			return true
		end
		for _, id in string.split((string.gsub(list, ",", " ")), " ") do
			if id == ruleId then
				return true
			end
		end
		return false
	end
	return matches(rawLines[index], "rbxkit-ignore") or matches(rawLines[index - 1], "rbxkit-ignore-next-line")
end

-- Lints one source. `path` is only used in the findings.
function Lint.checkSource(source: string, side: Side, path: string?): { Finding }
	local where = path or "source"
	local rawLines = splitLines(source)
	local masked = splitLines(Lint.mask(source))
	local findings: { Finding } = {}
	local function report(id: string, severity: Severity, index: number, message: string?)
		if message and not suppressed(rawLines, index, id) then
			table.insert(findings, { path = where, line = index, rule = id, severity = severity, message = message })
		end
	end

	for _, raw in rawLines do
		if string.find(raw, "%S") then
			if not string.find(raw, "^%s*%-%-!") then
				report("missing-strict", "info", 1, "add --!strict on the first line")
			end
			break
		end
	end

	for index, line in masked do
		if string.find(line, "%S") then
			local context: Context = { line = line, raw = rawLines[index] or "", side = side, masked = masked, index = index }
			for _, rule in RULES do
				report(rule.id, rule.severity, index, rule.test(context))
			end
		end
	end
	return findings
end

local CLIENT_CONTAINERS = { "StarterPlayer", "StarterGui", "StarterPack", "ReplicatedFirst" }

function Lint.sideOf(container: Instance): Side
	if container:IsA("LocalScript") then
		return "client"
	elseif container:IsA("Script") then
		local ok, context = pcall(function()
			return (container :: any).RunContext
		end)
		return if ok and context == Enum.RunContext.Client then "client" else "server"
	end
	if container:FindFirstAncestorOfClass("ServerScriptService") or container:FindFirstAncestorOfClass("ServerStorage") then
		return "server"
	end
	for _, className in CLIENT_CONTAINERS do
		if container:FindFirstAncestorOfClass(className) then
			return "client"
		end
	end
	return "shared"
end

local DEFAULT_ROOTS = {
	"ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst",
	"StarterPlayer", "StarterGui", "StarterPack", "Workspace",
}

-- Lints every script under `root` (default: all game containers that hold scripts).
function Lint.run(root: Instance?): Report
	local roots: { Instance } = {}
	if root then
		table.insert(roots, root)
	else
		for _, name in DEFAULT_ROOTS do
			local ok, service = pcall(game.GetService, game, name)
			if ok and service then
				table.insert(roots, service)
			end
		end
	end
	local report: Report = { scripts = 0, findings = {} }
	for _, r in roots do
		local list = r:GetDescendants()
		table.insert(list, r)
		for _, d in list do
			if d:IsA("LuaSourceContainer") then
				local ok, source = pcall(function()
					return (d :: any).Source :: string
				end)
				if ok and type(source) == "string" then
					report.scripts += 1
					for _, finding in Lint.checkSource(source, Lint.sideOf(d), d:GetFullName()) do
						table.insert(report.findings, finding)
					end
				end
			end
		end
	end
	return report
end

local ORDER = { error = 1, warning = 2, info = 3 }

-- Short text report. Info findings are counted but only listed when `includeInfo` is true.
function Lint.summary(report: Report, limit: number?, includeInfo: boolean?): string
	local counts = { error = 0, warning = 0, info = 0 }
	local shown: { Finding } = {}
	for _, f in report.findings do
		counts[f.severity] += 1
		if f.severity ~= "info" or includeInfo then
			table.insert(shown, f)
		end
	end
	table.sort(shown, function(a, b)
		if ORDER[a.severity] ~= ORDER[b.severity] then
			return ORDER[a.severity] < ORDER[b.severity]
		end
		return a.path < b.path or (a.path == b.path and a.line < b.line)
	end)
	local lines = {
		`{report.scripts} scripts: {counts.error} error(s), {counts.warning} warning(s), {counts.info} info`,
	}
	local max = limit or 30
	for k, f in shown do
		if k > max then
			table.insert(lines, `... {#shown - max} more`)
			break
		end
		table.insert(lines, `{f.path}:{f.line} {f.severity} {f.rule}: {f.message}`)
	end
	return table.concat(lines, "\n")
end

return Lint
