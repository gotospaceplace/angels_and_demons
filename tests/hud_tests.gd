extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[HudTests] Starting HUD test suite")

	# Team color tests
	_test_player_colors_exist()
	_test_player_color_index_bounds()
	_test_team_colors_distinct()

	# Roster in match state
	_test_roster_in_client_state()
	_test_player_color_assignment()
	_test_player_alive_tracking()
	_test_player_disconnect_cleanup()
	_test_state_changed_event()

	# HUD state
	_test_hud_creation()
	_test_hud_update_from_snapshot()
	_test_hud_update_from_match_state()
	_test_hud_timer_countdown()
	_test_hud_score_perspective()
	_test_hud_player_cards_filter_dead()
	_test_hud_hp_color_thresholds()
	_test_hud_timer_format()
	_test_hud_ammo_knife_hidden()

	print("[HudTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
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


# --- Team color tests ---

func _test_player_colors_exist() -> void:
	_assert(Team.PLAYER_COLORS.size() == 5, "player_colors_count",
		"expected 5, got %d" % Team.PLAYER_COLORS.size())


func _test_player_color_index_bounds() -> void:
	var c := Team.get_player_color(0)
	_assert(c != Color.WHITE, "player_color_0_valid")
	var out := Team.get_player_color(10)
	_assert(out == Color.WHITE, "player_color_out_of_bounds",
		"expected WHITE for index 10")
	var neg := Team.get_player_color(-1)
	_assert(neg == Color.WHITE, "player_color_negative",
		"expected WHITE for index -1")


func _test_team_colors_distinct() -> void:
	var colors: Array[Color] = []
	for i in range(Team.PLAYER_COLORS.size()):
		var c := Team.get_player_color(i)
		var is_unique := true
		for existing in colors:
			if existing.is_equal_approx(c):
				is_unique = false
				break
		_assert(is_unique, "player_color_%d_unique" % i)
		colors.append(c)


# --- Competitive plugin roster tests ---

func _test_roster_in_client_state() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)

	plugin.on_player_connect(1)
	plugin.on_player_connect(2)

	var state := plugin.get_client_state()
	_assert(state.has("roster"), "client_state_has_roster")
	var roster: Array = state["roster"]
	_assert(roster.size() == 2, "roster_size_2",
		"expected 2, got %d" % roster.size())

	var found_1 := false
	var found_2 := false
	for entry in roster:
		if entry["id"] == 1:
			found_1 = true
			_assert(entry.has("team"), "roster_entry_has_team")
			_assert(entry.has("alive"), "roster_entry_has_alive")
			_assert(entry.has("color"), "roster_entry_has_color")
			_assert(entry["alive"] == true, "roster_player_1_alive")
		if entry["id"] == 2:
			found_2 = true
	_assert(found_1 and found_2, "roster_has_both_players")


func _test_player_color_assignment() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)

	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.on_player_connect(3)

	_assert(plugin.player_colors.has(1), "player_1_has_color")
	_assert(plugin.player_colors.has(2), "player_2_has_color")
	_assert(plugin.player_colors.has(3), "player_3_has_color")

	var c1: int = plugin.player_colors[1]
	var c2: int = plugin.player_colors[2]
	_assert(c1 >= 0 and c1 < 5, "color_in_range",
		"got %d" % c1)


func _test_player_alive_tracking() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)

	plugin.on_player_connect(1)
	plugin.on_player_connect(2)

	_assert(plugin._player_alive.get(1, false) == true, "player_1_initially_alive")
	_assert(plugin._player_alive.get(2, false) == true, "player_2_initially_alive")

	plugin.on_player_kill(2, 1, 2, false)
	_assert(plugin._player_alive.get(1, true) == false, "player_1_dead_after_kill")
	_assert(plugin._player_alive.get(2, false) == true, "player_2_still_alive")

	var state := plugin.get_client_state()
	var roster: Array = state["roster"]
	for entry in roster:
		if entry["id"] == 1:
			_assert(entry["alive"] == false, "roster_player_1_dead")
		if entry["id"] == 2:
			_assert(entry["alive"] == true, "roster_player_2_alive")


func _test_player_disconnect_cleanup() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)

	plugin.on_player_connect(1)
	_assert(plugin.player_colors.has(1), "color_exists_before_dc")
	_assert(plugin._player_alive.has(1), "alive_exists_before_dc")

	plugin.on_player_disconnect(1)
	_assert(not plugin.player_colors.has(1), "color_cleaned_after_dc")
	_assert(not plugin._player_alive.has(1), "alive_cleaned_after_dc")


func _test_state_changed_event() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)

	var event_fired := [false]
	mgr.plugin_event.connect(func(name: StringName, _data: Dictionary):
		if name == &"match_state_changed":
			event_fired[0] = true
	)

	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.server_match.tick(0.1, 2)

	_assert(event_fired[0], "state_changed_event_fires",
		"expected match_state_changed after warmup→freeze transition")


# --- ClientHud state tests ---

func _test_hud_creation() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	_assert(hud.hp == 100, "hud_default_hp")
	_assert(hud.money == 800, "hud_default_money")
	_assert(hud.match_state == "WARMUP", "hud_default_state")
	hud.queue_free()


func _test_hud_update_from_snapshot() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	hud.update_from_snapshot(75, 50, 2, 20)
	_assert(hud.hp == 75, "hud_snapshot_hp", "expected 75, got %d" % hud.hp)
	_assert(hud.armor == 50, "hud_snapshot_armor")
	_assert(hud.weapon_idx == 2, "hud_snapshot_weapon")
	_assert(hud.ammo_mag == 20, "hud_snapshot_ammo")
	hud.queue_free()


func _test_hud_update_from_match_state() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	hud.my_peer_id = 1
	hud.update_from_match_state({
		"state": "LIVE",
		"round": 3,
		"score_angels": 2,
		"score_demons": 1,
		"timer": 90.0,
		"attack_team": Team.Id.DEMONS,
		"my_team": Team.Id.ANGELS,
		"money": 5000,
		"roster": [
			{"id": 1, "team": Team.Id.ANGELS, "alive": true, "color": 0},
			{"id": 2, "team": Team.Id.DEMONS, "alive": true, "color": 0},
		],
	})
	_assert(hud.match_state == "LIVE", "hud_ms_state")
	_assert(hud.round_number == 3, "hud_ms_round")
	_assert(hud.score_angels == 2, "hud_ms_score_angels")
	_assert(hud.round_timer == 90.0, "hud_ms_timer",
		"expected 90.0, got %.1f" % hud.round_timer)
	_assert(hud.money == 5000, "hud_ms_money")
	_assert(hud.my_team == Team.Id.ANGELS, "hud_ms_my_team")
	_assert(hud.roster.size() == 2, "hud_ms_roster_size")
	hud.queue_free()


func _test_hud_timer_countdown() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	hud.update_from_match_state({
		"state": "LIVE",
		"timer": 10.0,
		"round": 1,
		"my_team": 1,
		"money": 800,
	})
	var before := hud.round_timer
	hud._process(1.0)
	_assert(hud.round_timer < before, "hud_timer_decrements",
		"expected < %.1f, got %.1f" % [before, hud.round_timer])
	_assert(absf(hud.round_timer - 9.0) < 0.01, "hud_timer_value",
		"expected ~9.0, got %.1f" % hud.round_timer)
	hud.queue_free()


func _test_hud_score_perspective() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	hud.my_team = Team.Id.DEMONS
	hud.score_angels = 3
	hud.score_demons = 5
	hud._update_scores()
	_assert(hud.my_score_label.text == "5", "score_my_team_left",
		"expected 5 (demons), got %s" % hud.my_score_label.text)
	_assert(hud.enemy_score_label.text == "3", "score_enemy_right",
		"expected 3 (angels), got %s" % hud.enemy_score_label.text)
	hud.queue_free()


func _test_hud_player_cards_filter_dead() -> void:
	var hud := ClientHud.new()
	add_child(hud)
	hud.my_peer_id = 1
	hud.my_team = Team.Id.ANGELS
	hud.roster = [
		{"id": 1, "team": Team.Id.ANGELS, "alive": true, "color": 0},
		{"id": 2, "team": Team.Id.ANGELS, "alive": false, "color": 1},
		{"id": 3, "team": Team.Id.DEMONS, "alive": true, "color": 0},
	]
	hud._rebuild_player_cards()
	var my_count := hud.my_players_box.get_child_count()
	var enemy_count := hud.enemy_players_box.get_child_count()
	_assert(my_count == 1, "my_team_1_alive_card",
		"expected 1 (player 2 dead), got %d" % my_count)
	_assert(enemy_count == 1, "enemy_1_alive_card",
		"expected 1, got %d" % enemy_count)
	hud.queue_free()


func _test_hud_hp_color_thresholds() -> void:
	var hud := ClientHud.new()
	add_child(hud)

	hud.hp = 80
	hud._update_hp()
	var c_high: Color = hud.hp_label.get_theme_color("font_color")
	_assert(c_high.is_equal_approx(ClientHud.COL_HP_HIGH), "hp_color_high")

	hud.hp = 30
	hud._update_hp()
	var c_med: Color = hud.hp_label.get_theme_color("font_color")
	_assert(c_med.is_equal_approx(ClientHud.COL_HP_MED), "hp_color_med",
		"expected yellow at 30 HP")

	hud.hp = 10
	hud._update_hp()
	var c_low: Color = hud.hp_label.get_theme_color("font_color")
	_assert(c_low.is_equal_approx(ClientHud.COL_HP_LOW), "hp_color_low",
		"expected red at 10 HP")

	hud.queue_free()


func _test_hud_timer_format() -> void:
	var hud := ClientHud.new()
	add_child(hud)

	hud.match_state = "LIVE"
	hud.round_timer = 90.5
	hud._update_timer()
	_assert(hud.timer_label.text == "1:30", "timer_format_90s",
		"expected 1:30, got %s" % hud.timer_label.text)

	hud.round_timer = 5.0
	hud._update_timer()
	_assert(hud.timer_label.text == "0:05", "timer_format_5s",
		"expected 0:05, got %s" % hud.timer_label.text)
	var timer_color: Color = hud.timer_label.get_theme_color("font_color")
	_assert(timer_color.is_equal_approx(ClientHud.COL_TIMER_WARN), "timer_red_under_10s")

	hud.match_state = "WARMUP"
	hud._update_timer()
	_assert(hud.timer_label.text == "WARMUP", "timer_warmup_text")

	hud.queue_free()


func _test_hud_ammo_knife_hidden() -> void:
	var hud := ClientHud.new()
	add_child(hud)

	hud.weapon_idx = 0
	hud._update_ammo()
	_assert(hud.ammo_label.text == "", "ammo_hidden_for_knife")

	hud.weapon_idx = 2
	hud.ammo_mag = 25
	hud._update_ammo()
	_assert(hud.ammo_label.text == "25", "ammo_shown_for_ak",
		"expected 25, got %s" % hud.ammo_label.text)

	hud.queue_free()
