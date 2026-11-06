class_name ClientDeathReport
extends Node

const COL_BG := Color(0.12, 0.12, 0.15, 0.88)
const COL_HEADER_BG := Color(0.18, 0.18, 0.22, 0.95)
const COL_ROW_BG := Color(0.15, 0.15, 0.19, 0.85)
const COL_ROW_ALT := Color(0.13, 0.13, 0.17, 0.85)
const COL_BORDER := Color(0.3, 0.3, 0.4, 0.5)
const COL_GREEN := Color(0.3, 1.0, 0.3)
const COL_RED := Color(1.0, 0.35, 0.35)
const COL_TEXT := Color(0.85, 0.85, 0.85)
const COL_DIM := Color(0.55, 0.55, 0.55)
const COL_KILLED := Color(1.0, 0.2, 0.2)
const PANEL_W := 420
const ROW_H := 44

var _layer: CanvasLayer
var _panel: Control
var _content: VBoxContainer
var _visible: bool = false


func _ready() -> void:
	_build_ui()


func show_report(report: Dictionary, killer_id: int = 0) -> void:
	_clear_content()
	var given: Array = report.get("given", [])
	var taken: Array = report.get("taken", [])

	_add_killed_by_header(killer_id)
	_add_damage_report_header()

	var merged := _merge_entries(given, taken, killer_id)
	for i in range(merged.size()):
		_add_damage_row(merged[i], i % 2 == 1)

	if merged.is_empty():
		var empty := Label.new()
		empty.text = "No damage exchanged"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", COL_DIM)
		empty.custom_minimum_size.y = ROW_H
		_content.add_child(empty)

	_panel.visible = true
	_visible = true


func hide_report() -> void:
	_panel.visible = false
	_visible = false


func is_showing() -> bool:
	return _visible


func _merge_entries(given: Array, taken: Array, killer_id: int) -> Array:
	var by_id: Dictionary = {}
	for entry in taken:
		var pid: int = entry["id"]
		by_id[pid] = {
			"id": pid,
			"in_dmg": entry.get("dmg", 0),
			"in_hits": entry.get("hits", 0),
			"in_hs": entry.get("hs", 0),
			"out_dmg": 0, "out_hits": 0, "out_hs": 0,
			"killed_me": pid == killer_id,
			"i_killed": false,
		}
	for entry in given:
		var pid: int = entry["id"]
		if not by_id.has(pid):
			by_id[pid] = {
				"id": pid,
				"in_dmg": 0, "in_hits": 0, "in_hs": 0,
				"out_dmg": 0, "out_hits": 0, "out_hs": 0,
				"killed_me": false, "i_killed": false,
			}
		by_id[pid]["out_dmg"] = entry.get("dmg", 0)
		by_id[pid]["out_hits"] = entry.get("hits", 0)
		by_id[pid]["out_hs"] = entry.get("hs", 0)
	var result: Array = by_id.values()
	result.sort_custom(func(a, b):
		if a["killed_me"] and not b["killed_me"]: return true
		if b["killed_me"] and not a["killed_me"]: return false
		return (a["in_dmg"] + a["out_dmg"]) > (b["in_dmg"] + b["out_dmg"]))
	return result


func _add_killed_by_header(killer_id: int) -> void:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	header.add_theme_stylebox_override("panel", style)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	header.add_child(hbox)

	var killed_lbl := Label.new()
	killed_lbl.text = "KILLED BY"
	killed_lbl.add_theme_font_size_override("font_size", 14)
	killed_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	killed_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	killed_lbl.add_theme_constant_override("shadow_offset_x", 1)
	killed_lbl.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(killed_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "Player %d" % killer_id if killer_id > 0 else "Unknown"
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	_content.add_child(header)


func _add_damage_report_header() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_HEADER_BG
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	bar.add_child(hbox)

	var incoming := Label.new()
	incoming.text = "Incoming"
	incoming.add_theme_font_size_override("font_size", 12)
	incoming.add_theme_color_override("font_color", COL_RED)
	incoming.custom_minimum_size.x = 80
	hbox.add_child(incoming)

	var center := Label.new()
	center.text = "Damage Report"
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_theme_font_size_override("font_size", 14)
	center.add_theme_color_override("font_color", COL_TEXT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(center)

	var outgoing := Label.new()
	outgoing.text = "Outgoing"
	outgoing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	outgoing.add_theme_font_size_override("font_size", 12)
	outgoing.add_theme_color_override("font_color", COL_GREEN)
	outgoing.custom_minimum_size.x = 80
	hbox.add_child(outgoing)

	_content.add_child(bar)


func _add_damage_row(entry: Dictionary, alt: bool) -> void:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_ROW_ALT if alt else COL_ROW_BG
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.border_color = COL_BORDER
	style.border_width_bottom = 1
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	row.add_child(hbox)

	# --- Incoming (damage taken from this player) ---
	var in_col := VBoxContainer.new()
	in_col.custom_minimum_size.x = 70
	in_col.add_theme_constant_override("separation", 0)
	hbox.add_child(in_col)

	var in_dmg: int = entry.get("in_dmg", 0)
	var in_hits: int = entry.get("in_hits", 0)
	var in_hs: int = entry.get("in_hs", 0)

	var in_dmg_lbl := Label.new()
	in_dmg_lbl.text = str(in_dmg) if in_dmg > 0 else "-"
	in_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	in_dmg_lbl.add_theme_font_size_override("font_size", 20)
	in_dmg_lbl.add_theme_color_override("font_color", COL_RED if in_dmg > 0 else COL_DIM)
	in_dmg_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	in_dmg_lbl.add_theme_constant_override("shadow_offset_x", 1)
	in_dmg_lbl.add_theme_constant_override("shadow_offset_y", 1)
	in_col.add_child(in_dmg_lbl)

	if entry.get("killed_me", false):
		var killed_lbl := Label.new()
		killed_lbl.text = "Killed"
		killed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		killed_lbl.add_theme_font_size_override("font_size", 10)
		killed_lbl.add_theme_color_override("font_color", COL_KILLED)
		in_col.add_child(killed_lbl)
	elif in_hits > 0:
		var in_detail := Label.new()
		var detail_text := "%d hit%s" % [in_hits, "s" if in_hits != 1 else ""]
		if in_hs > 0:
			detail_text += " %dHS" % in_hs
		in_detail.text = detail_text
		in_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		in_detail.add_theme_font_size_override("font_size", 10)
		in_detail.add_theme_color_override("font_color", COL_DIM)
		in_col.add_child(in_detail)

	# --- Center: Player name ---
	var name_lbl := Label.new()
	name_lbl.text = "Player %d" % entry.get("id", 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# --- Outgoing (damage given to this player) ---
	var out_col := VBoxContainer.new()
	out_col.custom_minimum_size.x = 70
	out_col.add_theme_constant_override("separation", 0)
	hbox.add_child(out_col)

	var out_dmg: int = entry.get("out_dmg", 0)
	var out_hits: int = entry.get("out_hits", 0)
	var out_hs: int = entry.get("out_hs", 0)

	var out_dmg_lbl := Label.new()
	out_dmg_lbl.text = str(out_dmg) if out_dmg > 0 else "-"
	out_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out_dmg_lbl.add_theme_font_size_override("font_size", 20)
	out_dmg_lbl.add_theme_color_override("font_color", COL_GREEN if out_dmg > 0 else COL_DIM)
	out_dmg_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	out_dmg_lbl.add_theme_constant_override("shadow_offset_x", 1)
	out_dmg_lbl.add_theme_constant_override("shadow_offset_y", 1)
	out_col.add_child(out_dmg_lbl)

	if entry.get("i_killed", false):
		var killed_lbl := Label.new()
		killed_lbl.text = "Killed"
		killed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		killed_lbl.add_theme_font_size_override("font_size", 10)
		killed_lbl.add_theme_color_override("font_color", COL_KILLED)
		out_col.add_child(killed_lbl)
	elif out_hits > 0:
		var out_detail := Label.new()
		var detail_text := "%d hit%s" % [out_hits, "s" if out_hits != 1 else ""]
		if out_hs > 0:
			detail_text += " %dHS" % out_hs
		out_detail.text = detail_text
		out_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		out_detail.add_theme_font_size_override("font_size", 10)
		out_detail.add_theme_color_override("font_color", COL_DIM)
		out_col.add_child(out_detail)

	_content.add_child(row)


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DeathReportLayer"
	_layer.layer = 16
	add_child(_layer)

	var root := Control.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	_panel = Control.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.12
	_panel.offset_left = -(PANEL_W + 12)
	_panel.offset_right = -12
	_panel.offset_top = 0
	_panel.offset_bottom = 500
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)

	var bg := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COL_BG
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.border_color = COL_BORDER
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 0)
	_content.anchors_preset = Control.PRESET_FULL_RECT
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)
