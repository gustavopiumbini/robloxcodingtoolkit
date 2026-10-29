---
name: roblox-debug
description: Debug Roblox errors - Output messages, stack traces, "attempt to index nil", "Infinite yield possible", require errors, scripts that don't run, replication issues. Use when the user pastes an error, says something "doesn't work", or a play test shows errors.
---

# Debugging

## First: where does the script run?

- `Script` runs in `Workspace`/`ServerScriptService` (server containers), not in `ReplicatedStorage`/`StarterPlayerScripts`.
- `LocalScript` runs in `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, `StarterPack`/Backpack, or the character — not in Workspace or ServerScriptService.
- `RunContext = Client` scripts run on the client anywhere.
- ModuleScripts only run when required.
- Check `Disabled`/`Enabled` and that the script is a Script vs LocalScript as intended (`inspect_instance`).

## Common errors

| Message | Usual cause | Fix |
|---|---|---|
| `attempt to index nil with 'X'` | Object not there yet (replication/streaming), nil `FindFirstChild`, nil character | `WaitForChild(name, timeout)`, nil checks, `CharacterAdded` |
| `Infinite yield possible on ...WaitForChild("Y")` | Wrong name, created on the other side only, streaming | Check hierarchy (`search_game_tree`), timeout |
| `X is not a valid member of Y` | Typo/case, accessed too early | `FindFirstChild`, exact case |
| `Requested module experienced an error while loading` | Error at the top of the required module | Read the previous error |
| `Module code did not return exactly one value` | Missing `return Module` | Add it |
| Cyclic require (hang/nil) | A requires B requires A | Extract shared dependency |
| `DataStore request was added to queue` | Too many requests | Lower frequency, check budget |
| HTTP 403 on DataStore in Studio | API access off | Game Settings → Security → Enable Studio Access to API Services |
| `Script timeout: exhausted allowed execution time` | Loop without yield | `task.wait()` |
| Remote "doesn't fire" | Created on different sides, wrong name, handler connected late | Create on server, `Net.Names`, connect in `Init` |
| Client change "disappears" | Client changes don't replicate | Do it on the server via a remote |

## Method

1. Get the exact message and line (`ServerScriptService.Server.Services.ShopService:42`) from `get_console_output`; read that script around the line with `script_read`.
2. Read the code and full stack trace.
3. Form a hypothesis and confirm with evidence: temporary `warn` with context, or `execute_luau` to inspect live state.
4. Fix the cause, not the symptom (don't wrap everything in `pcall`).
5. Remove temporary logs; run the Studio lint: `return require(game.ServerStorage.DevTools.Lint).summary(require(game.ServerStorage.DevTools.Lint).run())` (via `execute_luau`).
