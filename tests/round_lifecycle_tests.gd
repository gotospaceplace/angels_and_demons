extends Node

var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var results: Array[String] = []


func _ready() -> void:
	test_queue = [
		&"test_initial_state_is_warmup",
		&"test_warmup_to_freeze_on_min_players",
		&"test_warmup_stays_without_min_players",
		&"test_freeze_to_live_after_timer",
		&"test_freeze_blocks_movement",
		&"test_live_allows_movement",
		&"test_warmup_allows_respawn",
		&"test_live_blocks_respawn",
		&"test_elimination_ends_round",
		&"test_timer_expiry_defense_wins",
		&"test_round_over_to_next_round",
		&"test_round_number_increments",
		&"test_score_tracks_wins",
		&"test_halftime_at_rounds_per_half",
		&"test_halftime_swaps_teams",
		&"test_halftime_resets_economy",
		&"test_match_over_at_rounds_to_win",
		&"test_match_over_tie_at_max_rounds",
		&"test_economy_win_reward",
		&"test_economy_loss_bonus",
		&"test_economy_kill_reward",
		&"test_alive_count_tracks_kills",
		&"test_player_disconnect_updates_alive",
		&"test_end_round_external",
	]

	print("=== Round Lifecycle Tests ===")
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


func _make_match() -> ServerMatch:
	var m := ServerMatch.new()
	m.freeze_time = 5.0
	m.round_time = 115.0
	m.round_over_time = 5.0
	m.halftime_time = 15.0
	m.rounds_per_half = 12
	m.rounds_to_win = 13
	m.warmup_min_players = 2
	return m


func _add_players(m: ServerMatch) -> void:
	for i in range(1, 6):
		m.set_team(i, Team.Id.ANGELS)
	for i in range(6, 11):
		m.set_team(i, Team.Id.DEMONS)


func _advance_to_live(m: ServerMatch) -> void:
	m.tick(0.0, 10)
	m.tick(m.freeze_time + 0.1, 10)


# --- Tests ---

func test_initial_state_is_warmup() -> void:
	var m := _make_match()
	if m.state == ServerMatch.State.WARMUP:
		_pass("initial state is WARMUP")
	else:
		_fail("expected WARMUP, got %s" % m.get_state_name())


func test_warmup_to_freeze_on_min_players() -> void:
	var m := _make_match()
	_add_players(m)
	m.tick(0.0, 2)
	if m.state == ServerMatch.State.FREEZE:
		_pass("WARMUP → FREEZE with %d players" % m.warmup_min_players)
	else:
		_fail("expected FREEZE, got %s" % m.get_state_name())


func test_warmup_stays_without_min_players() -> void:
	var m := _make_match()
	_add_players(m)
	m.tick(0.0, 1)
	if m.state == ServerMatch.State.WARMUP:
		_pass("stays WARMUP with 1 player")
	else:
		_fail("expected WARMUP, got %s" % m.get_state_name())


func test_freeze_to_live_after_timer() -> void:
	var m := _make_match()
	_add_players(m)
	m.tick(0.0, 10)
	if m.state != ServerMatch.State.FREEZE:
		_fail("expected FREEZE first, got %s" % m.get_state_name())
		return
	m.tick(m.freeze_time + 0.1, 10)
	if m.state == ServerMatch.State.LIVE:
		_pass("FREEZE → LIVE after %.1fs" % m.freeze_time)
	else:
		_fail("expected LIVE, got %s" % m.get_state_name())


func test_freeze_blocks_movement() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = _make_match()
	_add_players(plugin.server_match)
	plugin.server_match.tick(0.0, 10)
	if plugin.server_match.state != ServerMatch.State.FREEZE:
		_fail("expected FREEZE, got %s" % plugin.server_match.get_state_name())
		return
	if not plugin.can_player_move(1):
		_pass("movement blocked during FREEZE")
	else:
		_fail("movement should be blocked during FREEZE")


func test_live_allows_movement() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = _make_match()
	_add_players(plugin.server_match)
	_advance_to_live(plugin.server_match)
	if plugin.server_match.state != ServerMatch.State.LIVE:
		_fail("expected LIVE, got %s" % plugin.server_match.get_state_name())
		return
	if plugin.can_player_move(1):
		_pass("movement allowed during LIVE")
	else:
		_fail("movement should be allowed during LIVE")


func test_warmup_allows_respawn() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = _make_match()
	if plugin.can_player_respawn(1):
		_pass("respawn allowed during WARMUP")
	else:
		_fail("respawn should be allowed during WARMUP")


func test_live_blocks_respawn() -> void:
	var plugin := PluginCompetitive.new()
	plugin.server_match = _make_match()
	_add_players(plugin.server_match)
	_advance_to_live(plugin.server_match)
	if not plugin.can_player_respawn(1):
		_pass("respawn blocked during LIVE")
	else:
		_fail("respawn should be blocked during LIVE")


func test_elimination_ends_round() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	if m.state == ServerMatch.State.ROUND_OVER:
		_pass("all Angels killed → ROUND_OVER (Demons win)")
	else:
		_fail("expected ROUND_OVER, got %s" % m.get_state_name())


func test_timer_expiry_defense_wins() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)
	m.tick(m.round_time + 0.1, 10)
	if m.state == ServerMatch.State.ROUND_OVER:
		var defense_score: int = m.score.get(m.defense_team, 0)
		if defense_score == 1:
			_pass("timer expired → defense (%s) wins" % Team.get_team_name(m.defense_team))
		else:
			_fail("defense score=%d, expected 1" % defense_score)
	else:
		_fail("expected ROUND_OVER, got %s" % m.get_state_name())


func test_round_over_to_next_round() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)
	if m.state == ServerMatch.State.FREEZE and m.round_number == 2:
		_pass("ROUND_OVER → FREEZE (round 2)")
	else:
		_fail("expected FREEZE round 2, got %s round %d" % [m.get_state_name(), m.round_number])


func test_round_number_increments() -> void:
	var m := _make_match()
	_add_players(m)
	if m.round_number != 0:
		_fail("initial round should be 0, got %d" % m.round_number)
		return
	m.tick(0.0, 10)
	if m.round_number == 1:
		_pass("round incremented to %d on first round start" % m.round_number)
	else:
		_fail("expected round 1, got %d" % m.round_number)


func test_score_tracks_wins() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	var demon_score: int = m.score.get(Team.Id.DEMONS, 0)
	var angel_score: int = m.score.get(Team.Id.ANGELS, 0)
	if demon_score == 1 and angel_score == 0:
		_pass("Demons 1 - 0 Angels after elimination")
	else:
		_fail("score: Angels %d - Demons %d" % [angel_score, demon_score])


func test_halftime_at_rounds_per_half() -> void:
	var m := _make_match()
	m.rounds_per_half = 2
	m.rounds_to_win = 3
	m.max_rounds = 4
	_add_players(m)

	# Round 1: Demons eliminate Angels
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	# Round 2: Demons eliminate Angels again → halftime
	m.tick(m.freeze_time + 0.1, 10)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	if m.state == ServerMatch.State.HALFTIME:
		_pass("HALFTIME after %d rounds" % m.rounds_per_half)
	else:
		_fail("expected HALFTIME, got %s at round %d" % [m.get_state_name(), m.round_number])


func test_halftime_swaps_teams() -> void:
	var m := _make_match()
	m.rounds_per_half = 1
	m.rounds_to_win = 2
	m.max_rounds = 2
	_add_players(m)

	var attack_before := m.attack_team
	var p1_team_before: int = m.get_team(1)

	# Complete one round to trigger halftime
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	if m.state != ServerMatch.State.HALFTIME:
		_fail("expected HALFTIME, got %s" % m.get_state_name())
		return

	var attack_after := m.attack_team
	var p1_team_after: int = m.get_team(1)

	if attack_before != attack_after and p1_team_before != p1_team_after:
		_pass("teams swapped: attack %s→%s, P1 %s→%s" % [
			Team.get_team_name(attack_before), Team.get_team_name(attack_after),
			Team.get_team_name(p1_team_before), Team.get_team_name(p1_team_after)])
	else:
		_fail("swap failed: attack %s→%s, P1 %s→%s" % [
			Team.get_team_name(attack_before), Team.get_team_name(attack_after),
			Team.get_team_name(p1_team_before), Team.get_team_name(p1_team_after)])


func test_halftime_resets_economy() -> void:
	var m := _make_match()
	m.rounds_per_half = 1
	m.rounds_to_win = 2
	m.max_rounds = 2
	_add_players(m)

	m.economy.set_money(1, 10000)

	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	if m.state != ServerMatch.State.HALFTIME:
		_fail("expected HALFTIME, got %s" % m.get_state_name())
		return

	var money := m.economy.get_money(1)
	if money == Economy.STARTING_MONEY:
		_pass("economy reset to $%d at halftime" % money)
	else:
		_fail("expected $%d, got $%d" % [Economy.STARTING_MONEY, money])


func test_match_over_at_rounds_to_win() -> void:
	var m := _make_match()
	m.rounds_per_half = 2
	m.rounds_to_win = 2
	m.max_rounds = 4
	_add_players(m)

	# Round 1: Demons eliminate Angels
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	# Round 2: Demons eliminate Angels again
	m.tick(m.freeze_time + 0.1, 10)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	m.tick(m.round_over_time + 0.1, 10)

	if m.state == ServerMatch.State.MATCH_OVER:
		_pass("MATCH_OVER when team reaches %d wins" % m.rounds_to_win)
	else:
		_fail("expected MATCH_OVER, got %s (round %d, score A:%d D:%d)" % [
			m.get_state_name(), m.round_number,
			m.score.get(Team.Id.ANGELS, 0),
			m.score.get(Team.Id.DEMONS, 0)])


func test_match_over_tie_at_max_rounds() -> void:
	var m := _make_match()
	m.rounds_per_half = 1
	m.rounds_to_win = 2
	m.max_rounds = 2
	_add_players(m)

	# Round 1: Demons win by elimination
	_advance_to_live(m)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	# Score: Demons 1, Angels 0
	m.tick(m.round_over_time + 0.1, 10)

	# Halftime (round_number == rounds_per_half == 1)
	if m.state != ServerMatch.State.HALFTIME:
		_fail("expected HALFTIME, got %s" % m.get_state_name())
		return
	m.tick(m.halftime_time + 0.1, 10)

	# Round 2: Angels (now swapped, were Demons) — actually let's use timer expiry
	# After swap: old Angels are now Demons, old Demons are now Angels
	# Defense team wins on timer
	m.tick(m.freeze_time + 0.1, 10)
	m.tick(m.round_time + 0.1, 10)
	# Defense wins → Score should be 1-1 at max_rounds

	if m.state == ServerMatch.State.ROUND_OVER:
		m.tick(m.round_over_time + 0.1, 10)

	if m.state == ServerMatch.State.MATCH_OVER:
		_pass("MATCH_OVER at max_rounds with tie")
	else:
		_fail("expected MATCH_OVER, got %s (round %d, score A:%d D:%d)" % [
			m.get_state_name(), m.round_number,
			m.score.get(Team.Id.ANGELS, 0),
			m.score.get(Team.Id.DEMONS, 0)])


func test_economy_win_reward() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	var before := m.economy.get_money(6)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	var after := m.economy.get_money(6)

	# Demons won: should get elimination reward + kill rewards
	var kill_rewards := 5 * Economy.get_kill_reward(2)
	var win_reward := Economy.REWARD_WIN_ELIMINATION
	var expected := before + kill_rewards + win_reward
	expected = mini(expected, Economy.MAX_MONEY)
	if after == expected:
		_pass("winner got $%d (kills+win)" % (after - before))
	else:
		_fail("expected $%d, got $%d (before=$%d)" % [expected, after, before])


func test_economy_loss_bonus() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	var before := m.economy.get_money(1)
	for i in range(1, 6):
		m.report_kill(6, i, 2)
	var after := m.economy.get_money(1)

	var loss_bonus := Economy.get_loss_bonus(1)
	var expected := before + loss_bonus
	if after == expected:
		_pass("loser got loss bonus $%d" % loss_bonus)
	else:
		_fail("expected $%d, got $%d" % [expected, after])


func test_economy_kill_reward() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	var before := m.economy.get_money(6)
	m.report_kill(6, 1, 0)  # knife kill
	var after := m.economy.get_money(6)
	var gained := after - before

	if gained == Economy.get_kill_reward(0):
		_pass("knife kill reward $%d during round" % gained)
	else:
		_fail("expected $%d, got $%d" % [Economy.get_kill_reward(0), gained])


func test_alive_count_tracks_kills() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	var before := m.get_alive_count(Team.Id.ANGELS)
	m.report_kill(6, 1, 2)
	var after := m.get_alive_count(Team.Id.ANGELS)

	if before == 5 and after == 4:
		_pass("alive count %d → %d after kill" % [before, after])
	else:
		_fail("expected 5 → 4, got %d → %d" % [before, after])


func test_player_disconnect_updates_alive() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	var before := m.get_alive_count(Team.Id.ANGELS)
	m.remove_player(1)
	var after := m.get_alive_count(Team.Id.ANGELS)

	if before == 5 and after == 4:
		_pass("disconnect reduces alive %d → %d" % [before, after])
	else:
		_fail("expected 5 → 4, got %d → %d" % [before, after])


func test_end_round_external() -> void:
	var m := _make_match()
	_add_players(m)
	_advance_to_live(m)

	m.end_round_external(Team.Id.DEMONS, &"objective")
	if m.state == ServerMatch.State.ROUND_OVER:
		var score: int = m.score.get(Team.Id.DEMONS, 0)
		if score == 1:
			_pass("external round end → Demons win by objective")
		else:
			_fail("expected Demons score 1, got %d" % score)
	else:
		_fail("expected ROUND_OVER, got %s" % m.get_state_name())
