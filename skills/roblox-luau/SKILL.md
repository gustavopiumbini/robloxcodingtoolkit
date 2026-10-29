---
name: roblox-luau
description: Modern Luau rules for Roblox - strict typing, current vs deprecated APIs, task library, module patterns, silent-bug pitfalls. Use when writing or editing any Roblox .lua/.luau code.
---

# Modern Luau for Roblox

## Rules

- Every file starts with `--!strict`. Type public params/returns; `export type` for shared types.
- Services via `game:GetService("Name")` at the top; never `game.Players`. Use `workspace` for Workspace.
- `task.wait/spawn/defer/delay/cancel` only.
- String interpolation `` `Hi {player.Name}` ``; generic iteration `for _, x in list do`; `x += 1`.
- `if c then a else b` expressions, not `c and a or b` (breaks when `a` is falsy).
- Create an Instance, set all properties, set `Parent` **last**.
- `:Connect` (capital C); keep connections and clean them (`Trove`).

## Deprecated → current

| Don't | Do |
|---|---|
| `wait` / `spawn` / `delay` | `task.wait` / `task.spawn` / `task.delay` |
| `Instance.new("Part", parent)` | set props, then `.Parent` |
| `SetPrimaryPartCFrame` / `GetPrimaryPartCFrame` / `GetModelCFrame` | `PivotTo` / `GetPivot` |
| `Humanoid:LoadAnimation` | `Animator:LoadAnimation` |
| `BodyVelocity/Position/Gyro/Force` | `LinearVelocity`, `AlignPosition`, `AlignOrientation`, `VectorForce` |
| `FindPartOnRay*`, `Ray.new` | `workspace:Raycast(origin, dir, RaycastParams)` |
| `table.getn`, global `unpack` | `#t`, `table.unpack` |
| `LocalPlayer` on the server | the `player` argument |
| `loadstring`, `getfenv/setfenv`, `require(assetId)` | never (security/perf) |
| `BindableEvent` for module events | `Shared.Util.Signal` |
| `.Changed` for one property | `:GetPropertyChangedSignal("Prop")` |

Unsure about an API? `node tools/rbxkit.mjs docs --api Class:Member` (skill `roblox-docs`).

## Module and class patterns

```lua
--!strict
local Players = game:GetService("Players")

local MyModule = {}
export type Options = { speed: number, label: string? }
local DEFAULT_SPEED = 16 -- UPPER_SNAKE constants, camelCase locals

function MyModule.run(options: Options): boolean
	return options.speed > DEFAULT_SPEED
end

return MyModule
```

```lua
local Car = {}
Car.__index = Car
export type Car = typeof(setmetatable({} :: { speed: number, model: Model }, Car))

function Car.new(model: Model): Car
	return setmetatable({ speed = 0, model = model }, Car)
end

function Car.accelerate(self: Car, amount: number)
	self.speed += amount
end

return Car
```

## Silent-bug pitfalls

- `WaitForChild` without timeout can hang forever ("Infinite yield possible").
- `while true do` without `task.wait()` freezes the server.
- `player.Character` can be nil and changes on respawn: use `CharacterAdded`; `FindFirstChildOfClass("Humanoid")`.
- `Touched` fires many times per contact: debounce per player.
- Tables keyed by `Player` leak unless cleared on `PlayerRemoving`.
- `task.spawn` swallows return values; errors only show in Output.
- Compare floats/positions with tolerance, not `==`.
- `#t` doesn't count dictionary keys.
- Client numbers can be `NaN` (`x ~= x`) or `math.huge`: validate.
- `require` caches per ModuleScript per side: module state is shared on that side; modules in ReplicatedStorage run separately on client and server.

Finish with the Studio lint: `return require(game.ServerStorage.DevTools.Lint).summary(require(game.ServerStorage.DevTools.Lint).run())` (via `execute_luau`).
