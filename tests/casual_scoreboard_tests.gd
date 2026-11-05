extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[CasualScoreboardTests] Starting casual 10v10 scoreboard test suite")

	_test_casual_mode_activates_layout()
	_test_casual_row_count()
	_test_casual_team_sorting()
	_test_casual_score_display()
	_test_casual_local_highlight()
	_test_casual_score_equals_kills()
	_test_casual_no_money_or_dmg_column()
	_test_casual_empty_team()
	_test_casual_hidden_when_competitive()
	_test_casual_full_team_10_players()
	_test_casual_overflow_beyond_10()
	_test_casual_compact_row_height()
	_test_casual_header_labels()
	_test_casual_team_color_alternation()
	_test_casual_mode_switch_hides_others()

	print("[CasualScoreboardTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
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


func _setup_casual(players: Array) -> void:
	ClientScoreboard.update_mode(&"casual")
	ClientScoreboard.my_peer_id = 1
	ClientScoreboard.my_team = Team.Id.ANGELS
	ClientScoreboard.score_angels = 0
	ClientScoreboard.score_demons = 0
	ClientScoreboard.roster = players
	ClientScoreboard._refresh_casual()


func _make_player(id: int, team: int, kills: int, deaths: int, assists: int) -> Dictionary:
	return {"id": id, "team": team, "kills": kills, "deaths": deaths, "assists": assists, "damage": 0}


func _test_casual_mode_activates_layout() -> void:
	ClientScoreboard.update_mode(&"casual")
	_assert(ClientScoreboard.mode == &"casual", "cas_mode_set")
	_assert(ClientScoreboard._cas_root != null, "cas_root_exists")


func _test_casual_row_count() -> void:
	_assert(ClientScoreboard._cas_rows.has(Team.Id.ANGELS), "cas_has_angels_rows")
	_assert(ClientScoreboard._cas_rows.has(Team.Id.DEMONS), "cas_has_demons_rows")
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	var d_rows: Array = ClientScoreboard._cas_rows[Team.Id.DEMONS]
	_assert(a_rows.size() == ClientScoreboard.CAS_MAX_ROWS, "cas_angels_row_count",
		"expected %d, got %d" % [ClientScoreboard.CAS_MAX_ROWS, a_rows.size()])
	_assert(d_rows.size() == ClientScoreboard.CAS_MAX_ROWS, "cas_demons_row_count",
		"expected %d, got %d" % [ClientScoreboard.CAS_MAX_ROWS, d_rows.size()])


func _test_casual_team_sorting() -> void:
	_setup_casual([
		_make_player(1, Team.Id.ANGELS, 5, 2, 0),
		_make_player(2, Team.Id.ANGELS, 10, 1, 0),
		_make_player(3, Team.Id.DEMONS, 8, 3, 1),
	])
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	_assert(a_rows[0]["name"].text == "Player 2", "cas_angels_top_fragger",
		"expected Player 2 (10 kills), got %s" % a_rows[0]["name"].text)
	_assert(a_rows[1]["name"].text == "Player 1", "cas_angels_second",
		"expected Player 1 (5 kills), got %s" % a_rows[1]["name"].text)
	var d_rows: Array = ClientScoreboard._cas_rows[Team.Id.DEMONS]
	_assert(d_rows[0]["name"].text == "Player 3", "cas_demons_player",
		"expected Player 3, got %s" % d_rows[0]["name"].text)


func _test_casual_score_display() -> void:
	ClientScoreboard.update_mode(&"casual")
	ClientScoreboard.score_angels = 12
	ClientScoreboard.score_demons = 8
	ClientScoreboard.roster = []
	ClientScoreboard._refresh_casual()
	_assert(ClientScoreboard._cas_score_labels[Team.Id.ANGELS].text == "12",
		"cas_angels_score", "got %s" % ClientScoreboard._cas_score_labels[Team.Id.ANGELS].text)
	_assert(ClientScoreboard._cas_score_labels[Team.Id.DEMONS].text == "8",
		"cas_demons_score", "got %s" % ClientScoreboard._cas_score_labels[Team.Id.DEMONS].text)


func _test_casual_local_highlight() -> void:
	_setup_casual([
		_make_player(1, Team.Id.ANGELS, 5, 0, 0),
		_make_player(2, Team.Id.ANGELS, 10, 0, 0),
	])
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	var local_row := -1
	for i in range(2):
		if a_rows[i]["name"].text == "Player 1":
			local_row = i
	_assert(local_row >= 0, "cas_found_local")
	if local_row >= 0:
		_assert(a_rows[local_row]["highlight"].visible, "cas_local_highlighted")
		var font_color: Color = a_rows[local_row]["name"].get_theme_color("font_color")
		_assert(font_color.r > 0.9 and font_color.g > 0.8, "cas_local_gold_name",
			"expected gold, got %s" % str(font_color))


func _test_casual_score_equals_kills() -> void:
	_setup_casual([
		_make_player(1, Team.Id.ANGELS, 7, 3, 2),
	])
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	_assert(a_rows[0]["kills"].text == "7", "cas_kills_7",
		"got %s" % a_rows[0]["kills"].text)
	_assert(a_rows[0]["score"].text == "7", "cas_score_equals_kills",
		"expected score=7 (same as kills), got %s" % a_rows[0]["score"].text)


func _test_casual_no_money_or_dmg_column() -> void:
	_setup_casual([
		_make_player(1, Team.Id.ANGELS, 5, 0, 0),
	])
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	_assert(not a_rows[0].has("money"), "cas_no_money_column")
	_assert(not a_rows[0].has("dmg"), "cas_no_dmg_column")


func _test_casual_empty_team() -> void:
	_setup_casual([
		_make_player(1, Team.Id.ANGELS, 5, 0, 0),
	])
	var d_rows: Array = ClientScoreboard._cas_rows[Team.Id.DEMONS]
	for i in range(ClientScoreboard.CAS_MAX_ROWS):
		_assert(not d_rows[i]["bg"].visible, "cas_demons_row_%d_hidden" % i)


func _test_casual_hidden_when_competitive() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.panel.visible = true
	ClientScoreboard._refresh()
	_assert(not ClientScoreboard._cas_root.visible, "cas_hidden_in_competitive")
	ClientScoreboard.panel.visible = false


func _test_casual_full_team_10_players() -> void:
	var players := []
	for i in range(10):
		players.append(_make_player(i + 1, Team.Id.ANGELS, 10 - i, i, 0))
	_setup_casual(players)
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	for i in range(10):
		_assert(a_rows[i]["bg"].visible, "cas_full_row_%d_visible" % i)
	_assert(a_rows[0]["name"].text == "Player 1", "cas_full_top_player",
		"expected Player 1 (10 kills), got %s" % a_rows[0]["name"].text)


func _test_casual_overflow_beyond_10() -> void:
	var players := []
	for i in range(12):
		players.append(_make_player(i + 1, Team.Id.ANGELS, 12 - i, 0, 0))
	_setup_casual(players)
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	for i in range(10):
		_assert(a_rows[i]["bg"].visible, "cas_overflow_row_%d_visible" % i)
	_assert(a_rows[0]["name"].text == "Player 1", "cas_overflow_top",
		"got %s" % a_rows[0]["name"].text)
	_assert(a_rows[9]["name"].text == "Player 10", "cas_overflow_last_shown",
		"got %s" % a_rows[9]["name"].text)


func _test_casual_compact_row_height() -> void:
	_assert(ClientScoreboard.CAS_ROW_H == 22.0, "cas_row_height_22",
		"expected 22.0, got %s" % str(ClientScoreboard.CAS_ROW_H))
	_assert(ClientScoreboard.CAS_MAX_ROWS == 10, "cas_max_rows_10",
		"expected 10, got %d" % ClientScoreboard.CAS_MAX_ROWS)


func _test_casual_header_labels() -> void:
	ClientScoreboard.update_mode(&"casual")
	ClientScoreboard.round_number = 5
	ClientScoreboard.match_state = "LIVE"
	ClientScoreboard.roster = []
	ClientScoreboard._refresh_casual()
	_assert(ClientScoreboard._cas_hdr_mode.text == "Casual 10v10 | Map", "cas_header_mode",
		"got '%s'" % ClientScoreboard._cas_hdr_mode.text)
	_assert("Round 5" in ClientScoreboard._cas_hdr_time.text, "cas_header_round",
		"got '%s'" % ClientScoreboard._cas_hdr_time.text)


func _test_casual_team_color_alternation() -> void:
	var a_rows: Array = ClientScoreboard._cas_rows[Team.Id.ANGELS]
	if a_rows.size() >= 2:
		var c0: Color = a_rows[0]["bg"].color
		var c1: Color = a_rows[1]["bg"].color
		_assert(c0 != c1, "cas_row_color_alternates",
			"row 0 and 1 have same color %s" % str(c0))


func _test_casual_mode_switch_hides_others() -> void:
	ClientScoreboard.update_mode(&"casual")
	ClientScoreboard.panel.visible = true
	ClientScoreboard._refresh()
	_assert(ClientScoreboard._cas_root.visible, "cas_root_visible_in_casual")
	_assert(not ClientScoreboard._competitive_root.visible, "cas_comp_hidden_in_casual")
	_assert(not ClientScoreboard._fallback_root.visible, "cas_fallback_hidden_in_casual")
	ClientScoreboard.panel.visible = false
