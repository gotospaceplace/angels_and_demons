extends CanvasLayer

const ROW_H := 36.0
const PANEL_W := 540.0
const NAME_W := 200.0
const KEY_W := 180.0

const COL_BG := Color(0.08, 0.08, 0.1, 0.96)
const COL_HDR := Color(0.12, 0.12, 0.15, 1.0)
const COL_ROW := Color(0.14, 0.14, 0.18, 0.7)
const COL_ROW_ALT := Color(0.14, 0.14, 0.18, 0.45)
const COL_LISTENING := Color(0.4, 0.3, 0.1, 0.8)
const COL_TEXT := Color.WHITE
const COL_DIM := Color(0.6, 0.6, 0.6)
const COL_KEY := Color(0.85, 0.82, 0.55)

var _panel: Panel
var _scroll: ScrollContainer
var _rows := {}
var _listening_action: String = ""
var _visible := false


func _ready() -> void:
	layer = 14
	_build_ui()
	_panel.visible = false


func open() -> void:
	_visible = true
	_panel.visible = true
	_refresh_all()


func close() -> void:
	_visible = false
	_panel.visible = false
	_listening_action = ""


func is_open() -> bool:
	return _visible


func _unhandled_input(event: InputEvent) -> void:
	if not _visible:
		return

	if _listening_action != "":
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_cancel_listen()
			else:
				KeyBindings.set_action_event(_listening_action, event)
				_cancel_listen()
				_refresh_all()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index != MOUSE_BUTTON_LEFT or _listening_action.begins_with("fire") or _listening_action == "weapon_next" or _listening_action == "weapon_prev":
				KeyBindings.set_action_event(_listening_action, event)
				_cancel_listen()
				_refresh_all()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var title := Label.new()
	title.text = "KEY BINDINGS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(PANEL_W, 28)
	_panel.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(12, 48)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(vbox)

	for i in range(KeyBindings.BINDABLE_ACTIONS.size()):
		var action: String = KeyBindings.BINDABLE_ACTIONS[i]
		var row := _build_row(action, i)
		vbox.add_child(row)
		_rows[action] = row.get_meta("controls")

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.custom_minimum_size = Vector2(PANEL_W - 24, 48)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var reset_btn := Button.new()
	reset_btn.text = "Reset All"
	reset_btn.custom_minimum_size = Vector2(130, 36)
	reset_btn.pressed.connect(_on_reset)
	btn_row.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(130, 36)
	close_btn.pressed.connect(close)
	btn_row.add_child(close_btn)

	vbox.add_child(btn_row)


func _build_row(action: String, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(PANEL_W - 24, ROW_H)
	row.add_theme_constant_override("separation", 0)

	var bg := ColorRect.new()
	bg.color = COL_ROW if index % 2 == 0 else COL_ROW_ALT
	bg.custom_minimum_size = Vector2(PANEL_W - 24, ROW_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(bg)

	var name_lbl := Label.new()
	name_lbl.text = KeyBindings.get_display_name(action)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.custom_minimum_size = Vector2(NAME_W, ROW_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	var key_btn := Button.new()
	key_btn.text = KeyBindings.get_action_label(action)
	key_btn.custom_minimum_size = Vector2(KEY_W, ROW_H - 4)
	key_btn.add_theme_font_size_override("font_size", 13)
	key_btn.pressed.connect(_on_key_pressed.bind(action))
	row.add_child(key_btn)

	row.set_meta("controls", {"bg": bg, "name": name_lbl, "key_btn": key_btn})
	return row


func _refresh_all() -> void:
	for action in _rows:
		var c: Dictionary = _rows[action]
		c["key_btn"].text = KeyBindings.get_action_label(action)
		if action == _listening_action:
			c["bg"].color = COL_LISTENING
			c["key_btn"].text = "Press a key..."
		else:
			var idx := KeyBindings.BINDABLE_ACTIONS.find(action)
			c["bg"].color = COL_ROW if idx % 2 == 0 else COL_ROW_ALT

	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	var total_h := KeyBindings.BINDABLE_ACTIONS.size() * ROW_H + 60
	var panel_h := minf(total_h + 70, vp.y - 80)
	_panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - panel_h) * 0.5)
	_panel.size = Vector2(PANEL_W, panel_h)
	_scroll.size = Vector2(PANEL_W - 24, panel_h - 60)


func _on_key_pressed(action: String) -> void:
	_listening_action = action
	_refresh_all()


func _cancel_listen() -> void:
	_listening_action = ""


func _on_reset() -> void:
	KeyBindings.reset_to_defaults()
	_refresh_all()
