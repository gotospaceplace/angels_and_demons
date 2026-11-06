class_name ClientEscMenu
extends CanvasLayer

var _is_open: bool = false
var _showing_options: bool = false

var _overlay: ColorRect
var _menu_panel: PanelContainer
var _options_panel: PanelContainer
var _menu_vbox: VBoxContainer

var _resolution_option: OptionButton
var _window_mode_option: OptionButton
var _vsync_check: CheckButton
var _sensitivity_slider: HSlider
var _sensitivity_value: Label


func _ready() -> void:
	layer = 16
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _showing_options:
				_close_options()
			elif _is_open:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()


func open_menu() -> void:
	if _is_open:
		return
	_is_open = true
	_showing_options = false
	_menu_panel.visible = true
	_options_panel.visible = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_showing_options = false
	_menu_panel.visible = false
	_options_panel.visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _is_open


func _open_options() -> void:
	_showing_options = true
	_menu_panel.visible = false
	_options_panel.visible = true
	_load_options_state()


func _close_options() -> void:
	_showing_options = false
	_options_panel.visible = false
	_menu_panel.visible = true


func _on_resume() -> void:
	close_menu()


func _on_options() -> void:
	_open_options()


func _on_quit() -> void:
	close_menu()
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://client/scenes/main_menu.tscn")


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)

	_build_menu_panel(root)
	_build_options_panel(root)


func _build_menu_panel(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(32)

	_menu_panel = PanelContainer.new()
	_menu_panel.add_theme_stylebox_override("panel", style)
	_menu_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(_menu_panel)

	_menu_vbox = VBoxContainer.new()
	_menu_vbox.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(_menu_vbox)

	var title := Label.new()
	title.text = "MENU"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_vbox.add_child(title)

	var sep := HSeparator.new()
	_menu_vbox.add_child(sep)

	var resume_btn := _make_button("Resume", Color(0.2, 0.5, 0.3))
	resume_btn.pressed.connect(_on_resume)
	_menu_vbox.add_child(resume_btn)

	var options_btn := _make_button("Options", Color(0.2, 0.3, 0.5))
	options_btn.pressed.connect(_on_options)
	_menu_vbox.add_child(options_btn)

	var quit_btn := _make_button("Quit Game", Color(0.5, 0.2, 0.2))
	quit_btn.pressed.connect(_on_quit)
	_menu_vbox.add_child(quit_btn)


func _build_options_panel(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)

	_options_panel = PanelContainer.new()
	_options_panel.add_theme_stylebox_override("panel", style)
	_options_panel.custom_minimum_size = Vector2(420, 0)
	_options_panel.visible = false
	center.add_child(_options_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_options_panel.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(6))

	# Video section
	vbox.add_child(_section_label("VIDEO"))

	_resolution_option = OptionButton.new()
	_resolution_option.custom_minimum_size = Vector2(200, 0)
	for res in GameSettings.RESOLUTIONS:
		_resolution_option.add_item("%dx%d" % [res.x, res.y])
	vbox.add_child(_setting_row("Resolution", _resolution_option))

	_window_mode_option = OptionButton.new()
	_window_mode_option.custom_minimum_size = Vector2(200, 0)
	for mode_name in GameSettings.WINDOW_MODES:
		_window_mode_option.add_item(mode_name)
	vbox.add_child(_setting_row("Window Mode", _window_mode_option))

	_vsync_check = CheckButton.new()
	_vsync_check.text = "Enabled"
	vbox.add_child(_setting_row("VSync", _vsync_check))

	vbox.add_child(_spacer(6))

	# Controls section
	vbox.add_child(_section_label("CONTROLS"))

	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	var sens_label := Label.new()
	sens_label.text = "Mouse Sensitivity"
	sens_label.custom_minimum_size = Vector2(160, 0)
	sens_row.add_child(sens_label)

	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = 0.5
	_sensitivity_slider.max_value = 5.0
	_sensitivity_slider.step = 0.1
	_sensitivity_slider.custom_minimum_size = Vector2(180, 0)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	sens_row.add_child(_sensitivity_slider)

	_sensitivity_value = Label.new()
	_sensitivity_value.custom_minimum_size = Vector2(40, 0)
	_sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sens_row.add_child(_sensitivity_value)
	vbox.add_child(sens_row)

	var keybinds_btn := Button.new()
	keybinds_btn.text = "Key Bindings..."
	keybinds_btn.custom_minimum_size = Vector2(300, 36)
	keybinds_btn.pressed.connect(_on_key_bindings)
	vbox.add_child(keybinds_btn)

	vbox.add_child(_spacer(10))

	# Buttons
	var apply_btn := _make_button("Apply", Color(0.2, 0.5, 0.3))
	apply_btn.pressed.connect(_on_options_apply)
	vbox.add_child(apply_btn)

	var back_btn := _make_button("Back", Color(0.25, 0.25, 0.35))
	back_btn.pressed.connect(_close_options)
	vbox.add_child(back_btn)


func _load_options_state() -> void:
	_resolution_option.selected = GameSettings.resolution_index
	_window_mode_option.selected = GameSettings.window_mode
	_vsync_check.button_pressed = GameSettings.vsync_enabled
	var sens_display := GameSettings.mouse_sensitivity / 0.001
	_sensitivity_slider.value = sens_display
	_sensitivity_value.text = "%.1f" % sens_display


func _on_sensitivity_changed(value: float) -> void:
	_sensitivity_value.text = "%.1f" % value


func _on_options_apply() -> void:
	GameSettings.resolution_index = _resolution_option.selected
	GameSettings.window_mode = _window_mode_option.selected
	GameSettings.vsync_enabled = _vsync_check.button_pressed
	GameSettings.mouse_sensitivity = _sensitivity_slider.value * 0.001
	GameSettings.save_settings()
	GameSettings.apply_all()


func _on_key_bindings() -> void:
	KeyBindingsMenu.open()


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 44)
	btn.add_theme_font_size_override("font_size", 18)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(color.r + 0.1, color.g + 0.1, color.b + 0.1)
	style_hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", style_hover)
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(color.r + 0.15, color.g + 0.15, color.b + 0.15)
	style_pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	return btn


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return lbl


func _setting_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	row.add_child(control)
	return row


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
