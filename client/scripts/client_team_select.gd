class_name ClientTeamSelect
extends CanvasLayer

signal team_selected(team: int)

var _panel: PanelContainer
var _angels_btn: Button
var _demons_btn: Button
var _auto_btn: Button
var _spectate_btn: Button
var _angels_count_label: Label
var _demons_count_label: Label
var _is_open: bool = false


func _ready() -> void:
	layer = 18
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.name = "TeamSelectPanel"
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(360, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SELECT TEAM"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var angels_row := HBoxContainer.new()
	vbox.add_child(angels_row)
	_angels_btn = _make_team_button("Angels", Team.COLOR_ANGELS)
	_angels_btn.pressed.connect(_on_angels)
	angels_row.add_child(_angels_btn)
	_angels_count_label = Label.new()
	_angels_count_label.add_theme_font_size_override("font_size", 16)
	_angels_count_label.add_theme_color_override("font_color", Team.COLOR_ANGELS)
	_angels_count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_angels_count_label.text = "(0)"
	angels_row.add_child(_angels_count_label)

	var demons_row := HBoxContainer.new()
	vbox.add_child(demons_row)
	_demons_btn = _make_team_button("Demons", Team.COLOR_DEMONS)
	_demons_btn.pressed.connect(_on_demons)
	demons_row.add_child(_demons_btn)
	_demons_count_label = Label.new()
	_demons_count_label.add_theme_font_size_override("font_size", 16)
	_demons_count_label.add_theme_color_override("font_color", Team.COLOR_DEMONS)
	_demons_count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_demons_count_label.text = "(0)"
	demons_row.add_child(_demons_count_label)

	_auto_btn = _make_team_button("Auto Assign", Color(0.7, 0.7, 0.7))
	_auto_btn.pressed.connect(_on_auto)
	vbox.add_child(_auto_btn)

	_spectate_btn = _make_team_button("Spectate", Team.COLOR_SPECTATOR)
	_spectate_btn.pressed.connect(_on_spectate)
	vbox.add_child(_spectate_btn)


func _make_team_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(color, 0.3)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(color, 0.5)
	style_hover.set_corner_radius_all(4)
	style_hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", style_hover)
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(color, 0.7)
	style_pressed.set_corner_radius_all(4)
	style_pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	return btn


func open_menu() -> void:
	if _is_open:
		return
	_is_open = true
	_panel.visible = true
	get_child(0).visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	get_child(0).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _is_open


func update_counts(angels: int, demons: int) -> void:
	_angels_count_label.text = "(%d)" % angels
	_demons_count_label.text = "(%d)" % demons


func _on_angels() -> void:
	_select(Team.Id.ANGELS)

func _on_demons() -> void:
	_select(Team.Id.DEMONS)

func _on_auto() -> void:
	_select(Team.Id.UNASSIGNED)

func _on_spectate() -> void:
	_select(Team.Id.SPECTATOR)


func _select(team: int) -> void:
	close_menu()
	team_selected.emit(team)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			if _is_open:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_open:
			close_menu()
			get_viewport().set_input_as_handled()
