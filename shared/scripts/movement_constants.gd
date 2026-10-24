class_name MovementConstants
extends RefCounted

# Unit conversion: 1 Godot meter = 39.37 GoldSrc units
const UNITS_PER_METER := 39.37
const METERS_PER_UNIT := 1.0 / UNITS_PER_METER

# --- Gravity ---
# GoldSrc: sv_gravity = 800 u/s²
const GRAVITY := 800.0 * METERS_PER_UNIT  # 20.32 m/s²

# --- Friction ---
# GoldSrc: sv_friction = 4 (dimensionless)
const FRICTION := 4.0
# GoldSrc: sv_stopspeed = 75 u/s
const STOPSPEED := 75.0 * METERS_PER_UNIT  # 1.905 m/s
# GoldSrc: edgefriction = 2 (multiplier)
const EDGE_FRICTION := 2.0
# GoldSrc: STOP_EPSILON = 0.1 u/s
const STOP_EPSILON := 0.1 * METERS_PER_UNIT  # ~0.00254 m/s

# --- Acceleration ---
# GoldSrc: sv_accelerate = 10 (dimensionless)
const ACCELERATE := 10.0
# GoldSrc: sv_airaccelerate = 10 (dimensionless)
const AIR_ACCELERATE := 10.0
# GoldSrc: air wishspd cap = 30 u/s
const AIR_SPEED_CAP := 30.0 * METERS_PER_UNIT  # 0.762 m/s

# --- Jumping ---
# GoldSrc: sqrt(2 * 800 * 45) ≈ 268.33 u/s
const JUMP_SPEED := 268.33 * METERS_PER_UNIT  # 6.815 m/s

# --- Stepping ---
# GoldSrc: sv_stepsize = 18 u
const STEP_SIZE := 18.0 * METERS_PER_UNIT  # 0.457 m

# --- Hull dimensions ---
# GoldSrc: standing hull height = 72 u (from -36 to 36)
const HULL_STANDING_HEIGHT := 72.0 * METERS_PER_UNIT  # 1.829 m
# GoldSrc: ducked hull height = 36 u (from -18 to 18)
const HULL_DUCKING_HEIGHT := 36.0 * METERS_PER_UNIT  # 0.914 m
# GoldSrc: hull width = 32 u (radius 16)
const HULL_RADIUS := 16.0 * METERS_PER_UNIT  # 0.406 m → use capsule radius 0.35

# --- Eye heights (offset from hull center) ---
# GoldSrc: VEC_VIEW = 28 u
const VIEW_OFFSET_STANDING := 28.0 * METERS_PER_UNIT  # 0.711 m
# GoldSrc: VEC_DUCK_VIEW = 12 u
const VIEW_OFFSET_DUCKING := 12.0 * METERS_PER_UNIT  # 0.305 m

# --- Ducking ---
# GoldSrc: TIME_TO_DUCK = 0.4 s
const DUCK_TIME := 0.4
# GoldSrc: PLAYER_DUCKING_MULTIPLIER = 0.333
const DUCKING_MULTIPLIER := 0.333

# --- Bunny hop (A&D modified) ---
# GoldSrc CS 1.6: BUNNYJUMP_MAX_SPEED_FACTOR = 1.2
# A&D uses progressive degradation instead of hard cap
const BHOP_FREE_HOPS := 2          # full speed preservation for first N hops
const BHOP_DEGRADATION_RATE := 0.12 # speed factor lost per hop after free hops
const BHOP_MIN_SPEED_FACTOR := 0.8  # floor on degradation (never below 80% of maxspeed)

# --- Ladder ---
# GoldSrc: MAX_CLIMB_SPEED = 200 u/s
# A&D: enforce this cap (unlike CS 1.6 which allows exploits above it)
const MAX_CLIMB_SPEED := 200.0 * METERS_PER_UNIT  # 5.08 m/s

# --- Per-weapon maxspeed (Godot m/s) ---
# GoldSrc values from ReGameDLL weapons.h
const SPEED_KNIFE := 250.0 * METERS_PER_UNIT     # 6.35 m/s
const SPEED_PISTOL := 250.0 * METERS_PER_UNIT    # 6.35 m/s
const SPEED_SMG := 250.0 * METERS_PER_UNIT       # 6.35 m/s
const SPEED_SCOUT := 260.0 * METERS_PER_UNIT     # 6.60 m/s
const SPEED_P90 := 245.0 * METERS_PER_UNIT       # 6.22 m/s
const SPEED_GALIL := 240.0 * METERS_PER_UNIT     # 6.10 m/s
const SPEED_SG552 := 235.0 * METERS_PER_UNIT     # 5.97 m/s
const SPEED_M4A1 := 230.0 * METERS_PER_UNIT      # 5.84 m/s
const SPEED_AK47 := 221.0 * METERS_PER_UNIT      # 5.61 m/s
const SPEED_M249 := 220.0 * METERS_PER_UNIT      # 5.59 m/s
const SPEED_AWP := 210.0 * METERS_PER_UNIT        # 5.33 m/s
const SPEED_AWP_ZOOMED := 150.0 * METERS_PER_UNIT # 3.81 m/s

# --- Gameplay thresholds ---
# GoldSrc: 140 u/s movement inaccuracy threshold
const INACCURACY_SPEED_THRESHOLD := 140.0 * METERS_PER_UNIT  # 3.556 m/s

# --- Ground detection ---
const GROUND_TRACE_DIST := 2.0 * METERS_PER_UNIT  # 0.051 m
const FLOOR_NORMAL_MIN := 0.7  # normal.y >= 0.7 for walkable surface (~45°)

# --- Edge friction trace ---
const EDGE_FRICTION_TRACE_DIST := 16.0 * METERS_PER_UNIT  # 0.406 m ahead
