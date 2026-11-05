# aim_map Phase 2C — Texture Restoration Report

## Summary

Phase 2C adds original WAD textures from `cs_dust.wad` to the aim_map GLB. The 15 visible textures are embedded as glTF PBR materials with PNG base color images. Geometry, collision, spawns, and coordinate system are unchanged from Phase 2B.

## GLB Comparison

| Property | Phase 2B | Phase 2C |
|---|---|---|
| File size | 151,776 bytes | 851,448 bytes |
| Mesh nodes | 47 | 47 |
| Triangles | 2,490 | 2,490 |
| Materials | 20 (placeholder) | 20 (15 textured + 5 non-visible) |
| Winding corrections | 2,308 | 2,308 (unchanged) |
| Vertex bounds | Same | Same |

## Texture Assignment

All 15 visible material slots have embedded PNG textures sourced from `cs_dust.wad`:

| Material | Resolution | Source | Triangles |
|---|---|---|---|
| SandTrim | 96x32 | cs_dust.wad | 687 |
| -0csSandWall | 128x240 | cs_dust.wad | 454 |
| SandCCrete | 256x192 | cs_dust.wad | 392 |
| -3Sand | 128x128 | cs_dust.wad | 249 |
| -1csSandWall | 128x240 | cs_dust.wad | 232 |
| SandCrtLrgSd | 128x128 | cs_dust.wad | 197 |
| SandCrtSmSd | 64x64 | cs_dust.wad | 84 |
| SandCrtLrgTp | 128x128 | cs_dust.wad | 62 |
| MltryCrteSd2 | 64x64 | cs_dust.wad | 40 |
| -0Sand | 128x128 | cs_dust.wad | 33 |
| SandWllWndw | 128x240 | cs_dust.wad | 32 |
| SandWllDoor | 192x160 | cs_dust.wad | 20 |
| MltryCrteTp | 64x64 | cs_dust.wad | 8 |
| -1Sand | 128x128 | cs_dust.wad | — |
| -2Sand | 128x128 | cs_dust.wad | — |

Three non-visible textures are excluded (no replacement needed):
- `sky` — skybox texture, not rendered as geometry
- `aaatrigger` — GoldSrc trigger texture, invisible
- `xcrate9d` — not used on visible geometry

## Collision Verification

**40/40 aim_map collision tests PASS** with the textured GLB:
- 32 spawn drop tests: all players settle correctly
- 6 crate top tests: all crate surfaces have collision
- Walk-on-ground test: PASS
- Wall collision test: PASS

Collision uses single-sided trimesh (`backface_collision = false`), unchanged from Phase 2B.

## Existing Test Suites

- **Movement tests**: 12/12 PASS — no regression
- **Script validation**: 98 scripts, 0 errors — no compilation issues

## Known Limitations

1. **No WAD animation**: Textures with frame prefixes (`-0`, `-1`, `-2`, `-3`) are static. The GoldSrc animated texture sequence is not implemented.
2. **No lightmaps**: Original GoldSrc lightmaps are not transferred. Godot lighting is placeholder (DirectionalLight3D sun + WorldEnvironment).
3. **UV tiling**: BSP texinfo UV coordinates may extend outside [0,1] to tile. Godot's default wrap mode (repeat) handles this, but visual verification is recommended.
4. **Texture filtering**: Godot's default linear filtering may soften the low-res textures. Nearest-neighbor filtering could be applied for a crisper retro look.
5. **Missing clip hulls**: GoldSrc invisible collision geometry is not exported (same as Phase 2B).
6. **Copyright**: These are original Counter-Strike WAD assets. Use for local prototyping only unless redistribution rights are confirmed.

## Verdict

Phase 2C texture restoration is complete. All 15 visible materials have correct WAD textures embedded in the GLB. Collision behavior is identical to Phase 2B. Visual playtest recommended to verify UV orientation and texture appearance in-engine.
