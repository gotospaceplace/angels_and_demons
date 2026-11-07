class_name PluginDeathmatch
extends GamePlugin

var _player_stats: Dictionary = {}
var _round_damage: Dictionary = {}


func get_plugin_name() -> StringName: return &"deathmatch"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "Free-for-all deathmatch mode"
func get_client_mode() -> StringName: return &"deathmatch"


func register_settings(config) -> void:
	config.register("dm_fraglimit", 30, "Kills to win (0 = no limit)", get_plugin_name())
	config.register("dm_timelimit", 600, "Round time in seconds (0 = no limit)", get_plugin_name())
	config.register("dm_respawn_delay", 3.0, "Seconds before respawn", get_plugin_name())


func on_player_connect(peer_id: int) -> bool:
	_player_stats[peer_id] = {"kills": 0, "deaths": 0, "assists": 0, "damage": 0}
	return true


func on_player_disconnect(peer_id: int) -> void:
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
	var frag_limit: int = manager.match_config.get_int("dm_fraglimit") if manager else 0
	if frag_limit > 0 and _player_stats.has(killer_id):
		if _player_stats[killer_id]["kills"] >= frag_limit:
			if manager:
				manager.plugin_event.emit(&"match_state_changed", {})


func get_client_state() -> Dictionary:
	var roster_data: Array = []
	for pid in _player_stats:
		var stats: Dictionary = _player_stats[pid]
		roster_data.append({
			"id": pid,
			"kills": stats.get("kills", 0),
			"deaths": stats.get("deaths", 0),
			"assists": stats.get("assists", 0),
			"damage": stats.get("damage", 0),
		})
	return {
		"state": "LIVE",
		"roster": roster_data,
	}


func reset_match() -> void:
	_round_damage.clear()
	for pid in _player_stats:
		_player_stats[pid] = {"kills": 0, "deaths": 0, "assists": 0, "damage": 0}
	if manager:
		manager.plugin_event.emit(&"roster_changed", {})
	print("[Deathmatch] Match reset — all stats cleared")


func on_round_start(_round_number: int) -> void:
	pass


func on_round_end(_winner_team: int, _reason: StringName) -> void:
	pass


func on_match_start() -> void:
	pass


func on_match_end(_winner_team: int) -> void:
	pass
