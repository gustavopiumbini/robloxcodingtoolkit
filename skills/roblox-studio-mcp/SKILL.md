---
name: roblox-studio-mcp
description: Use the Roblox Studio MCP server (Roblox_Studio) to inspect the open place, read scripts, run Luau, play test, read Output, simulate input and take screenshots. Use whenever Studio MCP tools are available, to verify changes in Studio, or when asked to test or debug in the game.
---

# Roblox Studio via MCP

Tools (may be prefixed `mcp__Roblox_Studio__`):

| Group | Tools |
|---|---|
| Session | `list_roblox_studios` (every call needs `studio_id`), `get_studio_state` |
| Explore | `search_game_tree`, `inspect_instance`, `subagent` |
| Scripts | `script_read`, `script_search`, `script_grep`, `multi_edit` |
| Run | `execute_luau` |
| Play test | `start_stop_play`, `get_console_output`, `screen_capture` |
| Input | `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Assets | `search_asset`, `insert_asset`, `generate_mesh`, `generate_material`, `generate_procedural_model`, `wait_job_finished`, `upload_image`, `store_image` |
| Docs | `http_get` (Roblox docs), `skill` (Roblox's built-in `rbx-*` skills) |

No tools? Tell the user to enable them (`node tools/rbxkit.mjs mcp`).

## Rojo vs direct edits

- Rojo project (`default.project.json`, `rojo serve` running): **edit files in `src/`**; Rojo syncs. Don't `multi_edit` synced scripts (they get overwritten / diverge from git).
- Use MCP to read game state (maps, non-Rojo instances), run inspection code, play test, read logs, build geometry.
- No Rojo: edit scripts directly with `script_read` + `multi_edit` (always read first).

## Verify loop (after implementing)

1. `list_roblox_studios` → pick `studio_id` (ask if several).
2. `get_studio_state` (edit or play?).
3. Rojo: confirm sync with `script_grep` for a new line.
4. `start_stop_play` → wait a few seconds → `get_console_output`: errors, warnings, "Infinite yield possible".
5. Exercise the feature: `execute_luau` (e.g. read `Players:GetPlayers()[1]:GetAttribute("Coins")`), `character_navigation`/`user_keyboard_input`, `screen_capture` for UI.
6. Stop, fix, repeat until clean. Report what was and wasn't verified.

## Token-aware habits

- `execute_luau` should `return` a short summary (counts, names, a few values), never dumps.
- Prefer `script_grep`/`search_game_tree` with narrow queries over reading whole scripts or trees.
- Screenshots cost ~1k+ tokens each: take them only to judge visuals/UI, max 2-3 per iteration.
- In edit mode `execute_luau` changes persist like the Command Bar: inspect read-only unless asked to change; play-mode changes are discarded.

## Building and assets

Geometry: follow `roblox-3d-building` (DevTools `Build` + `Shots` review loop). Third-party assets via `insert_asset` only with user approval, then audit (`roblox-creator-store-security-audit`). Remind the user to save the place (Ctrl+S).

## Setup (for the user)

Studio: Assistant → ⋯ → Manage MCP Servers → **Enable Studio as MCP server** → Quick connect: Claude Code / Codex CLI → restart the client. Manual commands: `node tools/rbxkit.mjs mcp`. MCP can read and modify the open place: connect trusted clients only.
