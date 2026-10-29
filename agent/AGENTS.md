# Agent instructions (Codex, Claude Code, others)

Roblox game built **directly in Roblox Studio through the Studio MCP** (tools named like `list_roblox_studios`, `execute_luau`, `script_read`, `multi_edit`, `start_stop_play`). Reply in the user's language; they may not be a programmer, so explain results plainly.

## Setup (once per place)

Check with `execute_luau` whether `ServerStorage.DevTools` exists. If not, run the installers in `install/` in order with `execute_luau` (pass each file's content as the code): `1-shared`, `2-server`, `3-client` (game framework), `4-build-tools` before building 3D, `5-lint` before verifying. They're idempotent and never overwrite existing scripts. Tell the user to save the place (Ctrl+S).

## Map (in Studio)

- `ServerScriptService.Server` (Script): bootstrap that requires every ModuleScript in `Server.Services`, calls `Init()` then `Start()`. `Server.Config.DataTemplate` = saved data shape; `Server.Services.DataService` = player data.
- `StarterPlayer.StarterPlayerScripts.Client` (LocalScript): same for `Client.Controllers`.
- `ReplicatedStorage.Shared`: `Net` (remotes), `Util.Guard`, `Util.RateLimiter`, `Util.Signal`, `Util.Trove`, `Config`.
- `ServerStorage.DevTools`: `Build`, `Shots` (3D building), `Lint` (code checks). Never runs in live servers.

## Editing scripts

- New script: `execute_luau` creating the instance with `Name`, `Source` and `Parent` (Parent last), e.g. a ModuleScript in `Server.Services`.
- Existing script: `script_grep`/`script_read` the lines you need, then `multi_edit` small replacements — don't rewrite whole scripts.
- Read before you edit; never edit a script you haven't read in this session.

## Non-negotiables

1. **Server is authoritative** for currency, damage, inventory, purchases, progress. Clients send minimal intents.
2. **Every remote validated** via `Net.onServerEvent`/`Net.onServerInvoke` + `Guard` (types, ranges, ownership, distance, cooldown); names in `Net.Names`; never `InvokeClient`.
3. **Player data only via `DataService:Update`**; new fields go in `DataTemplate` (value + type).
4. `--!strict`, `task.*`, `GetService`, `Parent` last, `:Connect`, no deprecated APIs.
5. Don't delete scripts/instances or rename/remove saved-data fields unless asked. Big changes: ask the user to save or publish a version first.
6. If a skill disagrees with patterns already in the place, follow the place. If the official docs disagree with a skill, the docs win.

## Token economy (keep quality, spend less)

- Load only the 1-3 skills the task needs; open a skill's `references/` only for your exact case.
- Unsure about an API: `node tools/rbxkit.mjs docs --api Class:Member` (just that member) — never guess.
- Narrow reads (`script_grep`, `search_game_tree` with filters) instead of whole trees/scripts.
- `execute_luau` returns short summaries; screenshots only for visual judgment, max 2-3 per iteration.
- Don't paste large code back to the user.

## Done means

`return require(game.ServerStorage.DevTools.Lint).summary(require(game.ServerStorage.DevTools.Lint).run())` shows 0 errors; a play test (`start_stop_play` + `get_console_output`) with no errors; the `roblox-3d-building` review loop for anything visual; a short report (what changed, how to test, what to do in Studio) and a reminder to save/publish.
