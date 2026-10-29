---
name: roblox-networking
description: Secure client-server networking - RemoteEvent/RemoteFunction/UnreliableRemoteEvent, argument validation, rate limiting, anti-exploit, state replication. Use for any remote, or when the user mentions exploits, hackers or cheats.
---

# Secure networking

Exploiters run arbitrary client code: they can fire **any** remote with **any** arguments at **any** rate and read all client/ReplicatedStorage code. Write every server handler as if the client is hostile.

## Which remote

| Case | Use |
|---|---|
| Client requests an action | `RemoteEvent` → server |
| Server notifies clients | `RemoteEvent` `FireClient` / `FireAllClients` |
| High-frequency, droppable (aim, VFX) | `UnreliableRemoteEvent` |
| Client needs a reply | `RemoteFunction` `InvokeServer` |
| Server asks a client | **Never** `InvokeClient` (can hang the server) — RemoteEvent round-trip |
| Simple replicated state | Attributes / ValueObjects set by the server |

## Every `OnServerEvent` / `OnServerInvoke` checklist

1. Rate limit per player.
2. Exact argument count and types (`typeof`).
3. Finite numbers (reject NaN/inf) in range; integers for quantities.
4. Strings length-capped; ids checked against a server table (`Guard.keyOf(Items)`).
5. Instances: exist, are where expected (`IsDescendantOf`), owned/in range (distance to `HumanoidRootPart`).
6. Game state: alive? cooldown? enough currency? right round phase?
7. Never accept from the client: price, damage, reward amount, hit result, target UserId to give things to, unchecked teleport positions.
8. First parameter is always the `player` (injected by Roblox).

## Template `Net`

```lua
local Net = require(Shared.Net)
local Guard = require(Shared.Util.Guard)
-- add Attack = "Attack" to Net.Names
Net.onServerEvent(Net.Names.Attack, { check = Guard.tuple(Guard.instance("Model")), rate = 4, burst = 4 },
	function(player, target: Model)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if not (root and targetRoot and humanoid) or humanoid.Health <= 0 then return end
		if (root.Position - targetRoot.Position).Magnitude > 12 then return end -- range + latency slack
		if CombatService:IsOnCooldown(player) then return end
		humanoid:TakeDamage(WEAPON_DAMAGE) -- damage decided on the server
	end)
```

`Guard`: `any, boolean, number{min,max}, integer{min,max}, string{minLength,maxLength,pattern}, literal(...), keyOf(dict), vector3{maxMagnitude}, cframe, instance(className), optional(c), array(c, max), shape{field=c}, tuple(...)`.

## Anti-exploit patterns

- Movement: clients own their character. Detect speed/teleport by distance per Heartbeat with tolerance and a violation counter (never kick on one spike).
- Network ownership: critical loose parts → `part:SetNetworkOwner(nil)`.
- Projectiles: client shows the effect instantly; server re-validates (raycast with latency tolerance) before damage.
- Tools: damage logic on the server, never in the Tool's LocalScript.
- Player-authored text shown to others must be filtered (`roblox-text-chat`).
- Log rejections with `warn` + player name; don't kick on a single validation failure (lag).

## Replication

- Attributes for simple values. Lists (inventory): initial snapshot + deltas, or a `Get` RemoteFunction when UI opens.
- Don't `FireAllClients` big tables every frame: batch, cap Hz, use unreliable events for VFX.
- Mixed array/dict tables lose data when serialized; non-string dictionary keys are converted.
