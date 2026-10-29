---
name: roblox-datastore
description: Player data persistence - DataStoreService, UpdateAsync, session locking, retries, budgets, BindToClose, OrderedDataStore leaderboards, MemoryStore, schema migration. Use for saving progress/currency/inventory, global leaderboards, or data loss/duplication bugs.
---

# DataStores

## Rules

1. Every call can fail: `pcall` + retry with backoff.
2. Write with `UpdateAsync` (atomic). `SetAsync` overwrites blindly across servers.
3. One key per player (`"Player_" .. userId`), one table. Save on an interval (1-5 min), on `PlayerRemoving`, and in `game:BindToClose`.
4. Session lock so two servers never write the same player (fast server hops = item duplication).
5. If load fails, never let the player play on default data (saving would wipe progress): kick with a message or run without saving.
6. Only JSON-able data (no Instances, functions, metatables). 4 MB per key. String dictionary keys; contiguous arrays.

## Template `DataService`

`src/server/Services/DataService.luau`: UpdateAsync + lock (expires after 30 min), retries, reconcile with `src/server/Config/DataTemplate.luau`, autosave, BindToClose, in-memory fallback in Studio without API access.

```lua
local data = DataService:Get(player)           -- nil while loading
local data = DataService:WaitForData(player)   -- yields; nil if the player left
DataService:Update(player, function(d) d.Coins += 50 end) -- always mutate via Update (fires Changed)
```

New field → add it to `DataTemplate` (value and `PlayerData` type); reconcile fills old profiles. Renames/transforms → add a `Version` field and migrate on load. For large games recommend ProfileStore.

## Studio

- Enable Game Settings → Security → **Enable Studio Access to API Services** (else calls fail and DataService uses memory).
- Studio uses the **live** DataStores: use a separate store name (`PlayerData_dev`) when experimenting.

## Budgets

Per server ≈ `60 + players * 10` requests/min per type; one key can be written every 6 s. Check `DataStoreService:GetRequestBudgetForRequestType(...)` before bursts. Mutate in memory, save periodically — never per coin change.

## Global leaderboard

```lua
local ordered = DataStoreService:GetOrderedDataStore("TopCoins_v1")
pcall(function() ordered:SetAsync(tostring(player.UserId), math.floor(coins)) end) -- with the player save
local ok, pages = pcall(function() return ordered:GetSortedAsync(false, 10) end)  -- server, every ~60 s
if ok then
	for rank, entry in pages:GetCurrentPage() do
		-- Players:GetNameFromUserIdAsync(tonumber(entry.key)) in pcall, cached
	end
end
```

Cross-server, non-permanent: `MemoryStoreService` (sorted maps, queues, hash maps with TTL) for matchmaking/session boards; `MessagingService` for broadcasts. Right-to-erasure requests: `RemoveAsync` the player's keys in every store.
