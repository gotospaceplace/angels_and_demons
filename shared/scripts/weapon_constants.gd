class_name WeaponConstants
extends RefCounted

const HITGROUP_MULTIPLIERS := {
	"head": 4.0,
	"chest": 1.0,
	"stomach": 1.25,
	"arms": 1.0,
	"legs": 0.75,
}

# Distance unit for range_modifier exponent (GoldSrc units)
const RANGE_UNIT := 500.0

# Wall penetration damage retention per level
const WALL_PEN_RETENTION := {
	0: 0.0,   # none
	1: 0.0,   # pistol — no penetration
	2: 0.46,  # rifle
	3: 0.49,  # sniper
}

# Max wall thickness (Godot meters) a bullet can penetrate per tier
const PEN_MAX_DEPTH := {
	2: 0.4,   # rifle — ~16 GoldSrc units
	3: 0.6,   # sniper — ~24 GoldSrc units
}

# Armor absorption rate
const ARMOR_ABSORB_RATE := 0.5

# Max hitscan range in GoldSrc units
const MAX_HITSCAN_RANGE := 4096.0

# Unscoped spread penalty for AWP
const AWP_UNSCOPED_SPREAD := 0.08

# --- HE Grenade ---
const HE_DAMAGE := 100.0
const HE_BLAST_RADIUS_GSRC := 350.0  # GoldSrc units
const HE_ARMOR_PEN := 0.5

# --- Grenade throw ---
const GRENADE_FUSE := 3.5             # seconds (A&D cooking: starts on pin pull)
const GRENADE_SPAWN_OFFSET := 0.406   # 16 GoldSrc units in front of eye
const GRENADE_MAX_VEL_GSRC := 750.0   # cap on throw speed
const GRENADE_SHORT_TOSS_MULT := 0.33 # right-click toss velocity multiplier
const GRENADE_BOUNCE := 0.45          # restitution coefficient
const GRENADE_FRICTION := 0.6

# --- Flash grenade ---
const FLASH_ANGLES := [0.0, 45.0, 90.0, 180.0]
const FLASH_BLIND := [3.0, 2.3, 1.9, 0.0]
const FLASH_FADE := [5.7, 4.5, 2.8, 0.0]
const FLASH_TINT_TIME := 0.3
