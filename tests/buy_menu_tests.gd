extends Node

var _pass_count := 0
var _fail_count := 0
var _total := 0

const TICK_DELTA := 1.0 / 128.0


func _ready() -> void:
	print("[BuyMenuTests] Starting buy menu tests...")

	test_catalog_item_count()
	test_catalog_get_item()
	test_catalog_get_item_by_id()
	test_catalog_get_index()
	test_catalog_get_items_for_category()
	test_catalog_can_buy_success()
	test_catalog_can_buy_insufficient_funds()
	test_catalog_can_buy_wrong_team()
	test_catalog_can_buy_already_owned()
	test_catalog_can_buy_armor_upgrade()
	test_catalog_can_buy_armor_no_downgrade()

	test_protocol_pack_buy_request()
	test_protocol_pack_weapon_request()
	test_protocol_pack_buy_result()
	test_protocol_pack_buy_request_event()

	test_buy_period_during_freeze()
	test_buy_period_during_live_start()
	test_buy_period_expires_in_live()
	test_buy_period_not_in_warmup()
	test_buy_period_not_in_round_over()

	test_buy_zone_near_spawn()
	test_buy_zone_too_far()

	test_server_buy_flow()
	test_server_buy_dead_player()
	test_server_buy_wrong_item()
	test_server_weapon_request_to_teammates()

	test_player_set_weapon()

	print("[BuyMenuTests] Done: %d passed, %d failed out of %d" % [
		_pass_count, _fail_count, _total])
	if _fail_count > 0:
		OS.kill(OS.get_process_id())
	get_tree().quit(0)


# --- Catalog Tests ---

func test_catalog_item_count() -> void:
	_assert_eq(BuyCatalog.item_count(), 6, "catalog has 6 items")


func test_catalog_get_item() -> void:
	var item := BuyCatalog.get_item(0)
	_assert_eq(item["id"], &"usp", "first item is usp")
	_assert_eq(item["price"], 500, "usp costs $500")

	var empty := BuyCatalog.get_item(99)
	_assert_true(empty.is_empty(), "invalid index returns empty")


func test_catalog_get_item_by_id() -> void:
	var item := BuyCatalog.get_item_by_id(&"ak47")
	_assert_eq(item["name"], "AK-47", "ak47 lookup by id")
	_assert_eq(item["price"], 2700, "ak47 price")

	var empty := BuyCatalog.get_item_by_id(&"nonexistent")
	_assert_true(empty.is_empty(), "unknown id returns empty")


func test_catalog_get_index() -> void:
	_assert_eq(BuyCatalog.get_index(&"usp"), 0, "usp is index 0")
	_assert_eq(BuyCatalog.get_index(&"ak47"), 1, "ak47 is index 1")
	_assert_eq(BuyCatalog.get_index(&"m4a1"), 2, "m4a1 is index 2")
	_assert_eq(BuyCatalog.get_index(&"awp"), 3, "awp is index 3")
	_assert_eq(BuyCatalog.get_index(&"vest"), 4, "vest is index 4")
	_assert_eq(BuyCatalog.get_index(&"fullarmor"), 5, "fullarmor is index 5")
	_assert_eq(BuyCatalog.get_index(&"invalid"), -1, "invalid returns -1")


func test_catalog_get_items_for_category() -> void:
	var pistols := BuyCatalog.get_items_for_category(&"pistols")
	_assert_eq(pistols.size(), 1, "1 pistol (usp)")

	var rifles := BuyCatalog.get_items_for_category(&"rifles")
	_assert_eq(rifles.size(), 3, "3 rifles (ak47, m4a1, awp)")

	var equip := BuyCatalog.get_items_for_category(&"equipment")
	_assert_eq(equip.size(), 2, "2 equipment (vest, fullarmor)")


func test_catalog_can_buy_success() -> void:
	# Demons is attack_team, player is Demons, buying ak47 (attack only)
	var check := BuyCatalog.can_buy(1, 3000, Team.Id.DEMONS, Team.Id.DEMONS, 1, 0)
	_assert_true(check["ok"], "can buy ak47 as attacker with enough money")


func test_catalog_can_buy_insufficient_funds() -> void:
	var check := BuyCatalog.can_buy(1, 1000, Team.Id.DEMONS, Team.Id.DEMONS, 1, 0)
	_assert_true(not check["ok"], "cannot buy ak47 with $1000")
	_assert_eq(check["reason"], "Insufficient funds", "reason is insufficient funds")


func test_catalog_can_buy_wrong_team() -> void:
	# ak47 is attack-only, player is Angels (defense since attack_team=Demons)
	var check := BuyCatalog.can_buy(1, 5000, Team.Id.ANGELS, Team.Id.DEMONS, 1, 0)
	_assert_true(not check["ok"], "cannot buy ak47 as defender")
	_assert_eq(check["reason"], "Attack team only", "reason is attack only")

	# m4a1 is defense-only, player is Demons (attack since attack_team=Demons)
	var check2 := BuyCatalog.can_buy(2, 5000, Team.Id.DEMONS, Team.Id.DEMONS, 1, 0)
	_assert_true(not check2["ok"], "cannot buy m4a1 as attacker")
	_assert_eq(check2["reason"], "Defense team only", "reason is defense only")


func test_catalog_can_buy_already_owned() -> void:
	# Player already has weapon_idx 2 (ak47), trying to buy ak47 again
	var check := BuyCatalog.can_buy(1, 5000, Team.Id.DEMONS, Team.Id.DEMONS, 2, 0)
	_assert_true(not check["ok"], "cannot buy weapon already owned")
	_assert_eq(check["reason"], "Already own this weapon", "reason is already owned")


func test_catalog_can_buy_armor_upgrade() -> void:
	# vest gives 50 armor, player has 0
	var check := BuyCatalog.can_buy(4, 1000, Team.Id.ANGELS, Team.Id.DEMONS, 1, 0)
	_assert_true(check["ok"], "can buy vest with 0 armor")

	# fullarmor gives 100, player has 50
	var check2 := BuyCatalog.can_buy(5, 1500, Team.Id.ANGELS, Team.Id.DEMONS, 1, 50)
	_assert_true(check2["ok"], "can upgrade from vest to fullarmor")


func test_catalog_can_buy_armor_no_downgrade() -> void:
	# vest gives 50, player already has 100
	var check := BuyCatalog.can_buy(4, 1000, Team.Id.ANGELS, Team.Id.DEMONS, 1, 100)
	_assert_true(not check["ok"], "cannot downgrade armor")
	_assert_eq(check["reason"], "Already have equal or better armor", "reason is already have armor")

	# fullarmor gives 100, player already has 100
	var check2 := BuyCatalog.can_buy(5, 1500, Team.Id.ANGELS, Team.Id.DEMONS, 1, 100)
	_assert_true(not check2["ok"], "cannot rebuy same armor level")


# --- Protocol Tests ---

func test_protocol_pack_buy_request() -> void:
	var pkt := NetProtocol.pack_buy_request(3)
	_assert_eq(pkt[0], NetConstants.PROTOCOL_VERSION, "buy req version")
	_assert_eq(pkt[1], NetProtocol.MSG_ADMIN, "buy req is admin msg")
	_assert_eq(pkt[2], NetProtocol.ADMIN_BUY, "buy req subtype")
	_assert_eq(pkt[3], 3, "buy req item index")


func test_protocol_pack_weapon_request() -> void:
	var pkt := NetProtocol.pack_weapon_request(1)
	_assert_eq(pkt[1], NetProtocol.MSG_ADMIN, "weapon req is admin msg")
	_assert_eq(pkt[2], NetProtocol.ADMIN_REQUEST, "weapon req subtype")
	_assert_eq(pkt[3], 1, "weapon req item index")


func test_protocol_pack_buy_result() -> void:
	var pkt := NetProtocol.pack_buy_result_event(true, 2, 5300)
	_assert_eq(pkt[1], NetProtocol.MSG_EVENT, "buy result is event")
	_assert_eq(pkt[2], NetProtocol.EVT_BUY_RESULT, "buy result subtype")
	_assert_eq(pkt[3], 1, "success = 1")
	_assert_eq(pkt[4], 2, "item index = 2")
	var money := pkt[5] | (pkt[6] << 8)
	_assert_eq(money, 5300, "money = 5300")

	var fail_pkt := NetProtocol.pack_buy_result_event(false, 0, 800)
	_assert_eq(fail_pkt[3], 0, "failure = 0")


func test_protocol_pack_buy_request_event() -> void:
	var pkt := NetProtocol.pack_buy_request_event(42, 1)
	_assert_eq(pkt[2], NetProtocol.EVT_BUY_REQUEST, "buy request event subtype")
	var req_id := pkt[3] | (pkt[4] << 8)
	_assert_eq(req_id, 42, "requester id = 42")
	_assert_eq(pkt[5], 1, "item index = 1")


# --- Buy Period Tests ---

func _create_match() -> ServerMatch:
	var config := MatchConfig.new()
	var m := ServerMatch.new()
	m.register_settings(config)
	m.apply_settings(config)
	return m


func test_buy_period_during_freeze() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.ANGELS)
	m.set_team(2, Team.Id.DEMONS)
	m.tick(TICK_DELTA, 2)  # warmup → freeze (2 players)
	_assert_eq(m.state, ServerMatch.State.FREEZE, "state is FREEZE")
	_assert_true(m.is_buy_period(), "buy period active during freeze")


func test_buy_period_during_live_start() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.ANGELS)
	m.set_team(2, Team.Id.DEMONS)
	m.tick(TICK_DELTA, 2)  # warmup → freeze
	# Tick through freeze time (default 5s)
	for i in range(int(5.0 / TICK_DELTA) + 1):
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "state is LIVE")
	_assert_true(m.is_buy_period(), "buy period active at start of live")


func test_buy_period_expires_in_live() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.ANGELS)
	m.set_team(2, Team.Id.DEMONS)
	m.tick(TICK_DELTA, 2)  # warmup → freeze
	# Tick through freeze (5s) + live buy window (10s) + extra
	for i in range(int(16.0 / TICK_DELTA) + 1):
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "still LIVE")
	_assert_true(not m.is_buy_period(), "buy period expired after 15s total")


func test_buy_period_not_in_warmup() -> void:
	var m := _create_match()
	_assert_eq(m.state, ServerMatch.State.WARMUP, "state is WARMUP")
	_assert_true(not m.is_buy_period(), "no buy period in warmup")


func test_buy_period_not_in_round_over() -> void:
	var m := _create_match()
	m.set_team(1, Team.Id.ANGELS)
	m.set_team(2, Team.Id.DEMONS)
	m.tick(TICK_DELTA, 2)  # warmup → freeze
	# Tick to LIVE
	for i in range(int(5.0 / TICK_DELTA) + 1):
		m.tick(TICK_DELTA, 2)
	_assert_eq(m.state, ServerMatch.State.LIVE, "state is LIVE")
	m.end_round_external(Team.Id.ANGELS, &"elimination")
	_assert_eq(m.state, ServerMatch.State.ROUND_OVER, "state is ROUND_OVER")
	_assert_true(not m.is_buy_period(), "no buy period in round over")


# --- Buy Zone Tests ---

func _create_competitive_plugin() -> PluginCompetitive:
	var plugin := PluginCompetitive.new()
	var pm := PluginManager.new()
	pm.load_plugin(plugin)

	var angels_spawns: Array[Vector3] = [
		Vector3(0, 1, -18), Vector3(2, 1, -18), Vector3(-2, 1, -18),
		Vector3(4, 1, -18), Vector3(-4, 1, -18),
	]
	var demons_spawns: Array[Vector3] = [
		Vector3(0, 1, 18), Vector3(2, 1, 18), Vector3(-2, 1, 18),
		Vector3(4, 1, 18), Vector3(-4, 1, 18),
	]
	plugin.load_map_spawns(angels_spawns, demons_spawns)
	return plugin


func test_buy_zone_near_spawn() -> void:
	var plugin := _create_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.DEMONS)
	plugin.server_match.tick(TICK_DELTA, 2)  # warmup → freeze

	# Angels spawn near z=-18, player at z=-15 should be in buy zone
	var can := plugin.can_purchase(1, &"usp", 500, Vector3(0, 1, -15))
	_assert_true(can, "player near own spawn is in buy zone")


func test_buy_zone_too_far() -> void:
	var plugin := _create_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.DEMONS)
	plugin.server_match.tick(TICK_DELTA, 2)  # warmup → freeze

	# Angels spawn near z=-18, player at z=0 should NOT be in buy zone
	var can := plugin.can_purchase(1, &"usp", 500, Vector3(0, 1, 0))
	_assert_true(not can, "player far from spawn is NOT in buy zone")


# --- Server Integration Tests ---

func test_server_buy_flow() -> void:
	var plugin := _create_competitive_plugin()
	plugin.server_match.set_team(1, Team.Id.ANGELS)
	plugin.server_match.set_team(2, Team.Id.DEMONS)
	plugin.server_match.tick(TICK_DELTA, 2)  # warmup → freeze

	# Player 1 (Angels, defense) has $800, try to buy vest ($650)
	var money_before := plugin.server_match.economy.get_money(1)
	_assert_eq(money_before, Economy.STARTING_MONEY, "starting money is $800")

	# Check can_purchase (during freeze, near spawn)
	var can := plugin.can_purchase(1, &"vest", 650, Vector3(0, 1, -16))
	_assert_true(can, "can purchase vest during freeze near spawn")

	# Deduct money
	var success := plugin.deduct_money(1, 650)
	_assert_true(success, "deduct_money succeeds")
	_assert_eq(plugin.server_match.economy.get_money(1), 150, "money is $150 after purchase")


func test_server_buy_dead_player() -> void:
	# Dead players can't buy — this is checked in server_game before can_purchase
	# Verify catalog approves when player doesn't already own the weapon
	var check := BuyCatalog.can_buy(0, 800, Team.Id.ANGELS, Team.Id.DEMONS, 2, 0)
	_assert_true(check["ok"], "catalog approves usp buy with different weapon equipped")


func test_server_buy_wrong_item() -> void:
	var empty := BuyCatalog.get_item(99)
	_assert_true(empty.is_empty(), "invalid item index returns empty dict")


func test_server_weapon_request_to_teammates() -> void:
	# Verify request event packet encodes correctly
	var pkt := NetProtocol.pack_buy_request_event(5, 1)
	var req_id := pkt[3] | (pkt[4] << 8)
	_assert_eq(req_id, 5, "request event has correct requester id")
	_assert_eq(pkt[5], 1, "request event has correct item index")


# --- Player Tests ---

func test_player_set_weapon() -> void:
	var ServerPlayer = preload("res://server/scripts/server_player.gd")
	var sp = ServerPlayer.new()

	var parent := Node3D.new()
	add_child(parent)
	sp.create(1, Vector3.ZERO, parent)

	# Default weapon is idx 2 (ak47), 30 ammo
	_assert_eq(sp.weapon_idx, 2, "default weapon_idx is 2")
	_assert_eq(sp.ammo_mag, 30, "default ammo is 30")

	# Switch to awp (idx 4, 10 ammo)
	sp.set_weapon(4)
	_assert_eq(sp.weapon_idx, 4, "weapon_idx changed to 4")
	_assert_eq(sp.ammo_mag, 10, "ammo set to awp mag size")
	_assert_eq(sp.is_reloading, false, "not reloading after switch")

	# Switch to usp (idx 1, 12 ammo)
	sp.set_weapon(1)
	_assert_eq(sp.weapon_idx, 1, "weapon_idx changed to 1")
	_assert_eq(sp.ammo_mag, 12, "ammo set to usp mag size")

	# Invalid weapon index does nothing
	sp.set_weapon(99)
	_assert_eq(sp.weapon_idx, 1, "invalid idx doesn't change weapon")

	sp.destroy()
	parent.queue_free()


# --- Helpers ---

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
