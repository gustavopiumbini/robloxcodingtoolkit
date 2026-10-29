import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { stripComments, studioNodes, buildInstallers, INSTALL_CHUNKS, mcpInstructions } from "../tools/rbxkit.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "tools", "rbxkit.mjs");
const run = (args, cwd) => spawnSync(process.execPath, [CLI, ...args], { cwd, encoding: "utf8", env: { ...process.env, NO_COLOR: "1" } });
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), "rbxkit-"));

test("stripComments drops comments but keeps strings, code and --!strict", () => {
	const src = '--!strict\n--[[ header\nblock ]]\nlocal a = "-- not a comment" -- trailing\n-- full line\nlocal b = [==[ --keep ]==]\nlocal c = `x {a} -- y`\n';
	const out = stripComments(src);
	assert.equal(out, '--!strict\nlocal a = "-- not a comment"\nlocal b = [==[ --keep ]==]\nlocal c = `x {a} -- y`\n');
});

test("studioNodes mirrors the DataModel", () => {
	const byPath = Object.fromEntries(studioNodes().map((n) => [n.segments.join("."), n.className]));
	assert.equal(byPath["ServerScriptService"], "ServerScriptService");
	assert.equal(byPath["ServerScriptService.Server"], "Script");
	assert.equal(byPath["ServerScriptService.Server.Services.DataService"], "ModuleScript");
	assert.equal(byPath["StarterPlayer.StarterPlayerScripts"], "StarterPlayerScripts");
	assert.equal(byPath["StarterPlayer.StarterPlayerScripts.Client"], "LocalScript");
	assert.equal(byPath["ReplicatedStorage.Shared"], "Folder");
	assert.equal(byPath["ServerStorage.DevTools.Lint"], "ModuleScript");
});

test("installers cover every studio script exactly once", () => {
	const installers = buildInstallers();
	assert.equal(installers.length, INSTALL_CHUNKS.length);
	const scripts = studioNodes().filter((n) => n.file);
	const total = installers.reduce((sum, i) => sum + i.modules, 0);
	assert.equal(total, scripts.length, "each script belongs to exactly one installer");
	for (const node of scripts) {
		const hits = installers.filter((i) => i.code.includes(`${JSON.stringify(node.className)}, ${JSON.stringify(node.name)},`));
		assert.equal(hits.length, 1, `${node.segments.join(".")} in ${hits.length} installers`);
	}
	for (const i of installers) {
		assert.match(i.code, /^-- rbxkit installer \d\/\d:/);
		assert.match(i.code, /local FORCE = false/);
		assert.ok(!/--\[\[/.test(i.code.split("local FORCE")[1].replace(/\[(=*)\[[\s\S]*?\]\1\]/g, "")), "no block comments outside sources");
	}
	assert.ok(installers.slice(0, 3).reduce((s, i) => s + i.code.length, 0) < 40000, "core installers stay small (tokens)");
});

test("init creates an agent folder without touching existing AGENTS.md", () => {
	const dir = tmp();
	fs.writeFileSync(path.join(dir, "AGENTS.md"), "mine");
	const r = run(["init", dir], ROOT);
	assert.equal(r.status, 0, r.stderr);
	assert.equal(fs.readFileSync(path.join(dir, "AGENTS.md"), "utf8"), "mine");
	for (const f of ["CLAUDE.md", "tools/rbxkit.mjs", ".claude/skills/roblox-3d-building/SKILL.md", ".agents/skills/roblox-studio-mcp/SKILL.md", "install/1-shared.luau", "install/5-lint.luau"]) {
		assert.ok(fs.existsSync(path.join(dir, f)), `missing ${f}`);
	}
	assert.ok(!fs.existsSync(path.join(dir, "default.project.json")), "no Rojo project");
	const again = run(["init", dir, "--force"], ROOT);
	assert.equal(again.status, 0);
	assert.notEqual(fs.readFileSync(path.join(dir, "AGENTS.md"), "utf8"), "mine");
	// The copied CLI works standalone for docs/mcp/doctor but can't init without the toolkit.
	const local = path.join(dir, "tools", "rbxkit.mjs");
	assert.equal(spawnSync(process.execPath, [local, "mcp", "--os", "mac"], { cwd: dir, encoding: "utf8" }).status, 0);
	assert.equal(spawnSync(process.execPath, [local, "init", path.join(dir, "x")], { cwd: dir, encoding: "utf8" }).status, 2);
});

test("MCP instructions", () => {
	assert.match(mcpInstructions("windows", "claude"), /claude mcp add Roblox_Studio -- cmd\.exe \/c %LOCALAPPDATA%\\Roblox\\mcp\.bat/);
	assert.match(mcpInstructions("mac", "codex"), /\[mcp_servers\.Roblox_Studio\]/);
});

test("no Rojo leftovers in user-facing files", () => {
	const files = ["agent/AGENTS.md", "agent/CLAUDE.md", "docs/prompts/new-game.md", "docs/prompts/existing-project.md"];
	for (const name of fs.readdirSync(path.join(ROOT, "skills"))) {
		if (!fs.existsSync(path.join(ROOT, "skills", name, "LICENSE"))) files.push(`skills/${name}/SKILL.md`); // our own skills
	}
	for (const f of files) {
		const text = fs.readFileSync(path.join(ROOT, f), "utf8");
		assert.ok(!/\brojo\b|rokit|default\.project\.json|rbxkit\.mjs (check|new)\b/i.test(text), `${f} still mentions Rojo/rokit/old commands`);
	}
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
