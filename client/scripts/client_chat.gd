class_name ClientChat
extends CanvasLayer

const MAX_VISIBLE_MESSAGES := 8
const MESSAGE_FADE_TIME := 10.0
const MAX_MESSAGE_LENGTH := 256

var _chat_container: VBoxContainer
var _input_field: LineEdit
var _input_bg: PanelContainer
var _prefix_label: Label
var _margin: MarginContainer
var _last_vp_size := Vector2.ZERO
var _is_open: bool = false
var _team_mode: bool = false
var _messages: Array[Dictionary] = []
var _message_labels: Array[Label] = []
var _fade_timers: Array[float] = []


func _ready() -> void:
	layer = 15
	_build_ui()
	_input_bg.visible = false
	_input_field.visible = false
	_prefix_label.visible = false


func _build_ui() -> void:
	_margin = MarginContainer.new()
	_margin.name = "ChatMargin"
	_margin.anchors_preset = Control.PRESET_FULL_RECT
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_bottom", 216)
	_margin.add_theme_constant_override("margin_right", 984)
	_margin.add_theme_constant_override("margin_top", 324)
	add_child(_margin)

	var vbox := VBoxContainer.new()
	vbox.name = "ChatRoot"
	vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	_margin.add_child(vbox)

	_chat_container = VBoxContainer.new()
	_chat_container.name = "Messages"
	_chat_container.size_flags_vertical = Control.SIZE_SHRINK_END
	vbox.add_child(_chat_container)

	for i in range(MAX_VISIBLE_MESSAGES):
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.visible = false
		_chat_container.add_child(lbl)
		_message_labels.append(lbl)
		_fade_timers.append(0.0)

	var input_row := HBoxContainer.new()
	input_row.name = "InputRow"
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(input_row)

	_prefix_label = Label.new()
	_prefix_label.add_theme_font_size_override("font_size", 16)
	_prefix_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	_prefix_label.text = "[ALL] "
	input_row.add_child(_prefix_label)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(4)

	_input_bg = PanelContainer.new()
	_input_bg.name = "InputBg"
	_input_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_bg.add_theme_stylebox_override("panel", style)
	input_row.add_child(_input_bg)

	_input_field = LineEdit.new()
	_input_field.name = "ChatInput"
	_input_field.max_length = MAX_MESSAGE_LENGTH
	_input_field.placeholder_text = "Type a message..."
	_input_field.add_theme_font_size_override("font_size", 16)
	_input_field.add_theme_color_override("font_color", Color.WHITE)
	var empty_style := StyleBoxEmpty.new()
	_input_field.add_theme_stylebox_override("normal", empty_style)
	_input_field.add_theme_stylebox_override("focus", empty_style)
	_input_bg.add_child(_input_field)
	_input_field.text_submitted.connect(_on_text_submitted)


func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp != _last_vp_size and vp.y > 0:
		_last_vp_size = vp
		_margin.add_theme_constant_override("margin_top", int(vp.y * 0.45))
		_margin.add_theme_constant_override("margin_bottom", int(vp.y * 0.30))
		_margin.add_theme_constant_override("margin_right", int(vp.x - 296))

	for i in range(_fade_timers.size()):
		if _fade_timers[i] > 0.0 and not _is_open:
			_fade_timers[i] -= delta
			if _fade_timers[i] <= 0.0:
				_message_labels[i].visible = false
			elif _fade_timers[i] < 2.0:
				var alpha := _fade_timers[i] / 2.0
				_message_labels[i].modulate.a = alpha
			else:
				_message_labels[i].modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_open:
			if event.keycode == KEY_ESCAPE:
				_close_chat()
				get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_open_chat(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			_open_chat(true)
			get_viewport().set_input_as_handled()


func _open_chat(team: bool) -> void:
	_is_open = true
	_team_mode = team
	_prefix_label.text = "[TEAM] " if team else "[ALL] "
	_prefix_label.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.4) if team else Color(1.0, 1.0, 0.4))
	_input_bg.visible = true
	_input_field.visible = true
	_prefix_label.visible = true
	_input_field.text = ""
	_input_field.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_all_messages()


func _close_chat() -> void:
	_is_open = false
	_input_bg.visible = false
	_input_field.visible = false
	_prefix_label.visible = false
	_input_field.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_message_visibility()


func _on_text_submitted(text: String) -> void:
	var msg := text.strip_edges()
	if not msg.is_empty():
		_send_chat(msg, _team_mode)
	_close_chat()


func _send_chat(message: String, team_only: bool) -> void:
	var packet := NetProtocol.pack_admin_chat(message, team_only)
	var mp := get_tree().get_multiplayer()
	if mp and mp.has_multiplayer_peer():
		mp.send_bytes(packet, 1,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_ADMIN)


func on_chat_received(sender_id: int, message: String, team_only: bool) -> void:
	var prefix := "(TEAM) " if team_only else ""
	var display := "%sPlayer %d: %s" % [prefix, sender_id, message]
	_add_message(display, Color.WHITE if not team_only else Color(0.4, 1.0, 0.4))


func on_server_message(message: String) -> void:
	_add_message("[SERVER] %s" % message, Color(1.0, 0.85, 0.3))


func _add_message(text: String, color: Color) -> void:
	_messages.append({"text": text, "color": color})
	if _messages.size() > MAX_VISIBLE_MESSAGES:
		_messages.pop_front()

	for i in range(MAX_VISIBLE_MESSAGES):
		var idx := _messages.size() - MAX_VISIBLE_MESSAGES + i
		if idx >= 0 and idx < _messages.size():
			_message_labels[i].text = _messages[idx]["text"]
			_message_labels[i].add_theme_color_override("font_color", _messages[idx]["color"])
			_message_labels[i].visible = true
			_message_labels[i].modulate.a = 1.0
			_fade_timers[i] = MESSAGE_FADE_TIME
		else:
			_message_labels[i].visible = false
			_fade_timers[i] = 0.0


func _show_all_messages() -> void:
	for i in range(MAX_VISIBLE_MESSAGES):
		if _message_labels[i].text != "":
			_message_labels[i].visible = true
			_message_labels[i].modulate.a = 1.0


func _refresh_message_visibility() -> void:
	for i in range(MAX_VISIBLE_MESSAGES):
		if _fade_timers[i] <= 0.0:
			_message_labels[i].visible = false


func is_chat_open() -> bool:
	return _is_open
