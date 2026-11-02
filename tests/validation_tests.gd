extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []

const VALID_HITGROUPS := ["head", "chest", "stomach", "arms", "legs"]


func _ready() -> void:
	print("=== Validation Tests ===")
	print("Collision dimensions, hitbox exclusions, physics layers")
	print("")

	test_standing_hull_height()
	test_standing_hull_radius()
	test_ducked_hull_height()
	test_view_offset_standing()
	test_view_offset_ducking()
	test_hitgroup_only_combat_zones()
	test_hitgroup_multipliers_positive()
	test_cosmetic_not_in_hitgroups()
	test_physics_layer_names()
	test_gravity_matches_config()
	test_tick_rate_matches_config()

	_print_summary()


func _pass(test_name: String, msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  PASS %s" % msg)


func _fail(test_name: String, msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  FAIL %s" % msg)


func _approx(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) < tolerance


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


# --- Collision dimension tests ---

func test_standing_hull_height() -> void:
	var expected := 72.0 * MC.METERS_PER_UNIT
	if _approx(MC.HULL_STANDING_HEIGHT, expected, 0.001):
		_pass("test_standing_hull_height",
			"%.4fm (72 GoldSrc units)" % MC.HULL_STANDING_HEIGHT)
	else:
		_fail("test_standing_hull_height",
			"%.4fm, expected %.4fm (72u)" % [MC.HULL_STANDING_HEIGHT, expected])


func test_standing_hull_radius() -> void:
	var expected := 16.0 * MC.METERS_PER_UNIT
	if _approx(MC.HULL_RADIUS, expected, 0.001):
		_pass("test_standing_hull_radius",
			"%.4fm (16 GoldSrc units)" % MC.HULL_RADIUS)
	else:
		_fail("test_standing_hull_radius",
			"%.4fm, expected %.4fm (16u)" % [MC.HULL_RADIUS, expected])


func test_ducked_hull_height() -> void:
	var expected := 50.0 * MC.METERS_PER_UNIT
	if _approx(MC.HULL_DUCKING_HEIGHT, expected, 0.001):
		_pass("test_ducked_hull_height",
			"%.4fm (50 GoldSrc units, asymmetric -18 to +32)" % MC.HULL_DUCKING_HEIGHT)
	else:
		_fail("test_ducked_hull_height",
			"%.4fm, expected %.4fm (50u)" % [MC.HULL_DUCKING_HEIGHT, expected])


func test_view_offset_standing() -> void:
	var expected := 17.0 * MC.METERS_PER_UNIT
	if _approx(MC.VIEW_OFFSET_STANDING, expected, 0.001):
		_pass("test_view_offset_standing",
			"%.4fm (17 GoldSrc units, CS 1.6 VEC_VIEW)" % MC.VIEW_OFFSET_STANDING)
	else:
		_fail("test_view_offset_standing",
			"%.4fm, expected %.4fm (17u)" % [MC.VIEW_OFFSET_STANDING, expected])


func test_view_offset_ducking() -> void:
	var expected := 5.0 * MC.METERS_PER_UNIT
	if _approx(MC.VIEW_OFFSET_DUCKING, expected, 0.001):
		_pass("test_view_offset_ducking",
			"%.4fm (5u: 30u eye-from-feet − 25u capsule half-height)" % MC.VIEW_OFFSET_DUCKING)
	else:
		_fail("test_view_offset_ducking",
			"%.4fm, expected %.4fm (5u)" % [MC.VIEW_OFFSET_DUCKING, expected])


# --- Hitbox exclusion tests ---

func test_hitgroup_only_combat_zones() -> void:
	for group in WC.HITGROUP_MULTIPLIERS.keys():
		if group not in VALID_HITGROUPS:
			_fail("test_hitgroup_only_combat_zones",
				"unexpected hitgroup '%s' (valid: %s)" % [group, VALID_HITGROUPS])
			return
	_pass("test_hitgroup_only_combat_zones",
		"%d groups: %s" % [WC.HITGROUP_MULTIPLIERS.size(), ", ".join(WC.HITGROUP_MULTIPLIERS.keys())])


func test_hitgroup_multipliers_positive() -> void:
	for group in WC.HITGROUP_MULTIPLIERS.keys():
		var mult: float = WC.HITGROUP_MULTIPLIERS[group]
		if mult <= 0.0:
			_fail("test_hitgroup_multipliers_positive",
				"hitgroup '%s' has non-positive multiplier %.2f" % [group, mult])
			return
	_pass("test_hitgroup_multipliers_positive",
		"all %d multipliers > 0" % WC.HITGROUP_MULTIPLIERS.size())


func test_cosmetic_not_in_hitgroups() -> void:
	var cosmetic_names := ["halo", "horns", "wings", "tail", "aura", "crown", "cosmetic"]
	for name in cosmetic_names:
		if name in WC.HITGROUP_MULTIPLIERS:
			_fail("test_cosmetic_not_in_hitgroups",
				"cosmetic '%s' found in HITGROUP_MULTIPLIERS" % name)
			return
	_pass("test_cosmetic_not_in_hitgroups",
		"none of %s present in hitgroups" % str(cosmetic_names))


# --- Project config validation ---

func test_physics_layer_names() -> void:
	var expected := {1: "World", 2: "Players", 3: "Projectiles", 4: "Hitboxes"}
	var all_ok := true
	var details := ""
	for layer in expected.keys():
		var setting := "layer_names/3d_physics/layer_%d" % layer
		var actual: String = ProjectSettings.get_setting(setting, "")
		if actual != expected[layer]:
			all_ok = false
			details += "layer %d: '%s' (expected '%s') " % [layer, actual, expected[layer]]
	if all_ok:
		_pass("test_physics_layer_names",
			"layers 1-4: World, Players, Projectiles, Hitboxes")
	else:
		_fail("test_physics_layer_names", details)


func test_gravity_matches_config() -> void:
	var project_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 0.0)
	if _approx(project_gravity, MC.GRAVITY, 0.01):
		_pass("test_gravity_matches_config",
			"%.2f m/s² (MC.GRAVITY=%.2f)" % [project_gravity, MC.GRAVITY])
	else:
		_fail("test_gravity_matches_config",
			"project.godot=%.2f, MC.GRAVITY=%.2f" % [project_gravity, MC.GRAVITY])


func test_tick_rate_matches_config() -> void:
	var project_ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)
	if project_ticks == 128:
		_pass("test_tick_rate_matches_config",
			"%d Hz" % project_ticks)
	else:
		_fail("test_tick_rate_matches_config",
			"%d Hz, expected 128" % project_ticks)
