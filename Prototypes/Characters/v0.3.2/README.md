# Angels and Demons — One-knee pose v0.3.2

## Run
Extract into its own folder; import `project.godot` in Godot 4 and press Play.

## Controls
- C: one-knee pose (left foot forward, right knee down)
- V: stand
- R/T: rotate/stop rotation
- Mouse wheel or +/-: zoom
- 0: reset zoom

## Changes
Rebuilt the pose using explicit joint positions rather than independent bone rotations. Both faction mannequins use identical coordinates. The crouch capsule is a separate floor-anchored visual guide, 0.914m tall and 0.70m diameter. Standing guide is 1.829m tall.

## Important limitations
This version is **a pose geometry validation prototype**, not a rigged, skinned or network-ready character. It intentionally uses rigid boxes between joints, and the forward leg is allowed to protrude beyond the gameplay capsule. There is no IK solver, foot contact physics, hitbox verification or combat animation. Geometry/halo clearance must be visually confirmed in Godot. The character height target in the pose is about 0.86m, but it is not a guaranteed measured bounding box. No Godot runtime was available in the authoring environment.
