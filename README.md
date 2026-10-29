<p align="center">
  <img src="docs/assets/banner.svg" alt="Roblox Vibe Coding Toolkit" width="100%">
</p>

<h1 align="center">Roblox Vibe Coding Toolkit</h1>

<p align="center">
  <b>Describe your game. Your AI agent builds it directly in Roblox Studio — securely, cleanly, and good-looking.</b>
</p>

<p align="center">
  <a href="#-one-prompt-setup"><b>ONE-PROMPT SETUP →</b></a> ·
  <a href="#-manual-setup">MANUAL SETUP</a> ·
  <a href="#-whats-inside">WHAT'S INSIDE</a> ·
  <a href="#-3d-building-that-looks-good">3D BUILDING</a> ·
  <a href="#-the-rbxkit-cli">RBXKIT CLI</a>
</p>

<p align="center">
  <a href="https://github.com/gustavopiumbini/robloxcodingtoolkit/actions/workflows/ci.yml"><img src="https://github.com/gustavopiumbini/robloxcodingtoolkit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-E8B86D" alt="MIT"></a>
  <img src="https://img.shields.io/badge/skills-25-E8B86D" alt="25 skills">
  <img src="https://img.shields.io/badge/Luau-strict-2B2D31" alt="Luau strict">
</p>

<p align="center">
  <b>Claude Code</b> + <b>Codex CLI</b> / portable <code>SKILL.md</code> skills / Roblox Studio MCP / no extra toolchain
</p>

---

## 00 / Choose where to start

| Your situation | Path | What you get |
|---|---|---|
| **I have a game idea** | [One prompt](#-one-prompt-setup) · [manual](#-manual-setup) | Secure networking and data modules, 3D build tools, 25 skills, agent rules — installed into your place |
| **I already have a game** | [One prompt](#existing-game-one-prompt) | Skills + agent rules, DevTools in `ServerStorage`, a baseline audit — nothing overwritten |
| **I just want to connect Studio** | [Connect Studio](#-connect-roblox-studio) | Your agent can edit scripts, build, play test, read Output and take screenshots |

<p align="center">
  <img src="docs/assets/workflow.svg" alt="Describe it. Build it. Verify it." width="100%">
</p>

You describe the goal in plain language — *"add a shop with a sword and a shield"*, *"build a medieval tavern"*, *"make an obby with 10 checkpoints"*. The agent loads only the skills it needs, plans the client/server split, writes strict Luau on top of battle-tested modules, builds geometry in Studio, then **proves it works**: lint, play test, screenshots.

**Studio-first:** your game lives in Roblox Studio. No Rojo, no file sync, no extra tools to install — just Studio, your agent, and Node.js for the setup command.

---

## 🚀 One-prompt setup

Open **Claude Code** or **Codex** in an empty folder and paste two lines. Replace the second line with your game:

```text
Read https://raw.githubusercontent.com/gustavopiumbini/robloxcodingtoolkit/main/docs/prompts/new-game.md and follow it.
Game: [name, genre, core loop, look & feel, monetization, target devices]
```

Example:

```text
Read https://raw.githubusercontent.com/gustavopiumbini/robloxcodingtoolkit/main/docs/prompts/new-game.md and follow it.
Game: "Candy Tycoon" — players own a candy factory, buy droppers and conveyors with coins, upgrade
machines, and rebirth for multipliers. Bright cartoon candy style, mobile-first, VIP game pass with 2x coins.
```

The agent then does everything in one go:

| Step | What the agent does |
|---|---|
| **1 / Inspect** | Checks Node, Roblox Studio and the Studio MCP — asks you **once** for anything missing |
| **2 / Agent folder** | `rbxkit init`: skills, `AGENTS.md`, Studio installers |
| **3 / Studio** | Tells you the 3 clicks to connect the Studio MCP, then picks your open place |
| **4 / Install** | Runs the installers in Studio: game framework + DevTools (idempotent, never overwrites) |
| **5 / Game** | Designs the core loop, then builds services, remotes, saved data, UI, map and props |
| **6 / Verify** | Lint in Studio, play test with zero Output errors, screenshots — then a hand-over with next prompts |

If the agent has to restart (for example right after you connect the Studio MCP), just say **"continue Roblox setup"**: every step detects what's already done.

<a id="existing-game-one-prompt"></a>
**Existing game?** Open the agent in any folder (it only stores skills and notes there) with your place open in Studio:

```text
Read https://raw.githubusercontent.com/gustavopiumbini/robloxcodingtoolkit/main/docs/prompts/existing-project.md and follow it.
Task: [optional — e.g. "audit everything before I publish" or "add a daily reward"]
```

It maps your game, installs only the DevTools (plus the framework if you agree), runs a baseline audit and then does the task.

> [!TIP]
> If your agent can't open URLs (some Codex sandboxes block network), run `curl -sL <url>` yourself and paste the file, or clone this repo and point the agent at `docs/prompts/`.

---

## 🧭 Manual setup

**Requirements:** [Roblox Studio](https://create.roblox.com/) (Windows or macOS) · [Node.js 18+](https://nodejs.org/) · [Claude Code](https://claude.com/claude-code) and/or [Codex CLI](https://developers.openai.com/codex)

```bash
mkdir MyGame && cd MyGame
npx github:gustavopiumbini/robloxcodingtoolkit init     # skills, AGENTS.md, CLAUDE.md, install/*.luau
```

1. Open Roblox Studio and your place (or a new Baseplate).
2. [Connect the Studio MCP](#-connect-roblox-studio).
3. Start your agent in `MyGame/` (`claude` or `codex`) and ask:

> *Install the toolkit into my open place, then add a pet system: pets follow the player and boost coins.*
>
> *Build a cozy medieval tavern next to spawn, with an interior, and review it with screenshots.*
>
> *Add a VIP Game Pass that doubles coins.*
>
> */roblox-review — audit the game before I publish.*
>
> *My game throws `attempt to index nil with 'Humanoid'`.*

In Claude Code every skill is also a slash command (`/roblox-feature`, `/roblox-3d-building`, …). In Codex, mention the skill by name or use `$roblox-feature`. No Node? Copy `skills/*` to `.claude/skills/` and/or `.agents/skills/`, and `agent/*.md` to the folder.

---

## 🔌 Connect Roblox Studio

Studio ships a built-in MCP server. In Studio: **Assistant → ⋯ → Manage MCP Servers → Enable Studio as MCP server**, then under **Quick connect** turn on **Claude Code** and/or **Codex CLI** and restart the agent.

Manual setup (or run `node tools/rbxkit.mjs mcp`):

```bash
# Windows
claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
codex  mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat

# macOS
claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
codex  mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

> [!IMPORTANT]
> The agent edits your place directly. Connect trusted clients only, and **save or publish a version before big changes** — File → Version History can restore any published version.

To persist player data while testing, publish the place once and enable **Game Settings → Security → Enable Studio Access to API Services** (otherwise `DataService` keeps data in memory).

---

## 📦 What's inside

<p align="center">
  <img src="docs/assets/architecture.svg" alt="Your agent works in Roblox Studio through the Studio MCP" width="100%">
</p>

| Delivery area | Contents |
|---|---|
| **Skills** (`skills/`) | 25 portable `SKILL.md` skills — loaded on demand, so they cost nothing until needed |
| **Agent rules** (`agent/`) | Lean `AGENTS.md` (Codex & others) and `CLAUDE.md` (Claude Code): how to work in Studio, non-negotiables, token-economy rules |
| **Studio modules** (`studio/`) | The code installed into your place: server/client bootstraps (`Init` → `Start`), session-locked `DataService`, `Net` + `Guard` + `RateLimiter` secure remotes, `Signal`, `Trove`, and DevTools (`Build`, `Shots`, `Lint`) |
| **Installers** (`rbxkit init` → `install/`) | 5 idempotent Luau scripts the agent runs with `execute_luau`; comments stripped to save tokens; existing scripts are never overwritten |
| **CLI** (`tools/rbxkit.mjs`) | Zero-dependency: `init`, official docs lookup (`docs`), `mcp`, `doctor` |
| **Verification** (`.github/workflows/ci.yml`) | Strict `luau-lsp` type check against the Roblox API, Selene, Lune unit tests, installers executed in a simulated DataModel, CLI and token-budget tests |

### What gets installed in your place

```text
ServerScriptService
  Server (Script)              bootstrap: requires Services, Init() then Start()
    Config.DataTemplate        saved data shape
    Services.DataService       UpdateAsync + session lock + retries + autosave
ReplicatedStorage
  Shared
    Net                        named remotes with validation + rate limits
    Util.Guard · Util.RateLimiter · Util.Signal · Util.Trove
StarterPlayer.StarterPlayerScripts
  Client (LocalScript)         bootstrap for Controllers
ServerStorage
  DevTools                     Build · Shots · Lint  (Studio-only, never runs live)
```

### Skills

<table>
<tr><th>Workflow</th><th>Code & systems</th><th>World & feel</th><th>Platform</th></tr>
<tr valign="top">
<td>

`roblox-feature`<br>
`roblox-review`<br>
`roblox-debug`<br>
`roblox-docs`<br>
`roblox-studio-mcp`<br>
`roblox-testing`

</td>
<td>

`roblox-luau`<br>
`roblox-architecture`<br>
`roblox-networking`<br>
`roblox-datastore`<br>
`roblox-gameplay`<br>
`roblox-performance`<br>
`roblox-physics`<br>
`roblox-npc-ai`

</td>
<td>

`roblox-3d-building`<br>
`roblox-world-building`<br>
`roblox-ui`<br>
`roblox-input`<br>
`roblox-characters-animation`<br>
`roblox-audio`

</td>
<td>

`roblox-monetization`<br>
`roblox-text-chat`<br>
`roblox-teleport-matchmaking`<br>
`roblox-open-cloud`<br>
`roblox-creator-store-security-audit`

</td>
</tr>
</table>

Ten skills come from [EL4CTEO/roblox-skills](https://github.com/EL4CTEO/roblox-skills) and one from [AshExplained/roblox-skills](https://github.com/AshExplained/roblox-skills) (MIT) — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Also worth a look: Roblox's official [roblox-studio-agent-plugin](https://github.com/Roblox/roblox-studio-agent-plugin).

---

## 🧱 3D building that looks good

<p align="center">
  <img src="docs/assets/build-loop.svg" alt="Plan. Block out. Detail. Review." width="100%">
</p>

Agent-made builds usually look like "blocks placed by a bot": wrong scale, flat walls, random colors, flickering faces. The `roblox-3d-building` skill fixes that with a craft process and hard checks:

- **Correct scale** — avatar-relative reference (doors 4×7.5, ceilings 12–14, steps rise 1 / run 1.5, jump distances).
- **The right technique per shape** — parts for architecture, `generate_mesh`/vetted assets for organic shapes, MaterialVariants for custom surfaces, Terrain for landscapes.
- **Craft rules** — silhouette first, break flat surfaces (trims, insets, overhangs), one cohesive palette, 2–4 materials, deliberate lighting.
- **Automatic audit** — `Build.audit` finds z-fighting, tiny parts, unanchored parts and palette noise as cheap text, *before* spending tokens on screenshots.
- **Visual review loop** — `Shots.frame(model, "iso" | "front" | "close")` + `screen_capture`, scored on a 7-point rubric until every item is ≥ 4/5 (max 3 iterations).

```lua
local B = require(game:GetService("ServerStorage").DevTools.Build)
B.undoable("Cottage", function()                     -- one Ctrl+Z undoes the whole build
	local m = B.model("Cottage", workspace)          -- re-runnable: replaces the previous version
	B.wall(m, { from = Vector3.new(-12, 1, -9), to = Vector3.new(12, 1, -9), height = 12,
		color = B.palettes.cottage.wall, material = Enum.Material.Plaster, trim = B.palettes.cottage.trim,
		openings = { { offset = 12, width = 4, height = 7.5 }, { offset = 5, width = 4, height = 4, bottom = 3 } } })
	B.finalize(m)
end)
return B.summary(B.audit(workspace.Cottage))         -- "parts=13 meshParts=0 unanchored=0 ..."
```

---

## 🔎 Lint inside Studio

`DevTools.Lint` checks every script in the place for the mistakes agents (and humans) make most — the agent runs it before calling anything done:

```lua
local Lint = require(game:GetService("ServerStorage").DevTools.Lint)
return Lint.summary(Lint.run())   -- "14 scripts: 0 error(s), 1 warning(s), 0 info" + one line per finding
```

| Severity | Catches |
|---|---|
| **error** | `wait`/`spawn`/`delay`, `:connect`, `loadstring`, `require(assetId)` backdoors, `InvokeClient`, `LocalPlayer` on the server, server-only services on the client, `RenderStepped` on the server, yield-less `while true` |
| **warning** | Remote handlers without validation, `Instance.new(class, parent)`, `FireServer(player, …)`, `SetPrimaryPartCFrame`, `Humanoid:LoadAnimation`, BodyMovers, `FindPartOnRay`, `getfenv`/`setfenv`, DataStore calls without `pcall` |
| **info** | `SetAsync` (prefer `UpdateAsync`), `game.Players` without `GetService`, global `unpack`, missing `--!strict` |

Silence a line with `-- rbxkit-ignore: rule`, or the next one with `-- rbxkit-ignore-next-line`.

---

## 🪙 Built to save tokens (without losing quality)

| Technique | Effect |
|---|---|
| Skills load on demand; only names + one-line descriptions are always in context | ~2k tokens per session for 25 skills + rules |
| Lean `AGENTS.md` + English everywhere | Small always-loaded context |
| Progressive disclosure: deep recipes live in `references/` | Large tables load only for the exact case |
| `rbxkit docs --api Class:Member` returns just one member from the official docs | A few hundred tokens instead of multi-thousand-token class pages — and no hallucinated APIs |
| Edits with `multi_edit` and narrow `script_grep`/`script_read` | No rewriting or re-reading whole scripts |
| DevTools `Build`/`Shots`/`Lint` | One `B.wall{}` call instead of dozens of `Instance.new` lines; text audits before screenshots |
| Installers with comments stripped; DevTools only when needed | One-time setup cost per place |
| A token-budget test in CI | Prevents skills and rules from silently growing |

---

## 🛠 The `rbxkit` CLI

`npx github:gustavopiumbini/robloxcodingtoolkit <command>` — or `node tools/rbxkit.mjs <command>` inside an agent folder:

```text
init [dir] [--force]                set up an agent folder: skills, AGENTS.md, CLAUDE.md, install/*.luau
docs "<question in English>"        search the official Roblox docs
docs --api Class[:member]           API reference (TweenService:Create, task.wait, CFrame.new)
docs --deprecated <Name>            deprecated? what replaces it?
mcp [--client claude|codex] [--os windows|mac] [--write]
doctor                              check Node, Claude Code/Codex, Studio and the agent folder
```

---

## 🧪 Developing the toolkit

```bash
npm test                                         # CLI, installers, skills, token budget (node:test)
lune run tests/luau/utils.spec.luau              # Guard, RateLimiter, Signal, Trove
lune run tests/luau/build.spec.luau              # Build geometry + audit
lune run tests/luau/lint.spec.luau               # Lint rules + lint of every studio/ script
node tools/rbxkit.mjs init /tmp/agent && lune run tests/luau/install.spec.luau /tmp/agent/install
```

`studio/` mirrors the DataModel (`studio/ServerScriptService/Server/init.server.luau` → `ServerScriptService.Server`). CI also type-checks it with `luau-lsp` in strict mode against the Roblox API (sourcemap generated by `tests/sourcemap.mjs`) and runs Selene.

## License

[MIT](LICENSE). Third-party skills keep their own MIT licenses — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
