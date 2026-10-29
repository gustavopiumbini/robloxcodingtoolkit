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

No tools? Tell the user to enable them (`node tools/rbxkit.mjs mcp`): without MCP you can't touch the game.

## Editing the game

- Code lives in the place. Read with `script_grep`/`script_read` (only the lines you need), change with `multi_edit` (small replacements), create new scripts with `execute_luau` (`Instance.new`, set `Name`, `Source`, then `Parent`).
- Toolkit modules missing (`ServerStorage.DevTools` absent)? Run the `install/*.luau` installers with `execute_luau` (see `AGENTS.md`).
- Big or risky changes: ask the user to save/publish a version first (File → Version History can restore it).

## Verify loop (after implementing)

1. `list_roblox_studios` → pick `studio_id` (ask if several).
2. `get_studio_state` (edit or play?).
3. Lint: `local L = require(game.ServerStorage.DevTools.Lint) return L.summary(L.run())` → fix errors first.
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
