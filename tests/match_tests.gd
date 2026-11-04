extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")

var _pass_count := 0
var _fail_count := 0
var _total := 0


func _ready() -> void:
	print("[MatchTests] Starting consolidated match tests (WB13)...")

	test_walk_accuracy_threshold_matches_cap()
	test_walk_accuracy_spread_differs()
	test_walk_accuracy_recoil_differs()
	test_walk_footstep_silent()
	test_walk_footstep_running_triggers()
	test_walk_network_bit_roundtrip()
	test_walk_network_bit_isolation()
	test_team_balance_allows_equal()
	test_team_balance_blocks_oversize()
	test_team_balance_spectator_bypasses()
	test_team_balance_disabled_when_zero()

	print("[MatchTests] Done: %d passed, %d failed out of %d" % [
		_pass_count, _fail_count, _total])
	if _fail_count > 0:
		OS.kill(OS.get_process_id())
	get_tree().quit(0)


# --- Walk accuracy tests ---

func test_walk_accuracy_threshold_matches_cap() -> void:
	_assert_eq(MC.WALK_SPEED_CAP, MC.INACCURACY_SPEED_THRESHOLD,
		"WALK_SPEED_CAP equals INACCURACY_SPEED_THRESHOLD")


func test_walk_accuracy_spread_differs() -> void:
	var ak = WeaponRegistry.create_all()[2]  # AK-47
	_assert_true(ak.spread_moving > ak.spread_standing,
		"AK spread_moving (%.4f) > spread_standing (%.4f)" % [
			ak.spread_moving, ak.spread_standing])
	_assert_true(ak.spread_base_moving > 0.0,
		"AK has additive moving spread (%.4f)" % ak.spread_base_moving)


func test_walk_accuracy_recoil_differs() -> void:
	var ak = WeaponRegistry.create_all()[2]  # AK-47
	_assert_true(ak.recoil_moving[0] > ak.recoil_standing[0],
		"AK moving recoil_up (%.2f) > standing (%.2f)" % [
			ak.recoil_moving[0], ak.recoil_standing[0]])


# --- Walk footstep tests ---

func test_walk_footstep_silent() -> void:
	var sm := _make_sound_manager()
	add_child(sm)
	sm.update_footsteps(1.0, true, MC.WALK_SPEED_CAP, false, false, true)
	sm.update_footsteps(1.0, true, MC.WALK_SPEED_CAP, false, false, true)
	_assert_eq(sm._test_footstep_count, 0,
		"no footsteps when is_walking=true")
	sm.queue_free()


func test_walk_footstep_running_triggers() -> void:
	var sm := _make_sound_manager()
	add_child(sm)
	sm.update_footsteps(1.0, true, 5.0, false, false, false)
	sm.update_footsteps(1.0, true, 5.0, false, false, false)
	_assert_true(sm._test_footstep_count > 0,
		"footsteps play when running (count=%d)" % sm._test_footstep_count)
	sm.queue_free()


# --- Walk network bit tests ---

func test_walk_network_bit_roundtrip() -> void:
	var cmd := NetInput.create(100, 0, 45.0, -10.0)
	cmd.set_button(NetInput.BIT_WALK, true)
	cmd.set_button(NetInput.BIT_FORWARD, true)
	var packed := cmd.to_bytes()
	var unpacked := NetInput.from_bytes(packed)
	_assert_true(unpacked.has_button(NetInput.BIT_WALK),
		"BIT_WALK survives serialize/deserialize")
	_assert_true(unpacked.has_button(NetInput.BIT_FORWARD),
		"BIT_FORWARD also survives alongside BIT_WALK")
	_assert_eq(unpacked.tick, 100, "tick preserved")


func test_walk_network_bit_isolation() -> void:
	var cmd := NetInput.create(1, 0, 0.0, 0.0)
	_assert_true(not cmd.has_button(NetInput.BIT_WALK),
		"BIT_WALK off by default")
	cmd.set_button(NetInput.BIT_WALK, true)
	_assert_true(cmd.has_button(NetInput.BIT_WALK),
		"BIT_WALK on after set")
	_assert_true(not cmd.has_button(NetInput.BIT_DUCK),
		"BIT_DUCK unaffected by BIT_WALK set")
	cmd.set_button(NetInput.BIT_WALK, false)
	_assert_true(not cmd.has_button(NetInput.BIT_WALK),
		"BIT_WALK off after clear")


# --- Team balance tests ---

func test_team_balance_allows_equal() -> void:
	var plugin := _make_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.DEMONS)
	var allowed := plugin.on_team_assign(3, Team.Id.ANGELS)
	_assert_true(allowed,
		"joining 2v1 team allowed (1 diff < max_diff 1)")


func test_team_balance_blocks_oversize() -> void:
	var plugin := _make_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.ANGELS)
	plugin.server_match.set_team(3, Team.Id.DEMONS)
	var allowed := plugin.on_team_assign(4, Team.Id.ANGELS)
	_assert_true(not allowed,
		"joining 2v1 → 3v1 blocked (diff >= max_diff 1)")


func test_team_balance_spectator_bypasses() -> void:
	var plugin := _make_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.ANGELS)
	plugin.server_match.set_team(3, Team.Id.DEMONS)
	var allowed := plugin.on_team_assign(4, Team.Id.SPECTATOR)
	_assert_true(allowed,
		"joining spectator always allowed regardless of balance")


func test_team_balance_disabled_when_zero() -> void:
	var plugin := _make_competitive_plugin()
	plugin.manager.match_config.set_value("mp_team_balance_max", 0)
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.ANGELS)
	plugin.server_match.set_team(3, Team.Id.ANGELS)
	var allowed := plugin.on_team_assign(4, Team.Id.ANGELS)
	_assert_true(allowed,
		"balance disabled (max=0): any team join allowed")


# --- Helpers ---

func _make_competitive_plugin() -> PluginCompetitive:
	var plugin := PluginCompetitive.new()
	var pm := PluginManager.new()
	pm.load_plugin(plugin)
	return plugin


func _make_sound_manager() -> Node:
	var sm = preload("res://client/scripts/sound_manager.gd").new()
	sm._test_mode = true
	return sm


func _assert_eq(actual, expected, label: String) -> void:
	_total += 1
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected true" % label)
