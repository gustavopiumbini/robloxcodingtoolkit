---
name: roblox-3d-building
description: Build high-quality 3D models, buildings, props and maps in Roblox Studio (parts, MeshParts, generated meshes/materials, lighting) with correct avatar scale, cohesive style, and a screenshot review loop. Use for any request to build, model, decorate or improve how something looks in 3D.
---

# High-quality 3D building

Goal: builds that look intentional and polished, not "blocks placed by a bot". Quality comes from **plan → block-out → detail → audit → look → fix**, not from more parts.

## 1. Plan (before any code)

Write a 5-line brief: purpose & gameplay (walkable? climbable?), style (low-poly, realistic, stylized, sci-fi), palette (pick one `B.palettes.*` or 3-6 colors + 1 accent), footprint in studs, and a part budget (prop ≤ 60, house ≤ 400, plaza ≤ 1500). Check scale in [references/scale.md](references/scale.md). Characters are ~5.5 studs tall; **doors 4×7.5, ceilings 12-14, steps rise 1 / run 1.5**. Wrong scale is the #1 reason builds look amateur.

## 2. Pick the right technique

| Shape | Use |
|---|---|
| Architecture, furniture, blocky/stylized props | Parts via `DevTools.Build` (fast, clean, editable) |
| Organic/curved (trees, rocks, creatures, statues, vehicles) | MCP `generate_mesh` / `generate_procedural_model`, or a Creator Store asset via `search_asset` + `insert_asset` (audit it: `roblox-creator-store-security-audit`) |
| Custom surface look (tiles, brick, metal panels) | Built-in `Enum.Material` first; `generate_material` → MaterialVariant for something specific |
| Terrain (hills, water, caves) | `workspace.Terrain:FillBlock/FillBall/FillWedge` (see `roblox-world-building`) |

Never fake curves with dozens of thin parts; use a cylinder/ball/wedge, a mesh, or terrain.

## 3. Build with DevTools (`ServerStorage.DevTools`, installed by `install/4-build-tools.luau`)

Run in edit mode through MCP `execute_luau`. Builds are re-runnable (`B.model` replaces the old one) and undoable:

```lua
local B = require(game:GetService("ServerStorage").DevTools.Build)
local pal = B.palettes.cottage
B.undoable("Cottage", function()
	local m = B.model("Cottage", workspace)
	B.part(m, { name = "Foundation", size = Vector3.new(26, 1, 20), pos = Vector3.new(0, 0.5, 0), color = pal.stone, material = Enum.Material.Cobblestone })
	B.wall(m, { name = "FrontWall", from = Vector3.new(-12, 1, -9), to = Vector3.new(12, 1, -9), height = 12, color = pal.wall,
		material = Enum.Material.Plaster, trim = pal.trim, openings = { { offset = 12, width = 4, height = 7.5 }, { offset = 5, width = 4, height = 4, bottom = 3 } } })
	B.stairs(m, { cf = CFrame.new(0, 0, -11.5) * CFrame.Angles(0, math.pi, 0), steps = 1, width = 6, color = pal.stone, material = Enum.Material.Slate })
	B.finalize(m)
end)
return B.summary(B.audit(workspace.Cottage))
```

API: `model, folder, part{shape,size,cf|pos,color,material,decor,...}, cylinder{radius,height,axis}, wall{from,to,height,thickness,openings,trim}, stairs{cf,steps,width,rise,run}, array, ring, finalize, undoable, audit, summary, palettes`. Read the `Build` module with `script_read` only if you need details. Without DevTools, follow the same rules with plain `Instance.new`.

If an edited DevTools module seems stale in Studio, require a clone: `require(module:Clone())`.

## 4. Craft rules that make it look good

- **Silhouette first**: block out big masses, check proportions, then add medium forms (roof overhangs, porches, columns), then small details (trims, frames, props). Detail density should vary: concentrate it where players look (entrances, eye level).
- **Break flat surfaces**: baseboards, window frames (`trim`), cornices, pillars every 8-12 studs, inset panels (0.2-0.4 stud depth), overhangs of 1-2 studs. A big flat 24×12 wall is the clearest amateur tell.
- **Cohesion**: one palette, 2-4 materials per model. Use accent color on ≤10% of the surface. Neon only for real light sources.
- **Clean geometry**: snap to a 0.25/0.5 stud grid, rotations in 15°/45°/90° steps, no gaps, no overlapping coplanar faces (z-fighting) — offset decor by ≥0.02 or let `B.wall` trims handle it. Sizes ≥ 0.05.
- **Physics**: everything anchored; decor `decor = true` (no collide/touch/query); walkable surfaces flat and collidable; doorways actually walkable (test with `character_navigation`).
- **Light**: a build looks 2× better with good lighting. Check `Lighting` (Future technology set in Studio, Atmosphere, ColorCorrection, a sun angle with long shadows); add `PointLight`/`SpotLight` in lamps with warm colors, Range ≤ 16, few shadows.
- **Performance**: anchored static parts are cheap; hundreds of tiny decor parts are not. Repeated complex props → one MeshPart reused. Decor meshes: `CollisionFidelity = Box`, `CastShadow = false` for small items.

## 5. Review loop (mandatory, token-aware)

1. `return B.summary(B.audit(model))` — fix every z-fighting/tiny/unanchored item first (text is cheap).
2. `Shots.frame(model, "iso")` then `screen_capture`; then `"front"`; add `"close"` or `"low"` only when judging detail. Max 3 screenshots per iteration.
   `local Shots = require(game:GetService("ServerStorage").DevTools.Shots)`
3. Score 1-5 with the rubric below. Fix the lowest scores first. Stop when every item ≥ 4 or after 3 iterations, then `Shots.restore()`.
4. Tell the user what you built, the part count, and to save the place (Ctrl+S). Mention anything you could not verify.

| Rubric item | 5 looks like |
|---|---|
| Scale & proportion | Doors/stairs/furniture match a 5.5-stud avatar; nothing oversized |
| Silhouette | Readable from far away; varied heights and depth; roofline interesting |
| Detail hierarchy | Large → medium → small forms; no large blank surfaces |
| Color & material | One palette, 2-4 materials, accent used sparingly |
| Clean build | Aligned, no gaps, no z-fighting, no floating parts |
| Lighting & mood | Fits the style; light sources make sense |
| Playability & perf | Walkable where it should be; within part budget |

More: architecture/prop recipes and common fixes in [references/recipes.md](references/recipes.md).
