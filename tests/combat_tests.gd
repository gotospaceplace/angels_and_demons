extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")
const WR := preload("res://shared/scripts/weapon_registry.gd")

var player: CharacterBody3D
var ws: Node
var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var tick := 0
var test_state := {}
var results: Array[String] = []

var ak: Resource
var m4: Resource
var usp: Resource
var awp: Resource
var knife: Resource


func _ready() -> void:
	player = _find_player()
	if not player:
		_fail_hard("No player found in scene")
		return

	player.test_driven = true
	player.set_process_unhandled_input(false)

	var ws_nodes := get_tree().get_nodes_in_group("weapon_system")
	if ws_nodes.size() > 0:
		ws = ws_nodes[0]
	else:
		_fail_hard("No weapon system found")
		return

	var all := WR.create_all()
	for w in all:
		match w.weapon_name:
			"Knife": knife = w
			"USP": usp = w
			"AK-47": ak = w
			"M4A1": m4 = w
			"AWP": awp = w

	process_physics_priority = -1

	test_queue = [
		&"test_ak_headshot_damage",
		&"test_ak_headshot_kills_armor",
		&"test_m4_chest_armor_damage",
		&"test_legs_bypass_armor",
		&"test_range_falloff",
		&"test_wall_pen_pistol_blocked",
		&"test_wall_pen_rifle_retention",
		&"test_he_damage_falloff",
		&"test_flash_angle_180",
		&"test_weapon_switch_time",
		&"test_accuracy_first_shot",
		&"test_accuracy_degradation",
		&"test_per_weapon_maxspeed",
		&"test_movement_inaccuracy",
		&"test_bullet_tag",
	]

	print("=== Combat Regression Tests ===")
	print("Tests to run: %d" % test_queue.size())
	print("")
	_start_next_test()


func _physics_process(_delta: float) -> void:
	if current_test == "":
		return
	tick += 1
	call(current_test)


func _start_next_test() -> void:
	if test_queue.is_empty():
		_print_summary()
		return
	current_test = test_queue.pop_front()
	tick = 0
	test_state = {}
	print("  RUN  %s" % current_test)


func _pass(msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [current_test, msg])
	print("  PASS %s" % msg)
	current_test = ""
	_start_next_test()


func _fail(msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [current_test, msg])
	print("  FAIL %s" % msg)
	current_test = ""
	_start_next_test()


func _fail_hard(msg: String) -> void:
	print("FATAL: %s" % msg)
	get_tree().quit(2)


func _print_summary() -> void:
	print("")
	print("=== Results ===")
	for r in results:
		print(r)
	print("")
	var total := tests_passed + tests_failed
	print("%d/%d passed, %d failed" % [tests_passed, total, tests_failed])
	if tests_failed > 0:
		print("FAILED")
		get_tree().quit(1)
	else:
		print("ALL PASSED")
		get_tree().quit(0)


# --- Damage formula helpers ---

func _calc_raw_damage(weapon: Resource, hitgroup: String, distance_gsrc: float = 0.0) -> float:
	var base: float = weapon.base_damage
	var rm: float = weapon.range_modifier
	var mult: float = WC.HITGROUP_MULTIPLIERS.get(hitgroup, 1.0)
	var range_factor := pow(rm, distance_gsrc / WC.RANGE_UNIT)
	return base * range_factor * mult


func _calc_armor_result(raw: float, armor_pen: float, armor_val: float, hitgroup: String, helmet: bool) -> Dictionary:
	var armor_active := armor_val > 0.0
	if hitgroup == "legs":
		armor_active = false
	elif hitgroup == "head" and not helmet:
		armor_active = false

	if not armor_active:
		return {"hp_lost": raw, "armor_lost": 0.0}

	var hp_lost := raw * armor_pen
	var armor_lost := (raw - hp_lost) * WC.ARMOR_ABSORB_RATE
	if armor_lost > armor_val:
		armor_lost = armor_val
		hp_lost = raw - armor_lost / WC.ARMOR_ABSORB_RATE
	return {"hp_lost": hp_lost, "armor_lost": armor_lost}


func _lerp_flash(angle: float, angles: Array, values: Array) -> float:
	if angle <= float(angles[0]):
		return float(values[0])
	for i in range(1, angles.size()):
		if angle <= float(angles[i]):
			var t: float = (angle - float(angles[i - 1])) / (float(angles[i]) - float(angles[i - 1]))
			return lerpf(float(values[i - 1]), float(values[i]), t)
	return float(values[values.size() - 1])


func _approx(a: float, b: float, tolerance: float = 0.1) -> bool:
	return absf(a - b) < tolerance


# --- Tests ---

func test_ak_headshot_damage() -> void:
	var raw := _calc_raw_damage(ak, "head", 0.0)
	var expected := 36.0 * 4.0
	if _approx(raw, expected):
		_pass("AK headshot raw=%.1f (expected %.1f)" % [raw, expected])
	else:
		_fail("AK headshot raw=%.1f, expected %.1f" % [raw, expected])


func test_ak_headshot_kills_armor() -> void:
	var raw := _calc_raw_damage(ak, "head", 0.0)
	var result := _calc_armor_result(raw, ak.armor_penetration, 100.0, "head", true)
	var hp_left := 100.0 - float(result["hp_lost"])
	if hp_left <= 0.0:
		_pass("AK headshot kills through vest+helm (%.1f HP lost)" % float(result["hp_lost"]))
	else:
		_fail("AK headshot left %.1f HP through vest+helm" % hp_left)


func test_m4_chest_armor_damage() -> void:
	var raw := _calc_raw_damage(m4, "chest", 0.0)
	var result := _calc_armor_result(raw, m4.armor_penetration, 100.0, "chest", false)
	var hp_lost: float = result["hp_lost"]
	if _approx(hp_lost, 22.08, 0.5):
		_pass("M4 chest+vest HP lost=%.1f (expected ~22)" % hp_lost)
	else:
		_fail("M4 chest+vest HP lost=%.1f, expected ~22" % hp_lost)


func test_legs_bypass_armor() -> void:
	var raw := _calc_raw_damage(ak, "legs", 0.0)
	var result := _calc_armor_result(raw, ak.armor_penetration, 100.0, "legs", true)
	var hp_lost: float = result["hp_lost"]
	var armor_lost: float = result["armor_lost"]
	if _approx(hp_lost, raw) and armor_lost == 0.0:
		_pass("legs bypass: %.1f HP lost, 0 armor (raw=%.1f)" % [hp_lost, raw])
	else:
		_fail("legs didn't bypass: hp=%.1f armor=%.1f raw=%.1f" % [hp_lost, armor_lost, raw])


func test_range_falloff() -> void:
	var raw := _calc_raw_damage(ak, "chest", 500.0)
	var expected := 36.0 * 0.98
	if _approx(raw, expected, 0.1):
		_pass("AK@500u: %.2f (expected %.2f)" % [raw, expected])
	else:
		_fail("AK@500u: %.2f, expected %.2f" % [raw, expected])


func test_wall_pen_pistol_blocked() -> void:
	var retention: float = WC.WALL_PEN_RETENTION.get(usp.penetration_level, 0.0)
	if usp.penetration_level == 1 and retention == 0.0:
		_pass("USP pen_level=%d retention=0 (blocked)" % usp.penetration_level)
	else:
		_fail("USP pen_level=%d retention=%.2f (should block)" % [usp.penetration_level, retention])


func test_wall_pen_rifle_retention() -> void:
	var retention: float = WC.WALL_PEN_RETENTION.get(ak.penetration_level, 0.0)
	if _approx(retention, 0.46, 0.01):
		_pass("AK pen retention=%.2f (expected 0.46)" % retention)
	else:
		_fail("AK pen retention=%.2f, expected 0.46" % retention)


func test_he_damage_falloff() -> void:
	var d0 := WC.HE_DAMAGE * (1.0 - 0.0 / WC.HE_BLAST_RADIUS_GSRC)
	var d_half := WC.HE_DAMAGE * (1.0 - 175.0 / WC.HE_BLAST_RADIUS_GSRC)
	var d_edge := WC.HE_DAMAGE * (1.0 - 350.0 / WC.HE_BLAST_RADIUS_GSRC)
	if _approx(d0, 100.0) and _approx(d_half, 50.0) and _approx(d_edge, 0.0):
		_pass("HE falloff: 0u=%.0f 175u=%.0f 350u=%.0f" % [d0, d_half, d_edge])
	else:
		_fail("HE falloff: 0u=%.0f 175u=%.0f 350u=%.0f" % [d0, d_half, d_edge])


func test_flash_angle_180() -> void:
	var blind := _lerp_flash(180.0, WC.FLASH_ANGLES, WC.FLASH_BLIND)
	var fade := _lerp_flash(180.0, WC.FLASH_ANGLES, WC.FLASH_FADE)
	if blind <= 0.0:
		_pass("180° flash: blind=%.1f fade=%.1f (no full blind)" % [blind, fade])
	else:
		_fail("180° flash: blind=%.1f (should be 0)" % blind)


func test_weapon_switch_time() -> void:
	if not _approx(knife.draw_time, 0.5, 0.01):
		_fail("knife draw=%.2f, expected 0.5" % knife.draw_time)
		return
	if not _approx(awp.draw_time, 1.5, 0.01):
		_fail("AWP draw=%.2f, expected 1.5" % awp.draw_time)
		return
	var switch_time: float = float(knife.holster_time) + float(awp.draw_time)
	_pass("knife draw=%.1fs AWP draw=%.1fs switch=%.1fs" % [knife.draw_time, awp.draw_time, switch_time])


func test_accuracy_first_shot() -> void:
	var spread: float = float(ak.spread_standing) * float(ak.accuracy_deploy)
	if _approx(spread, 0.0055, 0.0005):
		_pass("AK first-shot spread=%.4f (expected ~0.0055)" % spread)
	else:
		_fail("AK first-shot spread=%.4f, expected ~0.0055" % spread)


func test_accuracy_degradation() -> void:
	var shots := 7
	var acc: float = (pow(shots, 3) / float(ak.accuracy_divisor)) + float(ak.accuracy_offset)
	acc = minf(acc, float(ak.accuracy_cap))
	var spread: float = float(ak.spread_standing) * acc
	if _approx(acc, ak.accuracy_cap, 0.01) and spread > 0.03:
		_pass("7 shots: acc=%.3f (cap=%.2f) spread=%.4f" % [acc, ak.accuracy_cap, spread])
	else:
		_fail("7 shots: acc=%.3f spread=%.4f" % [acc, spread])


func test_per_weapon_maxspeed() -> void:
	var ak_gsrc: float = float(ak.max_speed) * MC.UNITS_PER_METER
	if _approx(ak_gsrc, 221.0, 1.0):
		_pass("AK maxspeed=%.1f u/s (expected 221)" % ak_gsrc)
	else:
		_fail("AK maxspeed=%.1f u/s, expected 221" % ak_gsrc)


func test_movement_inaccuracy() -> void:
	var standing: float = float(ak.spread_standing) * float(ak.accuracy_deploy)
	var moving: float = float(ak.spread_base_moving) + float(ak.spread_moving) * float(ak.accuracy_deploy)
	if moving > standing * 5.0:
		_pass("moving=%.4f >> standing=%.4f (%.1fx worse)" % [moving, standing, moving / standing])
	else:
		_fail("moving=%.4f not much worse than standing=%.4f" % [moving, standing])


func test_bullet_tag() -> void:
	if tick == 1:
		player.velocity = Vector3(0, 0, -5.0)
		player.on_ground = true
		player.apply_bullet_tag(ak.max_speed)
	elif tick == 2:
		if player.tag_timer > 0.0 and player.tag_base_cap > 0.0:
			_pass("tag_timer=%.3f cap=%.3f" % [player.tag_timer, player.tag_base_cap])
		else:
			_fail("tag not applied: timer=%.3f cap=%.3f" % [player.tag_timer, player.tag_base_cap])


func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
