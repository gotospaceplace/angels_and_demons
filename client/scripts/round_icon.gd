extends Control

var reason: String = ""
var icon_color: Color = Color.WHITE


func _draw() -> void:
	if reason == "":
		return
	match reason:
		"elimination": _draw_skull()
		"portal_opened": _draw_portal()
		"portal_sealed": _draw_shield()
		"time_expired": _draw_hourglass()
		_: _draw_unknown()


func set_icon(p_reason: String, p_color: Color) -> void:
	reason = p_reason
	icon_color = p_color
	queue_redraw()


func _draw_skull() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.4
	var r := size.x * 0.32
	draw_circle(Vector2(cx, cy), r, icon_color)
	var eye_r := r * 0.22
	var eye_y := cy - r * 0.1
	var bg := Color(0.0, 0.0, 0.0, 0.9)
	draw_circle(Vector2(cx - r * 0.35, eye_y), eye_r, bg)
	draw_circle(Vector2(cx + r * 0.35, eye_y), eye_r, bg)
	var jaw_y := cy + r * 0.55
	draw_rect(Rect2(cx - r * 0.5, jaw_y, r, r * 0.45), icon_color)
	for i in range(3):
		var tx := cx - r * 0.35 + i * r * 0.35
		draw_line(Vector2(tx, jaw_y), Vector2(tx, jaw_y + r * 0.45), bg, 1.0)


func _draw_portal() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var r := size.x * 0.35
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, icon_color, 2.0)
	draw_arc(Vector2(cx, cy), r * 0.5, 0.0, TAU, 16, icon_color, 1.5)
	draw_circle(Vector2(cx, cy), r * 0.15, icon_color)


func _draw_shield() -> void:
	var cx := size.x * 0.5
	var top := size.y * 0.15
	var hw := size.x * 0.35
	var mid_y := size.y * 0.55
	var bot := size.y * 0.85
	var pts := PackedVector2Array([
		Vector2(cx - hw, top),
		Vector2(cx + hw, top),
		Vector2(cx + hw, mid_y),
		Vector2(cx, bot),
		Vector2(cx - hw, mid_y),
	])
	draw_polyline(pts, icon_color, 1.5)
	draw_line(pts[4], pts[0], icon_color, 1.5)


func _draw_hourglass() -> void:
	var cx := size.x * 0.5
	var hw := size.x * 0.3
	var top := size.y * 0.15
	var mid := size.y * 0.5
	var bot := size.y * 0.85
	var top_tri := PackedVector2Array([
		Vector2(cx - hw, top),
		Vector2(cx + hw, top),
		Vector2(cx, mid),
	])
	var bot_tri := PackedVector2Array([
		Vector2(cx, mid),
		Vector2(cx + hw, bot),
		Vector2(cx - hw, bot),
	])
	draw_polygon(top_tri, PackedColorArray([icon_color, icon_color, icon_color]))
	draw_polygon(bot_tri, PackedColorArray([icon_color, icon_color, icon_color]))
	draw_line(Vector2(cx - hw, top), Vector2(cx + hw, top), icon_color, 1.0)
	draw_line(Vector2(cx - hw, bot), Vector2(cx + hw, bot), icon_color, 1.0)


func _draw_unknown() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var r := size.x * 0.25
	draw_arc(Vector2(cx, cy - r * 0.3), r, deg_to_rad(180), deg_to_rad(360), 12, icon_color, 1.5)
	draw_line(Vector2(cx, cy), Vector2(cx, cy + r * 0.4), icon_color, 1.5)
	draw_circle(Vector2(cx, cy + r * 0.9), 1.5, icon_color)
