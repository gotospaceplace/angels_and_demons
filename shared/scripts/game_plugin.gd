class_name GamePlugin
extends RefCounted

var manager = null

# --- Identity ---
func get_plugin_name() -> StringName: return &""
func get_plugin_version() -> String: return "1.0"
func get_description() -> String: return ""

# --- Lifecycle ---
func on_load(_manager) -> void:
	manager = _manager
func on_unload() -> void: pass
func on_map_load(_map_name: String) -> void: pass
func on_tick(_tick: int, _delta: float) -> void: pass

# --- Settings registration (called once at load) ---
func register_settings(_config) -> void: pass

# --- Player lifecycle ---
func on_player_connect(_peer_id: int) -> bool: return true
func on_player_disconnect(_peer_id: int) -> void: pass
func on_player_pre_spawn(_peer_id: int) -> bool: return true
func on_player_spawn(_peer_id: int, _position: Vector3) -> void: pass
func can_player_respawn(_peer_id: int) -> bool: return true
func get_spawn_position(_peer_id: int) -> Vector3: return Vector3.ZERO

# --- Combat ---
func on_player_damage(_attacker_id: int, _victim_id: int, _damage: float,
		_weapon_idx: int, _hitgroup: String) -> float: return _damage
func on_player_kill(_killer_id: int, _victim_id: int, _weapon_idx: int, _headshot: bool) -> void: pass
func on_player_death(_peer_id: int, _killer_id: int) -> void: pass
func can_player_fire(_peer_id: int) -> bool: return true

# --- Movement ---
func can_player_move(_peer_id: int) -> bool: return true
func on_player_movement(_peer_id: int, _position: Vector3, _velocity: Vector3) -> void: pass

# --- Use key interaction ---
func on_player_use(_peer_id: int, _position: Vector3, _delta: float) -> void: pass
func on_player_use_release(_peer_id: int) -> void: pass

# --- Economy (raised by economy-aware plugins) ---
func on_money_change(_peer_id: int, _old_amount: int, _new_amount: int) -> void: pass
func can_purchase(_peer_id: int, _item: StringName, _price: int, _position: Vector3) -> bool: return true
func on_purchase(_peer_id: int, _item: StringName, _price: int) -> void: pass
func get_player_money(_peer_id: int) -> int: return -1
func get_attack_team() -> int: return -1
func deduct_money(_peer_id: int, _amount: int) -> bool: return false

# --- Portal objective (raised by objective-aware plugins) ---
func on_catalyst_activate_start(_peer_id: int, _site: StringName) -> bool: return true
func on_catalyst_activated(_peer_id: int, _site: StringName, _position: Vector3) -> void: pass
func on_portal_seal_start(_peer_id: int) -> bool: return true
func on_portal_sealed(_peer_id: int) -> void: pass
func on_portal_opened(_position: Vector3) -> void: pass
func on_catalyst_dropped(_position: Vector3) -> void: pass
func on_catalyst_picked_up(_peer_id: int) -> void: pass

# --- Round lifecycle (raised by round-based plugins) ---
func on_round_start(_round_number: int) -> void: pass
func on_round_end(_winner_team: int, _reason: StringName) -> void: pass
func on_freeze_start() -> void: pass
func on_freeze_end() -> void: pass
func on_match_start() -> void: pass
func on_match_end(_winner_team: int) -> void: pass
func on_halftime() -> void: pass

# --- Teams ---
func on_team_assign(_peer_id: int, _team: int) -> bool: return true
func get_player_team(_peer_id: int) -> int: return 0

# --- Chat / admin ---
func on_chat_message(_peer_id: int, _message: String, _team_only: bool) -> String: return _message
func on_console_command(_cmd: String, _args: String) -> bool: return false

# --- Client notification ---
func get_client_mode() -> StringName: return &""
func get_client_state() -> Dictionary: return {}
