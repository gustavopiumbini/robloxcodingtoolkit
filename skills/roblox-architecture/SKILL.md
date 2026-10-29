---
name: roblox-architecture
description: Rojo project layout and client/server boundaries - where scripts go, Services/Controllers with Init/Start, adding new systems. Use when creating files, organizing code, or deciding what runs on client vs server.
---

# Project architecture

## Rojo map (`default.project.json`)

| Disk | Studio | Runs / visible |
|---|---|---|
| `src/server/` (`init.server.luau`) | `ServerScriptService.Server` | Server only; clients never see it |
| `src/server/Services/*.luau` | ModuleScripts under Server | Server |
| `src/server/Config/` | ModuleScripts (save template, secret tables) | Server |
| `src/client/` (`init.client.luau`) | `StarterPlayerScripts.Client` | Each client |
| `src/client/Controllers/*.luau` | ModuleScripts under Client | Client |
| `src/shared/` | `ReplicatedStorage.Shared` | Both |
| `src/dev/` | `ServerStorage.DevTools` | Studio tooling only (Build, Shots); never runs live |

Rojo names: `X.server.luau` → Script, `X.client.luau` → LocalScript, `X.luau` → ModuleScript, folder with `init.*.luau` → that script. Maps/models usually live in the place file, not Rojo; to version assets use `.rbxm` in `assets/`.

## Client/server boundary (most important rule)

- **Server** owns money, inventory, damage, health, progress, purchases, item spawning, DataStores, `ProcessReceipt`.
- **Client** owns input, camera, UI, VFX/SFX, local animation, visual prediction.
- Client **asks** with minimal intent ("buy Sword"); server **decides** and replicates the result.
- Client changes to workspace don't replicate (except its character and physics it owns) — validate positions server-side.
- Anything in `ReplicatedStorage` is readable by exploiters; keep secrets in `ServerStorage`/`ServerScriptService`.

## Services / Controllers

Bootstraps require every module in `Services/` (or `Controllers/`), call `:Init()` alphabetically, then `:Start()` each in its own thread.
- `Init`: synchronous, no long yields. Create remotes, connect other services' signals.
- `Start`: loops/yields allowed.
- Cross-service: `require(script.Parent.OtherService)`. Break cycles with a third module or a `Signal`.

```
node tools/rbxkit.mjs new service Inventory     # src/server/Services/InventoryService.luau
node tools/rbxkit.mjs new controller Camera     # src/client/Controllers/CameraController.luau
node tools/rbxkit.mjs new module Util/Math      # src/shared/Util/Math.luau
```

## Ready-made shared modules

`Net` (named remotes + `Guard` + `RateLimiter`), `Util/Guard`, `Util/RateLimiter`, `Util/Signal`, `Util/Trove`, `Config/` (catalogs, visible constants).

## Where a new system goes

1. Authoritative state/rules → `src/server/Services/XService.luau`.
2. Data the client must know (catalog, display prices) → `src/shared/Config/`.
3. Communication → add to `Net.Names`, handler in the service's `Init` with `Guard`.
4. UI/input → `src/client/Controllers/XController.luau`.
5. Simple replicated state → `player:SetAttribute` (server) + `GetAttributeChangedSignal` (client); complex state → snapshot + deltas over a RemoteEvent.
6. Map objects with behavior (doors, coins, traps) → CollectionService tags + a service using `GetTagged` and `GetInstanceAddedSignal`.

Packages (Wally) live in `Packages/` → `ReplicatedStorage.Packages`. Known libraries: ProfileStore, Promise, Fusion/React-lua/Vide, Jecs. Don't add dependencies unless asked.
