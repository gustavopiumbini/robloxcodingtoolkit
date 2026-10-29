# One-prompt setup: existing Roblox game

You are an AI coding agent (Claude Code, Codex, or similar). The user has a Roblox game in Studio. Add the Roblox Vibe Coding Toolkit without breaking anything, then do the task that came with this file (if any). You work **directly in Studio through the Studio MCP**. Stop to ask only where this file says **ASK**. Reply in the user's language.

## 1. Agent folder

Run `npx --yes github:gustavopiumbini/robloxcodingtoolkit init .` in the current folder (keeps an existing `AGENTS.md`/`CLAUDE.md`; then append a short "Roblox toolkit" section to them pointing to the skills and `install/`). Read `AGENTS.md`.

## 2. Connect Studio

Studio MCP tools missing → give the user the steps from https://raw.githubusercontent.com/gustavopiumbini/robloxcodingtoolkit/main/docs/prompts/new-game.md (step 3) and stop until they say "continue Roblox setup". Connected → `list_roblox_studios` (**ASK** if several) and `get_studio_state` (edit mode).

## 3. Inspect the game (read-only, narrow reads)

- `search_game_tree` for scripts in ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui, Workspace; note frameworks (Knit, ProfileStore, Fusion…), existing remotes and data handling.
- Write a short "Map" of the real layout into `AGENTS.md`, replacing the template map. If the game uses other patterns (Knit, ProfileStore…), state that the game's patterns win.

## 4. Install the toolkit modules (non-destructive)

**ASK** the user to save/publish a version first. Then run `install/5-lint.luau` and `install/4-build-tools.luau` (DevTools only — they live in `ServerStorage` and never run live). Install `1-shared` (Net, Guard, RateLimiter, Signal, Trove) only if it doesn't clash with names in `ReplicatedStorage`, and `2-server`/`3-client` bootstraps only if the game has no framework of its own — **ASK** first. Installers never overwrite existing scripts.

## 5. Baseline audit

`local L = require(game.ServerStorage.DevTools.Lint) return L.summary(L.run(), 60)` → summarize by severity (don't fix yet). Also check for backdoors in models (`roblox-creator-store-security-audit`).

## 6. Task and hand-over

If the user gave a task, do it with `roblox-feature` (or `roblox-review` for audits, `roblox-debug` for errors). Final message: what was installed/changed, the audit summary with the top 3 fixes, what you verified, a reminder to save/publish, and 3 suggested next prompts.
