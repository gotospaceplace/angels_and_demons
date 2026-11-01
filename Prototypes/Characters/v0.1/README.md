# Angels and Demons — Character Fit Prototype v0.1

Open this folder as a Godot 4.2+ project and run (F6/F5). The scene builds two simplified mannequin figures: **A1 Templar** and **D1 Brute**, each within a visual standing collision reference. No external assets are required.

## Controls
- **C**: crouch *preview* (simple vertical compression, NOT a real crouch animation)
- **V**: standing
- **R**: rotate both visual mannequins
- **T**: stop rotation

## Locked reference dimensions
- Standing capsule: 1.829 m high, radius 0.35 m (diameter 0.7 m)
- Crouch capsule: 0.914 m high
- Target visible head top: ~1.75 m
- Target third-person model: 3,000–5,500 triangles (these primitive mannequins are **not** production meshes)

## IMPORTANT: Not yet validated
This is a standalone *illustrative* Godot project, not a tested integration into your actual repository. Godot is not available in the authoring environment, so you must run and test it locally. The mannequin uses static boxes rather than a skeleton; the crouch key scales the visual rather than bending knees. The reference capsule is a transparent MeshInstance3D, not a CollisionShape3D, and it is not the combat hitbox. The silhouette may exceed capsule curvature at some corners; the actual artist models need per-pose capsule-fit validation.

## Integration workflow
1. Open the standalone project in Godot and check scene loads.
2. Compare real `movement_constants.gd` values and `remote_player.gd` transforms to the supplied specification; update this reference if discrepancies exist.
3. Replace primitive body with one shared skeleton, with explicit bones for torso, arms, legs, neck and head.
4. Create actual idle/run/strafe/jump/crouch test animations; verify vertices remain inside collision envelope in all required poses.
5. Attach A1 and D1 cosmetic meshes to the same skeleton and run identical gameplay hitbox validation.
6. Only after the rig is validated, commission detailed 3D meshes and textures.

No existing repository files are modified.
