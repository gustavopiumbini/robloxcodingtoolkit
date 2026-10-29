# One-prompt setup: new Roblox game

You are an AI coding agent (Claude Code, Codex, or similar). The user wants a Roblox game built from the description that came with this file. Do the whole job: environment, project, Studio connection, the game itself, and verification. Work autonomously; stop to ask only where this file says **ASK**. Reply in the user's language and explain things plainly (they may not be a programmer).

Keep a short checklist of the 6 steps below and report progress in one line per step. Every step is idempotent: if the user restarts and says "continue Roblox setup", re-read this file, detect what is already done, and resume.

## 1. Inspect the environment (read-only)

Detect and note: OS (Windows/macOS; Studio doesn't run on Linux — on Linux, build everything but tell the user Studio steps need Windows/macOS), `node --version` (need 18+), `git`, `rokit`, `rojo`, and whether Roblox Studio is installed (Windows: `%LOCALAPPDATA%\Roblox\Versions`; macOS: `/Applications/RobloxStudio.app`). Check whether Roblox Studio MCP tools are available to you (names containing `Roblox_Studio`, e.g. `list_roblox_studios`).

**ASK once**, listing only what's missing, before installing anything: Node.js (https://nodejs.org), Rokit, Roblox Studio (https://create.roblox.com — the user must install and sign in themselves).

## 2. Create the project

- Pick a short PascalCase game name from the description.
- If the current folder is empty (or only has `.git`, `README.md`, `LICENSE`, `.gitignore`): `npx --yes github:gustavopiumbini/robloxcodingtoolkit init . --force --name <Name>`.
- Otherwise: `npx --yes github:gustavopiumbini/robloxcodingtoolkit init <Name>` and work inside `<Name>/` from now on.
- If `npx` can't reach GitHub, clone https://github.com/gustavopiumbini/robloxcodingtoolkit and run `node <clone>/tools/rbxkit.mjs init ...` instead.
- Read the generated `AGENTS.md` and follow it for the rest of the job. Skills are in `.claude/skills/` and `.agents/skills/`; if your client only loads skills at startup, read the relevant `SKILL.md` files directly.

## 3. Toolchain

- Rokit missing (after the user agreed): macOS/Linux `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`; Windows PowerShell `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression`. Open a new shell (PATH changes) or call it by full path (`~/.rokit/bin`).
- In the project: `rokit install --no-trust-check` (rojo, selene, stylua, luau-lsp pinned in `rokit.toml`).
- `rojo plugin install` (installs the Rojo plugin into Studio).
- `node tools/rbxkit.mjs doctor` to confirm.

## 4. Connect Roblox Studio

- Start live sync: `rojo serve` as a **background** process (keep it running). If you can't run background processes, tell the user to run `rojo serve` in a separate terminal in the project folder.
- Tell the user: open Roblox Studio → new Baseplate → Plugins tab → **Rojo** → **Connect**. Also: Game Settings → Security → **Enable Studio Access to API Services** (needed for saving data; requires the place to be published once — otherwise data stays in memory, which is fine for testing).
- Studio MCP not available to you yet → tell the user: Studio → Assistant → ⋯ → Manage MCP Servers → **Enable Studio as MCP server** → Quick connect → turn on your client (Claude Code or Codex CLI) → restart this agent in the project folder and say "continue Roblox setup". Show `node tools/rbxkit.mjs mcp` output if they prefer manual setup. While waiting, continue with step 5 (code doesn't need Studio).

## 5. Build the game

Follow the `roblox-feature` skill end to end:
1. Turn the description into a short design (core loop, systems, data, UI, world, monetization). Fill gaps with the most common choices in popular Roblox games and state them in a few lines — don't ask unless a choice changes everything.
2. Plan by system: server Services, `Net.Names` remotes with `Guard`, saved data in `DataTemplate`, client Controllers/UI, map/geometry.
3. Implement system by system with `node tools/rbxkit.mjs new ...` skeletons and the template modules. Remove or adapt the example Shop/Coin/HUD code if it doesn't fit the game.
4. World and props: follow `roblox-3d-building` (DevTools `Build` + `Shots` review loop) once Studio MCP is connected; otherwise write a build script the user can run later and say so.
5. Monetization only if the description asks for it (`roblox-monetization`); use placeholder ids marked `-- TODO`.

## 6. Verify and hand over

- `node tools/rbxkit.mjs check` → no errors. `selene src`, `stylua --check src`, `rojo build -o build.rbxl` → clean.
- With Studio MCP: play test (`roblox-studio-mcp` verify loop), zero errors in Output, screenshots of the main areas; fix and repeat.
- Final message: what was built (systems + map), how to play it in Studio, what the user must still do (publish, asset/pass ids, API access), what you could not verify, and 3 suggested next prompts.
