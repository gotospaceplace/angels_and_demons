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

	# Player stats tracking
	_test_player_stats_init()
	_test_player_kill_stats()
	_test_player_damage_tracking()
	_test_assist_detection()
	_test_round_history_recording()
	_test_round_history_objective_detail()
	_test_stats_in_client_state()

	# HUD state
	_test_hud_creation()
	_test_hud_update_from_snapshot()
	_test_hud_update_from_match_state()
	_test_hud_timer_countdown()
	_test_hud_score_perspective()
	_test_hud_player_cards_filter_dead()
	_test_hud_hp_color_thresholds()
	_test_hud_timer_format()
	_test_hud_ammo_melee_hidden()

	# Scoreboard
	_test_scoreboard_mode_update()
	_test_scoreboard_match_state_update()
	_test_scoreboard_roster_sorting()

	# Spectator
	_test_spectator_initial_state()
	_test_spectator_deathcam_enter()
	_test_spectator_follow_enter()
	_test_spectator_freecam_toggle()
	_test_spectator_exit()
	_test_spectator_team_filter()

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
	plugin.change_team(1, Team.Id.ANGELS)
	plugin.change_team(2, Team.Id.DEMONS)

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
	plugin.change_team(1, Team.Id.ANGELS)
	plugin.change_team(2, Team.Id.DEMONS)
	plugin.change_team(3, Team.Id.ANGELS)

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
	plugin.change_team(1, Team.Id.ANGELS)
	plugin.change_team(2, Team.Id.DEMONS)

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
	plugin.change_team(1, Team.Id.ANGELS)
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


# --- Player stats tracking tests ---

func _test_player_stats_init() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin.on_player_connect(1)
	_assert(plugin._player_stats.has(1), "stats_init_on_connect")
	var s: Dictionary = plugin._player_stats[1]
	_assert(s["kills"] == 0 and s["deaths"] == 0 and s["assists"] == 0 and s["damage"] == 0,
		"stats_init_zeros")


func _test_player_kill_stats() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.on_player_kill(1, 2, 2, false)
	_assert(plugin._player_stats[1]["kills"] == 1, "killer_kill_count",
		"expected 1, got %d" % plugin._player_stats[1]["kills"])
	_assert(plugin._player_stats[2]["deaths"] == 1, "victim_death_count",
		"expected 1, got %d" % plugin._player_stats[2]["deaths"])


func _test_player_damage_tracking() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.on_player_damage(1, 2, 35.0, 2, "body")
	_assert(plugin._player_stats[1]["damage"] == 35, "damage_tracked",
		"expected 35, got %d" % plugin._player_stats[1]["damage"])
	_assert(plugin._round_damage.has(2), "round_damage_victim_entry")
	_assert(plugin._round_damage[2].get(1, 0) == 35, "round_damage_amount")


func _test_assist_detection() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.on_player_connect(3)
	plugin.on_player_damage(1, 3, 40.0, 2, "body")
	plugin.on_player_damage(2, 3, 60.0, 2, "body")
	plugin.on_player_kill(2, 3, 2, false)
	_assert(plugin._player_stats[1]["assists"] == 1, "assist_credited",
		"expected 1 assist for player 1, got %d" % plugin._player_stats[1]["assists"])
	_assert(plugin._player_stats[2]["assists"] == 0, "killer_no_self_assist",
		"killer should not get assist, got %d" % plugin._player_stats[2]["assists"])


func _test_round_history_recording() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin._on_round_ended(Team.Id.ANGELS, &"elimination")
	_assert(plugin._round_history.size() == 1, "round_history_recorded",
		"expected 1 entry, got %d" % plugin._round_history.size())
	if plugin._round_history.size() > 0:
		var entry: Dictionary = plugin._round_history[0]
		_assert(entry.has("winner"), "history_has_winner")
		_assert(entry["winner"] == Team.Id.ANGELS, "history_winner_correct")
		_assert(entry.has("reason"), "history_has_reason")
		_assert(entry["reason"] == "elimination", "history_reason_elimination",
			"expected elimination, got %s" % entry["reason"])


func _test_round_history_objective_detail() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin._last_objective_detail = &"portal_opened"
	plugin._on_round_ended(Team.Id.DEMONS, &"objective")
	_assert(plugin._round_history.size() == 1, "objective_history_recorded")
	_assert(plugin._round_history[0]["reason"] == "portal_opened", "objective_detail_preserved",
		"expected portal_opened, got %s" % plugin._round_history[0]["reason"])
	_assert(plugin._last_objective_detail == &"", "detail_cleared_after_round")


func _test_stats_in_client_state() -> void:
	var plugin := PluginCompetitive.new()
	var mgr := PluginManager.new()
	plugin.on_load(mgr)
	plugin.on_player_connect(1)
	plugin.on_player_connect(2)
	plugin.on_player_damage(1, 2, 50.0, 2, "body")
	plugin.on_player_kill(1, 2, 2, false)
	var state := plugin.get_client_state()
	_assert(state.has("round_history"), "state_has_round_history")
	_assert(state.has("loss_streak_angels"), "state_has_loss_streak")
	var found_stats := false
	for entry in state["roster"]:
		if entry["id"] == 1:
			found_stats = true
			_assert(entry.has("kills"), "roster_has_kills")
			_assert(entry.has("deaths"), "roster_has_deaths")
			_assert(entry.has("assists"), "roster_has_assists")
			_assert(entry.has("damage"), "roster_has_damage")
			_assert(entry.has("money"), "roster_has_money")
			_assert(entry["kills"] == 1, "roster_kills_value",
				"expected 1, got %d" % entry["kills"])
			_assert(entry["damage"] == 50, "roster_damage_value",
				"expected 50, got %d" % entry["damage"])
	_assert(found_stats, "found_player_1_in_roster")


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
	hud.round_timer = 0.0
	hud._update_timer()
	_assert(hud.timer_label.text == "WARMUP", "timer_warmup_text")

	hud.queue_free()


func _test_hud_ammo_melee_hidden() -> void:
	var hud := ClientHud.new()
	add_child(hud)

	hud.weapon_idx = 0
	hud._update_ammo()
	_assert(hud.ammo_label.text == "", "ammo_hidden_for_melee")

	hud.weapon_idx = 2
	hud.ammo_mag = 25
	hud._update_ammo()
	_assert(hud.ammo_label.text == "25", "ammo_shown_for_ak",
		"expected 25, got %s" % hud.ammo_label.text)

	hud.queue_free()


# --- Scoreboard tests ---

func _test_scoreboard_mode_update() -> void:
	ClientScoreboard.update_mode(&"competitive")
	_assert(ClientScoreboard.mode == &"competitive", "scoreboard_mode_competitive")
	ClientScoreboard.update_mode(&"deathmatch")
	_assert(ClientScoreboard.mode == &"deathmatch", "scoreboard_mode_deathmatch")


func _test_scoreboard_match_state_update() -> void:
	ClientScoreboard.my_peer_id = 1
	ClientScoreboard.update_from_match_state({
		"state": "LIVE",
		"round": 5,
		"score_angels": 3,
		"score_demons": 2,
		"timer": 90.0,
		"attack_team": Team.Id.DEMONS,
		"my_team": Team.Id.ANGELS,
		"round_history": [
			{"winner": Team.Id.ANGELS, "reason": "elimination"},
			{"winner": Team.Id.DEMONS, "reason": "portal_opened"},
		],
		"loss_streak_angels": 0,
		"loss_streak_demons": 1,
		"roster": [
			{"id": 1, "team": Team.Id.ANGELS, "alive": true, "color": 0,
			 "kills": 10, "deaths": 3, "assists": 2, "damage": 1500, "money": 5000},
		],
	})
	_assert(ClientScoreboard.round_number == 5, "sb_round",
		"expected 5, got %d" % ClientScoreboard.round_number)
	_assert(ClientScoreboard.score_angels == 3, "sb_score_a")
	_assert(ClientScoreboard.score_demons == 2, "sb_score_d")
	_assert(ClientScoreboard.round_history.size() == 2, "sb_round_history_size")
	_assert(ClientScoreboard.loss_streak_demons == 1, "sb_loss_streak")
	_assert(ClientScoreboard.roster.size() == 1, "sb_roster_size")


func _test_scoreboard_roster_sorting() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.my_peer_id = 1
	ClientScoreboard.my_team = Team.Id.ANGELS
	ClientScoreboard.roster = [
		{"id": 1, "team": Team.Id.ANGELS, "alive": true, "color": 0,
		 "kills": 5, "deaths": 2, "assists": 1, "damage": 800, "money": 3000},
		{"id": 2, "team": Team.Id.ANGELS, "alive": true, "color": 1,
		 "kills": 10, "deaths": 1, "assists": 0, "damage": 1200, "money": 4000},
	]
	var sorted := ClientScoreboard._get_sorted_team_roster(Team.Id.ANGELS)
	_assert(sorted.size() == 2, "sorted_size_2")
	_assert(sorted[0]["id"] == 2, "sorted_top_fragger_first",
		"expected player 2 (10 kills) first, got player %d" % sorted[0]["id"])


# --- Spectator tests ---

func _test_spectator_initial_state() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	_assert(spec.mode == ClientSpectator.Mode.ALIVE, "spec_starts_alive")
	_assert(not spec.is_spectating(), "spec_not_spectating_initially")
	_assert(spec.spectate_target == 0, "spec_no_target_initially")
	spec.queue_free()


func _test_spectator_deathcam_enter() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	spec.enter_deathcam(Vector3(5, 2, 3), 1.5, -0.3)
	_assert(spec.mode == ClientSpectator.Mode.DEATHCAM, "spec_deathcam_mode")
	_assert(spec.is_spectating(), "spec_is_spectating_after_death")
	_assert(spec.camera.current, "spec_camera_current_on_deathcam")
	_assert(spec.global_position.is_equal_approx(Vector3(5, 2, 3)), "spec_deathcam_position",
		"expected (5,2,3), got %s" % spec.global_position)
	spec.queue_free()


func _test_spectator_follow_enter() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	spec.enter_deathcam(Vector3.ZERO, 0.0, 0.0)
	spec._deathcam_timer = 0.0
	spec._process(0.1)
	_assert(spec.mode == ClientSpectator.Mode.FREECAM or spec.mode == ClientSpectator.Mode.FOLLOW,
		"spec_transitions_from_deathcam",
		"expected FOLLOW or FREECAM, got %d" % spec.mode)
	spec.queue_free()


func _test_spectator_freecam_toggle() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	spec.enter_deathcam(Vector3.ZERO, 0.0, 0.0)
	spec._enter_freecam()
	_assert(spec.mode == ClientSpectator.Mode.FREECAM, "spec_freecam_mode")
	_assert(spec.spectate_target == 0, "spec_freecam_no_target")
	spec.queue_free()


func _test_spectator_exit() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	spec.enter_deathcam(Vector3.ZERO, 0.0, 0.0)
	_assert(spec.is_spectating(), "spec_spectating_before_exit")
	spec.exit_spectator()
	_assert(not spec.is_spectating(), "spec_not_spectating_after_exit")
	_assert(spec.mode == ClientSpectator.Mode.ALIVE, "spec_alive_after_exit")
	_assert(not spec.camera.current, "spec_camera_not_current_after_exit")
	spec.queue_free()


func _test_spectator_team_filter() -> void:
	var spec := ClientSpectator.new()
	add_child(spec)
	spec.game_mode = &"competitive"
	spec.my_team = Team.Id.ANGELS
	spec.update_roster([
		{"id": 10, "team": Team.Id.ANGELS, "alive": true},
		{"id": 20, "team": Team.Id.DEMONS, "alive": true},
		{"id": 30, "team": Team.Id.ANGELS, "alive": false},
	])
	_assert(spec._is_valid_target(10), "spec_alive_teammate_valid")
	_assert(not spec._is_valid_target(20), "spec_enemy_filtered",
		"enemy player should not be valid spectate target")
	_assert(not spec._is_valid_target(30), "spec_dead_teammate_filtered",
		"dead teammate should not be valid spectate target")
	spec.queue_free()
