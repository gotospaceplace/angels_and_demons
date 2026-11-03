class_name PluginDeathmatch
extends GamePlugin


func get_plugin_name() -> StringName: return &"deathmatch"
func get_plugin_version() -> String: return "1.0.0"
func get_description() -> String: return "Free-for-all deathmatch mode"
func get_client_mode() -> StringName: return &"deathmatch"


func register_settings(config) -> void:
	config.register("dm_fraglimit", 30, "Kills to win (0 = no limit)", get_plugin_name())
	config.register("dm_timelimit", 600, "Round time in seconds (0 = no limit)", get_plugin_name())
	config.register("dm_respawn_delay", 3.0, "Seconds before respawn", get_plugin_name())


func can_player_respawn(_peer_id: int) -> bool:
	return true


func get_spawn_position(_peer_id: int) -> Vector3:
	return Vector3.ZERO


func on_player_kill(killer_id: int, _victim_id: int, _weapon_idx: int, _headshot: bool) -> void:
	if manager == null:
		return
	var frag_limit: int = manager.match_config.get_int("dm_fraglimit")
	if frag_limit > 0:
		# TODO: Check killer's kill count against frag_limit and end match
		pass


func on_round_start(_round_number: int) -> void:
	pass


func on_round_end(_winner_team: int, _reason: StringName) -> void:
	pass


func on_match_start() -> void:
	pass


func on_match_end(_winner_team: int) -> void:
	pass
