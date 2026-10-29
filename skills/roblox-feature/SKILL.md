---
name: roblox-feature
description: End-to-end workflow for a Roblox feature from a plain-language request - understand, plan the client/server split, implement with template modules, lint, verify in Studio, report. Use when the user asks for a new mechanic or system ("make a shop", "add pets", "build an obby", "double jump").
---

# Feature workflow

## 1. Understand (fast)

Look at what exists with narrow reads: `search_game_tree` for `Server.Services`, `Client.Controllers`, `Shared` (run the `install/` installers if the toolkit modules are missing), and `script_grep` for `Net.Names`. Vague request → assume the most common pattern in popular Roblox games and state it in one line. Ask only questions that change the design.

## 2. Plan (3-8 lines to the user)

- **Server**: which Service, saved data (DataTemplate), validations.
- **Remotes**: names in `Net.Names`, args and their `Guard`. Minimal client data.
- **Shared**: what goes in `ReplicatedStorage.Shared.Config`.
- **Client**: Controller, UI, input, effects.
- **Studio**: parts/tags/assets the user must create or provide; geometry via `roblox-3d-building`.

## 3. Implement

- New scripts via `execute_luau` (ModuleScripts in `Server.Services` / `Client.Controllers` with `Init`/`Start`); edits via `multi_edit`.
- Load only the skills the task needs (e.g. `roblox-networking` for remotes, `roblox-datastore` for saved data, `roblox-ui` for screens). Read their `references/` only when the SKILL.md points you there for your exact case.
- Unsure about an API → `node tools/rbxkit.mjs docs --api Class:Member` instead of guessing.
- Balance numbers as constants or in `Config`. Keep files focused; don't rewrite unrelated files.

## 4. Verify (required before "done")

1. Lint in Studio: `local L = require(game.ServerStorage.DevTools.Lint) return L.summary(L.run())` → 0 errors; fix or justify warnings.
2. Play test with the `roblox-studio-mcp` verify loop: zero errors in Output, exercise the feature (`execute_luau`, simulated input), screenshots for UI/visuals.

## 5. Report

Files changed; what to do in Studio (tags, parts, asset/pass ids, API access); how to test; known limits and 1-3 next steps.

## Decomposition examples

- **Pets that follow and boost coins**: `PetService` (owned/equipped in DataTemplate, `EquipPet(petId)` validated against owned pets, multiplier applied in `CoinService:Add`); `Config/Pets`; `PetController` renders followers locally from a replicated `EquippedPet` attribute.
- **Double jump**: client-only (`UserInputService.JumpRequest` + `Humanoid.StateChanged`); the character replicates.
- **Robux shop**: `roblox-monetization` + `roblox-ui`.
