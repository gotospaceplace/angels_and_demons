# Angels and Demons — One-Knee Transition Prototype v0.3.3

Standalone Godot 4 project. Open `project.godot` and run the main scene.

## Controls
- `C`: Transition into one-knee pose (left foot forward, right knee down)
- `V`: Return to standing
- `1`: Front camera
- `2`: Left side camera
- `3`: Rear camera
- `R` / `T`: Start/stop mannequin rotation
- Mouse wheel or `+` / `-`: Zoom
- `0`: Reset zoom

## Changes from v0.3.2
- 0.48-second eased pose transition, reversible mid-transition.
- Explicit front/side/rear camera presets.
- Height-clearance *estimate* including helmet accessories.
- Preserves v0.3.2 fixed joint-target kneeling pose and grounded capsule guide.

## Known limitations
- Rigid segments are placed between explicit joint targets, not a skinned rig or inverse-kinematics solution.
- **Height-limit warning is expected**: the approved concept halo/horns can extend beyond the 0.914 m crouched hull; the estimate is not a complete geometry-bounds validation.
- The capsule is only a visualization, not a real collision shape. The extended left knee is permitted outside the guide for this design test.
- Foot contact, joint deformation, animation blending and multiplayer gameplay are not implemented.
- This prototype has not been run-tested by the assistant in Godot; please verify in the editor.
