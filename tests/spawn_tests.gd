extends Node

var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var results: Array[String] = []


func _ready() -> void:
	test_queue = [
		&"test_load_spawns",
		&"test_angels_get_angel_spawns",
		&"test_demons_get_demon_spawns",
		&"test_spawn_index_wraps",
		&"test_reset_indices",
		&"test_swap_sides",
		&"test_swap_sides_twice_restores",
		&"test_unassigned_returns_zero",
		&"test_plugin_get_spawn_position",
		&"test_plugin_get_spawn_position_unassigned",
		&"test_teleport_preserves_equipment",
		&"test_respawn_resets_equipment",
	]

	print("=== Spawn System Tests ===")
	print("Tests to run: %d" % test_queue.size())
	print("")
	_run_all()


func _run_all() -> void:
	for test_name in test_queue:
		current_test = test_name
		print("  RUN  %s" % current_test)
		call(test_name)
	_print_summary()


func _pass(msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [current_test, msg])
	print("  PASS %s" % msg)


func _fail(msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [current_test, msg])
	print("  FAIL %s" % msg)


func _print_summary() -> void:
	print("")
	print("=== Results ===")
	for r in results:
		print(r)
	print("")
	if tests_failed == 0:
		print("ALL PASSED")
	else:
		print("%d PASSED, %d FAILED" % [tests_passed, tests_failed])
	get_tree().quit(1 if tests_failed > 0 else 0)


var _angel_spawns: Array[Vector3] = [
	Vector3(-8, 1, -18),
	Vector3(-4, 1, -18),
	Vector3(0, 1, -18),
	Vector3(4, 1, -18),
	Vector3(8, 1, -18),
]

var _demon_spawns: Array[Vector3] = [
	Vector3(-8, 1, 18),
	Vector3(-4, 1, 18),
	Vector3(0, 1, 18),
	Vector3(4, 1, 18),
	Vector3(8, 1, 18),
]


func _make_spawns() -> CompetitiveSpawns:
	var s := CompetitiveSpawns.new()
	s.load_spawns(_angel_spawns, _demon_spawns)
	return s


# --- Tests ---

func test_load_spawns() -> void:
	var s := _make_spawns()
	var pos := s.get_spawn_for_team(Team.Id.ANGELS)
	if pos != Vector3.ZERO:
		_pass("loaded spawns, first angel at %s" % pos)
	else:
		_fail("get_spawn_for_team returned ZERO after load")


func test_angels_get_angel_spawns() -> void:
	var s := _make_spawns()
	var pos := s.get_spawn_for_team(Team.Id.ANGELS)
	if pos.z < 0:
		_pass("angels spawn on north side (z=%.0f)" % pos.z)
	else:
		_fail("expected negative z, got %.1f" % pos.z)


func test_demons_get_demon_spawns() -> void:
	var s := _make_spawns()
	var pos := s.get_spawn_for_team(Team.Id.DEMONS)
	if pos.z > 0:
		_pass("demons spawn on south side (z=%.0f)" % pos.z)
	else:
		_fail("expected positive z, got %.1f" % pos.z)


func test_spawn_index_wraps() -> void:
	var s := _make_spawns()
	for i in 5:
		s.get_spawn_for_team(Team.Id.ANGELS)
	var sixth := s.get_spawn_for_team(Team.Id.ANGELS)
	if sixth == _angel_spawns[0]:
		_pass("index wraps to first spawn after exhausting all 5")
	else:
		_fail("expected %s, got %s" % [_angel_spawns[0], sixth])


func test_reset_indices() -> void:
	var s := _make_spawns()
	s.get_spawn_for_team(Team.Id.ANGELS)
	s.get_spawn_for_team(Team.Id.ANGELS)
	s.reset_indices()
	var pos := s.get_spawn_for_team(Team.Id.ANGELS)
	if pos == _angel_spawns[0]:
		_pass("reset returns to first spawn")
	else:
		_fail("expected %s, got %s" % [_angel_spawns[0], pos])


func test_swap_sides() -> void:
	var s := _make_spawns()
	s.swap_sides()
	var angel_pos := s.get_spawn_for_team(Team.Id.ANGELS)
	var demon_pos := s.get_spawn_for_team(Team.Id.DEMONS)
	if angel_pos.z > 0 and demon_pos.z < 0:
		_pass("after swap: angels south (z=%.0f), demons north (z=%.0f)" % [angel_pos.z, demon_pos.z])
	else:
		_fail("swap failed: angels z=%.1f, demons z=%.1f" % [angel_pos.z, demon_pos.z])


func test_swap_sides_twice_restores() -> void:
	var s := _make_spawns()
	s.swap_sides()
	s.swap_sides()
	var angel_pos := s.get_spawn_for_team(Team.Id.ANGELS)
	if angel_pos.z < 0:
		_pass("double swap restores original sides (z=%.0f)" % angel_pos.z)
	else:
		_fail("expected negative z after double swap, got %.1f" % angel_pos.z)


func test_unassigned_returns_zero() -> void:
	var s := _make_spawns()
	var pos := s.get_spawn_for_team(Team.Id.UNASSIGNED)
	if pos == Vector3.ZERO:
		_pass("unassigned team returns ZERO")
	else:
		_fail("expected ZERO, got %s" % pos)


func test_plugin_get_spawn_position() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = ServerMatch.new()
	plugin.spawns = _make_spawns()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(6, Team.Id.DEMONS)

	var angel_pos := plugin.get_spawn_position(1)
	var demon_pos := plugin.get_spawn_position(6)

	if angel_pos.z < 0 and demon_pos.z > 0:
		_pass("plugin routes: angel z=%.0f, demon z=%.0f" % [angel_pos.z, demon_pos.z])
	else:
		_fail("angel z=%.1f, demon z=%.1f" % [angel_pos.z, demon_pos.z])


func test_plugin_get_spawn_position_unassigned() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = ServerMatch.new()
	plugin.spawns = _make_spawns()

	var pos := plugin.get_spawn_position(99)
	if pos == Vector3.ZERO:
		_pass("unassigned player gets ZERO (falls back to server default)")
	else:
		_fail("expected ZERO, got %s" % pos)


func test_teleport_preserves_equipment() -> void:
	var sp := _make_player(1)
	sp.weapon_idx = 4
	sp.ammo_mag = 8
	sp.armor = 100
	sp.teleport_to_spawn(Vector3(10, 1, 10))

	if sp.weapon_idx == 4 and sp.ammo_mag == 8 and sp.armor == 100 and sp.hp == 100:
		_pass("teleport keeps weapon=%d ammo=%d armor=%d hp=%d" % [
			sp.weapon_idx, sp.ammo_mag, sp.armor, sp.hp])
	else:
		_fail("equipment changed: weapon=%d ammo=%d armor=%d hp=%d" % [
			sp.weapon_idx, sp.ammo_mag, sp.armor, sp.hp])
	sp.destroy()


func test_respawn_resets_equipment() -> void:
	var sp := _make_player(2)
	sp.weapon_idx = 4
	sp.ammo_mag = 8
	sp.armor = 100
	sp.is_dead = true
	sp.respawn(Vector3(10, 1, 10))

	if sp.weapon_idx == 2 and sp.ammo_mag == 30 and sp.armor == 0 and sp.hp == 100:
		_pass("respawn resets to weapon=%d ammo=%d armor=%d hp=%d" % [
			sp.weapon_idx, sp.ammo_mag, sp.armor, sp.hp])
	else:
		_fail("unexpected loadout: weapon=%d ammo=%d armor=%d hp=%d" % [
			sp.weapon_idx, sp.ammo_mag, sp.armor, sp.hp])
	sp.destroy()


func _make_player(peer_id: int) -> RefCounted:
	var ServerPlayer = preload("res://server/scripts/server_player.gd")
	var sp = ServerPlayer.new()
	var parent := Node3D.new()
	parent.name = "TestWorld"
	add_child(parent)
	sp.create(peer_id, Vector3.ZERO, parent)
	return sp
