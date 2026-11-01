# Prototypes

Standalone Godot projects used for isolated feature exploration and visual validation.
Each prototype is a self-contained project with its own `project.godot`, scenes, scripts, and documentation.

## Directory Structure

```
Prototypes/
  Characters/
    v0.1/        Character Fit Prototype
    v0.1.1/      Character Fit Prototype (UID update)
    v0.2/        Shared Skeleton Prototype
    v0.2.1/      Shared Skeleton refinement
    v0.3/        Animation and Kneel Prototype
    v0.3.1/      Crouch update
    v0.3.2/      One-Knee Pose
    v0.3.3/      One-Knee Transition (animated)
    v0.3.4/      One-Knee Transition (refined)
    v0.3.5.1/    One-Knee Transition (iteration)
    v0.4/        Low Crouch Transition — active prototype
```

## Active Prototype

**v0.4** is the current active character prototype.
It replaces the one-knee kneel with a symmetrical low crouch, preserving the GoldSrc-mapped collision envelope.
See `Characters/v0.4/README.md` for controls and constraints.

## Historical Versions

Older versions (v0.1 through v0.3.5.1) are preserved as historical references.
They document the evolution from basic mannequin fitting through skeleton rigging, one-knee poses, and animated transitions.

### Known Naming Discrepancies

These discrepancies are preserved as-is from the original development:

- **v0.3**: Directory named `v0.3` but `project.godot` reports name as "v0.3.1".
- **v0.3.5.1**: Directory named `v0.3.5.1` but README and `project.godot` report "v0.3.4".

## Running a Prototype

1. Open the Godot Project Manager.
2. Import the `project.godot` file from the desired version directory.
3. Run the main scene (F5 or F6).

All prototypes target Godot 4.7 with GL Compatibility rendering.

## Validation

Prototypes are validated by a dedicated CI workflow (`prototype-validate.yml`) that is separate from production validation.
Prototype CI success does not constitute production integration approval.

Each prototype is validated independently in its own `--path` context using headless import and script compilation checks.

## Adding New Prototypes

Place new prototypes under the appropriate category directory (e.g., `Characters/`, `Weapons/`, `UI/`).
Each prototype must include its own `project.godot` and `README.md`.
Production CI excludes `Prototypes/` from resource-reference validation.
