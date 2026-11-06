class_name PluginTeamDeathmatch
extends GamePlugin

var _player_teams: Dictionary = {}
var _player_stats: Dictionary = {}
var _round_damage: Dictionary = {}
var _score: Dictionary = {Team.Id.ANGELS: 0, Team.Id.DEMONS: 0}
var _next_team: int = Team.Id.ANGELS


func get_plugin_name() -> StringName: return &"team_deathmatch"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "Team deathmatch mode"
func get_client_mode() -> StringName: return &"team_deathmatch"


func register_settings(config) -> void:
	config.register("tdm_scorelimit", 50, "Team kills to win (0 = no limit)", get_plugin_name())
	config.register("tdm_timelimit", 600, "Round time in seconds (0 = no limit)", get_plugin_name())
	config.register("tdm_respawn_delay", 3.0, "Seconds before respawn", get_plugin_name())


func on_player_connect(peer_id: int) -> bool:
	_player_teams[peer_id] = Team.Id.SPECTATOR
	_player_stats[peer_id] = {"kills": 0, "deaths": 0, "assists": 0, "damage": 0}
	if manager:
		manager.plugin_event.emit(&"roster_changed", {})
	return true


func on_player_disconnect(peer_id: int) -> void:
	_player_teams.erase(peer_id)
	_player_stats.erase(peer_id)
	_round_damage.erase(peer_id)
	for vid in _round_damage:
		_round_damage[vid].erase(peer_id)
	if manager:
		manager.plugin_event.emit(&"roster_changed", {})


func can_player_respawn(peer_id: int) -> bool:
	var team: int = _player_teams.get(peer_id, Team.Id.SPECTATOR)
	return Team.is_playing_team(team)


func get_spawn_position(_peer_id: int) -> Vector3:
	return Vector3.ZERO


func on_player_damage(attacker_id: int, victim_id: int, damage: float,
		_weapon_idx: int, _hitgroup: String) -> float:
	if _player_stats.has(attacker_id):
		_player_stats[attacker_id]["damage"] += int(damage)
	if not _round_damage.has(victim_id):
		_round_damage[victim_id] = {}
	_round_damage[victim_id][attacker_id] = _round_damage[victim_id].get(attacker_id, 0) + int(damage)
	return damage


func on_player_kill(killer_id: int, victim_id: int, _weapon_idx: int, _headshot: bool) -> void:
	if _player_stats.has(killer_id):
		_player_stats[killer_id]["kills"] += 1
		var killer_team: int = _player_teams.get(killer_id, 0)
		if killer_team in _score:
			_score[killer_team] += 1
	if _player_stats.has(victim_id):
		_player_stats[victim_id]["deaths"] += 1
	if _round_damage.has(victim_id):
		for aid in _round_damage[victim_id]:
			if aid != killer_id and aid != victim_id and _player_stats.has(aid):
				_player_stats[aid]["assists"] += 1
	_round_damage.erase(victim_id)
	if manager:
		manager.plugin_event.emit(&"roster_changed", {})


func get_client_state() -> Dictionary:
	var roster_data: Array = []
	for pid in _player_stats:
		var stats: Dictionary = _player_stats[pid]
		roster_data.append({
			"id": pid,
			"team": _player_teams.get(pid, 0),
			"kills": stats.get("kills", 0),
			"deaths": stats.get("deaths", 0),
			"assists": stats.get("assists", 0),
			"damage": stats.get("damage", 0),
		})
	return {
		"state": "LIVE",
		"score_angels": _score.get(Team.Id.ANGELS, 0),
		"score_demons": _score.get(Team.Id.DEMONS, 0),
		"team_counts": _get_team_counts(),
		"roster": roster_data,
	}


func get_player_team(peer_id: int) -> int:
	return _player_teams.get(peer_id, Team.Id.SPECTATOR)


func get_team_counts() -> Dictionary:
	return _get_team_counts()


func _get_team_counts() -> Dictionary:
	var a := 0
	var d := 0
	for pid in _player_teams:
		if _player_teams[pid] == Team.Id.ANGELS:
			a += 1
		elif _player_teams[pid] == Team.Id.DEMONS:
			d += 1
	return {Team.Id.ANGELS: a, Team.Id.DEMONS: d}


func _pick_team() -> int:
	var counts := _get_team_counts()
	if counts[Team.Id.ANGELS] <= counts[Team.Id.DEMONS]:
		return Team.Id.ANGELS
	return Team.Id.DEMONS


func change_team(peer_id: int, requested_team: int) -> bool:
	var actual_team := requested_team
	if requested_team == Team.Id.UNASSIGNED:
		actual_team = _pick_team()

	if Team.is_playing_team(actual_team):
		var counts := _get_team_counts()
		var other_team := Team.get_opposing(actual_team)
		var current_team: int = _player_teams.get(peer_id, Team.Id.SPECTATOR)
		var target_count: int = counts.get(actual_team, 0)
		var other_count: int = counts.get(other_team, 0)
		if current_team != actual_team:
			if target_count > other_count:
				return false

	var old_team: int = _player_teams.get(peer_id, Team.Id.SPECTATOR)
	_player_teams[peer_id] = actual_team
	if not _player_stats.has(peer_id):
		_player_stats[peer_id] = {"kills": 0, "deaths": 0, "assists": 0, "damage": 0}

	if old_team != actual_team and manager:
		manager.plugin_event.emit(&"roster_changed", {})

	return true


func on_round_start(_round_number: int) -> void: pass
func on_round_end(_winner_team: int, _reason: StringName) -> void: pass
func on_match_start() -> void: pass
func on_match_end(_winner_team: int) -> void: pass
