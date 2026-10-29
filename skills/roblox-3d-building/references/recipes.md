# Building recipes

All snippets assume `local B = require(game:GetService("ServerStorage").DevTools.Build)` and a model `m`.

## Gable roof (two wedges)

Roof over a W×D footprint at height H, pitch p (rise), overhang o:
```lua
local w, d, h, rise, o = 24, 18, 13, 6, 1.5
for side = -1, 1, 2 do
	B.part(m, { name = "Roof", shape = "Wedge", size = Vector3.new(w + o * 2, rise, d / 2 + o),
		cf = CFrame.new(0, h + rise / 2, side * (d / 4 + o / 2)) * CFrame.Angles(0, side == 1 and math.pi or 0, 0),
		color = B.palettes.cottage.roof, material = Enum.Material.Slate })
end
-- Gable ends: wedges with the slope facing out, or a thin wall under each slope.
```
Add a ridge cap (thin part along the top) and fascia boards (0.4 thick trim) along the eaves.

## Window with depth

Wall opening via `B.wall{ openings = {...}, trim = color }`, then a glass pane inset 0.3 from the outer face:
`B.part(m, { name="Glass", size=Vector3.new(width-0.8, height-0.8, 0.1), cf=..., color=pal.glass, material=Enum.Material.Glass, transparency=0.4, decor=true })`.
Add a sill (0.4 tall, protruding 0.4) and optional shutters.

## Column

Base (box 2.4×0.6×2.4) + shaft (`B.cylinder` radius 0.9) + capital (box 2.4×0.6×2.4). Spacing 8-12 studs.

## Fence / railing

`B.array(count, origin, Vector3.new(4, 0, 0), function(i, cf) B.part(m, { name = "Post", size = Vector3.new(0.5, 3.5, 0.5), cf = cf * CFrame.new(0, 1.75, 0), decor = true }) end)`, then two rails spanning the whole length (one part each, not one per gap).

## Tree (stylized, without meshes)

Trunk `B.cylinder` (r 1.2, h 14) + 3-5 overlapping balls of 2 close greens at different sizes/heights for the canopy (decor). For realism use `generate_mesh` or a vetted asset instead.

## Interior dressing

Floor material differs from walls; baseboards (0.6 tall, 0.2 deep trim); one rug; furniture against walls leaving ≥ 6-stud paths; 1-2 warm PointLights (Range 12-16, Brightness 1-2).

## Common fixes

| Problem | Fix |
|---|---|
| Flickering surfaces | z-fighting: offset one part by 0.02-0.05 or merge them |
| Looks flat/boring | Add depth: inset panels, overhangs, trims; vary heights; better lighting angle |
| Looks noisy | Too many colors/materials: collapse to the palette |
| Too big/small | Re-check `scale.md`; scale the whole model with `model:ScaleTo(factor)` |
| Players get stuck | Decor colliding: `decor = true`; widen paths; remove lips > 1 stud |
| Lag | Merge static detail into MeshParts, drop tiny decor, `CastShadow=false` on small parts |
