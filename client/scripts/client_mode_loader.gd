class_name ClientModeLoader
extends RefCounted

var current_mode: StringName = &""
var mode_state: Dictionary = {}


func apply_match_state(mode: StringName, state: Dictionary) -> void:
	if mode != current_mode:
		_unload_mode()
		current_mode = mode
		_load_mode(mode)
	mode_state = state


func _load_mode(mode: StringName) -> void:
	match mode:
		&"deathmatch":
			print("[Client] Mode: deathmatch")
		&"competitive":
			print("[Client] Mode: competitive")
		_:
			push_warning("Unknown mode '%s'" % mode)


func _unload_mode() -> void:
	if current_mode == &"":
		return
	print("[Client] Unloading mode: %s" % current_mode)
	current_mode = &""
	mode_state = {}
