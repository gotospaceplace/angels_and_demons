class_name PluginCompetitive
extends GamePlugin

var server_match: ServerMatch
var spawns: CompetitiveSpawns
var objective: CompetitiveObjective
var _next_team: int = Team.Id.ANGELS
const BUY_ZONE_RADIUS := 15.0


func get_plugin_name() -> StringName: return &"competitive"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "MR12 competitive round-based mode"
func get_client_mode() -> StringName: return &"competitive"


func on_load(_manager) -> void:
	super.on_load(_manager)
	server_match = ServerMatch.new()
	spawns = CompetitiveSpawns.new()
	objective = CompetitiveObjective.new()
	server_match.round_started.connect(_on_round_started)
	server_match.round_ended.connect(_on_round_ended)
	server_match.halftime_started.connect(_on_halftime)
	objective.catalyst_activated.connect(_on_catalyst_activated)
	objective.portal_opened.connect(_on_portal_opened)
	objective.portal_sealed.connect(_on_portal_sealed)


func register_settings(config) -> void:
	server_match.register_settings(config)
	objective.register_settings(config)


func on_map_load(_map_name: String) -> void:
	if manager != null:
		server_match.apply_settings(manager.match_config)
		objective.apply_settings(manager.match_config)


func load_map_spawns(angels_spawns: Array[Vector3], demons_spawns: Array[Vector3]) -> void:
	spawns.load_spawns(angels_spawns, demons_spawns)


func load_map_portal_sites(sites: Dictionary) -> void:
	objective.load_portal_sites(sites)


func on_tick(_tick: int, delta: float) -> void:
	objective.tick(delta)
	var player_count := 0
	for peer_id in server_match.get_team_players():
		if Team.is_playing_team(server_match.get_team(peer_id)):
			player_count += 1
	server_match.tick(delta, player_count)


func on_player_connect(peer_id: int) -> bool:
	var team := _pick_team()
	server_match.set_team(peer_id, team)
	print("[Competitive] Player %d assigned to %s" % [peer_id, Team.get_name(team)])
	return true


func on_player_disconnect(peer_id: int) -> void:
	server_match.remove_player(peer_id)


func on_player_damage(attacker_id: int, victim_id: int, damage: float,
		_weapon_idx: int, _hitgroup: String) -> float:
	objective.on_player_damaged(victim_id)
	return damage


func on_player_kill(killer_id: int, victim_id: int, weapon_idx: int, _headshot: bool) -> void:
	server_match.report_kill(killer_id, victim_id, weapon_idx)
	if objective.carrier_id == victim_id and objective.carrier_id != -1:
		objective.on_carrier_killed(manager.last_death_position)
	if objective.sealer_id == victim_id and objective.sealer_id != -1:
		objective.on_sealer_killed()


func can_player_respawn(_peer_id: int) -> bool:
	return server_match.state == ServerMatch.State.WARMUP


func can_player_move(_peer_id: int) -> bool:
	return server_match.state != ServerMatch.State.FREEZE


func get_player_team(peer_id: int) -> int:
	return server_match.get_team(peer_id)


func get_spawn_position(peer_id: int) -> Vector3:
	var team := server_match.get_team(peer_id)
	if not Team.is_playing_team(team):
		return Vector3.ZERO
	return spawns.get_spawn_for_team(team)


func get_player_money(peer_id: int) -> int:
	return server_match.economy.get_money(peer_id)


func get_attack_team() -> int:
	return server_match.attack_team


func deduct_money(peer_id: int, amount: int) -> bool:
	return server_match.economy.purchase(peer_id, amount)


func can_purchase(peer_id: int, _item: StringName, _price: int, position: Vector3) -> bool:
	if not server_match.is_buy_period():
		return false
	var team := server_match.get_team(peer_id)
	var center := spawns.get_spawn_center(team)
	var flat_dist := Vector2(position.x - center.x, position.z - center.z).length()
	return flat_dist <= BUY_ZONE_RADIUS


func on_player_use(peer_id: int, position: Vector3, delta: float) -> void:
	if server_match.state != ServerMatch.State.LIVE:
		return
	var team := server_match.get_team(peer_id)
	objective.process_use(peer_id, position, team,
		server_match.attack_team, delta, false)


func on_player_use_release(peer_id: int) -> void:
	objective.process_use_release(peer_id)


func get_client_state() -> Dictionary:
	return {
		"state": server_match.get_state_name(),
		"round": server_match.round_number,
		"score_angels": server_match.score.get(Team.Id.ANGELS, 0),
		"score_demons": server_match.score.get(Team.Id.DEMONS, 0),
		"timer": server_match.get_remaining_time(),
		"attack_team": server_match.attack_team,
		"portal_state": objective.get_state_name(),
		"portal_timer": objective.portal_timer,
		"catalyst_carrier": objective.carrier_id,
		"catalyst_position": objective.catalyst_position,
	}


func on_console_command(cmd: String, _args: String) -> bool:
	if cmd == "match":
		print("[Competitive] State: %s  Round: %d  Score: Angels %d - Demons %d" % [
			server_match.get_state_name(), server_match.round_number,
			server_match.score.get(Team.Id.ANGELS, 0),
			server_match.score.get(Team.Id.DEMONS, 0)])
		print("[Competitive] Alive: Angels %d - Demons %d  Timer: %.1fs" % [
			server_match.get_alive_count(Team.Id.ANGELS),
			server_match.get_alive_count(Team.Id.DEMONS),
			server_match.get_remaining_time()])
		return true
	return false


func _on_round_started(_round_number: int) -> void:
	spawns.reset_indices()

	var attackers: Array[int] = []
	for peer_id in server_match.get_team_players():
		if server_match.get_team(peer_id) == server_match.attack_team:
			attackers.append(peer_id)

	if attackers.size() > 0 and objective.has_portal_sites():
		var carrier := attackers[randi() % attackers.size()]
		objective.start_round(carrier)
		print("[Competitive] Catalyst assigned to player %d" % carrier)

	if manager != null:
		manager.plugin_event.emit(&"round_reset", {})


func _on_round_ended(_winner_team: int, _reason: StringName) -> void:
	objective.end_round()


func _on_halftime() -> void:
	spawns.swap_sides()


func _on_catalyst_activated(_site: StringName, _position: Vector3) -> void:
	server_match.round_timer_paused = true
	server_match.catalyst_activated = true
	server_match.economy.award_catalyst_activate(
		server_match.get_team_players(), server_match.attack_team)
	print("[Competitive] Catalyst activated at site %s — round timer paused" % _site)


func _on_portal_opened(_position: Vector3) -> void:
	server_match.end_round_external(server_match.attack_team, &"objective")
	print("[Competitive] Portal opened — attackers win")


func _on_portal_sealed(_peer_id: int) -> void:
	server_match.end_round_external(server_match.defense_team, &"objective")
	print("[Competitive] Portal sealed — defenders win")


func _pick_team() -> int:
	var team := _next_team
	if _next_team == Team.Id.ANGELS:
		_next_team = Team.Id.DEMONS
	else:
		_next_team = Team.Id.ANGELS
	return team
