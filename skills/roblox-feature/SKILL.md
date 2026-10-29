---
name: roblox-feature
description: End-to-end workflow for a Roblox feature from a plain-language request - understand, plan the client/server split, implement with template modules, lint, verify in Studio, report. Use when the user asks for a new mechanic or system ("make a shop", "add pets", "build an obby", "double jump").
---

# Feature workflow

## 1. Understand (fast)

Read `default.project.json`, list `src/` (services, `Net.Names`, Config). Vague request → assume the most common pattern in popular Roblox games and state it in one line. Ask only questions that change the design.

## 2. Plan (3-8 lines to the user)

- **Server**: which Service, saved data (DataTemplate), validations.
- **Remotes**: names in `Net.Names`, args and their `Guard`. Minimal client data.
- **Shared**: what goes in `src/shared/Config/`.
- **Client**: Controller, UI, input, effects.
- **Studio**: parts/tags/assets the user must create or provide; geometry via `roblox-3d-building`.

## 3. Implement

- Skeletons: `node tools/rbxkit.mjs new service|controller|module <Name>`.
- Load only the skills the task needs (e.g. `roblox-networking` for remotes, `roblox-datastore` for saved data, `roblox-ui` for screens). Read their `references/` only when the SKILL.md points you there for your exact case.
- Unsure about an API → `node tools/rbxkit.mjs docs --api Class:Member` instead of guessing.
- Balance numbers as constants or in `Config`. Keep files focused; don't rewrite unrelated files.

## 4. Verify (required before "done")

```
node tools/rbxkit.mjs check     # Roblox lint (deprecated APIs, unvalidated remotes, ...)
selene src                      # if installed (rokit install)
stylua --check src              # if installed; `stylua src` to format
rojo build -o build.rbxl        # if installed: the project assembles
```

Fix every error; fix or justify warnings. With Studio MCP: the `roblox-studio-mcp` verify loop. Without it: give short manual test steps ("run `rojo serve`, connect, press Play, click X, expect Y").

## 5. Report

Files changed; what to do in Studio (tags, parts, asset/pass ids, API access); how to test; known limits and 1-3 next steps.

## Decomposition examples

- **Pets that follow and boost coins**: `PetService` (owned/equipped in DataTemplate, `EquipPet(petId)` validated against owned pets, multiplier applied in `CoinService:Add`); `Config/Pets`; `PetController` renders followers locally from a replicated `EquippedPet` attribute.
- **Double jump**: client-only (`UserInputService.JumpRequest` + `Humanoid.StateChanged`); the character replicates.
- **Robux shop**: `roblox-monetization` + `roblox-ui`.
