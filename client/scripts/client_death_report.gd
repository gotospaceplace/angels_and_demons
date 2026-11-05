class_name ClientDeathReport
extends Node

var _layer: CanvasLayer
var _panel: PanelContainer
var _given_list: VBoxContainer
var _taken_list: VBoxContainer
var _visible: bool = false


func _ready() -> void:
	_build_ui()


func show_report(report: Dictionary) -> void:
	_clear_lists()
	var given: Array = report.get("given", [])
	var taken: Array = report.get("taken", [])

	given.sort_custom(func(a, b): return a["dmg"] > b["dmg"])
	taken.sort_custom(func(a, b): return a["dmg"] > b["dmg"])

	for entry in given:
		_given_list.add_child(_make_entry(entry, Color(0.3, 1.0, 0.3)))
	if given.is_empty():
		_given_list.add_child(_make_empty_label())

	for entry in taken:
		_taken_list.add_child(_make_entry(entry, Color(1.0, 0.35, 0.35)))
	if taken.is_empty():
		_taken_list.add_child(_make_empty_label())

	_panel.visible = true
	_visible = true


func hide_report() -> void:
	_panel.visible = false
	_visible = false


func is_showing() -> bool:
	return _visible


func _make_entry(entry: Dictionary, color: Color) -> Label:
	var lbl := Label.new()
	var dmg: int = entry.get("dmg", 0)
	var hits: int = entry.get("hits", 0)
	var hs: int = entry.get("hs", 0)
	var pid: int = entry.get("id", 0)
	var text := "Player %d: %d in %d hit%s" % [pid, dmg, hits, "s" if hits != 1 else ""]
	if hs > 0:
		text += " (%d HS)" % hs
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _make_empty_label() -> Label:
	var lbl := Label.new()
	lbl.text = "None"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	return lbl


func _clear_lists() -> void:
	for child in _given_list.get_children():
		child.queue_free()
	for child in _taken_list.get_children():
		child.queue_free()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DeathReportLayer"
	_layer.layer = 16
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.size = Vector2(500, 200)
	_panel.position = Vector2(-250, -100)
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	_panel.add_child(columns)

	var given_col := VBoxContainer.new()
	given_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(given_col)

	var given_title := Label.new()
	given_title.text = "Damage Given"
	given_title.add_theme_font_size_override("font_size", 16)
	given_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	given_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	given_title.add_theme_constant_override("shadow_offset_x", 1)
	given_title.add_theme_constant_override("shadow_offset_y", 1)
	given_col.add_child(given_title)

	_given_list = VBoxContainer.new()
	given_col.add_child(_given_list)

	var taken_col := VBoxContainer.new()
	taken_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(taken_col)

	var taken_title := Label.new()
	taken_title.text = "Damage Taken"
	taken_title.add_theme_font_size_override("font_size", 16)
	taken_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	taken_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	taken_title.add_theme_constant_override("shadow_offset_x", 1)
	taken_title.add_theme_constant_override("shadow_offset_y", 1)
	taken_col.add_child(taken_title)

	_taken_list = VBoxContainer.new()
	taken_col.add_child(_taken_list)
