---
name: roblox-gameplay
description: Gameplay system recipes - collectibles with CollectionService tags, melee/ranged combat flow, round systems, obby checkpoints, tools. Use when implementing game mechanics; pairs with roblox-physics, roblox-npc-ai and roblox-characters-animation.
---

# Gameplay recipes

Server is authoritative; client gives instant feedback. Related depth: `roblox-characters-animation` (Humanoid, spawning, animation), `roblox-physics` (raycasts, constraints, ownership), `roblox-npc-ai` (pathfinding, behavior).

## Collectibles via tags

Tag parts `Coin` in Studio (Tag Editor / Properties > Tags):

```lua
local function setup(part: BasePart)
	local busy = false
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if busy or not player then return end
		busy = true
		CoinService:Add(player, 1)
		part.Transparency = 1
		task.delay(10, function() part.Transparency = 0; busy = false end)
	end)
end
for _, p in CollectionService:GetTagged("Coin") do setup(p) end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(setup)
```

## Combat

- Melee: client input → animation → `FireServer` (intent). Server: per-player cooldown, authoritative hitbox `workspace:GetPartBoundsInBox(cframe, size, overlapParams)` in front of the `HumanoidRootPart` (exclude attacker), unique characters, `humanoid:TakeDamage(damage)`.
- Ranged: client raycasts for instant tracers; server validates `origin` near the shooter's head and a finite unit `direction`, re-raycasts excluding the shooter, applies damage, enforces fire rate. Slow projectiles: simulate on the server, render on clients.

## Round system

Server state machine `Intermission → Starting → Playing → Ended`. Publish `workspace:SetAttribute("RoundState", ...)` and `"RoundEndsAt"` (`workspace:GetServerTimeNow() + duration`) so clients compute timers locally (no per-second remote). One `Trove` per round for map, connections and players.

## Obby checkpoints

`Checkpoint` parts with a `Stage` attribute. On touch, only advance when `stage == current + 1`. Save `Stage` in DataService; respawn there (`player.RespawnLocation` or `PivotTo` on `CharacterAdded`). Gaps/heights: `roblox-3d-building/references/scale.md`.

## Tools

Give with `tool:Clone().Parent = player.Backpack` (server). `tool.Activated` in a LocalScript for feedback; the server validates and applies. `RequiresHandle = false` for handle-less tools.

## Assets

`rbxassetid://` ids must belong to the creator or be public. Ask the user for ids or use clearly marked placeholders (`-- TODO: asset id`).
