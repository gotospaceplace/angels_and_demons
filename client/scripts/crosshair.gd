extends CanvasLayer

var _draw_node: CrosshairDraw
var _weapon_system: Node


func _ready() -> void:
	layer = 10
	_draw_node = CrosshairDraw.new()
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)


func _process(_delta: float) -> void:
	if not _weapon_system:
		var ws_nodes := get_tree().get_nodes_in_group("weapon_system")
		if ws_nodes.size() > 0:
			_weapon_system = ws_nodes[0]

	if _weapon_system:
		_draw_node.spread = _weapon_system.get_current_spread()
		_draw_node.weapon_name = _weapon_system.get_weapon_name()
		_draw_node.ammo_text = _weapon_system.get_ammo_display()
		_draw_node.is_reloading = _weapon_system.is_reloading
		_draw_node.is_switching = _weapon_system.is_switching
		_draw_node.is_toggling = _weapon_system.is_toggling
		_draw_node.is_scoped = _weapon_system.is_scoped
		_draw_node.silencer_on = _weapon_system.silencer_on

	_draw_node.queue_redraw()


class CrosshairDraw extends Control:
	var spread: float = 0.0
	var weapon_name: String = ""
	var ammo_text: String = ""
	var is_reloading: bool = false
	var is_switching: bool = false
	var is_toggling: bool = false
	var is_scoped: bool = false
	var silencer_on: bool = false

	const LINE_LEN := 8.0
	const THICKNESS := 2.0
	const GAP_MIN := 3.0
	const DOT_RADIUS := 1.5
	const SPREAD_SCALE := 800.0
	const OUTLINE := Color(0, 0, 0, 0.85)
	const FILL := Color.WHITE
	const SCOPE_LINE := Color(0, 0, 0, 0.6)

	func _draw() -> void:
		var center := size / 2.0

		if is_scoped:
			_draw_scope(center)
		else:
			var gap := GAP_MIN + spread * SPREAD_SCALE
			_draw_cross(center, gap, OUTLINE, THICKNESS + 2.0)
			_draw_cross(center, gap, FILL, THICKNESS)

		# Weapon info (bottom center)
		if weapon_name != "":
			var info := weapon_name
			if silencer_on:
				info += " [S]"
			if is_reloading:
				info += "  [RELOADING]"
			elif is_switching:
				info += "  [SWITCHING]"
			elif is_toggling:
				info += "  [SILENCER]"
			elif ammo_text != "":
				info += "  " + ammo_text

			var font := ThemeDB.fallback_font
			var fsize := 14
			var text_size := font.get_string_size(info, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			var text_pos := Vector2(center.x - text_size.x / 2.0, size.y - 40)
			draw_string(font, text_pos + Vector2(1, 1), info, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, OUTLINE)
			draw_string(font, text_pos, info, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, FILL)

	func _draw_scope(center: Vector2) -> void:
		# Full-screen cross for AWP scope
		draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), SCOPE_LINE, 1.0)
		draw_line(Vector2(0, center.y), Vector2(size.x, center.y), SCOPE_LINE, 1.0)
		draw_circle(center, DOT_RADIUS, FILL)

	func _draw_cross(center: Vector2, gap: float, color: Color, thick: float) -> void:
		# Top
		draw_line(Vector2(center.x, center.y - gap - LINE_LEN),
				  Vector2(center.x, center.y - gap), color, thick)
		# Bottom
		draw_line(Vector2(center.x, center.y + gap),
				  Vector2(center.x, center.y + gap + LINE_LEN), color, thick)
		# Left
		draw_line(Vector2(center.x - gap - LINE_LEN, center.y),
				  Vector2(center.x - gap, center.y), color, thick)
		# Right
		draw_line(Vector2(center.x + gap, center.y),
				  Vector2(center.x + gap + LINE_LEN, center.y), color, thick)
		# Center dot
		draw_circle(center, DOT_RADIUS if thick <= THICKNESS else DOT_RADIUS + 1.0, color)
