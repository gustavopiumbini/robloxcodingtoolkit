---
name: roblox-architecture
description: Game layout in Roblox Studio and client/server boundaries - where scripts go, Services/Controllers with Init/Start, adding new systems. Use when creating scripts, organizing code, or deciding what runs on client vs server.
---

# Game architecture (in Studio)

## Layout installed by the toolkit

| Instance | Type | Runs / visible |
|---|---|---|
| `ServerScriptService.Server` | Script (bootstrap) | Server only; clients never see it |
| `Server.Services.*` | ModuleScripts | Server |
| `Server.Config.*` | ModuleScripts (save template, secret tables) | Server |
| `StarterPlayer.StarterPlayerScripts.Client` | LocalScript (bootstrap) | Each client |
| `Client.Controllers.*` | ModuleScripts | Client |
| `ReplicatedStorage.Shared` | Folder of ModuleScripts | Both |
| `ServerStorage.DevTools` | ModuleScripts (Build, Shots, Lint) | Studio tooling only; never runs live |

Missing? Run the `install/*.luau` installers with `execute_luau` (see `AGENTS.md`).

## Client/server boundary (most important rule)

- **Server** owns money, inventory, damage, health, progress, purchases, item spawning, DataStores, `ProcessReceipt`.
- **Client** owns input, camera, UI, VFX/SFX, local animation, visual prediction.
- Client **asks** with minimal intent ("buy Sword"); server **decides** and replicates the result.
- Client changes to workspace don't replicate (except its character and physics it owns) — validate positions server-side.
- Anything in `ReplicatedStorage`/`Workspace`/`StarterGui` is readable by exploiters; keep secrets in `ServerStorage`/`ServerScriptService`.

## Services / Controllers

Bootstraps require every ModuleScript in `Services` (or `Controllers`), call `:Init()` alphabetically, then `:Start()` each in its own thread.
- `Init`: synchronous, no long yields. Create remotes, connect other services' signals.
- `Start`: loops/yields allowed.
- Cross-service: `require(script.Parent.OtherService)`. Break cycles with a third module or a `Signal`.

New service (via `execute_luau`; same shape for a Controller in `Client.Controllers`):

```lua
local s = Instance.new("ModuleScript")
s.Name = "InventoryService"
s.Source = [==[
--!strict
local InventoryService = {}

function InventoryService:Init()
	-- create remotes (Net.onServerEvent + Guard), connect signals
end

function InventoryService:Start()
	-- loops, PlayerAdded, ...
end

return InventoryService
]==]
s.Parent = game.ServerScriptService.Server.Services
return s:GetFullName()
```

## Ready-made shared modules

`Net` (named remotes + `Guard` + `RateLimiter`), `Util.Guard`, `Util.RateLimiter`, `Util.Signal`, `Util.Trove`; put catalogs/constants in a `Shared.Config` folder.

## Where a new system goes

1. Authoritative state/rules → `Server.Services.XService`.
2. Data the client must know (catalog, display prices) → `ReplicatedStorage.Shared.Config`.
3. Communication → add to `Net.Names`, handler in the service's `Init` with `Guard`.
4. UI/input → `Client.Controllers.XController` (UI built in code or cloned from `StarterGui`/`ReplicatedStorage`).
5. Simple replicated state → `player:SetAttribute` (server) + `GetAttributeChangedSignal` (client); complex state → snapshot + deltas over a RemoteEvent.
6. Map objects with behavior (doors, coins, traps) → CollectionService tags + a service using `GetTagged` and `GetInstanceAddedSignal`.
7. Assets/models live in `ServerStorage` (server spawns them) or `ReplicatedStorage` (both need them).

Known libraries (ProfileStore, Promise, Fusion, Jecs) can be inserted as ModuleScripts; don't add dependencies unless asked.
