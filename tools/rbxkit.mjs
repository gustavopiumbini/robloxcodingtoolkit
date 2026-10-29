#!/usr/bin/env node
// rbxkit — CLI do Roblox Vibe Coding Toolkit. Node 18+, sem dependências.
//
//   rbxkit init <pasta>              cria um jogo novo (Rojo + skills + AGENTS.md)
//   rbxkit install [pasta]           instala skills/AGENTS.md num projeto existente
//   rbxkit new <tipo> <Nome>         gera service | controller | module
//   rbxkit check [caminhos...]       lint específico de Roblox
//   rbxkit docs <pergunta>           busca na documentação oficial da Roblox
//   rbxkit mcp                       mostra como conectar o MCP do Roblox Studio
//   rbxkit doctor                    confere ferramentas instaladas

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const SELF = fileURLToPath(import.meta.url);
const TOOLKIT_ROOT = path.resolve(path.dirname(SELF), "..");
const SKIP_DIRS = new Set(["node_modules", ".git", "Packages", "ServerPackages", "DevPackages", ".agents", ".claude"]);

const color = process.stdout.isTTY && !process.env.NO_COLOR
	? { red: (s) => `\x1b[31m${s}\x1b[0m`, yellow: (s) => `\x1b[33m${s}\x1b[0m`, cyan: (s) => `\x1b[36m${s}\x1b[0m`, dim: (s) => `\x1b[2m${s}\x1b[0m`, green: (s) => `\x1b[32m${s}\x1b[0m` }
	: { red: (s) => s, yellow: (s) => s, cyan: (s) => s, dim: (s) => s, green: (s) => s };

class UsageError extends Error {}

// ---------------------------------------------------------------------------
// Utilidades de arquivo

function hasToolkitSources() {
	return fs.existsSync(path.join(TOOLKIT_ROOT, "template")) && fs.existsSync(path.join(TOOLKIT_ROOT, "skills"));
}

function requireToolkitSources(command) {
	if (!hasToolkitSources()) {
		throw new UsageError(
			`"${command}" precisa ser executado a partir do repositório do toolkit (pastas template/ e skills/ não encontradas).\n` +
				"Use: npx github:gustavopiumbini/robloxcodingtoolkit " + command,
		);
	}
}

function copyDir(src, dest, { overwrite = true } = {}) {
	const written = [];
	fs.mkdirSync(dest, { recursive: true });
	for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
		const from = path.join(src, entry.name);
		const to = path.join(dest, entry.name);
		if (entry.isDirectory()) {
			written.push(...copyDir(from, to, { overwrite }));
		} else if (overwrite || !fs.existsSync(to)) {
			fs.copyFileSync(from, to);
			written.push(to);
		}
	}
	return written;
}

function findProjectRoot(start = process.cwd()) {
	let dir = path.resolve(start);
	for (;;) {
		if (fs.existsSync(path.join(dir, "default.project.json"))) return dir;
		const parent = path.dirname(dir);
		if (parent === dir) return null;
		dir = parent;
	}
}

function listLuauFiles(target) {
	const stat = fs.statSync(target);
	if (stat.isFile()) return /\.luau?$/.test(target) ? [target] : [];
	const files = [];
	for (const entry of fs.readdirSync(target, { withFileTypes: true })) {
		if (entry.isDirectory()) {
			if (!SKIP_DIRS.has(entry.name)) files.push(...listLuauFiles(path.join(target, entry.name)));
		} else if (/\.luau?$/.test(entry.name)) {
			files.push(path.join(target, entry.name));
		}
	}
	return files.sort();
}

function parseArgs(argv) {
	const positional = [];
	const flags = {};
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg.startsWith("--")) {
			const [key, inline] = arg.slice(2).split("=", 2);
			if (inline !== undefined) flags[key] = inline;
			else if (argv[i + 1] && !argv[i + 1].startsWith("--") && ["name", "client", "os", "api", "deprecated", "limit"].includes(key)) flags[key] = argv[++i];
			else flags[key] = true;
		} else {
			positional.push(arg);
		}
	}
	return { positional, flags };
}

// ---------------------------------------------------------------------------
// Lint: mascara comentários e conteúdo de strings preservando posições

export function maskSource(src) {
	const out = src.split("");
	const n = src.length;
	const stack = []; // um item por `string interpolada` aberta: { depth }
	const blank = (a, b) => {
		for (let k = a; k < b && k < n; k++) if (out[k] !== "\n") out[k] = " ";
	};
	const longBracketLevel = (pos) => {
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
	const scanTemplate = (j) => {
		const start = j;
		while (j < n && src[j] !== "`") {
			if (src[j] === "\\") {
				j += 2;
				continue;
			}
			if (src[j] === "{") {
				blank(start, j);
				stack.push({ depth: 0 });
				return j + 1;
			}
			j++;
		}
		blank(start, j);
		return j + 1;
	};

	let i = 0;
	while (i < n) {
		const c = src[i];
		if (c === "-" && src[i + 1] === "-") {
			const level = longBracketLevel(i + 2);
			let end;
			if (level >= 0) end = longClose(i + 4 + level, level);
			else {
				end = src.indexOf("\n", i);
				if (end === -1) end = n;
			}
			blank(i, end);
			i = end;
			continue;
		}
		if (c === "[") {
			const level = longBracketLevel(i);
			if (level >= 0) {
				const contentStart = i + level + 2;
				const end = longClose(contentStart, level);
				blank(contentStart, end - level - 2);
				i = end;
				continue;
			}
		}
		if (c === '"' || c === "'") {
			let j = i + 1;
			while (j < n && src[j] !== c && src[j] !== "\n") {
				if (src[j] === "\\") j++;
				j++;
			}
			blank(i + 1, j);
			i = j + 1;
			continue;
		}
		if (c === "`") {
			i = scanTemplate(i + 1);
			continue;
		}
		if (stack.length > 0) {
			const top = stack[stack.length - 1];
			if (c === "{") top.depth++;
			else if (c === "}") {
				if (top.depth === 0) {
					stack.pop();
					i = scanTemplate(i + 1);
					continue;
				}
				top.depth--;
			}
		}
		i++;
	}
	return out.join("");
}

const SERVER_ONLY_SERVICES = "DataStoreService|ServerStorage|ServerScriptService|MessagingService|MemoryStoreService";
const DIRECT_SERVICES =
	"Players|ReplicatedStorage|ServerStorage|ServerScriptService|Lighting|TweenService|RunService|UserInputService|DataStoreService|HttpService|SoundService|Teams|StarterGui|StarterPack|StarterPlayer|MarketplaceService|CollectionService|Debris";

// Cada regra recebe { line, raw, ctx } e retorna mensagem (string) ou null.
export const RULES = [
	{ id: "deprecated-wait", severity: "error", test: ({ line }) => /(^|[^.:\w])wait\s*\(/.test(line) && "wait() é depreciado: use task.wait()" },
	{ id: "deprecated-spawn", severity: "error", test: ({ line }) => /(^|[^.:\w])spawn\s*\(/.test(line) && "spawn() é depreciado: use task.spawn()" },
	{ id: "deprecated-delay", severity: "error", test: ({ line }) => /(^|[^.:\w])delay\s*\(/.test(line) && "delay() é depreciado: use task.delay()" },
	{ id: "lowercase-connect", severity: "error", test: ({ line }) => /:connect\s*\(/.test(line) && ":connect() é depreciado: use :Connect()" },
	{ id: "loadstring", severity: "error", test: ({ line }) => /(^|[^.:\w])loadstring\s*\(/.test(line) && "loadstring é inseguro e desativado por padrão" },
	{ id: "require-asset-id", severity: "error", test: ({ line }) => /\brequire\s*\(\s*\d+/.test(line) && "require(id) carrega código externo: risco de backdoor" },
	{
		id: "invoke-client",
		severity: "error",
		test: ({ line }) => /:InvokeClient\s*\(/.test(line) && "InvokeClient pode travar o servidor (cliente pode nunca responder): use RemoteEvent",
	},
	{
		id: "localplayer-on-server",
		severity: "error",
		test: ({ line, ctx }) => ctx.side === "server" && /\.LocalPlayer\b/.test(line) && "LocalPlayer é nil no servidor: use o player recebido do evento",
	},
	{
		id: "server-api-on-client",
		severity: "error",
		test: ({ line, raw, ctx }) =>
			ctx.side === "client" &&
			/GetService\s*\(/.test(line) &&
			new RegExp(`GetService\\s*\\(\\s*["'\`](${SERVER_ONLY_SERVICES})["'\`]`).test(raw) &&
			"este serviço não é acessível pelo cliente",
	},
	{
		id: "render-on-server",
		severity: "error",
		test: ({ line, ctx }) => ctx.side === "server" && /\b(RenderStepped|BindToRenderStep)\b/.test(line) && "RenderStepped só existe no cliente: use Heartbeat",
	},
	{
		id: "instance-new-parent",
		severity: "warning",
		test: ({ line }) => /Instance\.new\s*\(\s*(["'])[^"']*\1\s*,/.test(line) && "não passe Parent no Instance.new: configure propriedades e defina Parent por último",
	},
	{
		id: "fireserver-player-arg",
		severity: "warning",
		test: ({ line }) =>
			/:FireServer\s*\(\s*(player|plr|localPlayer|LocalPlayer|Players\.LocalPlayer|game\.Players\.LocalPlayer)\s*[,)]/.test(line) &&
			"o servidor já recebe o player automaticamente: não envie o player no FireServer",
	},
	{ id: "set-primary-part-cframe", severity: "warning", test: ({ line }) => /:SetPrimaryPartCFrame\s*\(/.test(line) && "SetPrimaryPartCFrame é depreciado: use :PivotTo()" },
	{ id: "get-primary-part-cframe", severity: "warning", test: ({ line }) => /:(GetPrimaryPartCFrame|GetModelCFrame)\s*\(/.test(line) && "use :GetPivot()" },
	{
		id: "humanoid-load-animation",
		severity: "warning",
		test: ({ line }) => /\b\w*[Hh]umanoid\w*\s*:\s*LoadAnimation\s*\(/.test(line) && "Humanoid:LoadAnimation é depreciado: use Animator:LoadAnimation",
	},
	{
		id: "body-movers",
		severity: "warning",
		test: ({ line, raw }) =>
			/Instance\.new/.test(line) &&
			/Instance\.new\s*\(\s*["'](BodyVelocity|BodyPosition|BodyGyro|BodyForce|BodyAngularVelocity|BodyThrust)["']/.test(raw) &&
			"Body movers são depreciados: use LinearVelocity, AlignPosition, AlignOrientation ou VectorForce",
	},
	{ id: "find-part-on-ray", severity: "warning", test: ({ line }) => /\bFindPartOnRay\w*\s*\(/.test(line) && "FindPartOnRay é depreciado: use workspace:Raycast" },
	{ id: "fenv", severity: "warning", test: ({ line }) => /(^|[^.:\w])(getfenv|setfenv)\s*\(/.test(line) && "getfenv/setfenv desativam otimizações do Luau" },
	{ id: "table-getn", severity: "warning", test: ({ line }) => /\btable\.getn\s*\(/.test(line) && "table.getn é depreciado: use #t" },
	{
		id: "datastore-no-pcall",
		severity: "warning",
		test: ({ line, ctx, index }) => {
			if (!/:(GetAsync|SetAsync|UpdateAsync|RemoveAsync|IncrementAsync|GetSortedAsync)\s*\(/.test(line)) return null;
			const context = ctx.masked.slice(Math.max(0, index - 3), index + 1).join("\n");
			return /pcall|retr(y|ies)|Retr(y|ies)|Promise/.test(context) ? null : "chamada de DataStore sem pcall/retry: pode falhar a qualquer momento";
		},
	},
	{ id: "prefer-update-async", severity: "info", test: ({ line }) => /:SetAsync\s*\(/.test(line) && "prefira UpdateAsync (SetAsync sobrescreve dados de outros servidores)" },
	{ id: "direct-service-index", severity: "info", test: ({ line }) => new RegExp(`\\bgame\\.(${DIRECT_SERVICES})\\b`).test(line) && 'use game:GetService("...") em vez de game.Servico' },
	{ id: "global-unpack", severity: "info", test: ({ line }) => /(^|[^.:\w])unpack\s*\(/.test(line) && "use table.unpack" },
];

function indentOf(text) {
	const m = /^[\t ]*/.exec(text)[0];
	return m.replace(/\t/g, "    ").length;
}

// Corpo de um bloco: linhas seguintes com indentação maior que a linha inicial.
function blockBody(masked, start, maxLines = 80) {
	const baseIndent = indentOf(masked[start]);
	const body = [];
	for (let j = start + 1; j < masked.length && j <= start + maxLines; j++) {
		const text = masked[j];
		if (text.trim() === "") continue;
		if (indentOf(text) <= baseIndent) break;
		body.push(text);
	}
	return body.join("\n");
}

const BLOCK_RULES = [
	{
		id: "while-true-no-yield",
		severity: "error",
		test: ({ line, ctx, index }) => {
			if (!/\bwhile\s+true\s+do\b/.test(line)) return null;
			const sameLine = line.slice(line.indexOf("do") + 2);
			const body = sameLine + "\n" + blockBody(ctx.masked, index);
			return /wait|Wait|yield|Yield|coroutine\.yield|\bbreak\b|\breturn\b/.test(body) ? null : "while true sem yield (task.wait) congela o jogo";
		},
	},
	{
		id: "remote-without-validation",
		severity: "warning",
		test: ({ line, ctx, index }) => {
			if (!/\.(OnServerEvent\s*:\s*Connect|OnServerInvoke\s*=)/.test(line)) return null;
			const params = /function\s*\(([^)]*)\)/.exec(line);
			if (!params) return null; // handler nomeado: não dá para inspecionar daqui
			const count = params[1].split(",").filter((p) => p.trim() !== "").length;
			if (count <= 1) return null;
			const body = blockBody(ctx.masked, index);
			return /typeof\s*\(|type\s*\(|Guard|assert\s*\(|tonumber|IsA\s*\(|valid|check|Check/.test(body)
				? null
				: "handler de remote não parece validar os argumentos do cliente (use Net.onServerEvent + Guard)";
		},
	},
];

function fileSide(file) {
	const normalized = file.replace(/\\/g, "/");
	if (/\.server\.luau?$/.test(normalized) || /(^|\/)(server|ServerScriptService|ServerStorage)\//.test(normalized)) return "server";
	if (/\.client\.luau?$/.test(normalized) || /(^|\/)(client|StarterPlayerScripts|StarterGui|StarterCharacterScripts)\//.test(normalized)) return "client";
	return "shared";
}

function suppressed(rawLines, index, ruleId) {
	const matches = (text) => {
		const m = /rbxkit-ignore(?!-next-line)(?::\s*([\w\-, ]+))?/.exec(text);
		return m && (!m[1] || m[1].split(/[,\s]+/).includes(ruleId));
	};
	const matchesNext = (text) => {
		const m = /rbxkit-ignore-next-line(?::\s*([\w\-, ]+))?/.exec(text);
		return m && (!m[1] || m[1].split(/[,\s]+/).includes(ruleId));
	};
	return matches(rawLines[index]) || (index > 0 && matchesNext(rawLines[index - 1]));
}

export function checkSource(source, file = "input.luau") {
	const rawLines = source.split(/\r?\n/);
	const masked = maskSource(source).split(/\r?\n/);
	const ctx = { side: fileSide(file), masked };
	const findings = [];
	const report = (rule, index, message) => {
		if (!message || suppressed(rawLines, index, rule.id)) return;
		findings.push({ file, line: index + 1, rule: rule.id, severity: rule.severity, message });
	};

	const firstCode = rawLines.find((l) => l.trim() !== "");
	if (firstCode !== undefined && !/^--!(strict|nonstrict|nocheck)/.test(firstCode.trim())) {
		report({ id: "missing-strict", severity: "info" }, 0, "adicione --!strict na primeira linha");
	}

	for (let index = 0; index < masked.length; index++) {
		const line = masked[index];
		if (line.trim() === "") continue;
		const args = { line, raw: rawLines[index], ctx, index };
		for (const rule of RULES) report(rule, index, rule.test(args));
		for (const rule of BLOCK_RULES) report(rule, index, rule.test(args));
	}
	return findings;
}

function cmdCheck({ positional, flags }) {
	const root = findProjectRoot() ?? process.cwd();
	let targets = positional;
	if (targets.length === 0) targets = [fs.existsSync(path.join(root, "src")) ? path.join(root, "src") : root];
	const files = targets.flatMap((t) => {
		if (!fs.existsSync(t)) throw new UsageError(`caminho não encontrado: ${t}`);
		return listLuauFiles(t);
	});
	const findings = files.flatMap((file) => checkSource(fs.readFileSync(file, "utf8"), path.relative(process.cwd(), file) || file));
	const shown = flags.quiet ? findings.filter((f) => f.severity !== "info") : findings;

	if (flags.json) {
		console.log(JSON.stringify({ files: files.length, findings: shown }, null, 2));
	} else {
		const paint = { error: color.red, warning: color.yellow, info: color.cyan };
		for (const f of shown) {
			console.log(`${f.file}:${f.line}  ${paint[f.severity](f.severity.padEnd(7))}  ${f.message} ${color.dim(`[${f.rule}]`)}`);
		}
		const count = (s) => findings.filter((f) => f.severity === s).length;
		const summary = `${files.length} arquivo(s): ${count("error")} erro(s), ${count("warning")} aviso(s), ${count("info")} info`;
		console.log(count("error") > 0 ? color.red(summary) : count("warning") > 0 ? color.yellow(summary) : color.green(summary));
		if (shown.length > 0) console.log(color.dim("Silenciar uma linha: -- rbxkit-ignore: <regra>  |  próxima linha: -- rbxkit-ignore-next-line"));
	}
	const failing = findings.some((f) => f.severity === "error" || (flags.strict && f.severity === "warning"));
	return failing ? 1 : 0;
}

// ---------------------------------------------------------------------------
// new: gera arquivos no padrão do template

const GENERATORS = {
	service: {
		dir: "src/server/Services",
		suffix: "Service",
		body: (name) => `--!strict
-- ${name}: TODO descreva a responsabilidade deste serviço (roda só no servidor).

local Players = game:GetService("Players")

local ${name} = {}

function ${name}:Init()
	-- Síncrono: crie remotes (Net.onServerEvent + Guard) e conecte sinais de outros serviços.
end

function ${name}:Start()
	Players.PlayerAdded:Connect(function(player)
		-- TODO
	end)
end

return ${name}
`,
	},
	controller: {
		dir: "src/client/Controllers",
		suffix: "Controller",
		body: (name) => `--!strict
-- ${name}: TODO descreva a responsabilidade deste controller (roda só no cliente).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ${name} = {}

function ${name}:Init()
	-- Síncrono: prepare estado e conexões.
end

function ${name}:Start()
	-- UI, input e efeitos. O servidor valida tudo; aqui só enviamos intenções.
	local _ = player
end

return ${name}
`,
	},
	module: {
		dir: "src/shared",
		suffix: "",
		body: (name) => `--!strict
-- ${name}: TODO descreva este módulo (compartilhado entre cliente e servidor).

local ${name} = {}

return ${name}
`,
	},
};

function cmdNew({ positional, flags }) {
	const [kind, rawName] = positional;
	const generator = GENERATORS[kind];
	if (!generator || !rawName) throw new UsageError("uso: rbxkit new <service|controller|module> <Nome>");
	const root = findProjectRoot();
	if (!root) throw new UsageError("default.project.json não encontrado: rode dentro de um projeto Rojo");

	const segments = rawName.split(/[\\/]/).filter(Boolean);
	let baseName = segments.pop();
	if (kind !== "module" && segments.length > 0) throw new UsageError("subpastas só são suportadas para module");
	if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(baseName)) throw new UsageError(`nome inválido: ${baseName}`);
	baseName = baseName[0].toUpperCase() + baseName.slice(1);
	if (generator.suffix && !baseName.endsWith(generator.suffix)) baseName += generator.suffix;

	const file = path.join(root, generator.dir, ...segments, `${baseName}.luau`);
	if (fs.existsSync(file) && !flags.force) throw new UsageError(`já existe: ${path.relative(process.cwd(), file)} (use --force para sobrescrever)`);
	fs.mkdirSync(path.dirname(file), { recursive: true });
	fs.writeFileSync(file, generator.body(baseName));
	console.log(color.green(`criado ${path.relative(process.cwd(), file)}`));
	return 0;
}

// ---------------------------------------------------------------------------
// init / install

function installAgentFiles(dest, { force = false } = {}) {
	requireToolkitSources("install");
	const actions = [];
	const skillsSrc = path.join(TOOLKIT_ROOT, "skills");
	for (const target of [".claude/skills", ".agents/skills"]) {
		for (const skill of fs.readdirSync(skillsSrc)) {
			copyDir(path.join(skillsSrc, skill), path.join(dest, target, skill));
		}
		actions.push(`skills -> ${target}/`);
	}
	for (const doc of ["AGENTS.md", "CLAUDE.md"]) {
		const to = path.join(dest, doc);
		if (fs.existsSync(to) && !force) {
			actions.push(color.yellow(`${doc} já existe: mantido (compare com ${path.join(TOOLKIT_ROOT, "agent", doc)} ou use --force)`));
		} else {
			fs.copyFileSync(path.join(TOOLKIT_ROOT, "agent", doc), to);
			actions.push(doc);
		}
	}
	fs.mkdirSync(path.join(dest, "tools"), { recursive: true });
	fs.copyFileSync(SELF, path.join(dest, "tools", "rbxkit.mjs"));
	actions.push("tools/rbxkit.mjs");
	return actions;
}

function cmdInstall({ positional, flags }) {
	const dest = path.resolve(positional[0] ?? process.cwd());
	if (!fs.existsSync(dest)) throw new UsageError(`pasta não encontrada: ${dest}`);
	if (path.resolve(dest) === TOOLKIT_ROOT) throw new UsageError("informe a pasta do seu jogo, não a do toolkit");
	const actions = installAgentFiles(dest, { force: Boolean(flags.force) });
	console.log(`Instalado em ${dest}:`);
	for (const a of actions) console.log(`  - ${a}`);
	if (!fs.existsSync(path.join(dest, "default.project.json"))) {
		console.log(color.yellow("\nAviso: sem default.project.json. As skills assumem um projeto Rojo; veja o README para migrar."));
	}
	return 0;
}

function cmdInit({ positional, flags }) {
	requireToolkitSources("init");
	const target = positional[0];
	if (!target) throw new UsageError("uso: rbxkit init <pasta> [--name NomeDoJogo]");
	const dest = path.resolve(target);
	if (fs.existsSync(dest) && fs.readdirSync(dest).length > 0 && !flags.force) {
		throw new UsageError(`${dest} não está vazia (use --force para mesclar)`);
	}
	copyDir(path.join(TOOLKIT_ROOT, "template"), dest, { overwrite: Boolean(flags.force) });
	const gitignore = path.join(dest, "_gitignore");
	if (fs.existsSync(gitignore)) {
		if (!fs.existsSync(path.join(dest, ".gitignore"))) fs.renameSync(gitignore, path.join(dest, ".gitignore"));
		else fs.rmSync(gitignore);
	}
	const name = typeof flags.name === "string" ? flags.name : path.basename(dest).replace(/[^\w-]/g, "") || "MyGame";
	const projectFile = path.join(dest, "default.project.json");
	const project = JSON.parse(fs.readFileSync(projectFile, "utf8"));
	project.name = name;
	fs.writeFileSync(projectFile, JSON.stringify(project, null, 2) + "\n");
	installAgentFiles(dest, { force: true });

	const rel = path.relative(process.cwd(), dest) || ".";
	console.log(color.green(`Projeto "${name}" criado em ${rel}\n`));
	console.log(`Próximos passos:
  1. cd ${rel}
  2. rokit install                 (instala rojo, selene, stylua, luau-lsp — https://github.com/rojo-rbx/rokit)
  3. rojo serve                    (e no Studio: plugin Rojo > Connect)
  4. Conecte o MCP do Studio:      node tools/rbxkit.mjs mcp
  5. Abra o agente na pasta:       claude   ou   codex
     e peça, por exemplo: "use a skill roblox-feature e crie um obby com 10 checkpoints"`);
	return 0;
}

// ---------------------------------------------------------------------------
// docs: consulta a documentação oficial (create.roblox.com) em Markdown

const DOCS_BASE = "https://create.roblox.com";
const API_KINDS = ["classes", "datatypes", "enums", "libraries", "globals"];

async function fetchText(url) {
	let response;
	try {
		response = await fetch(url, { headers: { Accept: "text/markdown, application/json" } });
	} catch (err) {
		throw new UsageError(`sem acesso a ${DOCS_BASE} (${err.cause?.code ?? err.message})`);
	}
	return { status: response.status, text: await response.text() };
}

// Títulos de membro variam por tipo de página: "### Method: TweenService:Create",
// "### task.wait", "### CFrame.new" (um por overload), "### assert".
const MEMBER_HEADING = /^###\s+(?!From\s)(?:\w+:\s+)?(\S+)\s*$/;

// Todas as seções do membro (overloads incluídos), até o próximo "##"/"###".
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
	return members.length ? `${intro}\n\nMembros:\n${members.map((m) => `  - ${m}`).join("\n")}` : intro;
}

async function cmdDocs({ positional, flags }) {
	if (flags.deprecated) {
		const name = typeof flags.deprecated === "string" ? flags.deprecated : positional.join(" ");
		if (!name) throw new UsageError("uso: rbxkit docs --deprecated <Classe ou membro>");
		const { text } = await fetchText(`${DOCS_BASE}/docs/reference/engine/deprecated.md`);
		const rows = text.split("\n").filter((l) => l.startsWith("|") && l.toLowerCase().includes(name.toLowerCase()));
		console.log(rows.length ? ["| Classe | Membro | Substituto | Nota |", ...rows].join("\n") : `nada depreciado contendo "${name}"`);
		return 0;
	}

	if (flags.api) {
		const target = typeof flags.api === "string" ? flags.api : positional[0];
		const match = /^([A-Za-z_][\w]*)(?:[.:]([A-Za-z_]\w*))?$/.exec(target ?? "");
		if (!match) throw new UsageError("uso: rbxkit docs --api TweenService | TweenService:Create | task.wait | CFrame.lookAt");
		const [, name, member] = match;
		for (const kind of API_KINDS) {
			const url = `${DOCS_BASE}/docs/reference/engine/${kind}/${name}.md`;
			const { status, text } = await fetchText(url);
			if (status !== 200) continue;
			if (flags.raw) console.log(text);
			else if (member) {
				const section = extractMember(text, member);
				console.log(section ?? `membro "${member}" não encontrado em ${name}. Membros:\n${listMembers(text).map((m) => `  - ${m}`).join("\n")}`);
			} else console.log(pageOverview(text));
			console.log(color.dim(`\nFonte: ${url.replace(/\.md$/, "")}`));
			return 0;
		}
		console.log(`"${name}" não é classe, datatype, enum, library ou global. Tente: rbxkit docs "${target}"`);
		return 1;
	}

	const query = positional.join(" ").trim();
	if (!query) throw new UsageError('uso: rbxkit docs "pergunta em linguagem natural" | --api Nome[:membro] | --deprecated Nome');
	const { text } = await fetchText(`${DOCS_BASE}/docs/api/search?q=${encodeURIComponent(query)}`);
	const data = JSON.parse(text);
	if (data.error) throw new UsageError(data.error);
	const limit = Number(flags.limit) || 8;
	for (const r of (data.results ?? []).slice(0, limit)) {
		console.log(`${r.title} [${r.type}]\n  ${r.url}\n  ${String(r.summary ?? "").trim().split("\n")[0]}`);
	}
	if (!data.results?.length) console.log("nenhum resultado");
	console.log(color.dim("\nLeia uma página: curl -s <url>  (já está em Markdown)  |  API: rbxkit docs --api Classe:membro"));
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
		lines.push("# ou .mcp.json na raiz do projeto:", JSON.stringify({ mcpServers: { Roblox_Studio: spec.args.length ? spec : { command: spec.command } } }, null, 2), "");
	}
	if (client === "codex" || client === "all") {
		lines.push(`# Codex CLI (${os})`, `codex mcp add Roblox_Studio -- ${cli}`, "");
		lines.push("# ou em ~/.codex/config.toml:", "[mcp_servers.Roblox_Studio]", `command = ${JSON.stringify(spec.command)}`);
		if (spec.args.length) lines.push(`args = [${spec.args.map((a) => JSON.stringify(a)).join(", ")}]`);
		lines.push("");
	}
	return lines.join("\n");
}

function cmdMcp({ flags }) {
	const os = typeof flags.os === "string" ? flags.os : currentOs();
	const client = typeof flags.client === "string" ? flags.client : "all";
	if (!["claude", "codex", "all"].includes(client)) throw new UsageError("--client deve ser claude, codex ou all");
	console.log(`Roblox Studio MCP
1. No Studio: Assistant > ... > Manage MCP Servers > ligue "Enable Studio as MCP server".
2. Mais fácil: em Quick connect, ligue Claude Code e/ou Codex CLI e reinicie o agente.
3. Manual:
`);
	const systems = os && MCP_COMMANDS[os] ? [os] : ["windows", "mac"];
	if (!os) console.log(color.dim("(Studio só roda em Windows e macOS; mostrando os dois)\n"));
	for (const s of systems) console.log(mcpInstructions(s, client));
	if (flags.write) {
		if (!os || !MCP_COMMANDS[os]) throw new UsageError("--write precisa de --os windows|mac");
		const root = findProjectRoot() ?? process.cwd();
		const file = path.join(root, ".mcp.json");
		const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
		config.mcpServers = { ...(config.mcpServers ?? {}), Roblox_Studio: MCP_COMMANDS[os].args.length ? MCP_COMMANDS[os] : { command: MCP_COMMANDS[os].command } };
		fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
		console.log(color.green(`escrito ${path.relative(process.cwd(), file)}`));
	}
	console.log("Confira: em Manage MCP Servers aparece um indicador verde com o número de clientes conectados.");
	console.log(color.yellow("Atenção: o MCP pode ler e modificar o place aberto. Conecte só clientes confiáveis."));
	return 0;
}

function cmdDoctor() {
	const check = (label, ok, hint) => console.log(`${ok ? color.green("ok ") : color.yellow("-- ")} ${label}${ok || !hint ? "" : color.dim(`  -> ${hint}`)}`);
	const version = (bin) => {
		const r = spawnSync(bin, ["--version"], { encoding: "utf8", shell: process.platform === "win32" });
		return r.status === 0 ? (r.stdout || r.stderr).trim().split("\n")[0] : null;
	};
	const major = Number(process.versions.node.split(".")[0]);
	check(`node ${process.versions.node}`, major >= 18, "instale Node 18+");
	for (const [bin, hint] of [
		["rokit", "https://github.com/rojo-rbx/rokit"],
		["rojo", "rokit install (ou rokit add rojo-rbx/rojo)"],
		["selene", "rokit install"],
		["stylua", "rokit install"],
		["luau-lsp", "opcional: extensão VS Code luau-lsp"],
		["claude", "https://claude.com/claude-code"],
		["codex", "https://developers.openai.com/codex"],
	]) {
		const v = version(bin);
		check(v ? `${bin} (${v})` : bin, Boolean(v), hint);
	}
	const root = findProjectRoot();
	check(root ? `projeto Rojo em ${root}` : "projeto Rojo", Boolean(root), "rode dentro do projeto ou use rbxkit init");
	if (root) {
		check(".claude/skills", fs.existsSync(path.join(root, ".claude", "skills")), "rbxkit install");
		check(".agents/skills (Codex)", fs.existsSync(path.join(root, ".agents", "skills")), "rbxkit install");
		check("AGENTS.md", fs.existsSync(path.join(root, "AGENTS.md")), "rbxkit install");
	}
	console.log(color.dim("\nMCP do Studio: node tools/rbxkit.mjs mcp"));
	return 0;
}

// ---------------------------------------------------------------------------

const HELP = `rbxkit — Roblox Vibe Coding Toolkit

Uso:
  rbxkit init <pasta> [--name Nome]       cria um jogo novo (Rojo + módulos + skills + AGENTS.md)
  rbxkit install [pasta] [--force]        instala skills, AGENTS.md e CLAUDE.md num projeto existente
  rbxkit new service <Nome>               src/server/Services/<Nome>Service.luau
  rbxkit new controller <Nome>            src/client/Controllers/<Nome>Controller.luau
  rbxkit new module <Pasta/Nome>          src/shared/<Pasta>/<Nome>.luau
  rbxkit check [caminhos] [--json] [--strict] [--quiet]
                                          lint de Roblox (erro -> exit 1; --strict inclui avisos)
  rbxkit docs "<pergunta>" [--limit N]   busca na documentação oficial (create.roblox.com)
  rbxkit docs --api Classe[:membro]       referência de API (ex.: TweenService:Create, task.wait)
  rbxkit docs --deprecated <Nome>         APIs depreciadas e seus substitutos
  rbxkit mcp [--client claude|codex] [--os windows|mac] [--write]
                                          como conectar o MCP do Roblox Studio (--write cria .mcp.json)
  rbxkit doctor                           confere ferramentas instaladas
`;

export async function main(argv) {
	const [command, ...rest] = argv;
	const args = parseArgs(rest);
	const commands = { init: cmdInit, install: cmdInstall, new: cmdNew, check: cmdCheck, docs: cmdDocs, mcp: cmdMcp, doctor: cmdDoctor };
	if (!command || command === "help" || command === "--help" || command === "-h") {
		console.log(HELP);
		return 0;
	}
	const handler = commands[command];
	if (!handler) {
		console.error(`comando desconhecido: ${command}\n\n${HELP}`);
		return 2;
	}
	try {
		return await handler(args);
	} catch (err) {
		if (err instanceof UsageError) {
			console.error(color.red(`erro: ${err.message}`));
			return 2;
		}
		throw err;
	}
}

if (process.argv[1] && pathToFileURL(fs.realpathSync(process.argv[1])).href === pathToFileURL(SELF).href) {
	process.exitCode = await main(process.argv.slice(2));
}
