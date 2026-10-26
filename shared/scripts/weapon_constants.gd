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

# Wall penetration damage retention per level (WB5 — stubbed)
const WALL_PEN_RETENTION := {
	0: 0.0,   # none
	1: 0.0,   # pistol — no penetration
	2: 0.46,  # rifle
	3: 0.49,  # sniper
}

# Armor absorption rate
const ARMOR_ABSORB_RATE := 0.5

# Max hitscan range in GoldSrc units
const MAX_HITSCAN_RANGE := 4096.0

# Unscoped spread penalty for AWP
const AWP_UNSCOPED_SPREAD := 0.08
