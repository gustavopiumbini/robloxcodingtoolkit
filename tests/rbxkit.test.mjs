import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { checkSource, maskSource, mcpInstructions } from "../tools/rbxkit.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "tools", "rbxkit.mjs");

const rules = (src, file = "src/shared/X.luau") => checkSource("--!strict\n" + src, file).map((f) => f.rule);
const run = (args, cwd) => spawnSync(process.execPath, [CLI, ...args], { cwd, encoding: "utf8", env: { ...process.env, NO_COLOR: "1" } });
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), "rbxkit-"));

test("maskSource keeps size/lines and blanks comments and strings", () => {
	const src = 'local a = "wait(1)" -- wait(2)\n--[[ spawn(f)\n]] local b = [==[ delay() ]==]\nlocal c = `x {wait(3)} y`';
	const masked = maskSource(src);
	assert.equal(masked.length, src.length);
	assert.equal(masked.split("\n").length, src.split("\n").length);
	assert.ok(!masked.includes("wait(1)"));
	assert.ok(!masked.includes("wait(2)"));
	assert.ok(!masked.includes("spawn"));
	assert.ok(!masked.includes("delay"));
	assert.ok(masked.includes("wait(3)"), "expressions inside interpolated strings are code");
});

test("detects deprecated APIs", () => {
	assert.deepEqual(rules("wait(1)"), ["deprecated-wait"]);
	assert.deepEqual(rules("spawn(f)"), ["deprecated-spawn"]);
	assert.deepEqual(rules("delay(1, f)"), ["deprecated-delay"]);
	assert.deepEqual(rules("part.Touched:connect(f)"), ["lowercase-connect"]);
	assert.deepEqual(rules("model:SetPrimaryPartCFrame(cf)"), ["set-primary-part-cframe"]);
	assert.deepEqual(rules("humanoid:LoadAnimation(anim)"), ["humanoid-load-animation"]);
	assert.deepEqual(rules('local v = Instance.new("BodyVelocity")'), ["body-movers"]);
	assert.deepEqual(rules('local p = Instance.new("Part", workspace)'), ["instance-new-parent"]);
});

test("ignores modern APIs and text inside strings/comments", () => {
	assert.deepEqual(rules("task.wait(1)\ntask.spawn(f)\ntask.delay(1, f)\nsignal:Wait()\nconn.Connected = true"), []);
	assert.deepEqual(rules('print("wait(1)") -- spawn(f)'), []);
	assert.deepEqual(rules('local p = Instance.new("Part")\np.Parent = workspace'), []);
	assert.deepEqual(rules("local s = game:GetService(\"Players\")"), []);
});

test("security rules", () => {
	assert.deepEqual(rules("require(123456)"), ["require-asset-id"]);
	assert.deepEqual(rules("loadstring(code)()"), ["loadstring"]);
	assert.deepEqual(rules("remote:InvokeClient(player)"), ["invoke-client"]);
	assert.deepEqual(rules("remote:FireServer(player, 1)"), ["fireserver-player-arg"]);
	assert.deepEqual(rules("local p = Players.LocalPlayer", "src/server/Services/A.luau"), ["localplayer-on-server"]);
	assert.deepEqual(rules("local p = Players.LocalPlayer", "src/client/Controllers/A.luau"), []);
	assert.deepEqual(rules('local d = game:GetService("DataStoreService")', "src/client/init.client.luau"), ["server-api-on-client"]);
	assert.deepEqual(rules("RunService.RenderStepped:Connect(f)", "src/server/X.server.luau"), ["render-on-server"]);
});

test("remote without validation", () => {
	const bad = "remote.OnServerEvent:Connect(function(player, amount)\n\tcoins += amount\nend)";
	assert.deepEqual(rules(bad), ["remote-without-validation"]);
	const good = 'remote.OnServerEvent:Connect(function(player, amount)\n\tif typeof(amount) ~= "number" then return end\nend)';
	assert.deepEqual(rules(good), []);
	const noArgs = "remote.OnServerEvent:Connect(function(player)\n\tprint(player)\nend)";
	assert.deepEqual(rules(noArgs), []);
});

test("while true without yield", () => {
	assert.deepEqual(rules("while true do\n\tx += 1\nend"), ["while-true-no-yield"]);
	assert.deepEqual(rules("while true do\n\ttask.wait(1)\nend"), []);
	assert.deepEqual(rules("while true do\n\tif x then break end\nend"), []);
});

test("DataStore without pcall", () => {
	assert.deepEqual(rules("local v = store:GetAsync(key)"), ["datastore-no-pcall"]);
	assert.deepEqual(rules("local ok, v = pcall(function()\n\treturn store:GetAsync(key)\nend)"), []);
	assert.ok(rules("pcall(store.SetAsync, store, k, v)").every((r) => r !== "datastore-no-pcall"));
});

test("suppression comments", () => {
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore"), []);
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore: deprecated-wait"), []);
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore: outra-regra"), ["deprecated-wait"]);
	assert.deepEqual(rules("-- rbxkit-ignore-next-line\nwait(1)"), []);
});

test("missing-strict", () => {
	assert.deepEqual(checkSource("local x = 1", "a.luau").map((f) => f.rule), ["missing-strict"]);
});

test("MCP instructions", () => {
	assert.match(mcpInstructions("windows", "claude"), /claude mcp add Roblox_Studio -- cmd\.exe \/c %LOCALAPPDATA%\\Roblox\\mcp\.bat/);
	assert.match(mcpInstructions("mac", "codex"), /\[mcp_servers\.Roblox_Studio\]/);
});

test("template passes its own lint", () => {
	const r = run(["check", "--strict", path.join(ROOT, "template", "src")], ROOT);
	assert.equal(r.status, 0, r.stdout + r.stderr);
});

test("init creates a full project and new generates files", () => {
	const dir = path.join(tmp(), "MyGame");
	const r = run(["init", dir], ROOT);
	assert.equal(r.status, 0, r.stderr);
	for (const f of [
		"default.project.json",
		".gitignore",
		"AGENTS.md",
		"CLAUDE.md",
		"tools/rbxkit.mjs",
		".claude/skills/roblox-feature/SKILL.md",
		".agents/skills/roblox-networking/SKILL.md",
		"src/shared/Net.luau",
		"src/server/Services/DataService.luau",
		"src/dev/Build.luau",
		"src/dev/Shots.luau",
	]) {
		assert.ok(fs.existsSync(path.join(dir, f)), `missing ${f}`);
	}
	assert.equal(JSON.parse(fs.readFileSync(path.join(dir, "default.project.json"), "utf8")).name, "MyGame");

	// The copied rbxkit works standalone inside the project.
	const localCli = path.join(dir, "tools", "rbxkit.mjs");
	const gen = (args) => spawnSync(process.execPath, [localCli, ...args], { cwd: dir, encoding: "utf8" });
	assert.equal(gen(["new", "service", "Inventory"]).status, 0);
	assert.equal(gen(["new", "controller", "camera"]).status, 0);
	assert.equal(gen(["new", "module", "Util/MathUtil"]).status, 0);
	assert.ok(fs.existsSync(path.join(dir, "src/server/Services/InventoryService.luau")));
	assert.ok(fs.existsSync(path.join(dir, "src/client/Controllers/CameraController.luau")));
	assert.ok(fs.existsSync(path.join(dir, "src/shared/Util/MathUtil.luau")));
	assert.equal(gen(["new", "service", "Inventory"]).status, 2, "does not overwrite without --force");
	const check = gen(["check", "--strict"]);
	assert.equal(check.status, 0, check.stdout);
	assert.notEqual(gen(["install", "."]).status, 0, "install needs the toolkit repository");
});

test("install keeps an existing AGENTS.md without --force", () => {
	const dir = tmp();
	fs.writeFileSync(path.join(dir, "AGENTS.md"), "mine");
	const r = run(["install", dir], ROOT);
	assert.equal(r.status, 0, r.stderr);
	assert.equal(fs.readFileSync(path.join(dir, "AGENTS.md"), "utf8"), "mine");
	assert.ok(fs.existsSync(path.join(dir, "CLAUDE.md")));
	assert.ok(fs.existsSync(path.join(dir, ".claude/skills/roblox-luau/SKILL.md")));
});

test("every skill has frontmatter with name == folder and a description", () => {
	const skillsDir = path.join(ROOT, "skills");
	for (const name of fs.readdirSync(skillsDir)) {
		const text = fs.readFileSync(path.join(skillsDir, name, "SKILL.md"), "utf8");
		const fm = /^---\n([\s\S]*?)\n---\n/.exec(text);
		assert.ok(fm, `${name}: no frontmatter`);
		assert.match(fm[1], new RegExp(`^name: ${name}$`, "m"));
		assert.match(fm[1], /^description: .{40,}$/m);
	}
});

test("docs: extracts member sections in every Roblox page format", async () => {
	const { extractMember, listMembers } = await import("../tools/rbxkit.mjs");
	const page = [
		"# Class: TweenService",
		"## Methods",
		"### Method: TweenService:Create",
		"cria tween",
		"### Method: TweenService:GetValue",
		"valor",
		"## Inherited Members",
		"### From [Instance](/x.md)",
	].join("\n");
	assert.equal(extractMember(page, "Create"), "### Method: TweenService:Create\ncria tween");
	assert.equal(extractMember(page, "Nope"), null);
	assert.deepEqual(listMembers(page), ["Method: TweenService:Create", "Method: TweenService:GetValue"]);

	const overloads = "## Constructors\n### CFrame.new\na\n### CFrame.new\nb\n### CFrame.lookAt\nc";
	assert.equal(extractMember(overloads, "new"), "### CFrame.new\na\n\n### CFrame.new\nb");
	assert.equal(extractMember("## Functions\n### task.wait\nyield", "wait"), "### task.wait\nyield");
});

test("token budget: always-loaded context and skill sizes stay lean", () => {
	const tokens = (text) => Math.round(Buffer.byteLength(text) / 4);
	const agents = fs.readFileSync(path.join(ROOT, "agent", "AGENTS.md"), "utf8");
	assert.ok(tokens(agents) <= 900, `AGENTS.md is ~${tokens(agents)} tokens (budget 900): it loads every session`);
	let descriptions = 0;
	for (const name of fs.readdirSync(path.join(ROOT, "skills"))) {
		const text = fs.readFileSync(path.join(ROOT, "skills", name, "SKILL.md"), "utf8");
		const description = /^description: (.*)$/m.exec(text)[1];
		assert.ok(description.length <= 300, `${name}: description is ${description.length} chars (max 300)`);
		assert.ok(tokens(text) <= 3000, `${name}: SKILL.md is ~${tokens(text)} tokens (max 3000); move detail to references/`);
		descriptions += tokens(description);
	}
	assert.ok(descriptions <= 1800, `skill descriptions total ~${descriptions} tokens (budget 1800)`);
});

test("README: local links/images exist and one-prompt URLs point to real files", () => {
	const readme = fs.readFileSync(path.join(ROOT, "README.md"), "utf8");
	const local = [...readme.matchAll(/(?:src|href)="([^"#:]+)"|\]\(([^)#:\s]+)\)/g)].map((m) => m[1] ?? m[2]);
	assert.ok(local.length > 5);
	for (const link of local) assert.ok(fs.existsSync(path.join(ROOT, link)), `broken README link: ${link}`);
	const raw = [...readme.matchAll(/raw\.githubusercontent\.com\/gustavopiumbini\/robloxcodingtoolkit\/main\/(\S+\.md)/g)].map((m) => m[1]);
	assert.ok(raw.length >= 2);
	for (const file of raw) assert.ok(fs.existsSync(path.join(ROOT, file)), `one-prompt file missing: ${file}`);
});
