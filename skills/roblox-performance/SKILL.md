---
name: roblox-performance
description: Performance - server/client lag, memory leaks, per-frame work, StreamingEnabled, part counts, physics, remote spam, Parallel Luau, MicroProfiler. Use for low FPS, high ping, memory growth, or scaling to many players/NPCs.
---

# Performance

## Diagnose first

- Developer Console (F9): Memory by category, Network (bytes per remote), ServerStats, Scripts.
- MicroProfiler (Ctrl+F6); mark sections with `debug.profilebegin("Name")` / `debug.profileend()`.
- Script Profiler (Studio) for CPU hotspots per function.
- Via MCP: play test + `get_console_output`; `execute_luau` to count instances or time code with `os.clock()`.

## Usual causes

| Symptom | Likely cause | Fix |
|---|---|---|
| Memory keeps growing | Connections never disconnected, per-player tables not cleared, forgotten clones | `Trove` per lifetime; clear on `PlayerRemoving`; `Destroy()` not `Parent = nil` |
| Server lag | Many `while true` loops with short waits; heavy `Heartbeat` work | One central loop; lower frequency; batch work |
| High network | `FireAllClients` every frame, big tables | Deltas, cap Hz, unreliable events, attributes |
| Low client FPS | Too many parts/meshes, shadows, particles, UI rebuilt | StreamingEnabled, LOD, `CastShadow=false` on details, reuse UI |
| Physics stutter | Many unanchored parts, ownership flipping | Anchor static parts, `SetNetworkOwner`, constraints instead of per-frame CFrame |
| Spawn spikes | Cloning big models at once | Pooling, spread over frames |

## Code habits

- Cache services, instance references and results outside hot loops.
- Avoid recursive `FindFirstChild(name, true)` / `GetDescendants` in hot paths.
- `RunService.Heartbeat` for per-frame logic; `RenderStepped`/`BindToRenderStep` only on the client for camera/visuals.
- Pool projectiles/effects; spatial queries over distance checks against everything.
- `table.concat`, `table.create(n)`, `buffer` for compact data.
- One scheduler instead of hundreds of `task.wait()` threads.

## StreamingEnabled

On by default. Clients only have nearby parts: on the client use `WaitForChild` with timeouts and tag signals; set `Model.ModelStreamingMode = Persistent` for always-needed models.

## Parallel Luau

For heavy parallel work (many NPC paths, procedural generation): scripts under `Actor`s, `task.desynchronize()` for read-only work, `task.synchronize()` before writing instances; communicate with `actor:SendMessage` / `SharedTable`. Only worth it for genuinely heavy work.

Targets: server Heartbeat ~60 Hz; script activity < 20-30%; mobile client memory < ~1.5 GB.
