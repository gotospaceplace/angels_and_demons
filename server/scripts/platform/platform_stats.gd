class_name PlatformStats
extends GamePlugin


func get_plugin_name() -> StringName: return &"platform_stats"
func get_description() -> String: return "Global stats collection and ranking feed"


func on_player_kill(killer_id: int, victim_id: int, weapon_idx: int, headshot: bool) -> void:
	# TODO: Record kill to stats service
	pass


func on_player_death(peer_id: int, _killer_id: int) -> void:
	# TODO: Record death to stats service
	pass


func on_match_end(_winner_team: int) -> void:
	# TODO: Submit match results to ranking service
	pass
