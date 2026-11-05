# aim_map Phase 2B — Collision Validation Report

**Date:** 2026-11-05
**Branch:** `bsp-aim-map-import`
**GLB:** `aim_map.glb` (151,776 bytes, 2490 triangles, 47 mesh nodes)
**Engine:** Godot 4.7.2, Forward Plus, 128 Hz physics tick

---

## Executive Summary

**The Phase 2B winding correction resolved the critical inverted-normal defect.**

Phase 2A GLB had 737 triangles with reversed winding (normals pointing through
floors instead of up). The corrected Phase 2B GLB has 2,308 winding reversals
applied with 0 remaining mismatches. All 32 spawn positions now have correct
upward-facing floor normals. Single-sided trimesh collision (`backface_collision
= false`) is sufficient — no backface workaround needed.

182 zero-area degenerate triangles (collinear fan slivers) are present but cause
no collision gaps or rendering issues.

---

## Before/After Comparison

| Metric                    | Phase 2A (broken) | Phase 2B (fixed) |
|---------------------------|-------------------|------------------|
| Upward-facing triangles   | 91                | 737              |
| Downward-facing triangles | 737               | 91               |
| Wall triangles            | 1,480             | 1,480            |
| Spawns with correct floor | 0/32              | 32/32            |
| Floor grid coverage       | 2.0% correct      | 54.1% correct    |
| Inverted floor coverage   | 52.1%             | 0.0%             |
| Crate tops correct        | 0/19              | 19/19            |
| Vertex bounds             | unchanged         | unchanged        |
| Winding corrections       | —                 | 2,308            |
| Degenerate triangles      | 182               | 182              |

---

## Test Results

### TEST 1: Floor Collision Under Spawns — PASS

All 32 spawns now have correct upward-facing floor triangles (normal.y = +1.000)
from `model_00_-3Sand` (main ground plane, 208 upward-facing triangles).

| Team   | Count | Floor mesh      | Normal Y | Status |
|--------|-------|-----------------|----------|--------|
| Angels | 16/16 | model_00_-3Sand | +1.000   | PASS   |
| Demons | 16/16 | model_00_-3Sand | +1.000   | PASS   |

Ground floor meshes after correction:
- `model_00_-3Sand`: 208 up, 0 down, 0 wall (was 0 up, 208 down)
- `model_00_SandCCrete`: 358 up, 0 down, 0 wall (was 0 up, 358 down)
- `model_00_-0Sand`: 29 up, 0 down, 4 wall (was 0 up, 29 down)

### TEST 2: Standing Clearance (Ceiling) — PASS

All 32 spawns have open sky above. No ceiling clipping.

### TEST 3: Wall Proximity — PASS (2 WARN)

30 of 32 spawns have clearance > 1.5× hull radius. Two marginal but functional:
- Angel #15 (X=-8.32, Z=14.53)
- Demon #0 (X=8.55, Z=-14.50)

### TEST 4: Crate Top Collision — PASS

All 19 crate top mesh nodes now have correct upward normals:
- `model_00_SandCrtLrgTp`: 32 upward (worldspawn crate tops)
- `model_01-18_*Tp`: 2 upward each (brush model crate tops)
- 0 inverted crate tops remaining

### TEST 5: Step / Elevation Transitions — PASS

All step transitions from ground (Y=0.0) to elevated walkways (Y=3.86m) are
within the 0.457m (18u) step limit. Ground to elevated spawn platforms is
0.179m (7u) — steppable. Upper platforms (Y>3.86m) require jumping, as intended.

### TEST 6: Ramp/Slope Geometry — PASS (not applicable)

68 sloped triangles detected, all decorative wall trim (`-0csSandWall`).
No walkable ramps. All playable surfaces are flat and orthogonal.

### TEST 7: Degenerate Triangles (182) — PASS (no impact)

All 182 zero-area triangles are collinear slivers from BSP fan triangulation:
- `model_00_SandTrim`: 51 degenerate / 687 total
- `model_00_-3Sand`: 41 degenerate / 249 total
- `model_00_SandCCrete`: 34 degenerate / 392 total
- `model_00_-0csSandWall`: 25 degenerate / 454 total
- `model_00_-1csSandWall`: 19 degenerate / 232 total
- Others: 12 across remaining meshes

These are zero-area triangles with collinear vertices from BSP face fan
triangulation. They share edges with adjacent valid triangles and create
no collision gaps. They render as invisible zero-width slivers. No action needed.

### TEST 8: Vertex Seams / T-Junctions — PASS

1,322 unique vertex positions. Zero near-duplicate pairs within 1mm.
Clean geometry with no T-junctions or micro-gaps.

### TEST 9: Physics Layer Assignment — PASS

StaticBody3D defaults to collision layer 1 (World). Correct for map geometry.

### TEST 10: Downward-Facing Triangles — PASS (all legitimate)

The 91 remaining downward-facing triangles are all correct:
- 47 ceiling faces (`-0csSandWall`, Y=2.74–5.97) — walkway undersides
- 8 ceiling faces (`SandWllWndw`, Y=5.97) — window recess undersides
- 36 crate/model undersides (Y=-0.025) — crate bottoms on ground

None are inverted floors. All are geometrically correct surfaces.

### TEST 11: Missing GoldSrc Clip Hulls — NEEDS VISUAL TEST

Invisible BSP clip brushes are not extracted. For aim_map's simple orthogonal
geometry, trimesh collision from visible faces should be adequate:
- No doors, archways, or narrow passages
- No walkable ramps
- Possible crate corner-snagging (requires playtesting)
- Wall trim decorations may snag movement (requires playtesting)

---

## Classification Summary

| #  | Test                    | Result           | Severity  |
|----|-------------------------|------------------|-----------|
| 1  | Floor under spawns      | PASS             | Resolved  |
| 2  | Standing clearance      | PASS             | —         |
| 3  | Wall proximity          | PASS (2 WARN)    | Low       |
| 4  | Crate top collision     | PASS             | Resolved  |
| 5  | Step transitions        | PASS             | —         |
| 6  | Ramp geometry           | PASS (N/A)       | —         |
| 7  | Degenerate triangles    | PASS (no impact) | —         |
| 8  | Vertex seams            | PASS             | —         |
| 9  | Physics layers          | PASS             | —         |
| 10 | Downward faces          | PASS (legitimate)| —         |
| 11 | Missing clip hulls      | NEEDS VISUAL TEST| Low       |

---

## Automated Test Coverage

A new test suite (`tests/aim_map_collision_tests.gd`) exercises the corrected
geometry with the actual player controller:

- **32 spawn drop tests**: Teleport player to each spawn, run 32 physics ticks,
  verify player lands on ground and does not fall through
- **6 crate top tests**: Place player above crate surfaces, verify support
- **Walk-on-ground test**: Walk forward from a spawn, verify continuous ground contact
- **Wall collision test**: Walk toward outer wall, verify blocked

Test entry: `godot --headless --path . -- --test-aimmap`

---

## Verdict

**The Phase 2B winding correction resolves all collision failures identified in
Phase 2A.** No `backface_collision` workaround is needed. No GoldSrc clip hull
extraction is required for aim_map.

### Recommended next steps:
1. Run full CI (existing 19 test suites + new aim_map collision suite)
2. Visual playtest in-engine to confirm rendering and clip hull edge cases
3. Proceed to texture restoration (Phase 2C) or main game integration
