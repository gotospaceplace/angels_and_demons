class_name PlatformAnticheat
extends GamePlugin

var _kill_times: Dictionary = {}
var _headshot_counts: Dictionary = {}
var _kill_counts: Dictionary = {}


func get_plugin_name() -> StringName: return &"platform_anticheat"
func get_description() -> String: return "Combat analysis and aim detection"


func on_player_kill(killer_id: int, _victim_id: int, _weapon_idx: int, headshot: bool) -> void:
	var now := Time.get_ticks_msec()

	if not _kill_times.has(killer_id):
		_kill_times[killer_id] = []
	_kill_times[killer_id].append(now)

	_kill_counts[killer_id] = _kill_counts.get(killer_id, 0) + 1
	if headshot:
		_headshot_counts[killer_id] = _headshot_counts.get(killer_id, 0) + 1

	# TODO: Analyze kill rate vs weapon fire rate
	# TODO: Check aim snap speed between consecutive kills
	# TODO: Report suspicious patterns to central service


func on_player_disconnect(peer_id: int) -> void:
	_kill_times.erase(peer_id)
	_headshot_counts.erase(peer_id)
	_kill_counts.erase(peer_id)
