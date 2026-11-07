extends Node

var _pass_count := 0
var _fail_count := 0
var _total := 0

const TICK_DELTA := 1.0 / 128.0
const SITE_A := Vector3(-10, 1, -8)
const SITE_B := Vector3(10, 1, -8)


func _ready() -> void:
	print("[ObjectiveTests] Starting portal objective tests...")

	test_initial_state()
	test_start_round_sets_carrier()
	test_carrier_at_site_starts_activation()
	test_activation_completes()
	test_activation_interrupt_on_release()
	test_activation_interrupt_on_move_away()
	test_activation_interrupt_on_damage()
	test_carrier_killed_drops_catalyst()
	test_pickup_catalyst()
	test_portal_timer_opens_portal()
	test_seal_starts()
	test_seal_completes()
	test_seal_interrupt_on_release()
	test_seal_interrupt_on_damage()
	test_sealer_killed_cancels_seal()
	test_seal_with_relic_faster()
	test_end_round_resets_objective()
	test_no_objective_without_sites()
	test_catalyst_activated_pauses_round_timer()
	test_elimination_after_activation_attackers_die()
	test_elimination_after_activation_defenders_die()
	test_catalyst_activation_awards_bonus()
	test_portal_opened_ends_round()
	test_portal_sealed_ends_round()

	print("[ObjectiveTests] Done: %d passed, %d failed out of %d" % [
		_pass_count, _fail_count, _total])
	if _fail_count > 0:
		OS.kill(OS.get_process_id())
	get_tree().quit(0)


func _create_objective() -> CompetitiveObjective:
	var obj := CompetitiveObjective.new()
	obj.load_portal_sites({&"A": SITE_A, &"B": SITE_B})
	return obj


func _create_match() -> ServerMatch:
	var config := MatchConfig.new()
	var m := ServerMatch.new()
	m.register_settings(config)
	m.apply_settings(config)
	m.warmup_time = 0.0
	return m


func _create_plugin() -> PluginCompetitive:
	var plugin := PluginCompetitive.new()
	var pm := PluginManager.new()
	pm.load_plugin(plugin)
	plugin.server_match.warmup_time = 0.0
	return plugin


# --- Tests ---


func test_initial_state() -> void:
	var obj := _create_objective()
	_assert_eq(obj.state, CompetitiveObjective.State.INACTIVE,
		"initial state is INACTIVE")
	_assert_eq(obj.carrier_id, -1, "initial carrier is -1")


func test_start_round_sets_carrier() -> void:
	var obj := _create_objective()
	obj.start_round(42)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"state is CARRIED after start_round")
	_assert_eq(obj.carrier_id, 42, "carrier_id is 42")


func test_carrier_at_site_starts_activation() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATING,
		"carrier at site starts activation")
	_assert_eq(obj.activate_site, &"A", "activate_site is A")
	_assert_eq(obj.activator_id, 1, "activator_id is carrier")


func test_activation_completes() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	var flag := [false]
	obj.catalyst_activated.connect(func(_s, _p): flag[0] = true)

	var ticks := int(ceil(obj.activate_time / TICK_DELTA))
	for i in ticks + 1:
		obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)

	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATED,
		"activation completes after activate_time")
	_assert_true(flag[0], "catalyst_activated signal emitted")
	_assert_true(obj.portal_timer > 0.0, "portal_timer started")


func test_activation_interrupt_on_release() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATING, "activating")

	obj.process_use_release(1)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"releasing use interrupts activation")
	_assert_eq(obj.activation_progress, 0.0, "progress reset")


func test_activation_interrupt_on_move_away() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATING, "activating")

	var far_pos := SITE_A + Vector3(20, 0, 0)
	obj.process_use(1, far_pos, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"moving away interrupts activation")


func test_activation_interrupt_on_damage() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATING, "activating")

	obj.on_player_damaged(1)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"taking damage interrupts activation")


func test_carrier_killed_drops_catalyst() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	var drop_pos := Vector3(5, 1, 5)
	var flag := [false]
	obj.catalyst_dropped.connect(func(_p): flag[0] = true)

	obj.on_carrier_killed(drop_pos)
	_assert_eq(obj.state, CompetitiveObjective.State.DROPPED,
		"state is DROPPED after carrier killed")
	_assert_eq(obj.catalyst_position, drop_pos, "catalyst at death position")
	_assert_eq(obj.carrier_id, -1, "no carrier")
	_assert_true(flag[0], "catalyst_dropped signal emitted")


func test_pickup_catalyst() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	var drop_pos := Vector3(5, 1, 5)
	obj.on_carrier_killed(drop_pos)
	_assert_eq(obj.state, CompetitiveObjective.State.DROPPED, "dropped")

	var flag := [false]
	obj.catalyst_picked_up.connect(func(_pid): flag[0] = true)

	var near_pos := drop_pos + Vector3(0.5, 0, 0)
	obj.process_use(2, near_pos, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"attacker picks up catalyst")
	_assert_eq(obj.carrier_id, 2, "new carrier is 2")
	_assert_true(flag[0], "catalyst_picked_up signal emitted")


func test_portal_timer_opens_portal() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	var flag := [false]
	obj.portal_opened.connect(func(_p): flag[0] = true)

	var act_ticks := int(ceil(obj.activate_time / TICK_DELTA))
	for i in act_ticks + 1:
		obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATED, "activated")

	var portal_ticks := int(ceil(obj.portal_time / TICK_DELTA))
	for i in portal_ticks + 1:
		obj.tick(TICK_DELTA)
	_assert_eq(obj.state, CompetitiveObjective.State.PORTAL_OPENED,
		"portal opens after timer expires")
	_assert_true(flag[0], "portal_opened signal emitted")


func test_seal_starts() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)

	obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
		Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.SEALING,
		"defender starts sealing at catalyst")
	_assert_eq(obj.sealer_id, 10, "sealer is defender")


func test_seal_completes() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)
	var flag := [false]
	obj.portal_sealed.connect(func(_pid): flag[0] = true)

	var seal_ticks := int(ceil(obj.seal_time / TICK_DELTA))
	for i in seal_ticks + 1:
		obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
			Team.Id.DEMONS, TICK_DELTA, false)

	_assert_eq(obj.state, CompetitiveObjective.State.PORTAL_SEALED,
		"portal sealed after seal_time")
	_assert_true(flag[0], "portal_sealed signal emitted")


func test_seal_interrupt_on_release() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)

	obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
		Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.SEALING, "sealing")

	obj.process_use_release(10)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATED,
		"releasing use interrupts seal")
	_assert_eq(obj.seal_progress, 0.0, "seal progress reset")


func test_seal_interrupt_on_damage() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)

	obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
		Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.SEALING, "sealing")

	obj.on_player_damaged(10)
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATED,
		"damage interrupts seal")


func test_sealer_killed_cancels_seal() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)

	obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
		Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.SEALING, "sealing")

	obj.on_sealer_killed()
	_assert_eq(obj.state, CompetitiveObjective.State.ACTIVATED,
		"sealer killed cancels seal")
	_assert_eq(obj.sealer_id, -1, "no sealer")


func test_seal_with_relic_faster() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_activate_catalyst(obj)

	var relic_ticks := int(ceil(obj.seal_time_relic / TICK_DELTA))
	for i in relic_ticks + 1:
		obj.process_use(10, obj.catalyst_position, Team.Id.ANGELS,
			Team.Id.DEMONS, TICK_DELTA, true)

	_assert_eq(obj.state, CompetitiveObjective.State.PORTAL_SEALED,
		"seal completes faster with relic")


func test_end_round_resets_objective() -> void:
	var obj := _create_objective()
	obj.start_round(1)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED, "carried")

	obj.end_round()
	_assert_eq(obj.state, CompetitiveObjective.State.INACTIVE,
		"end_round resets to INACTIVE")
	_assert_eq(obj.carrier_id, -1, "carrier reset")


func test_no_objective_without_sites() -> void:
	var obj := CompetitiveObjective.new()
	_assert_true(not obj.has_portal_sites(), "no portal sites by default")

	obj.start_round(1)
	obj.process_use(1, Vector3(0, 1, 0), Team.Id.DEMONS, Team.Id.DEMONS,
		TICK_DELTA, false)
	_assert_eq(obj.state, CompetitiveObjective.State.CARRIED,
		"cannot activate without portal sites")


func test_catalyst_activated_pauses_round_timer() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.DEMONS)
	m.set_team(2, Team.Id.ANGELS)
	m.tick(0.0, 2)
	_assert_eq(m.state, ServerMatch.State.FREEZE, "match in freeze")

	for i in int(ceil(m.freeze_time / TICK_DELTA)) + 1:
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "match live")

	var timer_before := m.round_timer
	m.round_timer_paused = true
	m.catalyst_activated = true
	m.tick(1.0, 2)
	_assert_eq(m.round_timer, timer_before,
		"round timer does not decrease when paused")


func test_elimination_after_activation_attackers_die() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.DEMONS)
	m.set_team(2, Team.Id.ANGELS)
	m.tick(0.0, 2)
	for i in int(ceil(m.freeze_time / TICK_DELTA)) + 1:
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "live")

	m.catalyst_activated = true
	m.report_kill(2, 1, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE,
		"attack team eliminated but catalyst activated — round continues")


func test_elimination_after_activation_defenders_die() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.DEMONS)
	m.set_team(2, Team.Id.ANGELS)
	m.tick(0.0, 2)
	for i in int(ceil(m.freeze_time / TICK_DELTA)) + 1:
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "live")

	m.catalyst_activated = true
	m.report_kill(1, 2, 2)
	_assert_eq(m.state, ServerMatch.State.ROUND_OVER,
		"defense team eliminated after activation — round ends")


func test_catalyst_activation_awards_bonus() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.DEMONS)
	m.set_team(2, Team.Id.ANGELS)
	var money_before := m.economy.get_money(1)
	m.economy.award_catalyst_activate(m.get_team_players(), m.attack_team)
	var money_after := m.economy.get_money(1)
	_assert_eq(money_after - money_before, Economy.CATALYST_ACTIVATE_BONUS,
		"attacker gets catalyst activation bonus")

	var def_money := m.economy.get_money(2)
	_assert_eq(def_money, Economy.STARTING_MONEY,
		"defender does not get activation bonus")


func test_portal_opened_ends_round() -> void:
	var plugin := _create_plugin()
	plugin.load_map_portal_sites({&"A": SITE_A, &"B": SITE_B})
	plugin.on_map_load("test")

	plugin.server_match.set_team(1, Team.Id.DEMONS)
	plugin.server_match.set_team(2, Team.Id.ANGELS)
	plugin.server_match.tick(0.0, 2)
	for i in int(ceil(plugin.server_match.freeze_time / TICK_DELTA)) + 1:
		plugin.server_match.tick(TICK_DELTA, 2)
	_assert_eq(plugin.server_match.state, ServerMatch.State.LIVE, "live")

	plugin.objective.start_round(1)
	var act_ticks := int(ceil(plugin.objective.activate_time / TICK_DELTA))
	for i in act_ticks + 1:
		plugin.objective.process_use(1, SITE_A, Team.Id.DEMONS,
			Team.Id.DEMONS, TICK_DELTA, false)
	_assert_eq(plugin.objective.state, CompetitiveObjective.State.ACTIVATED, "activated")

	var portal_ticks := int(ceil(plugin.objective.portal_time / TICK_DELTA))
	for i in portal_ticks + 1:
		plugin.objective.tick(TICK_DELTA)

	_assert_eq(plugin.server_match.state, ServerMatch.State.ROUND_OVER,
		"portal opened ends the round")
	_assert_eq(plugin.server_match.score.get(plugin.server_match.attack_team, 0), 1,
		"attack team gets a point")


func test_portal_sealed_ends_round() -> void:
	var plugin := _create_plugin()
	plugin.load_map_portal_sites({&"A": SITE_A, &"B": SITE_B})
	plugin.on_map_load("test")

	plugin.server_match.set_team(1, Team.Id.DEMONS)
	plugin.server_match.set_team(2, Team.Id.ANGELS)
	plugin.server_match.tick(0.0, 2)
	for i in int(ceil(plugin.server_match.freeze_time / TICK_DELTA)) + 1:
		plugin.server_match.tick(TICK_DELTA, 2)
	_assert_eq(plugin.server_match.state, ServerMatch.State.LIVE, "live")

	plugin.objective.start_round(1)
	_activate_catalyst(plugin.objective)
	_assert_eq(plugin.objective.state, CompetitiveObjective.State.ACTIVATED, "activated")

	var seal_ticks := int(ceil(plugin.objective.seal_time / TICK_DELTA))
	for i in seal_ticks + 1:
		plugin.objective.process_use(2, plugin.objective.catalyst_position,
			Team.Id.ANGELS, Team.Id.DEMONS, TICK_DELTA, false)

	_assert_eq(plugin.server_match.state, ServerMatch.State.ROUND_OVER,
		"portal sealed ends the round")
	_assert_eq(plugin.server_match.score.get(plugin.server_match.defense_team, 0), 1,
		"defense team gets a point")


# --- Helpers ---


func _activate_catalyst(obj: CompetitiveObjective) -> void:
	var ticks := int(ceil(obj.activate_time / TICK_DELTA))
	for i in ticks + 1:
		obj.process_use(1, SITE_A, Team.Id.DEMONS, Team.Id.DEMONS, TICK_DELTA, false)


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
