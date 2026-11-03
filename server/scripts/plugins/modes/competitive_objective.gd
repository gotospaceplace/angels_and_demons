class_name CompetitiveObjective
extends RefCounted

enum State {
	INACTIVE,
	CARRIED,
	DROPPED,
	ACTIVATING,
	ACTIVATED,
	SEALING,
	PORTAL_OPENED,
	PORTAL_SEALED,
}

signal catalyst_activated(site: StringName, position: Vector3)
signal portal_opened(position: Vector3)
signal portal_sealed(peer_id: int)
signal catalyst_dropped(position: Vector3)
signal catalyst_picked_up(peer_id: int)

var state: int = State.INACTIVE
var carrier_id: int = -1
var catalyst_position: Vector3 = Vector3.ZERO
var activate_site: StringName = &""
var activator_id: int = -1
var sealer_id: int = -1

var activation_progress: float = 0.0
var portal_timer: float = 0.0
var seal_progress: float = 0.0

var activate_time: float = 3.5
var portal_time: float = 40.0
var seal_time: float = 10.0
var seal_time_relic: float = 5.0
var site_radius: float = 3.0
var pickup_radius: float = 2.0

var _portal_sites: Dictionary = {}


func register_settings(config: MatchConfig) -> void:
	config.register("mp_activate_time", activate_time,
		"Catalyst activation time in seconds", &"competitive")
	config.register("mp_portal_timer", portal_time,
		"Portal timer after activation in seconds", &"competitive")
	config.register("mp_seal_time", seal_time,
		"Seal time without relic", &"competitive")
	config.register("mp_seal_time_relic", seal_time_relic,
		"Seal time with relic equipped", &"competitive")


func apply_settings(config: MatchConfig) -> void:
	activate_time = config.get_float("mp_activate_time")
	portal_time = config.get_float("mp_portal_timer")
	seal_time = config.get_float("mp_seal_time")
	seal_time_relic = config.get_float("mp_seal_time_relic")


func load_portal_sites(sites: Dictionary) -> void:
	_portal_sites = sites
	print("[Objective] Loaded %d portal sites" % sites.size())


func has_portal_sites() -> bool:
	return _portal_sites.size() > 0


func start_round(catalyst_carrier: int) -> void:
	state = State.CARRIED
	carrier_id = catalyst_carrier
	catalyst_position = Vector3.ZERO
	activate_site = &""
	activator_id = -1
	sealer_id = -1
	activation_progress = 0.0
	portal_timer = 0.0
	seal_progress = 0.0


func end_round() -> void:
	state = State.INACTIVE
	carrier_id = -1
	activator_id = -1
	sealer_id = -1
	activation_progress = 0.0
	seal_progress = 0.0


func tick(delta: float) -> void:
	if state == State.ACTIVATED:
		portal_timer -= delta
		if portal_timer <= 0.0:
			portal_timer = 0.0
			state = State.PORTAL_OPENED
			portal_opened.emit(catalyst_position)


func on_carrier_killed(death_position: Vector3) -> void:
	if state == State.CARRIED or state == State.ACTIVATING:
		if state == State.ACTIVATING:
			activator_id = -1
			activation_progress = 0.0
			activate_site = &""
		state = State.DROPPED
		catalyst_position = death_position
		carrier_id = -1
		catalyst_dropped.emit(death_position)


func on_sealer_killed() -> void:
	if state == State.SEALING:
		sealer_id = -1
		seal_progress = 0.0
		state = State.ACTIVATED


func on_player_damaged(peer_id: int) -> void:
	if state == State.ACTIVATING and peer_id == activator_id:
		_interrupt_activation()
	elif state == State.SEALING and peer_id == sealer_id:
		_interrupt_seal()


func process_use(peer_id: int, position: Vector3, team: int,
		attack_team: int, delta: float, has_relic: bool) -> void:
	var defense_team := Team.get_opposing(attack_team)

	match state:
		State.CARRIED:
			if peer_id == carrier_id and team == attack_team:
				_try_start_activation(peer_id, position)
		State.ACTIVATING:
			if peer_id == activator_id:
				_continue_activation(position, delta)
		State.DROPPED:
			if team == attack_team:
				_try_pickup(peer_id, position)
		State.ACTIVATED:
			if team == defense_team:
				_try_start_seal(peer_id, position)
		State.SEALING:
			if peer_id == sealer_id:
				_continue_seal(position, delta, has_relic)


func process_use_release(peer_id: int) -> void:
	if state == State.ACTIVATING and peer_id == activator_id:
		_interrupt_activation()
	elif state == State.SEALING and peer_id == sealer_id:
		_interrupt_seal()


func get_state_name() -> String:
	match state:
		State.INACTIVE: return "INACTIVE"
		State.CARRIED: return "CARRIED"
		State.DROPPED: return "DROPPED"
		State.ACTIVATING: return "ACTIVATING"
		State.ACTIVATED: return "ACTIVATED"
		State.SEALING: return "SEALING"
		State.PORTAL_OPENED: return "PORTAL_OPENED"
		State.PORTAL_SEALED: return "PORTAL_SEALED"
		_: return "UNKNOWN"


func _try_start_activation(peer_id: int, position: Vector3) -> void:
	var site := _get_nearest_site(position)
	if site == &"":
		return
	state = State.ACTIVATING
	activate_site = site
	activator_id = peer_id
	activation_progress = 0.0


func _continue_activation(position: Vector3, delta: float) -> void:
	var site_pos: Vector3 = _portal_sites.get(activate_site, Vector3.ZERO)
	if _h_distance(position, site_pos) > site_radius:
		_interrupt_activation()
		return

	activation_progress += delta
	if activation_progress >= activate_time:
		state = State.ACTIVATED
		catalyst_position = site_pos
		carrier_id = -1
		activator_id = -1
		portal_timer = portal_time
		catalyst_activated.emit(activate_site, site_pos)


func _interrupt_activation() -> void:
	state = State.CARRIED
	activator_id = -1
	activation_progress = 0.0
	activate_site = &""


func _try_pickup(peer_id: int, position: Vector3) -> void:
	if _h_distance(position, catalyst_position) <= pickup_radius:
		state = State.CARRIED
		carrier_id = peer_id
		catalyst_position = Vector3.ZERO
		catalyst_picked_up.emit(peer_id)


func _try_start_seal(peer_id: int, position: Vector3) -> void:
	if _h_distance(position, catalyst_position) <= site_radius:
		state = State.SEALING
		sealer_id = peer_id
		seal_progress = 0.0


func _continue_seal(position: Vector3, delta: float, has_relic: bool) -> void:
	if _h_distance(position, catalyst_position) > site_radius:
		_interrupt_seal()
		return

	var required_time := seal_time_relic if has_relic else seal_time
	seal_progress += delta
	if seal_progress >= required_time:
		state = State.PORTAL_SEALED
		portal_sealed.emit(sealer_id)


func _interrupt_seal() -> void:
	state = State.ACTIVATED
	sealer_id = -1
	seal_progress = 0.0


func _get_nearest_site(position: Vector3) -> StringName:
	for site_name in _portal_sites:
		var site_pos: Vector3 = _portal_sites[site_name]
		if _h_distance(position, site_pos) <= site_radius:
			return site_name
	return &""


func _h_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
