extends RefCounted

const MC = preload("res://shared/scripts/movement_constants.gd")
const WC = preload("res://shared/scripts/weapon_constants.gd")
const WR = preload("res://shared/scripts/weapon_registry.gd")

const HISTORY_SIZE := 32
const INTERP_TICKS := 13
const HEAD_RADIUS := 0.15
const BODY_RADIUS := 0.35

var history: Array = []
var weapons: Array = []


func _init() -> void:
	weapons = WR.create_all()


func store_tick(tick: int, players: Dictionary) -> void:
	var entry := {"tick": tick, "players": {}}
	for pid in players:
		var sp = players[pid]
		if sp.is_dead:
			continue
		entry["players"][pid] = {
			"position": sp.body.global_position,
			"is_ducked": sp.body.is_ducked,
		}
	history.append(entry)
	if history.size() > HISTORY_SIZE:
		history.pop_front()


func get_weapon(idx: int):
	if idx >= 0 and idx < weapons.size():
		return weapons[idx]
	return weapons[2]


func process_fire(shooter_id: int, cmd: NetInput, current_tick: int,
		players: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var shooter_sp = players.get(shooter_id)
	if not shooter_sp or shooter_sp.is_dead:
		return {}

	var rewind_tick := cmd.tick - INTERP_TICKS
	var min_tick := current_tick - NetConstants.MAX_REWIND_TICKS
	rewind_tick = maxi(rewind_tick, min_tick)

	var state := _find_closest_state(rewind_tick)
	if state.is_empty():
		return {}

	var is_ducked: bool = shooter_sp.body.is_ducked
	var view_offset: float = MC.VIEW_OFFSET_DUCKING if is_ducked else MC.VIEW_OFFSET_STANDING
	var eye_pos: Vector3 = Vector3(shooter_sp.body.global_position) + Vector3(0, view_offset, 0)

	var yaw_rad := deg_to_rad(cmd.yaw)
	var pitch_rad := deg_to_rad(cmd.pitch)
	var direction := Vector3(
		-sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		-cos(yaw_rad) * cos(pitch_rad)
	).normalized()

	var weapon = get_weapon(shooter_sp.weapon_idx)
	var max_range: float
	if weapon.is_melee:
		max_range = weapon.melee_range
	else:
		max_range = WC.MAX_HITSCAN_RANGE / MC.UNITS_PER_METER

	var world_dist := max_range
	var params := PhysicsRayQueryParameters3D.create(
		eye_pos, eye_pos + direction * max_range)
	params.collision_mask = 1
	var excludes: Array[RID] = [shooter_sp.body.get_rid()]
	for sp in players.values():
		excludes.append(sp.body.get_rid())
	params.exclude = excludes
	var world_result := space.intersect_ray(params)
	if world_result:
		world_dist = eye_pos.distance_to(world_result["position"])

	var best_hit := {}
	var best_dist := world_dist

	for pid in state["players"]:
		if pid == shooter_id:
			continue
		if not players.has(pid):
			continue

		var ps: Dictionary = state["players"][pid]
		var target_pos: Vector3 = ps["position"]
		var target_ducked: bool = ps["is_ducked"]
		var hull_h: float = MC.HULL_DUCKING_HEIGHT if target_ducked else MC.HULL_STANDING_HEIGHT
		var head_off: float = MC.VIEW_OFFSET_DUCKING if target_ducked else MC.VIEW_OFFSET_STANDING

		var t := _ray_capsule_vertical(eye_pos, direction, target_pos, hull_h, BODY_RADIUS)
		if t <= 0 or t >= best_dist:
			continue

		var hit_y: float = eye_pos.y + direction.y * t
		var rel_y: float = hit_y - target_pos.y
		var head_threshold := head_off - HEAD_RADIUS

		var hitgroup: String
		var headshot: bool
		if rel_y > head_threshold:
			hitgroup = "head"
			headshot = true
		elif rel_y > 0.0:
			hitgroup = "chest"
			headshot = false
		elif rel_y > -hull_h * 0.15:
			hitgroup = "stomach"
			headshot = false
		else:
			hitgroup = "legs"
			headshot = false

		best_dist = t
		best_hit = {
			"hit": true,
			"victim_id": pid,
			"hitgroup": hitgroup,
			"headshot": headshot,
			"distance": t,
		}

	if best_hit.is_empty():
		return {}

	var dist_gsrc: float = best_hit["distance"] * MC.UNITS_PER_METER
	var hitgroup_mult: float = WC.HITGROUP_MULTIPLIERS.get(best_hit["hitgroup"], 1.0)
	var range_factor := pow(weapon.range_modifier, dist_gsrc / WC.RANGE_UNIT)
	best_hit["damage"] = weapon.base_damage * range_factor * hitgroup_mult
	best_hit["weapon_idx"] = shooter_sp.weapon_idx

	return best_hit


func _find_closest_state(target_tick: int) -> Dictionary:
	var best := {}
	var best_diff := 999999
	for entry in history:
		var diff := absi(entry["tick"] - target_tick)
		if diff < best_diff:
			best_diff = diff
			best = entry
	return best


static func _ray_capsule_vertical(origin: Vector3, dir: Vector3,
		cap_center: Vector3, height: float, radius: float) -> float:
	var half_h := height * 0.5
	var cy_bottom := cap_center.y - half_h + radius
	var cy_top := cap_center.y + half_h - radius
	var cx := cap_center.x
	var cz := cap_center.z

	var best_t := -1.0

	var dx := origin.x - cx
	var dz := origin.z - cz
	var a := dir.x * dir.x + dir.z * dir.z
	var b_val := 2.0 * (dx * dir.x + dz * dir.z)
	var c := dx * dx + dz * dz - radius * radius

	if a > 0.00001:
		var disc := b_val * b_val - 4.0 * a * c
		if disc >= 0:
			var sqrt_d := sqrt(disc)
			var t1 := (-b_val - sqrt_d) / (2.0 * a)
			var t2 := (-b_val + sqrt_d) / (2.0 * a)
			for t in [t1, t2]:
				if t > 0.001:
					var hit_y: float = origin.y + dir.y * float(t)
					if hit_y >= cy_bottom and hit_y <= cy_top:
						if best_t < 0 or t < best_t:
							best_t = t

	var bottom_center := Vector3(cx, cy_bottom, cz)
	var top_center := Vector3(cx, cy_top, cz)

	var tb := _ray_sphere_hit(origin, dir, bottom_center, radius)
	if tb > 0.001:
		var hit_y_b: float = origin.y + dir.y * tb
		if hit_y_b <= cy_bottom:
			if best_t < 0 or tb < best_t:
				best_t = tb

	var tt := _ray_sphere_hit(origin, dir, top_center, radius)
	if tt > 0.001:
		var hit_y_t: float = origin.y + dir.y * tt
		if hit_y_t >= cy_top:
			if best_t < 0 or tt < best_t:
				best_t = tt

	return best_t


static func _ray_sphere_hit(origin: Vector3, dir: Vector3,
		center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b_val := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b_val * b_val - c
	if disc < 0:
		return -1.0
	var sqrt_d := sqrt(disc)
	var t := -b_val - sqrt_d
	if t < 0.001:
		t = -b_val + sqrt_d
	if t < 0.001:
		return -1.0
	return t
