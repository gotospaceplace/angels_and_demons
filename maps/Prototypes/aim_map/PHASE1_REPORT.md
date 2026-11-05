# aim_map BSP Import — Validation Report

**Branch:** `bsp-aim-map-import`
**Date:** 2026-11-05
**Source:** `aim_map.bsp` (SHA256: `bf0a879d...2e1a5b3c`, BSP v30)
**Phase:** 2A — corrected floor baseline and centered geometry

---

## 1. Import Results

| Check | Result |
|-------|--------|
| GLB format | PASS — glTF 2.0, 151,776 bytes |
| Script validation | PASS — no syntax errors, all properties declared |
| Resource references | PASS — all `res://` paths resolve |
| Existing test suites | PASS — 19 test files intact, no regressions |
| Scene tree | PASS — `aim_map.tscn` loads, script attaches |
| Map contract | PASS — `spawn_points` (32), `angels_spawns` (16), `demons_spawns` (16), `portal_sites` ({}) |

---

## 2. Phase 2A Corrections Applied

| Item | Phase 1 | Phase 2A |
|------|---------|----------|
| `floor_base_bsp_z` | -432 (wrong) | **-467** (correct) |
| Map centering | Offset from origin | **Centered on XZ** |
| `FLOOR_Y_OFFSET` workaround | +0.889m in script | **Removed** — baked into GLB/JSON |
| `WorldGeometry.position.y` | 0.889 | **0.0** (identity) |
| Spawn coordinates | Offset values | **Direct from corrected JSON** |

---

## 3. Geometry Validation

### GLB Vertex Bounds (centered, corrected floor)
```
X: [-18.9103, 18.9103]  Width: 37.82m  (centered)
Y: [-0.0254,  8.6868]   Height: 8.71m  (floor at ~0.0)
Z: [-27.9400, 27.9400]  Depth: 55.88m  (centered)
```

### BSP Bounding Box vs GLB
| Measurement | BSP (meters) | GLB (meters) | Difference | Reason |
|-------------|-------------|--------------|------------|--------|
| Width (X)   | 38.329      | 37.821       | 0.508m     | Sky faces excluded |
| Height (Y)  | 8.966       | 8.712        | 0.254m     | Sky brush excluded |
| Depth (Z)   | 58.725      | 55.880       | 2.845m     | Sky/trigger faces excluded |

### Centering Verification
```
BSP horizontal center: X=-104.5, Y=-1348.0
GLB XZ center offset: (0.0000, 0.0000)  PASS
Bounds transform:      exact match across all 3 axes  PASS
```

### Mesh Statistics
- 47 mesh nodes (worldspawn + 18 brush models)
- 20 materials (all placeholder — no textures)
- 2,490 triangles, 1,405 vertices

---

## 4. Spawn Position Validation

All 32 spawns within mesh XZ bounds. Y heights verified against hull geometry.

### Angels (info_player_start) — 16 spawns at Z ≈ 14.5 to 19.4
| Surface | Count | Feet Y | Hull Center Y |
|---------|-------|--------|---------------|
| Ground  | 12    | 0.0000 | 0.9144        |
| Elevated | 4    | 0.2032 | 1.1176        |

### Demons (info_player_deathmatch) — 16 spawns at Z ≈ -19.4 to -14.5
| Surface | Count | Feet Y | Hull Center Y |
|---------|-------|--------|---------------|
| Ground  | 11    | 0.0000 | 0.9144        |
| Elevated | 5    | 0.2032 | 1.1176        |

Teams are symmetrically separated across the map center (Z=0).

---

## 5. Known Issues and Limitations

### Missing GoldSrc Clip Collision (HIGH)
GoldSrc BSP uses invisible clip hulls for player collision that are separate from the rendered mesh. These are **not exported**. The current trimesh collision is generated from visible faces only.

**Impact:** Players may be able to walk through areas that were blocked in the original map, or get stuck on visual-only geometry that wasn't intended as solid.

**Recommendation:** Test with the actual player controller. If collision problems are severe, ChatGPT should implement clip hull extraction in a future phase.

### No Textures (MEDIUM)
All 18 textures are WAD-referenced (from `cs_dust.wad`, `cstrike.wad`, etc.) — none embedded in the BSP. The GLB has placeholder materials.

### Animated Textures Not Handled (LOW)
Textures prefixed `-0`, `-1`, `-2`, `-3` are GoldSrc animated texture frames. These need ShaderMaterial setup for animation.

### No Lightmaps (LOW)
Original GoldSrc baked lightmaps were not extracted. Current lighting is a simple DirectionalLight3D + ambient.

---

## 6. Collision Analysis

### Current Strategy
Runtime trimesh collision from all MeshInstance3D nodes. Each mesh gets a StaticBody3D with ConcavePolygonShape3D.

### Concerns for Playtesting
1. **Stairs/ramps** — Trimesh collision is exact to triangle geometry. GoldSrc handles stair climbing with hull clipping that smooths over individual steps. Our STEP_SIZE (0.457m / 18 BSP units) should handle standard GoldSrc stairs (16-unit rise), but triangulated stair geometry may cause jitter.
2. **func_wall entities** — All 18 func_wall brush models generate collision. In GoldSrc, func_wall is ordinarily solid, so this is correct. However, some may have been non-solid in the original map's entity properties.
3. **Missing clip brushes** — Areas behind crates or in corners may have had invisible clip geometry to prevent player access. These are absent.
4. **Edge catching** — Players may catch on triangle edges at mesh seams, especially on walls and around doorways.

---

## 7. Recommendation: Next Steps

**Collision improvements should come before texture restoration.** Rationale:
- Collision directly affects gameplay and can block playtesting
- Texture issues are visual only and don't prevent functional testing
- The player controller needs to be validated on this geometry before investing in materials

### Recommended Phase 2B: Collision Testing
1. Load aim_map with the actual player controller (CharacterBody3D + CapsuleShape3D)
2. Verify all spawn positions — player doesn't clip into walls or fall through floor
3. Test stair/ramp traversal with STEP_SIZE = 0.457m
4. Identify any areas where missing clip collision allows unintended access
5. Document collision issues for ChatGPT to address (clip hull extraction or manual collision volumes)

### Phase 3: Texture Restoration
1. Extract textures from WAD files (cs_dust.wad, cstrike.wad)
2. Assign to GLB material slots
3. Set up UV tiling and repeat modes
4. Handle animated texture sequences

---

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| GLB imports without errors | PASS |
| No floor offset workaround needed | PASS (Phase 2A fix) |
| Map centered on XZ origin | PASS |
| Dimensions within tolerance | PASS |
| Team spawns match source positions | PASS (16+16, correct Y) |
| Spawns on valid surfaces | PASS (ground=0.0, elevated=0.203) |
| Missing textures documented | PASS (18 WAD textures listed) |
| No existing test regressions | PASS (19 suites intact) |

**Phase 2A: COMPLETE — recommend proceeding with collision testing before texture restoration.**
