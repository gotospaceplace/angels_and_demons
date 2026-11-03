extends Node

var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var results: Array[String] = []


func _ready() -> void:
	test_queue = [
		&"test_starting_money",
		&"test_loss_bonus_escalation",
		&"test_loss_bonus_cap",
		&"test_win_resets_loss_streak",
		&"test_round_win_elimination",
		&"test_round_win_objective",
		&"test_kill_reward_rifle",
		&"test_kill_reward_smg",
		&"test_kill_reward_sniper",
		&"test_kill_reward_pistol",
		&"test_kill_reward_knife",
		&"test_catalyst_activate_bonus",
		&"test_purchase_success",
		&"test_purchase_insufficient_funds",
		&"test_max_money_cap",
		&"test_reset_economy",
		&"test_remove_player",
	]

	print("=== Economy Tests ===")
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


func _make_economy() -> ServerEconomy:
	var eco := ServerEconomy.new()
	return eco


func _make_team_players(eco: ServerEconomy) -> Dictionary:
	# 5v5: peers 1-5 = Angels, 6-10 = Demons
	var team_players := {}
	for i in range(1, 6):
		eco.init_player(i)
		team_players[i] = Team.Id.ANGELS
	for i in range(6, 11):
		eco.init_player(i)
		team_players[i] = Team.Id.DEMONS
	return team_players


# --- Tests ---

func test_starting_money() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var money := eco.get_money(1)
	if money == Economy.STARTING_MONEY:
		_pass("starting money=$%d" % money)
	else:
		_fail("expected $%d, got $%d" % [Economy.STARTING_MONEY, money])


func test_loss_bonus_escalation() -> void:
	var expected := [1400, 1900, 2400, 2900, 3400]
	var actual := []
	for i in range(1, 6):
		actual.append(Economy.get_loss_bonus(i))
	if actual == expected:
		_pass("loss bonus escalation: %s" % str(actual))
	else:
		_fail("expected %s, got %s" % [str(expected), str(actual)])


func test_loss_bonus_cap() -> void:
	var bonus := Economy.get_loss_bonus(10)
	if bonus == Economy.LOSS_BONUS_MAX:
		_pass("loss bonus caps at $%d after 10 losses" % bonus)
	else:
		_fail("expected $%d cap, got $%d" % [Economy.LOSS_BONUS_MAX, bonus])


func test_win_resets_loss_streak() -> void:
	var eco := _make_economy()
	var tp := _make_team_players(eco)

	# Lose 3 rounds as Angels
	for i in 3:
		eco.award_round_loss(Team.Id.ANGELS, tp)
		eco.award_round_win(Team.Id.DEMONS, false, tp)
	var streak_before := eco.get_loss_streak(Team.Id.ANGELS)

	# Angels win a round
	eco.award_round_win(Team.Id.ANGELS, false, tp)
	eco.award_round_loss(Team.Id.DEMONS, tp)
	var streak_after := eco.get_loss_streak(Team.Id.ANGELS)

	# Lose again — should be back to 1st loss bonus
	eco.award_round_loss(Team.Id.ANGELS, tp)
	var next_bonus := Economy.get_loss_bonus(eco.get_loss_streak(Team.Id.ANGELS))

	if streak_before == 3 and streak_after == 0 and next_bonus == Economy.LOSS_BONUS_BASE:
		_pass("win resets streak (3→0), next loss=$%d" % next_bonus)
	else:
		_fail("streak before=%d after=%d next_bonus=$%d" % [
			streak_before, streak_after, next_bonus])


func test_round_win_elimination() -> void:
	var eco := _make_economy()
	var tp := _make_team_players(eco)
	var before := eco.get_money(1)
	eco.award_round_win(Team.Id.ANGELS, false, tp)
	var after := eco.get_money(1)
	var gained := after - before
	if gained == Economy.REWARD_WIN_ELIMINATION:
		_pass("elimination win +$%d (total $%d)" % [gained, after])
	else:
		_fail("expected +$%d, got +$%d" % [Economy.REWARD_WIN_ELIMINATION, gained])


func test_round_win_objective() -> void:
	var eco := _make_economy()
	var tp := _make_team_players(eco)
	var before := eco.get_money(1)
	eco.award_round_win(Team.Id.ANGELS, true, tp)
	var after := eco.get_money(1)
	var gained := after - before
	if gained == Economy.REWARD_WIN_OBJECTIVE:
		_pass("objective win +$%d (total $%d)" % [gained, after])
	else:
		_fail("expected +$%d, got +$%d" % [Economy.REWARD_WIN_OBJECTIVE, gained])


func test_kill_reward_rifle() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var before := eco.get_money(1)
	eco.award_kill(1, 2)  # weapon_idx 2 = AK-47 (rifle)
	var gained := eco.get_money(1) - before
	if gained == 300:
		_pass("rifle kill +$%d" % gained)
	else:
		_fail("expected +$300, got +$%d" % gained)


func test_kill_reward_smg() -> void:
	# No SMG in current registry, test via Economy constant directly
	var reward := Economy.KILL_REWARDS[Economy.WeaponCategory.SMG]
	if reward == 600:
		_pass("SMG kill reward=$%d" % reward)
	else:
		_fail("expected $600, got $%d" % reward)


func test_kill_reward_sniper() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var before := eco.get_money(1)
	eco.award_kill(1, 4)  # weapon_idx 4 = AWP (sniper)
	var gained := eco.get_money(1) - before
	if gained == 100:
		_pass("sniper kill +$%d" % gained)
	else:
		_fail("expected +$100, got +$%d" % gained)


func test_kill_reward_pistol() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var before := eco.get_money(1)
	eco.award_kill(1, 1)  # weapon_idx 1 = USP (pistol)
	var gained := eco.get_money(1) - before
	if gained == 300:
		_pass("pistol kill +$%d" % gained)
	else:
		_fail("expected +$300, got +$%d" % gained)


func test_kill_reward_knife() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var before := eco.get_money(1)
	eco.award_kill(1, 0)  # weapon_idx 0 = knife
	var gained := eco.get_money(1) - before
	if gained == 1500:
		_pass("knife kill +$%d" % gained)
	else:
		_fail("expected +$1500, got +$%d" % gained)


func test_catalyst_activate_bonus() -> void:
	var eco := _make_economy()
	var tp := _make_team_players(eco)
	var before := eco.get_money(1)  # Angels player
	eco.award_catalyst_activate(tp, Team.Id.ANGELS)
	var gained := eco.get_money(1) - before
	# Verify Demons didn't get it
	var demon_before := Economy.STARTING_MONEY
	var demon_after := eco.get_money(6)
	if gained == Economy.CATALYST_ACTIVATE_BONUS and demon_after == demon_before:
		_pass("catalyst activate +$%d to attack team only" % gained)
	else:
		_fail("angels got +$%d, demons got +$%d" % [
			gained, demon_after - demon_before])


func test_purchase_success() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var ok := eco.purchase(1, 700)
	var remaining := eco.get_money(1)
	if ok and remaining == 100:
		_pass("purchase $700: ok, remaining=$%d" % remaining)
	else:
		_fail("purchase ok=%s, remaining=$%d (expected $100)" % [ok, remaining])


func test_purchase_insufficient_funds() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	var ok := eco.purchase(1, 900)
	var remaining := eco.get_money(1)
	if not ok and remaining == Economy.STARTING_MONEY:
		_pass("purchase denied, money unchanged=$%d" % remaining)
	else:
		_fail("purchase ok=%s, remaining=$%d" % [ok, remaining])


func test_max_money_cap() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	eco.set_money(1, 15500)
	eco.add_money(1, 1000)
	var money := eco.get_money(1)
	if money == Economy.MAX_MONEY:
		_pass("capped at $%d" % money)
	else:
		_fail("expected $%d cap, got $%d" % [Economy.MAX_MONEY, money])


func test_reset_economy() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	eco.init_player(2)
	eco.set_money(1, 10000)
	eco.set_money(2, 5000)
	eco.reset_economy()
	var m1 := eco.get_money(1)
	var m2 := eco.get_money(2)
	if m1 == Economy.STARTING_MONEY and m2 == Economy.STARTING_MONEY:
		_pass("reset to $%d each" % m1)
	else:
		_fail("player1=$%d player2=$%d (expected $%d)" % [
			m1, m2, Economy.STARTING_MONEY])


func test_remove_player() -> void:
	var eco := _make_economy()
	eco.init_player(1)
	eco.remove_player(1)
	var money := eco.get_money(1)
	if money == 0:
		_pass("removed player returns $0")
	else:
		_fail("expected $0 after remove, got $%d" % money)
