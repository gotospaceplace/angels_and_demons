# MAP_TD_CSAIMMAP — Phase 2A corrected extraction

This package replaces the Phase 1 geometry and entity files. **Do not retain the Phase 1 +0.889 m WorldGeometry/spawn offsets**: these are now baked into both the GLB and JSON coordinates. Do not apply a second offset.

## Changes
- Floor baseline corrected from -432 to **-467 GoldSrc units** using spawn origin minus 36-unit half standing hull. This is a heuristic and should be checked against actual walkable polygons on other maps.
- X/Z geometry and entities centered using world model BSP bounding-box midpoint; all entity `position_bsp` values remain unchanged.
- GLB and JSON regenerated with identical transform.

## Files
- `aim_map.glb`: visible triangle geometry, placeholder materials
- `entities.json`: entities, original BSP positions, converted Godot positions
- `validation.json`: measurements and known limitations
- `convert_bsp.py`: reproducible extraction script
- `source/aim_map.bsp`: original source (check redistribution rights before public commit)

## Claude Code instructions
1. On existing `bsp-aim-map-import` branch, replace GLB and JSON, remove `FLOOR_Y_OFFSET` and any previous +0.889m adjustment from both WorldGeometry and spawn arrays.
2. Regenerate the scene's spawn arrays from updated JSON rather than preserving stale hardcoded coordinates.
3. Check mesh/spawn alignment, import, and all 19 existing test suites.
4. Playtest collisions and clip behavior before integrating into gameplay.
5. Do not treat visual faces as authoritative GoldSrc collision: clip hulls are not extracted.

## Still not implemented
- Invisible GoldSrc clip hull / collision-only geometry
- Brush-specific solidity/collision selection (func_wall is generally solid)
- WAD texture extraction or material texture assignment (WAD files not supplied)
- Per-spawn floor raycasts and in-engine visual verification
- Animated texture playback

## Coordinate convention
Godot X = (BSP X - center X) * 0.0254; Godot Y = (BSP Z + 467) * 0.0254; Godot Z = -(BSP Y - center Y) * 0.0254.
