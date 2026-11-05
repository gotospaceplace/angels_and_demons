extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[TDMScoreboardTests] Starting TDM scoreboard test suite")

	_test_tdm_mode_activates_layout()
	_test_tdm_row_count()
	_test_tdm_team_sorting()
	_test_tdm_score_display()
	_test_tdm_kdr_calculation()
	_test_tdm_local_highlight()
	_test_tdm_no_money_column()
	_test_tdm_empty_team()
	_test_tdm_hidden_when_competitive()

	print("[TDMScoreboardTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
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


func _setup_tdm(players: Array) -> void:
	ClientScoreboard.update_mode(&"team_deathmatch")
	ClientScoreboard.my_peer_id = 1
	ClientScoreboard.my_team = Team.Id.ANGELS
	ClientScoreboard.score_angels = 0
	ClientScoreboard.score_demons = 0
	ClientScoreboard.roster = players
	ClientScoreboard._refresh_tdm()


func _test_tdm_mode_activates_layout() -> void:
	ClientScoreboard.update_mode(&"team_deathmatch")
	_assert(ClientScoreboard.mode == &"team_deathmatch", "tdm_mode_set")
	_assert(ClientScoreboard._tdm_root != null, "tdm_root_exists")


func _test_tdm_row_count() -> void:
	_assert(ClientScoreboard._tdm_rows.has(Team.Id.ANGELS), "tdm_has_angels_rows")
	_assert(ClientScoreboard._tdm_rows.has(Team.Id.DEMONS), "tdm_has_demons_rows")
	var a_rows: Array = ClientScoreboard._tdm_rows[Team.Id.ANGELS]
	var d_rows: Array = ClientScoreboard._tdm_rows[Team.Id.DEMONS]
	_assert(a_rows.size() == ClientScoreboard.TDM_MAX_ROWS, "tdm_angels_row_count",
		"expected %d, got %d" % [ClientScoreboard.TDM_MAX_ROWS, a_rows.size()])
	_assert(d_rows.size() == ClientScoreboard.TDM_MAX_ROWS, "tdm_demons_row_count",
		"expected %d, got %d" % [ClientScoreboard.TDM_MAX_ROWS, d_rows.size()])


func _test_tdm_team_sorting() -> void:
	_setup_tdm([
		{"id": 1, "team": Team.Id.ANGELS, "kills": 5, "deaths": 2, "assists": 0, "damage": 400},
		{"id": 2, "team": Team.Id.ANGELS, "kills": 10, "deaths": 1, "assists": 0, "damage": 800},
		{"id": 3, "team": Team.Id.DEMONS, "kills": 8, "deaths": 3, "assists": 1, "damage": 600},
	])
	var a_rows: Array = ClientScoreboard._tdm_rows[Team.Id.ANGELS]
	_assert(a_rows[0]["name"].text == "Player 2", "tdm_angels_top_fragger",
		"expected Player 2 (10 kills), got %s" % a_rows[0]["name"].text)
	_assert(a_rows[1]["name"].text == "Player 1", "tdm_angels_second",
		"expected Player 1 (5 kills), got %s" % a_rows[1]["name"].text)
	var d_rows: Array = ClientScoreboard._tdm_rows[Team.Id.DEMONS]
	_assert(d_rows[0]["name"].text == "Player 3", "tdm_demons_player",
		"expected Player 3, got %s" % d_rows[0]["name"].text)


func _test_tdm_score_display() -> void:
	ClientScoreboard.update_mode(&"team_deathmatch")
	ClientScoreboard.score_angels = 7
	ClientScoreboard.score_demons = 3
	ClientScoreboard.roster = []
	ClientScoreboard._refresh_tdm()
	_assert(ClientScoreboard._tdm_score_labels[Team.Id.ANGELS].text == "7",
		"tdm_angels_score", "got %s" % ClientScoreboard._tdm_score_labels[Team.Id.ANGELS].text)
	_assert(ClientScoreboard._tdm_score_labels[Team.Id.DEMONS].text == "3",
		"tdm_demons_score", "got %s" % ClientScoreboard._tdm_score_labels[Team.Id.DEMONS].text)


func _test_tdm_kdr_calculation() -> void:
	_setup_tdm([
		{"id": 1, "team": Team.Id.ANGELS, "kills": 12, "deaths": 4, "assists": 0, "damage": 0},
	])
	var a_rows: Array = ClientScoreboard._tdm_rows[Team.Id.ANGELS]
	_assert(a_rows[0]["kdr"].text == "3.0", "tdm_kdr_3_0",
		"expected 3.0, got %s" % a_rows[0]["kdr"].text)


func _test_tdm_local_highlight() -> void:
	_setup_tdm([
		{"id": 1, "team": Team.Id.ANGELS, "kills": 5, "deaths": 0, "assists": 0, "damage": 0},
		{"id": 2, "team": Team.Id.ANGELS, "kills": 10, "deaths": 0, "assists": 0, "damage": 0},
	])
	var a_rows: Array = ClientScoreboard._tdm_rows[Team.Id.ANGELS]
	var local_row := -1
	for i in range(2):
		if a_rows[i]["name"].text == "Player 1":
			local_row = i
	_assert(local_row >= 0, "tdm_found_local")
	if local_row >= 0:
		_assert(a_rows[local_row]["highlight"].visible, "tdm_local_highlighted")


func _test_tdm_no_money_column() -> void:
	_setup_tdm([
		{"id": 1, "team": Team.Id.ANGELS, "kills": 5, "deaths": 0, "assists": 0, "damage": 0},
	])
	var a_rows: Array = ClientScoreboard._tdm_rows[Team.Id.ANGELS]
	_assert(not a_rows[0].has("money"), "tdm_no_money_column")


func _test_tdm_empty_team() -> void:
	_setup_tdm([
		{"id": 1, "team": Team.Id.ANGELS, "kills": 5, "deaths": 0, "assists": 0, "damage": 0},
	])
	var d_rows: Array = ClientScoreboard._tdm_rows[Team.Id.DEMONS]
	for i in range(ClientScoreboard.TDM_MAX_ROWS):
		_assert(not d_rows[i]["bg"].visible, "tdm_demons_row_%d_hidden" % i)


func _test_tdm_hidden_when_competitive() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.panel.visible = true
	ClientScoreboard._refresh()
	_assert(not ClientScoreboard._tdm_root.visible, "tdm_hidden_in_competitive")
	ClientScoreboard.panel.visible = false
