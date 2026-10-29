---
name: roblox-review
description: Audit Roblox code - remote security, client trust, data loss/duplication, memory leaks, deprecated APIs, performance. Use for reviews, "is something wrong?", "my game got hacked", before publishing, or when inheriting code/free models.
---

# Code review

1. Automated pass: `local L = require(game.ServerStorage.DevTools.Lint) return L.summary(L.run(), 60, true)` via `execute_luau` (install `install/5-lint.luau` first if missing). Treat results as leads; confirm each with `script_read`.
2. Manual pass by priority:

**Critical (security/economy)**
- [ ] Every `OnServerEvent`/`OnServerInvoke` validates types, ranges, ownership, distance, cooldown (`roblox-networking`).
- [ ] No economic value (price, damage, reward, quantity) comes from the client.
- [ ] No `InvokeClient` on the server.
- [ ] No `require(<number>)`, `loadstring`, `getfenv/setfenv` (backdoors); scan models in workspace (`script_search`, `roblox-creator-store-security-audit`).
- [ ] `ProcessReceipt` idempotent; `PurchaseGranted` only after saving.
- [ ] No authoritative logic in LocalScripts.

**High (data)**
- [ ] DataStores: `pcall`, retries, `UpdateAsync`, session lock, save on `PlayerRemoving` + `BindToClose`.
- [ ] Failed load never saves defaults over real data.
- [ ] Nothing non-serializable saved.

**Medium (stability/perf)**
- [ ] Connections and per-player tables cleaned up.
- [ ] `WaitForChild` timeouts where objects may not exist (streaming).
- [ ] No yield-less `while true`; no needless per-frame work; remotes not spammed.

**Low (maintenance)**
- [ ] `--!strict`, types, modern APIs (`roblox-luau`); clear names; no dead code.

3. Report grouped by severity: `file:line`, one-sentence problem, a concrete exploit/failure scenario, a short fix. End with the top 3 to fix first. Apply fixes only if asked.
