extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[KeyBindingsTests] Starting key bindings test suite")

	_test_autoload_exists()
	_test_menu_autoload_exists()
	_test_bindable_actions_defined()
	_test_display_names_complete()
	_test_all_actions_in_input_map()
	_test_get_action_label()
	_test_default_capture()
	_test_set_action_event()
	_test_reset_to_defaults()
	_test_event_label_key()
	_test_event_label_mouse()
	_test_save_and_load()
	_test_menu_open_close()
	_test_menu_rows_created()
	_test_menu_initial_visibility()
	_test_unbound_action_label()

	print("[KeyBindingsTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
	if fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	total += 1
	if condition:
		pass_count += 1
		print("  PASS %s" % test_name)
	else:
		fail_count += 1
		var msg := "  FAIL %s" % test_name
		if detail != "":
			msg += " — %s" % detail
		print(msg)


func _test_autoload_exists() -> void:
	_assert(KeyBindings != null, "keybindings_autoload_exists")


func _test_menu_autoload_exists() -> void:
	_assert(KeyBindingsMenu != null, "keybindings_menu_autoload_exists")


func _test_bindable_actions_defined() -> void:
	_assert(KeyBindings.BINDABLE_ACTIONS.size() > 0, "has_bindable_actions",
		"size=%d" % KeyBindings.BINDABLE_ACTIONS.size())
	_assert(KeyBindings.BINDABLE_ACTIONS.size() == 23, "bindable_count_23",
		"got %d" % KeyBindings.BINDABLE_ACTIONS.size())


func _test_display_names_complete() -> void:
	var missing := []
	for action in KeyBindings.BINDABLE_ACTIONS:
		if not KeyBindings.ACTION_DISPLAY_NAMES.has(action):
			missing.append(action)
	_assert(missing.size() == 0, "all_actions_have_display_names",
		"missing: %s" % str(missing))


func _test_all_actions_in_input_map() -> void:
	var missing := []
	for action in KeyBindings.BINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(action)
	_assert(missing.size() == 0, "all_actions_in_input_map",
		"missing: %s" % str(missing))


func _test_get_action_label() -> void:
	var label := KeyBindings.get_action_label("move_forward")
	_assert(label != "---", "move_forward_has_label", "got '%s'" % label)
	_assert(label.length() > 0, "move_forward_label_not_empty")


func _test_default_capture() -> void:
	_assert(KeyBindings._defaults.size() > 0, "defaults_captured",
		"size=%d" % KeyBindings._defaults.size())
	_assert(KeyBindings._defaults.has("move_forward"), "defaults_has_move_forward")
	var events: Array = KeyBindings._defaults.get("move_forward", [])
	_assert(events.size() > 0, "defaults_move_forward_has_events",
		"size=%d" % events.size())


func _test_set_action_event() -> void:
	var original_events := InputMap.action_get_events("interact").duplicate()

	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_F
	KeyBindings.set_action_event("interact", new_key)

	var events := InputMap.action_get_events("interact")
	_assert(events.size() == 1, "set_event_replaces",
		"expected 1 event, got %d" % events.size())
	if events.size() > 0:
		_assert(events[0] is InputEventKey, "set_event_is_key")

	InputMap.action_erase_events("interact")
	for ev in original_events:
		InputMap.action_add_event("interact", ev)


func _test_reset_to_defaults() -> void:
	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_P
	KeyBindings.set_action_event("reload", new_key)

	KeyBindings.reset_to_defaults()

	var events := InputMap.action_get_events("reload")
	_assert(events.size() > 0, "reset_restored_events",
		"size=%d" % events.size())
	if events.size() > 0 and events[0] is InputEventKey:
		var k: InputEventKey = events[0]
		_assert(k.physical_keycode == KEY_R, "reset_restored_R_key",
			"got keycode %d" % k.physical_keycode)


func _test_event_label_key() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	var label := KeyBindings._event_label(ev)
	_assert(label == "W", "event_label_W", "got '%s'" % label)


func _test_event_label_mouse() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	var label := KeyBindings._event_label(ev)
	_assert(label == "Mouse 1", "event_label_mouse1", "got '%s'" % label)

	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_WHEEL_UP
	var label2 := KeyBindings._event_label(ev2)
	_assert(label2 == "Wheel Up", "event_label_wheel_up", "got '%s'" % label2)


func _test_save_and_load() -> void:
	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_G
	KeyBindings.set_action_event("interact", new_key)

	KeyBindings.load_bindings()
	var events := InputMap.action_get_events("interact")
	_assert(events.size() > 0, "save_load_events_exist")
	if events.size() > 0 and events[0] is InputEventKey:
		var k: InputEventKey = events[0]
		_assert(k.physical_keycode == KEY_G, "save_load_preserved_G",
			"got keycode %d" % k.physical_keycode)

	KeyBindings.reset_to_defaults()


func _test_menu_open_close() -> void:
	KeyBindingsMenu.open()
	_assert(KeyBindingsMenu.is_open(), "menu_opens")
	KeyBindingsMenu.close()
	_assert(not KeyBindingsMenu.is_open(), "menu_closes")


func _test_menu_rows_created() -> void:
	_assert(KeyBindingsMenu._rows.size() == KeyBindings.BINDABLE_ACTIONS.size(),
		"menu_rows_match_actions",
		"expected %d, got %d" % [KeyBindings.BINDABLE_ACTIONS.size(), KeyBindingsMenu._rows.size()])


func _test_menu_initial_visibility() -> void:
	_assert(not KeyBindingsMenu._panel.visible, "menu_hidden_by_default")


func _test_unbound_action_label() -> void:
	var label := KeyBindings.get_action_label("weapon_prev")
	_assert(label == "---", "unbound_action_shows_dashes",
		"got '%s'" % label)
