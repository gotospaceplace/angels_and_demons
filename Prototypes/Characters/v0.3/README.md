# Angels and Demons — Animation and Kneel Prototype v0.3

Open `project.godot` with Godot 4 and run the main scene.

## Controls
- **C** crouch; **V** stand; **K** switch between one-knee kneel (default) and squat.
- **1** idle; **2** walk-in-place; **3** run-in-place; **4** jump preview.
- **R/T** start/stop rotation; **mouse wheel or +/-** zoom; **0** reset zoom.

## Changes
- Both faction mannequins use the same asymmetric one-knee kneel pose, with a comparison squat.
- Retains the validated floor-alignment correction from v0.2.1.
- Adds visual height/radius diagnostics compared to the 1.829 m standing and 0.914 m crouched capsule guides.

## Important limitations
- The one-knee pose is an experimental **visual pose** and may exceed the crouched 0.914 m hull; the diagnostic warns when this occurs. The pose is not approved for competitive gameplay until the actual skinned mesh fits the capsule in all poses.
- The torso/arms/legs are rigid bone attachments, not deforming skinned geometry. There is no foot IK, animation blending, real collision shape, weapon aiming or network gameplay.
- The guide is not a physics collider. Test in your own Godot installation; this ZIP has not been runtime tested here.
- A genuine one-knee kneel that remains under 0.914 m may require deep torso folding, proportion adjustments, or a compromise pose. Do not enlarge the collision capsule to accommodate cosmetics.
