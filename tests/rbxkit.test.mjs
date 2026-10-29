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

test("maskSource preserva tamanho e linhas e apaga comentários/strings", () => {
	const src = 'local a = "wait(1)" -- wait(2)\n--[[ spawn(f)\n]] local b = [==[ delay() ]==]\nlocal c = `x {wait(3)} y`';
	const masked = maskSource(src);
	assert.equal(masked.length, src.length);
	assert.equal(masked.split("\n").length, src.split("\n").length);
	assert.ok(!masked.includes("wait(1)"));
	assert.ok(!masked.includes("wait(2)"));
	assert.ok(!masked.includes("spawn"));
	assert.ok(!masked.includes("delay"));
	assert.ok(masked.includes("wait(3)"), "expressão dentro de string interpolada é código");
});

test("detecta APIs depreciadas", () => {
	assert.deepEqual(rules("wait(1)"), ["deprecated-wait"]);
	assert.deepEqual(rules("spawn(f)"), ["deprecated-spawn"]);
	assert.deepEqual(rules("delay(1, f)"), ["deprecated-delay"]);
	assert.deepEqual(rules("part.Touched:connect(f)"), ["lowercase-connect"]);
	assert.deepEqual(rules("model:SetPrimaryPartCFrame(cf)"), ["set-primary-part-cframe"]);
	assert.deepEqual(rules("humanoid:LoadAnimation(anim)"), ["humanoid-load-animation"]);
	assert.deepEqual(rules('local v = Instance.new("BodyVelocity")'), ["body-movers"]);
	assert.deepEqual(rules('local p = Instance.new("Part", workspace)'), ["instance-new-parent"]);
});

test("não acusa APIs modernas nem texto em strings/comentários", () => {
	assert.deepEqual(rules("task.wait(1)\ntask.spawn(f)\ntask.delay(1, f)\nsignal:Wait()\nconn.Connected = true"), []);
	assert.deepEqual(rules('print("wait(1)") -- spawn(f)'), []);
	assert.deepEqual(rules('local p = Instance.new("Part")\np.Parent = workspace'), []);
	assert.deepEqual(rules("local s = game:GetService(\"Players\")"), []);
});

test("regras de segurança", () => {
	assert.deepEqual(rules("require(123456)"), ["require-asset-id"]);
	assert.deepEqual(rules("loadstring(code)()"), ["loadstring"]);
	assert.deepEqual(rules("remote:InvokeClient(player)"), ["invoke-client"]);
	assert.deepEqual(rules("remote:FireServer(player, 1)"), ["fireserver-player-arg"]);
	assert.deepEqual(rules("local p = Players.LocalPlayer", "src/server/Services/A.luau"), ["localplayer-on-server"]);
	assert.deepEqual(rules("local p = Players.LocalPlayer", "src/client/Controllers/A.luau"), []);
	assert.deepEqual(rules('local d = game:GetService("DataStoreService")', "src/client/init.client.luau"), ["server-api-on-client"]);
	assert.deepEqual(rules("RunService.RenderStepped:Connect(f)", "src/server/X.server.luau"), ["render-on-server"]);
});

test("remote sem validação", () => {
	const bad = "remote.OnServerEvent:Connect(function(player, amount)\n\tcoins += amount\nend)";
	assert.deepEqual(rules(bad), ["remote-without-validation"]);
	const good = 'remote.OnServerEvent:Connect(function(player, amount)\n\tif typeof(amount) ~= "number" then return end\nend)';
	assert.deepEqual(rules(good), []);
	const noArgs = "remote.OnServerEvent:Connect(function(player)\n\tprint(player)\nend)";
	assert.deepEqual(rules(noArgs), []);
});

test("while true sem yield", () => {
	assert.deepEqual(rules("while true do\n\tx += 1\nend"), ["while-true-no-yield"]);
	assert.deepEqual(rules("while true do\n\ttask.wait(1)\nend"), []);
	assert.deepEqual(rules("while true do\n\tif x then break end\nend"), []);
});

test("DataStore sem pcall", () => {
	assert.deepEqual(rules("local v = store:GetAsync(key)"), ["datastore-no-pcall"]);
	assert.deepEqual(rules("local ok, v = pcall(function()\n\treturn store:GetAsync(key)\nend)"), []);
	assert.ok(rules("pcall(store.SetAsync, store, k, v)").every((r) => r !== "datastore-no-pcall"));
});

test("supressão por comentário", () => {
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore"), []);
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore: deprecated-wait"), []);
	assert.deepEqual(rules("wait(1) -- rbxkit-ignore: outra-regra"), ["deprecated-wait"]);
	assert.deepEqual(rules("-- rbxkit-ignore-next-line\nwait(1)"), []);
});

test("missing-strict", () => {
	assert.deepEqual(checkSource("local x = 1", "a.luau").map((f) => f.rule), ["missing-strict"]);
});

test("instruções de MCP", () => {
	assert.match(mcpInstructions("windows", "claude"), /claude mcp add Roblox_Studio -- cmd\.exe \/c %LOCALAPPDATA%\\Roblox\\mcp\.bat/);
	assert.match(mcpInstructions("mac", "codex"), /\[mcp_servers\.Roblox_Studio\]/);
});

test("template passa no próprio lint", () => {
	const r = run(["check", "--strict", path.join(ROOT, "template", "src")], ROOT);
	assert.equal(r.status, 0, r.stdout + r.stderr);
});

test("init cria projeto completo e new gera arquivos", () => {
	const dir = path.join(tmp(), "MeuJogo");
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
	]) {
		assert.ok(fs.existsSync(path.join(dir, f)), `faltando ${f}`);
	}
	assert.equal(JSON.parse(fs.readFileSync(path.join(dir, "default.project.json"), "utf8")).name, "MeuJogo");

	// O rbxkit copiado funciona sozinho dentro do projeto.
	const localCli = path.join(dir, "tools", "rbxkit.mjs");
	const gen = (args) => spawnSync(process.execPath, [localCli, ...args], { cwd: dir, encoding: "utf8" });
	assert.equal(gen(["new", "service", "Inventory"]).status, 0);
	assert.equal(gen(["new", "controller", "camera"]).status, 0);
	assert.equal(gen(["new", "module", "Util/MathUtil"]).status, 0);
	assert.ok(fs.existsSync(path.join(dir, "src/server/Services/InventoryService.luau")));
	assert.ok(fs.existsSync(path.join(dir, "src/client/Controllers/CameraController.luau")));
	assert.ok(fs.existsSync(path.join(dir, "src/shared/Util/MathUtil.luau")));
	assert.equal(gen(["new", "service", "Inventory"]).status, 2, "não sobrescreve sem --force");
	const check = gen(["check", "--strict"]);
	assert.equal(check.status, 0, check.stdout);
	assert.notEqual(gen(["install", "."]).status, 0, "install precisa do repositório do toolkit");
});

test("install não sobrescreve AGENTS.md existente sem --force", () => {
	const dir = tmp();
	fs.writeFileSync(path.join(dir, "AGENTS.md"), "meu");
	const r = run(["install", dir], ROOT);
	assert.equal(r.status, 0, r.stderr);
	assert.equal(fs.readFileSync(path.join(dir, "AGENTS.md"), "utf8"), "meu");
	assert.ok(fs.existsSync(path.join(dir, "CLAUDE.md")));
	assert.ok(fs.existsSync(path.join(dir, ".claude/skills/roblox-luau/SKILL.md")));
});

test("toda skill tem frontmatter com name igual à pasta e description", () => {
	const skillsDir = path.join(ROOT, "skills");
	for (const name of fs.readdirSync(skillsDir)) {
		const text = fs.readFileSync(path.join(skillsDir, name, "SKILL.md"), "utf8");
		const fm = /^---\n([\s\S]*?)\n---\n/.exec(text);
		assert.ok(fm, `${name}: sem frontmatter`);
		assert.match(fm[1], new RegExp(`^name: ${name}$`, "m"));
		assert.match(fm[1], /^description: .{40,}$/m);
	}
});
