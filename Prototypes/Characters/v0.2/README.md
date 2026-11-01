# Angels and Demons — Shared Skeleton Prototype v0.2

Standalone Godot 4 project. Open `project.godot` and run the main scene.

## Controls
- `1`: Idle
- `2`: Walk-in-place
- `3`: Run-in-place
- `4`: Jump preview
- `C`: Crouch bone pose
- `V`: Stand
- `R`: Rotate character views
- `T`: Stop rotation
- Mouse wheel / `+` / `-`: Zoom
- `0`: Reset zoom

## What is implemented
- Both factions use identical `Skeleton3D` bone names, hierarchy and rest transforms.
- Torso, head, upper/lower arms, upper/lower legs and boots follow the bones using `BoneAttachment3D`.
- Procedural animation poses and joint-based crouching; no whole-body scale compression.
- Standing/crouch visual capsule guides and original camera controls.

## Known limitations
- Mannequins are **rigid bone attachments**, not skinned meshes or production animations.
- Animation poses are illustrative; visual geometry clearance and foot contact are NOT guaranteed.
- The collision capsule is a visual guide, not an actual CharacterBody3D collision shape.
- No network gameplay, hitboxes, authored AnimationPlayer clips or animation blending.
- Needs user-side Godot runtime testing.
