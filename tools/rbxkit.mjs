#!/usr/bin/env node
// rbxkit — Roblox Vibe Coding Toolkit CLI. Node 18+, zero dependencies.
// Studio-first: your game lives in Roblox Studio; the agent edits it through the Studio MCP.
//
//   rbxkit init [dir]                set up an agent folder (skills, AGENTS.md, Studio installers)
//   rbxkit docs <question>           search the official Roblox docs
//   rbxkit mcp                       how to connect the Roblox Studio MCP
//   rbxkit doctor                    check what's installed

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const SELF = fileURLToPath(import.meta.url);
const TOOLKIT_ROOT = path.resolve(path.dirname(SELF), "..");
const STUDIO_ROOT = path.join(TOOLKIT_ROOT, "studio");

const color = process.stdout.isTTY && !process.env.NO_COLOR
	? { red: (s) => `\x1b[31m${s}\x1b[0m`, yellow: (s) => `\x1b[33m${s}\x1b[0m`, dim: (s) => `\x1b[2m${s}\x1b[0m`, green: (s) => `\x1b[32m${s}\x1b[0m` }
	: { red: (s) => s, yellow: (s) => s, dim: (s) => s, green: (s) => s };

class UsageError extends Error {}

function parseArgs(argv) {
	const positional = [];
	const flags = {};
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg.startsWith("--")) {
			const [key, inline] = arg.slice(2).split("=", 2);
			if (inline !== undefined) flags[key] = inline;
			else if (argv[i + 1] && !argv[i + 1].startsWith("--") && ["client", "os", "api", "deprecated", "limit"].includes(key)) flags[key] = argv[++i];
			else flags[key] = true;
		} else {
			positional.push(arg);
		}
	}
	return { positional, flags };
}

function copyDir(src, dest) {
	fs.mkdirSync(dest, { recursive: true });
	for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
		const from = path.join(src, entry.name);
		const to = path.join(dest, entry.name);
		if (entry.isDirectory()) copyDir(from, to);
		else fs.copyFileSync(from, to);
	}
}

// ---------------------------------------------------------------------------
// Studio installers: studio/<Service>/... mirrors the DataModel. A folder with
// init.server.luau / init.client.luau / init.luau becomes that script; other
// folders become Folders; X.server.luau / X.client.luau / X.luau become scripts.

// Removes comments (keeps strings, the --!strict directive and rbxkit-ignore lint suppressions) to save tokens.
export function stripComments(src) {
	const out = src.split("");
	const n = src.length;
	const stack = [];
	const blank = (a, b) => {
		for (let k = a; k < b && k < n; k++) if (out[k] !== "\n") out[k] = " ";
	};
	const longLevel = (pos) => {
		if (src[pos] !== "[") return -1;
		let j = pos + 1;
		let level = 0;
		while (src[j] === "=") {
			level++;
			j++;
		}
		return src[j] === "[" ? level : -1;
	};
	const longClose = (from, level) => {
		const close = "]" + "=".repeat(level) + "]";
		const idx = src.indexOf(close, from);
		return idx === -1 ? n : idx + close.length;
	};
	const skipTemplate = (j) => {
		while (j < n && src[j] !== "`") {
			if (src[j] === "\\") j += 2;
			else if (src[j] === "{") {
				stack.push({ depth: 0 });
				return j + 1;
			} else j++;
		}
		return j + 1;
	};
	let i = 0;
	while (i < n) {
		const c = src[i];
		if (c === "-" && src[i + 1] === "-") {
			if (src[i + 2] === "!") {
				i = src.indexOf("\n", i) === -1 ? n : src.indexOf("\n", i);
				continue;
			}
			const level = longLevel(i + 2);
			const end = level >= 0 ? longClose(i + 4 + level, level) : src.indexOf("\n", i) === -1 ? n : src.indexOf("\n", i);
			if (!src.slice(i, end).includes("rbxkit-ignore")) blank(i, end); // keep lint suppressions
			i = end;
		} else if (c === "[" && longLevel(i) >= 0) {
			const level = longLevel(i);
			i = longClose(i + level + 2, level);
		} else if (c === '"' || c === "'") {
			let j = i + 1;
			while (j < n && src[j] !== c && src[j] !== "\n") j += src[j] === "\\" ? 2 : 1;
			i = j + 1;
		} else if (c === "`") {
			i = skipTemplate(i + 1);
		} else if (stack.length > 0 && c === "{") {
			stack[stack.length - 1].depth++;
			i++;
		} else if (stack.length > 0 && c === "}") {
			const top = stack[stack.length - 1];
			if (top.depth === 0) {
				stack.pop();
				i = skipTemplate(i + 1);
			} else {
				top.depth--;
				i++;
			}
		} else i++;
	}
	const rawLines = src.split("\n");
	const lines = out.join("").split("\n");
	const kept = [];
	for (let k = 0; k < lines.length; k++) {
		const line = lines[k].replace(/\s+$/, "");
		if (line === "" && rawLines[k].trim() !== "") continue; // comment-only line
		if (line === "" && kept.length > 0 && kept[kept.length - 1] === "") continue; // collapse blanks
		kept.push(line);
	}
	return kept.join("\n").trim() + "\n";
}

const CONTAINER_CLASSES = new Set(["StarterPlayerScripts", "StarterCharacterScripts"]);
const SCRIPT_SUFFIXES = [
	[".server.luau", "Script"],
	[".client.luau", "LocalScript"],
	[".luau", "ModuleScript"],
];

function scriptKind(fileName) {
	for (const [suffix, className] of SCRIPT_SUFFIXES) {
		if (fileName.endsWith(suffix)) return { name: fileName.slice(0, -suffix.length), className };
	}
	return null;
}

// Flat list of DataModel nodes under studio/: { segments, name, className, file? }.
export function studioNodes(root = STUDIO_ROOT) {
	const nodes = [];
	const walk = (dir, segments) => {
		const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
		for (const entry of entries) {
			const full = path.join(dir, entry.name);
			if (entry.isDirectory()) {
				const init = ["init.server.luau", "init.client.luau", "init.luau"].find((f) => fs.existsSync(path.join(full, f)));
				const node = { segments: [...segments, entry.name], name: entry.name, className: "Folder" };
				if (segments.length === 0 || CONTAINER_CLASSES.has(entry.name)) node.className = entry.name;
				if (init) Object.assign(node, { className: scriptKind(init).className, file: path.join(full, init) });
				nodes.push(node);
				walk(full, node.segments);
			} else if (segments.length > 0 && !entry.name.startsWith("init.")) {
				const kind = scriptKind(entry.name);
				if (kind) nodes.push({ segments: [...segments, kind.name], name: kind.name, className: kind.className, file: full });
			}
		}
	};
	walk(root, []);
	return nodes;
}

export const INSTALL_CHUNKS = [
	{ file: "1-shared.luau", root: "ReplicatedStorage/Shared", label: "ReplicatedStorage.Shared: Net, Guard, RateLimiter, Signal, Trove" },
	{ file: "2-server.luau", root: "ServerScriptService/Server", label: "ServerScriptService.Server: bootstrap, DataService", folders: ["Services"] },
	{ file: "3-client.luau", root: "StarterPlayer/StarterPlayerScripts/Client", label: "StarterPlayerScripts.Client: bootstrap", folders: ["Controllers"] },
	{ file: "4-build-tools.luau", root: "ServerStorage/DevTools", only: ["Build", "Shots"], label: "ServerStorage.DevTools: Build, Shots (3D building)" },
	{ file: "5-lint.luau", root: "ServerStorage/DevTools", only: ["Lint"], label: "ServerStorage.DevTools: Lint (code checks)" },
];

function longString(source) {
	let level = 0;
	while (source.includes("]" + "=".repeat(level) + "]")) level++;
	const eq = "=".repeat(level);
	return `[${eq}[\n${source}]${eq}]`;
}

const INSTALLER_PRELUDE = `local FORCE = false -- true: also update scripts that already exist (your edits to them are lost)
local created, updated, kept = 0, 0, 0
local function child(parent: Instance, className: string, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local new = Instance.new(className)
	new.Name = name
	new.Parent = parent
	created += 1
	return new
end
local function put(parent: Instance, className: string, name: string, source: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		assert(found:IsA(className), \`{found:GetFullName()} exists but is not a {className}\`)
		if not FORCE then
			kept += 1
			return found
		end
		local ok = pcall(function()
			(found :: any).Source = source
		end)
		if not ok then
			game:GetService("ScriptEditorService"):UpdateSourceAsync(found :: any, function()
				return source
			end)
		end
		updated += 1
		return found
	end
	local new = Instance.new(className) :: any
	new.Name = name
	new.Source = source
	new.Parent = parent
	created += 1
	return new
end
`;

// Builds the Luau installer scripts (one per chunk) from studio/.
export function buildInstallers(root = STUDIO_ROOT) {
	const nodes = studioNodes(root);
	const total = INSTALL_CHUNKS.length;
	return INSTALL_CHUNKS.map((chunk, index) => {
		const rootSegments = chunk.root.split("/");
		const inChunk = nodes.filter((node) => {
			const prefix = node.segments.slice(0, rootSegments.length).join("/");
			if (node.segments.length < rootSegments.length || prefix !== chunk.root) {
				// ancestors of the chunk root are created as containers
				return rootSegments.slice(0, node.segments.length).join("/") === node.segments.join("/");
			}
			if (chunk.only && node.segments.length > rootSegments.length) return chunk.only.includes(node.segments[rootSegments.length]);
			return true;
		});
		const vars = new Map();
		const lines = [
			`-- rbxkit installer ${index + 1}/${total}: ${chunk.label}`,
			"-- Run in Roblox Studio (edit mode) with the Studio MCP execute_luau tool or the command bar.",
			"-- Re-running is safe: existing scripts are kept unless FORCE = true.",
			INSTALLER_PRELUDE,
		];
		let modules = 0;
		for (const node of inChunk) {
			const key = node.segments.join("/");
			const varName = `n${vars.size + 1}`;
			const parentKey = node.segments.slice(0, -1).join("/");
			if (node.segments.length === 1) {
				lines.push(`local ${varName} = game:GetService(${JSON.stringify(node.name)})`);
			} else if (node.file) {
				const source = stripComments(fs.readFileSync(node.file, "utf8"));
				lines.push(`local ${varName} = put(${vars.get(parentKey)}, ${JSON.stringify(node.className)}, ${JSON.stringify(node.name)}, ${longString(source)})`);
				modules++;
			} else {
				lines.push(`local ${varName} = child(${vars.get(parentKey)}, ${JSON.stringify(node.className)}, ${JSON.stringify(node.name)})`);
			}
			vars.set(key, varName);
		}
		for (const folder of chunk.folders ?? []) {
			lines.push(`child(${vars.get(chunk.root)}, "Folder", ${JSON.stringify(folder)})`);
		}
		lines.push(`return \`${chunk.label} -> created {created}, updated {updated}, kept {kept}\``);
		return { file: chunk.file, label: chunk.label, modules, code: lines.join("\n") + "\n" };
	});
}

// ---------------------------------------------------------------------------
// init: agent folder = skills + AGENTS.md/CLAUDE.md + rbxkit + Studio installers

function cmdInit({ positional, flags }) {
	if (!fs.existsSync(STUDIO_ROOT) || !fs.existsSync(path.join(TOOLKIT_ROOT, "skills"))) {
		throw new UsageError("init must run from the toolkit (studio/ and skills/ not found). Use: npx github:gustavopiumbini/robloxcodingtoolkit init");
	}
	const dest = path.resolve(positional[0] ?? ".");
	if (dest === TOOLKIT_ROOT) throw new UsageError("pass your game's folder, not the toolkit's");
	fs.mkdirSync(dest, { recursive: true });
	const done = [];
	for (const target of [".claude/skills", ".agents/skills"]) {
		for (const skill of fs.readdirSync(path.join(TOOLKIT_ROOT, "skills"))) {
			const to = path.join(dest, target, skill);
			fs.rmSync(to, { recursive: true, force: true });
			copyDir(path.join(TOOLKIT_ROOT, "skills", skill), to);
		}
		done.push(`skills -> ${target}/`);
	}
	for (const doc of ["AGENTS.md", "CLAUDE.md"]) {
		const to = path.join(dest, doc);
		if (fs.existsSync(to) && !flags.force) {
			done.push(color.yellow(`${doc} exists: kept (use --force to replace)`));
		} else {
			fs.copyFileSync(path.join(TOOLKIT_ROOT, "agent", doc), to);
			done.push(doc);
		}
	}
	fs.mkdirSync(path.join(dest, "tools"), { recursive: true });
	fs.copyFileSync(SELF, path.join(dest, "tools", "rbxkit.mjs"));
	done.push("tools/rbxkit.mjs");
	const installDir = path.join(dest, "install");
	fs.mkdirSync(installDir, { recursive: true });
	for (const installer of buildInstallers()) fs.writeFileSync(path.join(installDir, installer.file), installer.code);
	done.push(`install/ (${INSTALL_CHUNKS.length} Studio installers)`);

	const rel = path.relative(process.cwd(), dest) || ".";
	console.log(color.green(`Ready in ${rel}:`));
	for (const line of done) console.log(`  - ${line}`);
	console.log(`
Next:
  1. Open Roblox Studio, open your place, and connect the Studio MCP:  node tools/rbxkit.mjs mcp
  2. Open your agent in ${rel}:  claude   or   codex
  3. Ask, e.g.: "set up the toolkit in my place and build an obby with 10 checkpoints"`);
	return 0;
}

// ---------------------------------------------------------------------------
// docs: query the official docs (create.roblox.com) as Markdown

const DOCS_BASE = "https://create.roblox.com";
const API_KINDS = ["classes", "datatypes", "enums", "libraries", "globals"];

async function fetchText(url) {
	let response;
	try {
		response = await fetch(url, { headers: { Accept: "text/markdown, application/json" } });
	} catch (err) {
		throw new UsageError(`cannot reach ${DOCS_BASE} (${err.cause?.code ?? err.message})`);
	}
	return { status: response.status, text: await response.text() };
}

// Member headings vary by page type: "### Method: TweenService:Create",
// "### task.wait", "### CFrame.new" (one per overload), "### assert".
const MEMBER_HEADING = /^###\s+(?!From\s)(?:\w+:\s+)?(\S+)\s*$/;

// Every section for the member (overloads included), up to the next "##"/"###".
export function extractMember(markdown, member) {
	const lines = markdown.split("\n");
	const sections = [];
	for (let start = 0; start < lines.length; start++) {
		const m = MEMBER_HEADING.exec(lines[start]);
		if (!m || m[1].split(/[.:]/).pop() !== member) continue;
		let end = lines.findIndex((l, i) => i > start && /^#{2,3}\s/.test(l));
		if (end === -1) end = lines.length;
		sections.push(lines.slice(start, end).join("\n").trim());
		start = end - 1;
	}
	return sections.length ? sections.join("\n\n") : null;
}

export function listMembers(markdown) {
	const names = markdown
		.split("\n")
		.filter((l) => MEMBER_HEADING.test(l))
		.map((l) => l.replace(/^###\s+/, "").trim());
	return [...new Set(names)];
}

function pageOverview(markdown, maxLines = 60) {
	const body = markdown.replace(/^<!--.*?-->\s*/s, "").replace(/^---\n[\s\S]*?\n---\n/, "");
	const lines = body.split("\n");
	const methodsAt = lines.findIndex((l) => /^## (Code Samples|Properties|Methods|Events|Callbacks|Functions|Constructors)/.test(l));
	const intro = lines.slice(0, methodsAt === -1 ? maxLines : Math.min(methodsAt, maxLines)).join("\n").trim();
	const members = listMembers(markdown);
	return members.length ? `${intro}\n\nMembers:\n${members.map((m) => `  - ${m}`).join("\n")}` : intro;
}

async function cmdDocs({ positional, flags }) {
	if (flags.deprecated) {
		const name = typeof flags.deprecated === "string" ? flags.deprecated : positional.join(" ");
		if (!name) throw new UsageError("usage: rbxkit docs --deprecated <Class or member>");
		const { text } = await fetchText(`${DOCS_BASE}/docs/reference/engine/deprecated.md`);
		const rows = text.split("\n").filter((l) => l.startsWith("|") && l.toLowerCase().includes(name.toLowerCase()));
		console.log(rows.length ? ["| Class | Member | Replacement | Note |", ...rows].join("\n") : `nothing deprecated matching "${name}"`);
		return 0;
	}

	if (flags.api) {
		const target = typeof flags.api === "string" ? flags.api : positional[0];
		const match = /^([A-Za-z_][\w]*)(?:[.:]([A-Za-z_]\w*))?$/.exec(target ?? "");
		if (!match) throw new UsageError("usage: rbxkit docs --api TweenService | TweenService:Create | task.wait | CFrame.lookAt");
		const [, name, member] = match;
		for (const kind of API_KINDS) {
			const url = `${DOCS_BASE}/docs/reference/engine/${kind}/${name}.md`;
			const { status, text } = await fetchText(url);
			if (status !== 200) continue;
			if (flags.raw) console.log(text);
			else if (member) {
				const section = extractMember(text, member);
				console.log(section ?? `member "${member}" not found in ${name}. Members:\n${listMembers(text).map((m) => `  - ${m}`).join("\n")}`);
			} else console.log(pageOverview(text));
			console.log(color.dim(`\nSource: ${url.replace(/\.md$/, "")}`));
			return 0;
		}
		console.log(`"${name}" is not a class, datatype, enum, library or global. Try: rbxkit docs "${target}"`);
		return 1;
	}

	const query = positional.join(" ").trim();
	if (!query) throw new UsageError('usage: rbxkit docs "question in English" | --api Name[:member] | --deprecated Name');
	const { text } = await fetchText(`${DOCS_BASE}/docs/api/search?q=${encodeURIComponent(query)}`);
	const data = JSON.parse(text);
	if (data.error) throw new UsageError(data.error);
	const limit = Number(flags.limit) || 8;
	for (const r of (data.results ?? []).slice(0, limit)) {
		console.log(`${r.title} [${r.type}]\n  ${r.url}\n  ${String(r.summary ?? "").trim().split("\n")[0]}`);
	}
	if (!data.results?.length) console.log("no results");
	console.log(color.dim("\nRead a page: curl -s <url>  (already Markdown)  |  API: rbxkit docs --api Class:member"));
	return 0;
}

// ---------------------------------------------------------------------------
// mcp / doctor

const MCP_COMMANDS = {
	windows: { command: "cmd.exe", args: ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"] },
	mac: { command: "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP", args: [] },
};

function currentOs() {
	return process.platform === "win32" ? "windows" : process.platform === "darwin" ? "mac" : null;
}

export function mcpInstructions(os, client) {
	const spec = MCP_COMMANDS[os];
	const cli = [spec.command, ...spec.args].join(" ");
	const lines = [];
	if (client === "claude" || client === "all") {
		lines.push(`# Claude Code (${os})`, `claude mcp add Roblox_Studio -- ${cli}`, "");
		lines.push("# or .mcp.json at the project root:", JSON.stringify({ mcpServers: { Roblox_Studio: spec.args.length ? spec : { command: spec.command } } }, null, 2), "");
	}
	if (client === "codex" || client === "all") {
		lines.push(`# Codex CLI (${os})`, `codex mcp add Roblox_Studio -- ${cli}`, "");
		lines.push("# or in ~/.codex/config.toml:", "[mcp_servers.Roblox_Studio]", `command = ${JSON.stringify(spec.command)}`);
		if (spec.args.length) lines.push(`args = [${spec.args.map((a) => JSON.stringify(a)).join(", ")}]`);
		lines.push("");
	}
	return lines.join("\n");
}

function cmdMcp({ flags }) {
	const os = typeof flags.os === "string" ? flags.os : currentOs();
	const client = typeof flags.client === "string" ? flags.client : "all";
	if (!["claude", "codex", "all"].includes(client)) throw new UsageError("--client must be claude, codex or all");
	console.log(`Roblox Studio MCP
1. In Studio: Assistant > ... > Manage MCP Servers > turn on "Enable Studio as MCP server".
2. Easiest: under Quick connect, turn on Claude Code and/or Codex CLI, then restart the agent.
3. Manual:
`);
	const systems = os && MCP_COMMANDS[os] ? [os] : ["windows", "mac"];
	if (!os) console.log(color.dim("(Studio runs on Windows and macOS only; showing both)\n"));
	for (const s of systems) console.log(mcpInstructions(s, client));
	if (flags.write) {
		if (!os || !MCP_COMMANDS[os]) throw new UsageError("--write needs --os windows|mac");
		const file = path.join(process.cwd(), ".mcp.json");
		const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
		config.mcpServers = { ...(config.mcpServers ?? {}), Roblox_Studio: MCP_COMMANDS[os].args.length ? MCP_COMMANDS[os] : { command: MCP_COMMANDS[os].command } };
		fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
		console.log(color.green(`wrote ${path.relative(process.cwd(), file)}`));
	}
	console.log("Check: Manage MCP Servers shows a green indicator with the number of connected clients.");
	console.log(color.yellow("Warning: MCP can read and modify the open place. Only connect trusted clients."));
	return 0;
}

function cmdDoctor() {
	const check = (label, ok, hint) => console.log(`${ok ? color.green("ok ") : color.yellow("-- ")} ${label}${ok || !hint ? "" : color.dim(`  -> ${hint}`)}`);
	const version = (bin) => {
		const r = spawnSync(bin, ["--version"], { encoding: "utf8", shell: process.platform === "win32" });
		return r.status === 0 ? (r.stdout || r.stderr).trim().split("\n")[0] : null;
	};
	const major = Number(process.versions.node.split(".")[0]);
	check(`node ${process.versions.node}`, major >= 18, "install Node 18+");
	for (const [bin, hint] of [
		["claude", "https://claude.com/claude-code"],
		["codex", "https://developers.openai.com/codex"],
	]) {
		const v = version(bin);
		check(v ? `${bin} (${v})` : bin, Boolean(v), hint);
	}
	const studio =
		process.platform === "win32"
			? fs.existsSync(path.join(process.env.LOCALAPPDATA ?? "", "Roblox", "Versions"))
			: process.platform === "darwin"
				? fs.existsSync("/Applications/RobloxStudio.app")
				: false;
	check("Roblox Studio", studio, process.platform === "linux" ? "Studio runs on Windows/macOS only" : "https://create.roblox.com");
	const cwd = process.cwd();
	check("AGENTS.md", fs.existsSync(path.join(cwd, "AGENTS.md")), "rbxkit init");
	check(".claude/skills + .agents/skills", fs.existsSync(path.join(cwd, ".claude", "skills")) && fs.existsSync(path.join(cwd, ".agents", "skills")), "rbxkit init");
	check("install/ (Studio installers)", fs.existsSync(path.join(cwd, "install")), "rbxkit init");
	console.log(color.dim("\nStudio MCP: node tools/rbxkit.mjs mcp"));
	return 0;
}

// ---------------------------------------------------------------------------

const HELP = `rbxkit — Roblox Vibe Coding Toolkit (Studio-first)

Usage:
  rbxkit init [dir] [--force]             set up an agent folder: skills, AGENTS.md, CLAUDE.md,
                                          and install/*.luau (run them in Studio via MCP execute_luau)
  rbxkit docs "<question>" [--limit N]    search the official docs (create.roblox.com)
  rbxkit docs --api Class[:member]        API reference (e.g. TweenService:Create, task.wait)
  rbxkit docs --deprecated <Name>         deprecated APIs and their replacements
  rbxkit mcp [--client claude|codex] [--os windows|mac] [--write]
                                          connect the Roblox Studio MCP (--write creates .mcp.json)
  rbxkit doctor                           check node, agents, Studio and the agent folder
`;

export async function main(argv) {
	const [command, ...rest] = argv;
	const args = parseArgs(rest);
	const commands = { init: cmdInit, install: cmdInit, docs: cmdDocs, mcp: cmdMcp, doctor: cmdDoctor };
	if (!command || command === "help" || command === "--help" || command === "-h") {
		console.log(HELP);
		return 0;
	}
	const handler = commands[command];
	if (!handler) {
		console.error(`unknown command: ${command}\n\n${HELP}`);
		return 2;
	}
	try {
		return await handler(args);
	} catch (err) {
		if (err instanceof UsageError) {
			console.error(color.red(`error: ${err.message}`));
			return 2;
		}
		throw err;
	}
}

if (process.argv[1] && pathToFileURL(fs.realpathSync(process.argv[1])).href === pathToFileURL(SELF).href) {
	process.exitCode = await main(process.argv.slice(2));
}
