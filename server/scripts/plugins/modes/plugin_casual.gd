class_name PluginCasual
extends GamePlugin

var _player_teams: Dictionary = {}
var _player_stats: Dictionary = {}
var _round_damage: Dictionary = {}
var _score: Dictionary = {Team.Id.ANGELS: 0, Team.Id.DEMONS: 0}
var _round_number: int = 0


func get_plugin_name() -> StringName: return &"casual"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "Casual 10v10 mode"
func get_client_mode() -> StringName: return &"casual"


func register_settings(config) -> void:
	config.register("cas_rounds_to_win", 8, "Rounds to win", get_plugin_name())
	config.register("cas_timelimit", 120, "Round time in seconds", get_plugin_name())
	config.register("cas_respawn_delay", 3.0, "Seconds before respawn", get_plugin_name())


func on_player_connect(peer_id: int) -> bool:
	var team := _pick_team()
	_player_teams[peer_id] = team
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


func can_player_respawn(_peer_id: int) -> bool:
	return true


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
		"round": _round_number,
		"score_angels": _score.get(Team.Id.ANGELS, 0),
		"score_demons": _score.get(Team.Id.DEMONS, 0),
		"team_counts": _get_team_counts(),
		"roster": roster_data,
	}


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


func on_round_start(round_number: int) -> void:
	_round_number = round_number

func on_round_end(_winner_team: int, _reason: StringName) -> void: pass
func on_match_start() -> void: pass
func on_match_end(_winner_team: int) -> void: pass
