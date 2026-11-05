extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[FFAScoreboardTests] Starting FFA scoreboard test suite")

	_test_ffa_mode_activates_layout()
	_test_ffa_row_count()
	_test_ffa_sorted_by_kills()
	_test_ffa_rank_numbers()
	_test_ffa_kdr_calculation()
	_test_ffa_kdr_no_deaths()
	_test_ffa_local_highlight()
	_test_ffa_score_equals_kills()
	_test_ffa_max_rows_enforced()
	_test_ffa_empty_roster()
	_test_ffa_hidden_when_competitive()

	print("[FFAScoreboardTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
	if fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	total += 1
	if condition:
		pass_count += 1
		print("  PASS %s" % test_name)
	else:
		fail_count += 1
		var msg := "  FAIL %s" % test_name
		if detail != "":
			msg += " — %s" % detail
		print(msg)


func _setup_ffa(players: Array) -> void:
	ClientScoreboard.update_mode(&"deathmatch")
	ClientScoreboard.my_peer_id = 1
	ClientScoreboard.roster = players
	ClientScoreboard._refresh_ffa()


func _test_ffa_mode_activates_layout() -> void:
	ClientScoreboard.update_mode(&"deathmatch")
	_assert(ClientScoreboard.mode == &"deathmatch", "ffa_mode_set")
	_assert(ClientScoreboard._ffa_root != null, "ffa_root_exists")


func _test_ffa_row_count() -> void:
	_assert(ClientScoreboard._ffa_rows.size() == ClientScoreboard.FFA_MAX_ROWS,
		"ffa_row_count",
		"expected %d, got %d" % [ClientScoreboard.FFA_MAX_ROWS, ClientScoreboard._ffa_rows.size()])


func _test_ffa_sorted_by_kills() -> void:
	_setup_ffa([
		{"id": 1, "kills": 5, "deaths": 2, "assists": 1, "damage": 400},
		{"id": 2, "kills": 15, "deaths": 3, "assists": 0, "damage": 1200},
		{"id": 3, "kills": 10, "deaths": 1, "assists": 2, "damage": 800},
	])
	_assert(ClientScoreboard._ffa_rows[0]["name"].text == "Player 2",
		"ffa_top_fragger_first",
		"expected Player 2 (15 kills), got %s" % ClientScoreboard._ffa_rows[0]["name"].text)
	_assert(ClientScoreboard._ffa_rows[1]["name"].text == "Player 3",
		"ffa_second_fragger",
		"expected Player 3 (10 kills), got %s" % ClientScoreboard._ffa_rows[1]["name"].text)
	_assert(ClientScoreboard._ffa_rows[2]["name"].text == "Player 1",
		"ffa_third_fragger",
		"expected Player 1 (5 kills), got %s" % ClientScoreboard._ffa_rows[2]["name"].text)


func _test_ffa_rank_numbers() -> void:
	_setup_ffa([
		{"id": 1, "kills": 10, "deaths": 0, "assists": 0, "damage": 0},
		{"id": 2, "kills": 5, "deaths": 0, "assists": 0, "damage": 0},
	])
	_assert(ClientScoreboard._ffa_rows[0]["rank"].text == "1", "ffa_rank_1",
		"got %s" % ClientScoreboard._ffa_rows[0]["rank"].text)
	_assert(ClientScoreboard._ffa_rows[1]["rank"].text == "2", "ffa_rank_2",
		"got %s" % ClientScoreboard._ffa_rows[1]["rank"].text)


func _test_ffa_kdr_calculation() -> void:
	_setup_ffa([
		{"id": 1, "kills": 10, "deaths": 5, "assists": 0, "damage": 0},
	])
	_assert(ClientScoreboard._ffa_rows[0]["kdr"].text == "2.0", "ffa_kdr_2_0",
		"expected 2.0, got %s" % ClientScoreboard._ffa_rows[0]["kdr"].text)


func _test_ffa_kdr_no_deaths() -> void:
	_setup_ffa([
		{"id": 1, "kills": 7, "deaths": 0, "assists": 0, "damage": 0},
	])
	_assert(ClientScoreboard._ffa_rows[0]["kdr"].text == "7.0", "ffa_kdr_no_deaths",
		"expected 7.0, got %s" % ClientScoreboard._ffa_rows[0]["kdr"].text)


func _test_ffa_local_highlight() -> void:
	_setup_ffa([
		{"id": 1, "kills": 5, "deaths": 0, "assists": 0, "damage": 0},
		{"id": 2, "kills": 10, "deaths": 0, "assists": 0, "damage": 0},
	])
	var row_for_p1 := -1
	for i in range(2):
		if ClientScoreboard._ffa_rows[i]["name"].text == "Player 1":
			row_for_p1 = i
	_assert(row_for_p1 >= 0, "ffa_found_local_player")
	if row_for_p1 >= 0:
		_assert(ClientScoreboard._ffa_rows[row_for_p1]["highlight"].visible,
			"ffa_local_highlighted")
		var row_for_p2 := 1 - row_for_p1
		_assert(not ClientScoreboard._ffa_rows[row_for_p2]["highlight"].visible,
			"ffa_other_not_highlighted")


func _test_ffa_score_equals_kills() -> void:
	_setup_ffa([
		{"id": 1, "kills": 12, "deaths": 3, "assists": 4, "damage": 900},
	])
	_assert(ClientScoreboard._ffa_rows[0]["score"].text == "12", "ffa_score_eq_kills",
		"expected 12, got %s" % ClientScoreboard._ffa_rows[0]["score"].text)


func _test_ffa_max_rows_enforced() -> void:
	var players: Array = []
	for i in range(15):
		players.append({"id": i + 10, "kills": 15 - i, "deaths": 0, "assists": 0, "damage": 0})
	_setup_ffa(players)
	var visible_count := 0
	for i in range(ClientScoreboard.FFA_MAX_ROWS):
		if ClientScoreboard._ffa_rows[i]["bg"].visible:
			visible_count += 1
	_assert(visible_count == ClientScoreboard.FFA_MAX_ROWS, "ffa_max_rows_visible",
		"expected %d, got %d" % [ClientScoreboard.FFA_MAX_ROWS, visible_count])


func _test_ffa_empty_roster() -> void:
	_setup_ffa([])
	for i in range(ClientScoreboard.FFA_MAX_ROWS):
		_assert(not ClientScoreboard._ffa_rows[i]["bg"].visible,
			"ffa_row_%d_hidden_empty" % i)


func _test_ffa_hidden_when_competitive() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.panel.visible = true
	ClientScoreboard._refresh()
	_assert(not ClientScoreboard._ffa_root.visible, "ffa_hidden_in_competitive")
	ClientScoreboard.panel.visible = false
