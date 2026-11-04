class_name PluginChat
extends GamePlugin

var _rate_buckets: Dictionary = {}
var _dead_players: Dictionary = {}


func get_plugin_name() -> StringName: return &"chat"
func get_plugin_version() -> String: return "1.0"
func get_description() -> String: return "Chat system with team filtering, dead talk, and rate limiting"


func register_settings(config) -> void:
	config.register("sv_alltalk", 0, "1 = all players hear all chat, 0 = team chat is team-only", &"chat")
	config.register("sv_deadtalk", 0, "1 = dead players can team-chat to alive, 0 = dead all-chat only", &"chat")
	config.register("sv_chat_rate", 3, "Max chat messages per second per player", &"chat")


func on_player_disconnect(peer_id: int) -> void:
	_rate_buckets.erase(peer_id)
	_dead_players.erase(peer_id)


func on_player_death(peer_id: int, _killer_id: int) -> void:
	_dead_players[peer_id] = true


func on_player_spawn(peer_id: int, _position: Vector3) -> void:
	_dead_players.erase(peer_id)


func on_round_start(_round_number: int) -> void:
	_dead_players.clear()


func on_chat_message(peer_id: int, message: String, _team_only: bool) -> String:
	if not _check_rate(peer_id):
		return ""
	return message


func is_dead(peer_id: int) -> bool:
	return _dead_players.get(peer_id, false)


func should_force_all_chat(peer_id: int) -> bool:
	var deadtalk: int = manager.match_config.get_int("sv_deadtalk")
	return is_dead(peer_id) and deadtalk == 0


func is_alltalk() -> bool:
	return manager.match_config.get_int("sv_alltalk") == 1


func get_eligible_peers(sender_id: int, team_only: bool, all_players: Dictionary) -> Array[int]:
	var recipients: Array[int] = []
	var sender_dead := is_dead(sender_id)
	var alltalk := is_alltalk()
	var deadtalk: int = manager.match_config.get_int("sv_deadtalk")
	var effective_all := not team_only or alltalk or (sender_dead and deadtalk == 0)

	if effective_all:
		for pid in all_players:
			recipients.append(pid)
	else:
		var sender_team: int = manager.dispatch_get_player_team(sender_id)
		for pid in all_players:
			if int(manager.dispatch_get_player_team(pid)) == sender_team:
				recipients.append(pid)
	return recipients


func _check_rate(peer_id: int) -> bool:
	var max_rate: int = manager.match_config.get_int("sv_chat_rate")
	if max_rate <= 0:
		return true
	var now := Time.get_ticks_msec()
	if not _rate_buckets.has(peer_id):
		_rate_buckets[peer_id] = []
	var bucket: Array = _rate_buckets[peer_id]
	var cutoff := now - 1000
	while not bucket.is_empty() and bucket[0] < cutoff:
		bucket.pop_front()
	if bucket.size() >= max_rate:
		return false
	bucket.append(now)
	return true
