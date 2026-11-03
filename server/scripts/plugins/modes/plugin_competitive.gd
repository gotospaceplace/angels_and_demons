class_name PluginCompetitive
extends GamePlugin

var server_match: ServerMatch
var _next_team: int = Team.Id.ANGELS


func get_plugin_name() -> StringName: return &"competitive"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "MR12 competitive round-based mode"
func get_client_mode() -> StringName: return &"competitive"


func on_load(_manager) -> void:
	super.on_load(_manager)
	server_match = ServerMatch.new()


func register_settings(config) -> void:
	server_match.register_settings(config)


func on_map_load(_map_name: String) -> void:
	if manager != null:
		server_match.apply_settings(manager.match_config)


func on_tick(tick: int, delta: float) -> void:
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


func on_player_kill(killer_id: int, victim_id: int, weapon_idx: int, _headshot: bool) -> void:
	server_match.report_kill(killer_id, victim_id, weapon_idx)


func can_player_respawn(_peer_id: int) -> bool:
	return server_match.state == ServerMatch.State.WARMUP


func can_player_move(_peer_id: int) -> bool:
	return server_match.state != ServerMatch.State.FREEZE


func get_player_team(peer_id: int) -> int:
	return server_match.get_team(peer_id)


func get_client_state() -> Dictionary:
	return {
		"state": server_match.get_state_name(),
		"round": server_match.round_number,
		"score_angels": server_match.score.get(Team.Id.ANGELS, 0),
		"score_demons": server_match.score.get(Team.Id.DEMONS, 0),
		"timer": server_match.get_remaining_time(),
		"attack_team": server_match.attack_team,
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


func _pick_team() -> int:
	var team := _next_team
	if _next_team == Team.Id.ANGELS:
		_next_team = Team.Id.DEMONS
	else:
		_next_team = Team.Id.ANGELS
	return team
