# One-prompt setup: new Roblox game

You are an AI coding agent (Claude Code, Codex, or similar). The user wants a Roblox game built from the description that came with this file. You build it **directly in Roblox Studio through the Studio MCP**. Work autonomously; stop to ask only where this file says **ASK**. Reply in the user's language and explain things plainly (they may not be a programmer).

Keep a short checklist of the 6 steps and report progress in one line per step. Every step is idempotent: if the user restarts you and says "continue Roblox setup", re-read this file, detect what is done, and resume.

## 1. Inspect (read-only)

Detect: OS (Studio runs on Windows/macOS only), `node --version` (18+), whether Roblox Studio is installed (Windows: `%LOCALAPPDATA%\Roblox\Versions`; macOS: `/Applications/RobloxStudio.app`), and whether Studio MCP tools are available to you (names containing `Roblox_Studio`, e.g. `list_roblox_studios`).

**ASK once**, listing only what's missing: Node.js (https://nodejs.org) and Roblox Studio (https://create.roblox.com — the user installs it and signs in).

## 2. Agent folder

In the current folder run `npx --yes github:gustavopiumbini/robloxcodingtoolkit init .` (non-destructive: adds skills, `AGENTS.md`, `CLAUDE.md`, `tools/rbxkit.mjs` and the Studio installers in `install/`). If `npx` can't reach GitHub, clone https://github.com/gustavopiumbini/robloxcodingtoolkit and run `node <clone>/tools/rbxkit.mjs init .`.

Read `AGENTS.md` and follow it from now on. If your client loads skills only at startup, read the needed `SKILL.md` files from `.claude/skills/` or `.agents/skills/` directly.

## 3. Connect Roblox Studio

If the Studio MCP tools are not available, tell the user exactly this, then stop until they say "continue Roblox setup":
1. Open Roblox Studio → **New** → **Baseplate** (or open their place).
2. **Assistant** → **⋯** → **Manage MCP Servers** → turn on **Enable Studio as MCP server**.
3. Under **Quick connect**, turn on their client (**Claude Code** or **Codex CLI**).
4. Restart this agent in the same folder and say "continue Roblox setup".
(`node tools/rbxkit.mjs mcp` prints manual setup commands if Quick connect isn't available.)

While waiting you may draft the design (step 5.1) so no time is lost.

When connected: `list_roblox_studios` → if several, **ASK** which one; `get_studio_state` must be in edit mode (stop a running play test first).

## 4. Install the toolkit into the place

`execute_luau` with `return game:GetService("ServerStorage"):FindFirstChild("DevTools") ~= nil`. If false, run every installer in `install/` in order (`1-shared` … `5-lint`), passing each file's full content as the code. Each returns a one-line summary; re-running is safe. Then ask the user to save (Ctrl+S / File → Save to Roblox).

## 5. Build the game

Follow the `roblox-feature` skill end to end:
1. Turn the description into a short design (core loop, systems, saved data, UI, world, monetization). Fill gaps with the most common choices in popular Roblox games and state them in a few lines — don't ask unless a choice changes everything.
2. Plan by system: server Services, `Net.Names` remotes with `Guard`, `DataTemplate` fields, client Controllers/UI, map and props.
3. Implement system by system: create ModuleScripts with `execute_luau`, edit with `multi_edit` (see `AGENTS.md`).
4. World, buildings and props: `roblox-3d-building` (DevTools `Build` + `Shots` review loop with screenshots).
5. Monetization only if requested (`roblox-monetization`), with placeholder ids marked `-- TODO`.

## 6. Verify and hand over

- Lint: `local L = require(game.ServerStorage.DevTools.Lint) return L.summary(L.run())` → 0 errors.
- Play test (`roblox-studio-mcp` verify loop): zero errors in Output, exercise the core loop, screenshots of the main areas; fix and repeat.
- Final message: what was built (systems + map), how to play it, what the user must do (save/publish, asset/pass ids, Game Settings → Security → Enable Studio Access to API Services after publishing so data saves), what you could not verify, and 3 suggested next prompts.
