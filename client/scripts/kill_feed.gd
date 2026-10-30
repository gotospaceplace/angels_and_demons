extends CanvasLayer

const MAX_ENTRIES := 5
const DISPLAY_TIME := 5.0
const FADE_DURATION := 1.0
const WEAPON_NAMES := ["Knife", "USP", "AK-47", "M4A1", "AWP"]

var entries: Array = []
var container: VBoxContainer


func _ready() -> void:
	layer = 11
	container = VBoxContainer.new()
	container.name = "KillFeedContainer"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 2)
	add_child(container)


func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	container.position = Vector2(vp.x - 420, 16)
	container.size = Vector2(404, 0)

	var i := entries.size() - 1
	while i >= 0:
		entries[i]["time"] += delta
		if entries[i]["time"] >= DISPLAY_TIME + FADE_DURATION:
			entries[i]["label"].queue_free()
			entries.remove_at(i)
		elif entries[i]["time"] >= DISPLAY_TIME:
			var t := (entries[i]["time"] - DISPLAY_TIME) / FADE_DURATION
			entries[i]["label"].modulate.a = 1.0 - t
		i -= 1


func add_kill(killer_id: int, victim_id: int, weapon_idx: int, headshot: bool) -> void:
	var my_id := _get_local_peer_id()
	var killer := "Player %d" % killer_id
	var victim := "Player %d" % victim_id
	var weapon := WEAPON_NAMES[weapon_idx] if weapon_idx < WEAPON_NAMES.size() else "???"
	var is_knife := weapon_idx == 0

	var text := "[right]"
	text += _styled_name(killer, killer_id == my_id)
	text += "  "
	if is_knife:
		text += "[color=#aaaaaa]KNIFE[/color]"
	else:
		text += "[color=#aaaaaa]%s[/color]" % weapon
	if headshot:
		text += " [color=#ff3333]☠[/color]"
	text += "  "
	text += _styled_name(victim, victim_id == my_id)
	text += "[/right]"

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	container.add_child(label)
	container.move_child(label, 0)
	entries.insert(0, {"label": label, "time": 0.0})

	while entries.size() > MAX_ENTRIES:
		var old: Dictionary = entries.pop_back()
		old["label"].queue_free()


func _styled_name(player_name: String, is_local: bool) -> String:
	if is_local:
		return "[color=#ffda33]%s[/color]" % player_name
	return "[color=#ffffff]%s[/color]" % player_name


func _get_local_peer_id() -> int:
	var cg := get_tree().get_first_node_in_group("client_game")
	return cg.my_peer_id if cg else 0
