extends Node

var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var tick := 0
var test_state := {}
var results: Array[String] = []


func _ready() -> void:
	test_queue = [
		&"test_damage_log_tracks_hits",
		&"test_report_given_taken_split",
		&"test_report_aggregates_multiple_hits",
		&"test_report_headshot_count",
		&"test_report_empty_when_no_damage",
		&"test_protocol_pack_unpack",
		&"test_damage_log_round_isolation",
	]

	print("=== Death Report Tests ===")
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


func _build_report(log: Array, victim_id: int) -> Dictionary:
	var given: Dictionary = {}
	var taken: Dictionary = {}
	for entry in log:
		if entry["attacker"] == victim_id:
			var vid: int = entry["victim"]
			if not given.has(vid):
				given[vid] = {"id": vid, "dmg": 0, "hits": 0, "hs": 0}
			given[vid]["dmg"] += entry["damage"]
			given[vid]["hits"] += 1
			if entry["headshot"]:
				given[vid]["hs"] += 1
		if entry["victim"] == victim_id:
			var aid: int = entry["attacker"]
			if not taken.has(aid):
				taken[aid] = {"id": aid, "dmg": 0, "hits": 0, "hs": 0}
			taken[aid]["dmg"] += entry["damage"]
			taken[aid]["hits"] += 1
			if entry["headshot"]:
				taken[aid]["hs"] += 1
	return {"given": given.values(), "taken": taken.values()}


# --- Tests ---

func test_damage_log_tracks_hits() -> void:
	var log: Array = []
	log.append({"attacker": 1, "victim": 2, "damage": 36, "weapon": 2, "headshot": false})
	log.append({"attacker": 3, "victim": 2, "damage": 40, "weapon": 0, "headshot": false})

	if log.size() == 2 and log[0]["attacker"] == 1 and log[1]["attacker"] == 3:
		_pass("damage log tracks %d entries" % log.size())
	else:
		_fail("damage log entries incorrect")


func test_report_given_taken_split() -> void:
	var log: Array = [
		{"attacker": 2, "victim": 1, "damage": 36, "weapon": 2, "headshot": false},
		{"attacker": 1, "victim": 2, "damage": 55, "weapon": 0, "headshot": false},
		{"attacker": 3, "victim": 2, "damage": 40, "weapon": 0, "headshot": false},
	]
	var report := _build_report(log, 2)
	var given: Array = report["given"]
	var taken: Array = report["taken"]

	if given.size() == 1 and given[0]["id"] == 1 and given[0]["dmg"] == 36:
		if taken.size() == 2:
			_pass("given=%d taken=%d (correct split)" % [given.size(), taken.size()])
		else:
			_fail("taken count=%d expected 2" % taken.size())
	else:
		_fail("given count=%d expected 1 with id=1" % given.size())


func test_report_aggregates_multiple_hits() -> void:
	var log: Array = [
		{"attacker": 1, "victim": 2, "damage": 36, "weapon": 2, "headshot": false},
		{"attacker": 1, "victim": 2, "damage": 36, "weapon": 2, "headshot": false},
		{"attacker": 1, "victim": 2, "damage": 36, "weapon": 2, "headshot": true},
	]
	var report := _build_report(log, 2)
	var taken: Array = report["taken"]

	if taken.size() == 1 and taken[0]["dmg"] == 108 and taken[0]["hits"] == 3:
		_pass("3 hits from player 1: total=%d hits=%d" % [taken[0]["dmg"], taken[0]["hits"]])
	else:
		_fail("aggregation wrong: entries=%d" % taken.size())


func test_report_headshot_count() -> void:
	var log: Array = [
		{"attacker": 1, "victim": 2, "damage": 144, "weapon": 2, "headshot": true},
		{"attacker": 1, "victim": 2, "damage": 36, "weapon": 2, "headshot": false},
	]
	var report := _build_report(log, 2)
	var taken: Array = report["taken"]

	if taken.size() == 1 and taken[0]["hs"] == 1 and taken[0]["hits"] == 2:
		_pass("headshots=%d hits=%d" % [taken[0]["hs"], taken[0]["hits"]])
	else:
		_fail("headshot tracking wrong")


func test_report_empty_when_no_damage() -> void:
	var log: Array = [
		{"attacker": 3, "victim": 4, "damage": 50, "weapon": 1, "headshot": false},
	]
	var report := _build_report(log, 2)

	if report["given"].size() == 0 and report["taken"].size() == 0:
		_pass("empty report for uninvolved player")
	else:
		_fail("report not empty for uninvolved player")


func test_protocol_pack_unpack() -> void:
	var report := {
		"given": [{"id": 1, "dmg": 68, "hits": 2, "hs": 1}],
		"taken": [{"id": 3, "dmg": 100, "hits": 3, "hs": 0}],
	}
	var packet := NetProtocol.pack_death_report_event(42, report)
	var result := NetProtocol.unpack_death_report_event(packet)

	if result.is_empty():
		_fail("unpack returned empty")
		return

	if result["victim_id"] != 42:
		_fail("victim_id=%d expected 42" % result["victim_id"])
		return

	var unpacked: Dictionary = result["report"]
	var g: Array = unpacked.get("given", [])
	var t: Array = unpacked.get("taken", [])

	if g.size() == 1 and g[0]["dmg"] == 68 and t.size() == 1 and t[0]["dmg"] == 100:
		_pass("pack/unpack round-trip: victim=%d given=%d taken=%d" % [
			result["victim_id"], g[0]["dmg"], t[0]["dmg"]])
	else:
		_fail("round-trip data mismatch")


func test_damage_log_round_isolation() -> void:
	var log: Array = [
		{"attacker": 1, "victim": 2, "damage": 50, "weapon": 2, "headshot": false},
	]
	var report_before := _build_report(log, 2)
	log.clear()
	var report_after := _build_report(log, 2)

	if report_before["taken"].size() == 1 and report_after["taken"].size() == 0:
		_pass("round clear isolates reports")
	else:
		_fail("round isolation failed")
