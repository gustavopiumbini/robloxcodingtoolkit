# Agent instructions (Codex, Claude Code, others)

Roblox game in **Luau**, synced to Roblox Studio with **Rojo**. Reply in the user's language; they may not be a programmer, so explain results plainly and say what to do in Studio.

## Map

- `src/server/` → `ServerScriptService.Server`: server only. `Services/*.luau` loaded by `init.server.luau` (Init, then Start).
- `src/client/` → `StarterPlayerScripts.Client`: `Controllers/*.luau` loaded by `init.client.luau`.
- `src/shared/` → `ReplicatedStorage.Shared`: `Net` (remotes), `Util/Guard`, `Util/RateLimiter`, `Util/Signal`, `Util/Trove`, `Config/`.
- `src/dev/` → `ServerStorage.DevTools`: `Build` and `Shots` for building geometry in Studio (never runs live).
- `src/server/Config/DataTemplate.luau`: saved player data shape (`DataService`).

## Non-negotiables

1. **Server is authoritative** for currency, damage, inventory, purchases, progress. Clients send minimal intents.
2. **Every remote validated** via `Net.onServerEvent`/`Net.onServerInvoke` + `Guard` (types, ranges, ownership, distance, cooldown); names in `Net.Names`; never `InvokeClient`.
3. **Player data only via `DataService:Update`**; new fields go in `DataTemplate` (value + type).
4. `--!strict`, `task.*`, `GetService`, `Parent` last, `:Connect`, no deprecated APIs.
5. With Rojo, **edit files in `src/`**, not synced scripts in Studio.
6. Don't add dependencies, delete files, or rename/remove saved-data fields unless asked.
7. If a skill disagrees with the template's patterns, follow the template already in use. If the official docs disagree with a skill, the docs win.

## Token economy (keep quality, spend less)

- Load only the 1-3 skills the task needs; open a skill's `references/` file only when it covers your exact case.
- Unsure about an API: `node tools/rbxkit.mjs docs --api Class:Member` (returns just that member) — never read whole class pages or guess.
- Search narrowly (`rg`, `script_grep`) instead of reading whole files; read only the lines you need.
- `execute_luau` returns short summaries; screenshots only for visual judgment, max 2-3 per iteration.
- Don't re-read files you just wrote; don't paste large code back to the user — reference `file:line`.

## Commands

```
node tools/rbxkit.mjs check                     # Roblox lint — run before finishing
node tools/rbxkit.mjs new service|controller|module <Name>
node tools/rbxkit.mjs docs --api Class:Member   # official API reference, member only
node tools/rbxkit.mjs docs "question in English"
node tools/rbxkit.mjs mcp                       # connect Roblox Studio MCP
rokit install && rojo serve                     # toolchain + live sync
selene src && stylua --check src                # lint/format (if installed)
```

## Done means

`rbxkit check` clean; with Studio MCP, a play test with no Output errors (and the `roblox-3d-building` review loop for anything visual); a short report: files changed, Studio steps, how to test.
