class_name WeaponRegistry
extends RefCounted

const MC := preload("res://shared/scripts/movement_constants.gd")
const WD := preload("res://shared/scripts/weapon_data.gd")

static func create_all() -> Array:
	return [_knife(), _usp(), _ak47(), _m4a1(), _awp()]


static func _knife() -> Resource:
	var w = WD.new()
	w.weapon_name = "Knife"
	w.slot = 0
	w.is_melee = true
	w.melee_range = 2.0
	w.base_damage = 40.0
	w.range_modifier = 1.0
	w.cycle_time = 0.4
	w.reload_time = 0.0
	w.draw_time = 0.5
	w.holster_time = 0.3
	w.magazine_size = 0
	w.reserve_ammo = 0
	w.is_automatic = false
	w.max_speed = MC.SPEED_KNIFE
	w.armor_penetration = 1.0
	w.accuracy_type = 0  # None
	return w


static func _usp() -> Resource:
	var w = WD.new()
	w.weapon_name = "USP"
	w.slot = 1
	w.base_damage = 34.0
	w.range_modifier = 0.79
	w.penetration_level = 1
	w.armor_penetration = 0.5
	w.cycle_time = 0.15
	w.reload_time = 2.7
	w.draw_time = 0.8
	w.holster_time = 0.3
	w.magazine_size = 12
	w.reserve_ammo = 100
	w.is_automatic = false
	w.max_speed = MC.SPEED_PISTOL
	w.moving_threshold = 0.0  # any movement
	# Pistol spread: multiply by (1 - accuracy)
	w.spread_standing = 0.1
	w.spread_crouching = 0.08
	w.spread_moving = 0.225
	w.spread_airborne = 1.2
	w.accuracy_type = 2  # Pistol
	w.accuracy_deploy = 0.92
	# Recoil: fixed 2° up per shot
	w.recoil_standing = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_crouching = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_moving = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_airborne = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	# Silencer
	w.has_silencer = true
	w.silenced_damage = 30.0
	w.silenced_range_modifier = 0.79
	w.silenced_spread_standing = 0.15
	w.silenced_spread_crouching = 0.125
	w.silenced_spread_moving = 0.25
	w.silenced_spread_airborne = 1.3
	return w


static func _ak47() -> Resource:
	var w = WD.new()
	w.weapon_name = "AK-47"
	w.slot = 2
	w.base_damage = 36.0
	w.range_modifier = 0.98
	w.penetration_level = 2
	w.armor_penetration = 0.77
	w.cycle_time = 0.0955
	w.reload_time = 2.45
	w.draw_time = 1.2
	w.holster_time = 0.3
	w.magazine_size = 30
	w.reserve_ammo = 90
	w.is_automatic = true
	w.max_speed = MC.SPEED_AK47
	# Rifle spread: multiply by accuracy
	w.spread_standing = 0.0275
	w.spread_crouching = 0.0275
	w.spread_moving = 0.07
	w.spread_airborne = 0.4
	w.spread_base_moving = 0.04
	w.spread_base_airborne = 0.04
	w.accuracy_type = 1  # Rifle
	w.accuracy_deploy = 0.2
	w.accuracy_offset = 0.35
	w.accuracy_divisor = 200.0
	w.accuracy_cap = 1.25
	# Recoil [up_base, lat_base, up_mod, lat_mod, up_max, lat_max, dir_change]
	w.recoil_standing = PackedFloat64Array([1.0, 0.375, 0.175, 0.0375, 5.75, 1.75, 8])
	w.recoil_crouching = PackedFloat64Array([0.9, 0.35, 0.15, 0.025, 5.5, 1.5, 9])
	w.recoil_moving = PackedFloat64Array([1.5, 0.45, 0.225, 0.05, 6.5, 2.5, 7])
	w.recoil_airborne = PackedFloat64Array([2.0, 1.0, 0.5, 0.35, 9.0, 6.0, 5])
	return w


static func _m4a1() -> Resource:
	var w = WD.new()
	w.weapon_name = "M4A1"
	w.slot = 2
	w.base_damage = 32.0
	w.range_modifier = 0.97
	w.penetration_level = 2
	w.armor_penetration = 0.69
	w.cycle_time = 0.0875
	w.reload_time = 3.05
	w.draw_time = 1.2
	w.holster_time = 0.3
	w.magazine_size = 30
	w.reserve_ammo = 90
	w.is_automatic = true
	w.max_speed = MC.SPEED_M4A1
	w.spread_standing = 0.02
	w.spread_crouching = 0.02
	w.spread_moving = 0.07
	w.spread_airborne = 0.4
	w.spread_base_moving = 0.035
	w.spread_base_airborne = 0.035
	w.accuracy_type = 1  # Rifle
	w.accuracy_deploy = 0.2
	w.accuracy_offset = 0.3
	w.accuracy_divisor = 220.0
	w.accuracy_cap = 1.0
	w.recoil_standing = PackedFloat64Array([0.65, 0.35, 0.25, 0.015, 3.5, 2.25, 7])
	w.recoil_crouching = PackedFloat64Array([0.6, 0.3, 0.2, 0.0125, 3.25, 2.0, 7])
	w.recoil_moving = PackedFloat64Array([1.0, 0.45, 0.28, 0.045, 3.75, 3.0, 7])
	w.recoil_airborne = PackedFloat64Array([1.2, 0.5, 0.23, 0.15, 5.5, 3.5, 6])
	# Silencer
	w.has_silencer = true
	w.silenced_damage = 33.0
	w.silenced_range_modifier = 0.95
	w.silenced_spread_standing = 0.025
	w.silenced_spread_crouching = 0.025
	w.silenced_spread_moving = 0.07
	w.silenced_spread_airborne = 0.4
	return w


static func _awp() -> Resource:
	var w = WD.new()
	w.weapon_name = "AWP"
	w.slot = 2
	w.base_damage = 115.0
	w.range_modifier = 0.99
	w.penetration_level = 3
	w.armor_penetration = 0.975
	w.cycle_time = 1.45
	w.reload_time = 2.5
	w.draw_time = 1.5
	w.holster_time = 0.3
	w.magazine_size = 10
	w.reserve_ammo = 30
	w.is_automatic = false
	w.max_speed = MC.SPEED_AWP
	# Fixed spread (scoped values — unscoped adds +0.08 in weapon_system)
	w.spread_standing = 0.001
	w.spread_crouching = 0.0
	w.spread_moving = 0.25
	w.spread_airborne = 0.85
	w.accuracy_type = 0  # None (fixed)
	w.recoil_standing = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_crouching = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_moving = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.recoil_airborne = PackedFloat64Array([2.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0])
	w.has_scope = true
	w.zoom_fov_1 = 40.0
	w.zoom_fov_2 = 10.0
	w.scoped_max_speed = MC.SPEED_AWP_ZOOMED
	return w
