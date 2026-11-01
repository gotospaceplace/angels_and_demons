# Angels and Demons — Character Prototype v0.3.4

Godot 4 standalone debug project. Import `project.godot` and run.

## Controls
- `C` kneel (left foot forward, right knee down); `V` stand
- `1` front, `2` side, `3` rear; `R` rotate, `T` stop
- Mouse wheel / +/- zoom; `0` reset
- `B` show/hide blue movement capsule
- `H` show/hide red illustrative damage hitboxes
- `G` show/hide gold halo or red horns (cosmetic attachments)

## Approved gameplay decision
Horns and halos are **not damageable**. Both factions use identical movement dimensions and hitbox layout. Cosmetic geometry is not a source of damage or collision advantage.

## Prototype limits
The blue capsule is a MeshInstance3D **visual guide**, not a physics CapsuleShape3D. Red zones are **visual guides**, not collision shapes or active damage detection. This project does not prove hitbox alignment, network authority, line-of-sight behavior, or headshot accuracy. Head accessories may extend beyond the visual crouch height; final clearance and cover tests are still required. The original standing/crouch limits are unchanged (1.829m / 0.914m; 0.35m radius).

## v0.3.5.1 hotfix
- Declares `hitbox_group` and `HITBOX_NAMES` for the J key.
- Applies intended per-part widths to red hitbox meshes.
- Adds actual per-region visibility filtering and reduces red opacity.
- This is still a visual-only prototype; Godot runtime verification is pending.
