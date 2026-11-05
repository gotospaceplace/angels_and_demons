extends Node

const BINDINGS_PATH := "user://keybindings.cfg"

const BINDABLE_ACTIONS := [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "duck", "walk",
	"fire", "fire_secondary", "reload",
	"weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5",
	"weapon_last", "weapon_next", "weapon_prev",
	"interact", "buy_menu",
	"toggle_hud", "toggle_net_hud",
	"screenshot",
]

const ACTION_DISPLAY_NAMES := {
	"move_forward": "Move Forward",
	"move_backward": "Move Backward",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"duck": "Crouch",
	"walk": "Walk",
	"fire": "Fire",
	"fire_secondary": "Secondary Fire",
	"reload": "Reload",
	"weapon_1": "Weapon Slot 1",
	"weapon_2": "Weapon Slot 2",
	"weapon_3": "Weapon Slot 3",
	"weapon_4": "Weapon Slot 4",
	"weapon_5": "Weapon Slot 5",
	"weapon_last": "Last Weapon",
	"weapon_next": "Next Weapon",
	"weapon_prev": "Previous Weapon",
	"interact": "Interact",
	"buy_menu": "Buy Menu",
	"toggle_hud": "Toggle HUD",
	"toggle_net_hud": "Toggle Net HUD",
	"screenshot": "Screenshot",
}

var _defaults := {}


func _ready() -> void:
	_capture_defaults()
	load_bindings()


func _capture_defaults() -> void:
	for action in BINDABLE_ACTIONS:
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate()
		else:
			_defaults[action] = []


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BINDINGS_PATH) != OK:
		return
	for action in BINDABLE_ACTIONS:
		if not cfg.has_section_key("bindings", action):
			continue
		var data: Dictionary = cfg.get_value("bindings", action, {})
		var event := _dict_to_event(data)
		if event:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action in BINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			cfg.set_value("bindings", action, _event_to_dict(events[0]))
		else:
			cfg.set_value("bindings", action, {})
	cfg.save(BINDINGS_PATH)


func reset_to_defaults() -> void:
	for action in BINDABLE_ACTIONS:
		if _defaults.has(action):
			InputMap.action_erase_events(action)
			for event in _defaults[action]:
				InputMap.action_add_event(action, event)
	save_bindings()


func set_action_event(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_bindings()


func get_action_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "---"
	var events := InputMap.action_get_events(action)
	if events.size() == 0:
		return "---"
	return _event_label(events[0])


func get_display_name(action: String) -> String:
	return ACTION_DISPLAY_NAMES.get(action, action)


func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var k: InputEventKey = event
		var keycode := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(keycode)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "Mouse 1"
			MOUSE_BUTTON_RIGHT: return "Mouse 2"
			MOUSE_BUTTON_MIDDLE: return "Mouse 3"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
			_: return "Mouse %d" % mb.button_index
	return event.as_text()


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k: InputEventKey = event
		return {"type": "key", "physical_keycode": k.physical_keycode, "keycode": k.keycode}
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		return {"type": "mouse_button", "button_index": mb.button_index}
	return {}


func _dict_to_event(data: Dictionary) -> InputEvent:
	var type: String = data.get("type", "")
	if type == "key":
		var k := InputEventKey.new()
		k.physical_keycode = data.get("physical_keycode", 0) as Key
		k.keycode = data.get("keycode", 0) as Key
		return k
	if type == "mouse_button":
		var mb := InputEventMouseButton.new()
		mb.button_index = data.get("button_index", 0) as MouseButton
		return mb
	return null
