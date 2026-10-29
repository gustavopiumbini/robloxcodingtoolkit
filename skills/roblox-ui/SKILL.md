---
name: roblox-ui
description: Roblox UI - ScreenGui, responsive layout (Scale, constraints, layouts), mobile/console/PC, tweens, BillboardGui, ProximityPrompt. Use for HUDs, menus, shops, inventories, popups and any 2D element.
---

# UI

## Principles

- UI is presentation: reads state (Attributes, remotes) and sends intents; never decides prices/rewards.
- Lives in client Controllers, created in `player.PlayerGui` (or Studio-made templates cloned from ReplicatedStorage/StarterGui).
- HUDs: `ScreenGui.ResetOnSpawn = false` (otherwise rebuilt on death with duplicated connections).

## Responsive (≈half of players are on mobile)

- `UDim2.fromScale` for size/position; `Offset` only for small details.
- `AnchorPoint` + `Position` to align (`Vector2.new(0.5, 0.5)` centers).
- `UIAspectRatioConstraint` on buttons/icons; `TextScaled` + `UITextSizeConstraint`.
- `UIListLayout`, `UIGridLayout`, `UIPadding`, `UIScale`, `UIFlexItem`, `UICorner`, `UIStroke`.
- Keep `ScreenInsets = CoreUISafeInsets`; don't cover the mobile joystick/jump (bottom corners).
- Buttons ≥ ~44 px tall on mobile; use `Activated` (touch, mouse, gamepad).
- Test with the Device Simulator (phone, tablet, 1080p).

## Input

```lua
ContextActionService:BindAction("OpenInventory", function(_, state)
	if state == Enum.UserInputState.Begin then toggleInventory() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY) -- true = touch button on mobile
```

Deeper input/camera work: `roblox-input`.

## Animation and state

```lua
TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Position = UDim2.fromScale(0.5, 0.5) }):Play()

local function render() label.Text = `Coins: {player:GetAttribute("Coins") or 0}` end
player:GetAttributeChangedSignal("Coins"):Connect(render)
render()
```

Cancel the previous tween when reopening quickly. Lists: keep an `id -> frame` map and update diffs; one `Trove` per open window.

## 3D-space UI

- `BillboardGui` (names/health): `AlwaysOnTop`, `MaxDistance`, stud-based size.
- `SurfaceGui` on parts (signs, screens).
- `ProximityPrompt` ("Press E"): `Triggered` fires on the server with the player; still check state/cooldown.

## Checklist

- [ ] Works on a small phone (no overlap, tappable buttons)
- [ ] Text readable and not cut off
- [ ] `ZIndex`/`DisplayOrder` correct for popups
- [ ] No duplicated connections after respawn
- [ ] Instant button feedback (sound/scale) while waiting for the server
- [ ] Player-authored text filtered before showing to others
