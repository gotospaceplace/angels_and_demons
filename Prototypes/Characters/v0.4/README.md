# Angels and Demons — Character Prototype v0.4

Standalone Godot 4 project. Import `project.godot` in Godot Project Manager.

## Purpose
Replace the retired one-knee kneel with a symmetrical low crouch, preserving the original GoldSrc-mapped collision envelope and visual hitbox comparison.

## Controls
- `C`: Low crouch; `V`: Stand
- `B`: Toggle blue movement capsule; `H`: Toggle red damage zones
- `J`: Cycle damage zones (all/head/torso/arms/legs)
- `G`: Toggle non-targetable horn/halo cosmetics
- `1`, `2`, `3`: Front, side, rear
- `R`, `T`: Rotate / stop
- Mouse wheel or `+`/`-`: Zoom; `0`: Reset

## Constraints
- Standing capsule: 1.829m high x 0.700m diameter.
- Crouched capsule: 0.914m high x 0.700m diameter.
- Both teams use exactly the same pose and debug damage zones.
- Horns and halos are non-targetable cosmetic elements.

## Limitations
- This is a **visual prototype** with explicit joint-target mannequin parts, not a skinned skeleton or functional damage detection.
- The capsule is a visual guide, not a collision shape.
- Crouch transition uses interpolated joint coordinates and requires visual validation.
- Cosmetic height overrun is indicated, not automatically corrected.
- Not run-tested in Godot in the build environment.
