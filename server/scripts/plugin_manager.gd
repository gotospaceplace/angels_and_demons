class_name PluginManager
extends RefCounted

signal plugin_event(event_name: StringName, data: Dictionary)

var plugins: Array[GamePlugin] = []
var match_config: MatchConfig
var _mode_plugin: GamePlugin
var last_death_position: Vector3 = Vector3.ZERO


func _init() -> void:
	match_config = MatchConfig.new()


func load_plugin(plugin: GamePlugin) -> void:
	plugin.on_load(self)
	plugin.register_settings(match_config)
	plugins.append(plugin)
	if plugin.get_client_mode() != &"":
		_mode_plugin = plugin
	print("[PluginManager] Loaded: %s v%s" % [plugin.get_plugin_name(), plugin.get_plugin_version()])


func unload_plugin(plugin: GamePlugin) -> void:
	plugin.on_unload()
	plugins.erase(plugin)
	if _mode_plugin == plugin:
		_mode_plugin = null
	print("[PluginManager] Unloaded: %s" % plugin.get_plugin_name())


func get_plugin(plugin_name: StringName) -> GamePlugin:
	for p in plugins:
		if p.get_plugin_name() == plugin_name:
			return p
	return null


func get_mode_plugin() -> GamePlugin:
	return _mode_plugin


func get_client_mode() -> StringName:
	if _mode_plugin:
		return _mode_plugin.get_client_mode()
	return &""


func get_client_state() -> Dictionary:
	if _mode_plugin:
		return _mode_plugin.get_client_state()
	return {}


func set_map_spawns(angels_spawns: Array[Vector3], demons_spawns: Array[Vector3]) -> void:
	for p in plugins:
		if p.has_method("load_map_spawns"):
			p.load_map_spawns(angels_spawns, demons_spawns)


func set_map_portal_sites(sites: Dictionary) -> void:
	for p in plugins:
		if p.has_method("load_map_portal_sites"):
			p.load_map_portal_sites(sites)


# --- Hook dispatch ---
# Void hooks: all plugins called in load order
# Bool hooks: all called, ANY false blocks the action
# Modifier hooks: output chains through plugins
# Provider hooks: first non-default return wins


func dispatch_on_tick(tick: int, delta: float) -> void:
	for p in plugins:
		p.on_tick(tick, delta)


func dispatch_on_player_connect(peer_id: int) -> bool:
	for p in plugins:
		if not p.on_player_connect(peer_id):
			return false
	return true


func dispatch_on_player_disconnect(peer_id: int) -> void:
	for p in plugins:
		p.on_player_disconnect(peer_id)


func dispatch_on_player_pre_spawn(peer_id: int) -> bool:
	for p in plugins:
		if not p.on_player_pre_spawn(peer_id):
			return false
	return true


func dispatch_on_player_spawn(peer_id: int, position: Vector3) -> void:
	for p in plugins:
		p.on_player_spawn(peer_id, position)


func dispatch_can_player_respawn(peer_id: int) -> bool:
	for p in plugins:
		if not p.can_player_respawn(peer_id):
			return false
	return true


func dispatch_get_spawn_position(peer_id: int) -> Vector3:
	for p in plugins:
		var pos := p.get_spawn_position(peer_id)
		if pos != Vector3.ZERO:
			return pos
	return Vector3.ZERO


func dispatch_on_player_damage(attacker_id: int, victim_id: int, damage: float,
		weapon_idx: int, hitgroup: String) -> float:
	var d := damage
	for p in plugins:
		d = p.on_player_damage(attacker_id, victim_id, d, weapon_idx, hitgroup)
	return d


func dispatch_on_player_kill(killer_id: int, victim_id: int, weapon_idx: int, headshot: bool) -> void:
	for p in plugins:
		p.on_player_kill(killer_id, victim_id, weapon_idx, headshot)


func dispatch_on_player_death(peer_id: int, killer_id: int) -> void:
	for p in plugins:
		p.on_player_death(peer_id, killer_id)


func dispatch_can_player_fire(peer_id: int) -> bool:
	for p in plugins:
		if not p.can_player_fire(peer_id):
			return false
	return true


func dispatch_can_player_move(peer_id: int) -> bool:
	for p in plugins:
		if not p.can_player_move(peer_id):
			return false
	return true


func dispatch_on_console_command(cmd: String, args: String) -> bool:
	for p in plugins:
		if p.on_console_command(cmd, args):
			return true
	return false


func dispatch_on_chat_message(peer_id: int, message: String, team_only: bool) -> String:
	var msg := message
	for p in plugins:
		msg = p.on_chat_message(peer_id, msg, team_only)
		if msg.is_empty():
			return ""
	return msg


func dispatch_on_team_assign(peer_id: int, team: int) -> bool:
	for p in plugins:
		if not p.on_team_assign(peer_id, team):
			return false
	return true


func dispatch_get_player_team(peer_id: int) -> int:
	for p in plugins:
		var team := p.get_player_team(peer_id)
		if team != 0:
			return team
	return 0


# --- Round lifecycle dispatch ---

func dispatch_on_round_start(round_number: int) -> void:
	for p in plugins:
		p.on_round_start(round_number)


func dispatch_on_round_end(winner_team: int, reason: StringName) -> void:
	for p in plugins:
		p.on_round_end(winner_team, reason)


func dispatch_on_match_start() -> void:
	for p in plugins:
		p.on_match_start()


func dispatch_on_match_end(winner_team: int) -> void:
	for p in plugins:
		p.on_match_end(winner_team)


# --- Portal objective dispatch ---

func dispatch_on_player_use(peer_id: int, position: Vector3, delta: float) -> void:
	for p in plugins:
		p.on_player_use(peer_id, position, delta)


func dispatch_on_player_use_release(peer_id: int) -> void:
	for p in plugins:
		p.on_player_use_release(peer_id)


func dispatch_on_catalyst_activate_start(peer_id: int, site: StringName) -> bool:
	for p in plugins:
		if not p.on_catalyst_activate_start(peer_id, site):
			return false
	return true


func dispatch_on_catalyst_activated(peer_id: int, site: StringName, position: Vector3) -> void:
	for p in plugins:
		p.on_catalyst_activated(peer_id, site, position)


func dispatch_on_portal_opened(position: Vector3) -> void:
	for p in plugins:
		p.on_portal_opened(position)


func dispatch_on_portal_sealed(peer_id: int) -> void:
	for p in plugins:
		p.on_portal_sealed(peer_id)
