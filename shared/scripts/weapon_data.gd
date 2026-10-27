class_name WeaponData
extends Resource

@export var weapon_name: String = ""
@export var slot: int = 0  # 0=knife, 1=pistol, 2=primary

# --- Damage ---
@export var base_damage: float = 0.0
@export var range_modifier: float = 1.0  # per 500 GoldSrc units (12.7m)
@export var penetration_level: int = 0  # 0=none, 1=pistol, 2=rifle, 3=sniper
@export var armor_penetration: float = 0.0

# --- Timing ---
@export var cycle_time: float = 0.1
@export var reload_time: float = 2.0
@export var draw_time: float = 1.0
@export var holster_time: float = 0.3

# --- Ammo ---
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var is_automatic: bool = true

# --- Movement ---
@export var max_speed: float = 6.35  # Godot m/s

# --- Spread ---
# For Rifle: multiplied by accuracy value
# For Pistol: multiplied by (1 - accuracy)
# For None (fixed): used directly
@export var spread_standing: float = 0.0
@export var spread_crouching: float = 0.0
@export var spread_moving: float = 0.0
@export var spread_airborne: float = 0.0
@export var spread_base_moving: float = 0.0  # constant added to moving spread (rifles)
@export var spread_base_airborne: float = 0.0  # constant added to airborne spread (rifles)
@export var moving_threshold: float = 140.0  # GoldSrc u/s; 0 = any movement

# --- Accuracy degradation ---
@export_enum("None", "Rifle", "Pistol") var accuracy_type: int = 0
@export var accuracy_deploy: float = 0.2  # initial value on draw/reload
@export var accuracy_offset: float = 0.35  # constant in cubic formula
@export var accuracy_divisor: float = 200.0  # cubic divisor
@export var accuracy_cap: float = 1.25

# --- Recoil KickBack [up_base, lat_base, up_mod, lat_mod, up_max, lat_max, dir_change] ---
@export var recoil_standing := PackedFloat64Array()
@export var recoil_crouching := PackedFloat64Array()
@export var recoil_moving := PackedFloat64Array()
@export var recoil_airborne := PackedFloat64Array()

# --- Scope ---
@export var has_scope: bool = false
@export var zoom_fov_1: float = 40.0
@export var zoom_fov_2: float = 10.0
@export var scoped_max_speed: float = 3.81

# --- Silencer ---
@export var has_silencer: bool = false
@export var silencer_toggle_time: float = 0.0
@export var silenced_damage: float = 0.0
@export var silenced_range_modifier: float = 1.0
@export var silenced_spread_standing: float = 0.0
@export var silenced_spread_crouching: float = 0.0
@export var silenced_spread_moving: float = 0.0
@export var silenced_spread_airborne: float = 0.0

# --- Melee ---
@export var is_melee: bool = false
@export var melee_range: float = 2.0
