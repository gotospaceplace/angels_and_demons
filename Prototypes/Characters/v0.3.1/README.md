# Angels and Demons — Character Prototype v0.3.1

Standalone Godot 4 project. Import `project.godot` and run.

## Updated crouch
- **C**: One-knee crouch: **left foot forward, right knee on the floor**.
- **K**: Toggle one-knee and squat comparison.
- **V**: Stand.
- Standing guide: 1.829 m high, 0.700 m diameter; centered Y = 0.9145 m.
- Crouch guide: 0.914 m high, 0.700 m diameter; centered Y = 0.457 m.
- Capsule is anchored to floor, independent of skeleton and foot placement.
- Left knee/foot may protrude beyond the capsule in this visual preview; the game must separately determine hit registration and cover behavior.

## Other controls
1 Idle, 2 Walk, 3 Run, 4 Jump; R rotate, T stop; mouse wheel / +/- zoom, 0 reset.

## Prototype limitations
This uses rigid meshes attached to procedural bones, not a skinned mesh or IK. The pose is an experimental approximation, not a validated anatomical kneel; the actual knee-floor contact and exact capsule clearance need Godot-side inspection. The translucent capsule is a visual reference, not a gameplay collision body. This build has not been runtime-tested here.
