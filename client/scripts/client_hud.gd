class_name ClientHud
extends CanvasLayer

var my_peer_id: int = 0
var my_team: int = 0
var attack_team: int = 0
var money: int = 800
var hp: int = 100
var armor: int = 0
var weapon_idx: int = 0
var ammo_mag: int = 0
var round_timer: float = 0.0
var match_state: String = "WARMUP"
var round_number: int = 0
var score_angels: int = 0
var score_demons: int = 0
var roster: Array = []
var portal_state: String = "inactive"
var catalyst_carrier: int = -1
var timer_counting: bool = false

# Top bar
var top_bar: Control
var my_team_icon: ColorRect
var enemy_team_icon: ColorRect
var my_players_box: HBoxContainer
var enemy_players_box: HBoxContainer
var my_score_label: Label
var enemy_score_label: Label
var timer_label: Label
var objective_label: Label

# Minimap
var minimap_bg: Control
var area_label: Label

# Chatbox
var chatbox_panel: Panel

# Weapon slots
var weapon_container: VBoxContainer
var weapon_panels: Array[Panel] = []
var weapon_labels: Array[Label] = []
var weapon_key_labels: Array[Label] = []

# Bottom bar
var bottom_bar: Control
var money_label: Label
var hp_label: Label
var armor_bar: ColorRect
var grenade_container: HBoxContainer
var grenade_panels: Array[Panel] = []
var grenade_count_labels: Array[Label] = []
var grenade_key_labels: Array[Label] = []
var ammo_label: Label
var catalyst_panel: Panel
var catalyst_label: Label

const WEAPON_NAMES := ["Knife", "USP", "AK-47", "M4A1", "AWP"]
const GRENADE_KEYS := ["V", "C", "Z"]
const GRENADE_NAMES := ["HE", "Flash", "Smoke"]
const WEAPON_SLOT_MAP := [2, 1, 0]

const COL_BG := Color(0, 0, 0, 0.55)
const COL_BG_LIGHT := Color(0.15, 0.15, 0.15, 0.55)
const COL_ACTIVE := Color(1.0, 1.0, 1.0, 0.15)
const COL_MONEY := Color(0.4, 0.9, 0.3)
const COL_HP_HIGH := Color.WHITE
const COL_HP_MED := Color(1.0, 0.85, 0.2)
const COL_HP_LOW := Color(1.0, 0.25, 0.25)
const COL_TIMER_WARN := Color(1.0, 0.25, 0.25)


func _ready() -> void:
	layer = 10
	_build_ui()


func _process(delta: float) -> void:
	if match_state == "LIVE" or match_state == "FREEZE" or match_state == "ROUND_OVER" or match_state == "HALFTIME":
		round_timer = maxf(0.0, round_timer - delta)
	_layout()
	_update_display()


func update_from_snapshot(snap_hp: int, snap_armor: int, snap_weapon: int, snap_ammo: int) -> void:
	hp = snap_hp
	armor = snap_armor
	weapon_idx = snap_weapon
	ammo_mag = snap_ammo


func update_from_match_state(state: Dictionary) -> void:
	match_state = state.get("state", "WARMUP")
	round_number = state.get("round", 0)
	score_angels = state.get("score_angels", 0)
	score_demons = state.get("score_demons", 0)
	round_timer = state.get("timer", 0.0)
	attack_team = state.get("attack_team", 0)
	portal_state = state.get("portal_state", "inactive")
	catalyst_carrier = state.get("catalyst_carrier", -1)
	my_team = state.get("my_team", 0)
	money = state.get("money", money)
	roster = state.get("roster", roster)
	_rebuild_player_cards()


# --- UI building ---

func _build_ui() -> void:
	_build_top_bar()
	_build_minimap()
	_build_chatbox()
	_build_weapon_slots()
	_build_bottom_bar()


func _build_top_bar() -> void:
	top_bar = Control.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	my_team_icon = _make_rect(Color.WHITE, Vector2(24, 24))
	top_bar.add_child(my_team_icon)

	my_players_box = HBoxContainer.new()
	my_players_box.add_theme_constant_override("separation", 3)
	my_players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(my_players_box)

	my_score_label = _make_label(24, Color.WHITE)
	my_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(my_score_label)

	var timer_bg := _make_panel(COL_BG, Vector2(120, 48))
	top_bar.add_child(timer_bg)

	timer_label = _make_label(26, Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_bg.add_child(timer_label)

	objective_label = _make_label(13, Color(0.7, 0.7, 0.7))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_bg.add_child(objective_label)

	enemy_score_label = _make_label(24, Color.WHITE)
	top_bar.add_child(enemy_score_label)

	enemy_players_box = HBoxContainer.new()
	enemy_players_box.add_theme_constant_override("separation", 3)
	enemy_players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(enemy_players_box)

	enemy_team_icon = _make_rect(Color.WHITE, Vector2(24, 24))
	top_bar.add_child(enemy_team_icon)


func _build_minimap() -> void:
	minimap_bg = Control.new()
	minimap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap_bg)

	var circle := ColorRect.new()
	circle.color = Color(0.3, 0.3, 0.3, 0.4)
	circle.size = Vector2(120, 120)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_bg.add_child(circle)

	area_label = _make_label(13, Color(0.7, 0.7, 0.7))
	area_label.text = "Area Name"
	minimap_bg.add_child(area_label)


func _build_chatbox() -> void:
	chatbox_panel = _make_panel(Color(0.3, 0.3, 0.3, 0.25), Vector2(280, 200))
	chatbox_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chatbox_panel)

	var chat_label := _make_label(13, Color(0.5, 0.5, 0.5))
	chat_label.text = "Chat"
	chat_label.position = Vector2(10, 10)
	chatbox_panel.add_child(chat_label)


func _build_weapon_slots() -> void:
	weapon_container = VBoxContainer.new()
	weapon_container.add_theme_constant_override("separation", 4)
	weapon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_container)

	for i in range(3):
		var slot_panel := _make_panel(COL_BG, Vector2(140, 32))
		weapon_container.add_child(slot_panel)
		weapon_panels.append(slot_panel)

		var key_lbl := _make_label(12, Color(0.6, 0.6, 0.6))
		key_lbl.text = str(i + 1)
		key_lbl.position = Vector2(6, 7)
		slot_panel.add_child(key_lbl)
		weapon_key_labels.append(key_lbl)

		var name_lbl := _make_label(14, Color.WHITE)
		name_lbl.position = Vector2(24, 6)
		name_lbl.size = Vector2(110, 22)
		slot_panel.add_child(name_lbl)
		weapon_labels.append(name_lbl)


func _build_bottom_bar() -> void:
	bottom_bar = Control.new()
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)

	money_label = _make_label(28, COL_MONEY)
	money_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	money_label.add_theme_constant_override("shadow_offset_x", 2)
	money_label.add_theme_constant_override("shadow_offset_y", 2)
	bottom_bar.add_child(money_label)

	hp_label = _make_label(36, COL_HP_HIGH)
	hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hp_label.add_theme_constant_override("shadow_offset_x", 2)
	hp_label.add_theme_constant_override("shadow_offset_y", 2)
	bottom_bar.add_child(hp_label)

	armor_bar = _make_rect(Color(0.3, 0.5, 1.0, 0.6), Vector2(0, 4))
	bottom_bar.add_child(armor_bar)

	grenade_container = HBoxContainer.new()
	grenade_container.add_theme_constant_override("separation", 6)
	grenade_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(grenade_container)

	for i in range(3):
		var g_panel := _make_panel(COL_BG_LIGHT, Vector2(44, 44))
		grenade_container.add_child(g_panel)
		grenade_panels.append(g_panel)

		var count_lbl := _make_label(16, Color.WHITE)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.position = Vector2(0, 4)
		count_lbl.size = Vector2(44, 20)
		count_lbl.text = "0"
		g_panel.add_child(count_lbl)
		grenade_count_labels.append(count_lbl)

		var key_lbl := _make_label(10, Color(0.5, 0.5, 0.5))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.position = Vector2(0, 28)
		key_lbl.size = Vector2(44, 14)
		key_lbl.text = GRENADE_KEYS[i]
		g_panel.add_child(key_lbl)
		grenade_key_labels.append(key_lbl)

	ammo_label = _make_label(30, Color.WHITE)
	ammo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ammo_label.add_theme_constant_override("shadow_offset_x", 2)
	ammo_label.add_theme_constant_override("shadow_offset_y", 2)
	bottom_bar.add_child(ammo_label)

	catalyst_panel = _make_panel(COL_BG_LIGHT, Vector2(50, 50))
	bottom_bar.add_child(catalyst_panel)

	var cat_key := _make_label(10, Color(0.5, 0.5, 0.5))
	cat_key.text = "5"
	cat_key.position = Vector2(38, 2)
	catalyst_panel.add_child(cat_key)

	catalyst_label = _make_label(14, Color.WHITE)
	catalyst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalyst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalyst_label.position = Vector2(0, 12)
	catalyst_label.size = Vector2(50, 30)
	catalyst_panel.add_child(catalyst_label)


# --- Layout ---

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1920, 1080)

	_layout_top_bar(vp)
	_layout_minimap(vp)
	_layout_chatbox(vp)
	_layout_weapon_slots(vp)
	_layout_bottom_bar(vp)


func _layout_top_bar(vp: Vector2) -> void:
	var cx := vp.x * 0.5
	var y := 8.0
	var timer_w := 120.0
	var timer_h := 48.0
	var score_w := 40.0
	var card_w := 20.0
	var card_gap := 3.0
	var section_gap := 10.0

	var timer_bg: Panel = timer_label.get_parent()
	timer_bg.position = Vector2(cx - timer_w * 0.5, y)
	timer_bg.size = Vector2(timer_w, timer_h)
	timer_label.position = Vector2(0, 2)
	timer_label.size = Vector2(timer_w, 26)
	objective_label.position = Vector2(0, 28)
	objective_label.size = Vector2(timer_w, 16)

	my_score_label.size = Vector2(score_w, 30)
	my_score_label.position = Vector2(cx - timer_w * 0.5 - section_gap - score_w, y + 6)

	var my_cards_w := _count_visible_cards(my_players_box) * (card_w + card_gap)
	my_players_box.position = Vector2(
		my_score_label.position.x - section_gap - my_cards_w, y + 8)

	my_team_icon.position = Vector2(
		my_players_box.position.x - section_gap - 24, y + 4)

	enemy_score_label.size = Vector2(score_w, 30)
	enemy_score_label.position = Vector2(cx + timer_w * 0.5 + section_gap, y + 6)

	enemy_players_box.position = Vector2(
		enemy_score_label.position.x + score_w + section_gap, y + 8)

	var enemy_cards_w := _count_visible_cards(enemy_players_box) * (card_w + card_gap)
	enemy_team_icon.position = Vector2(
		enemy_players_box.position.x + enemy_cards_w + section_gap, y + 4)


func _layout_minimap(vp: Vector2) -> void:
	minimap_bg.position = Vector2(16, 16)
	area_label.position = Vector2(10, 128)
	area_label.size = Vector2(120, 20)


func _layout_chatbox(vp: Vector2) -> void:
	chatbox_panel.position = Vector2(16, vp.y * 0.45)
	chatbox_panel.size = Vector2(280, vp.y * 0.25)


func _layout_weapon_slots(vp: Vector2) -> void:
	weapon_container.position = Vector2(vp.x - 160, vp.y * 0.52)


func _layout_bottom_bar(vp: Vector2) -> void:
	var y := vp.y - 60.0

	money_label.position = Vector2(20, y)
	money_label.size = Vector2(160, 40)

	hp_label.position = Vector2(vp.x * 0.25, y - 4)
	hp_label.size = Vector2(100, 50)

	armor_bar.position = Vector2(vp.x * 0.25, y + 38)
	var armor_pct := clampf(float(armor) / 100.0, 0.0, 1.0)
	armor_bar.size = Vector2(80.0 * armor_pct, 4)
	armor_bar.visible = armor > 0

	grenade_container.position = Vector2(vp.x * 0.42, y - 2)

	ammo_label.position = Vector2(vp.x * 0.60, y)
	ammo_label.size = Vector2(120, 40)

	catalyst_panel.position = Vector2(vp.x * 0.76, y - 8)


# --- Display updates ---

func _update_display() -> void:
	_update_money()
	_update_hp()
	_update_ammo()
	_update_timer()
	_update_scores()
	_update_weapons()
	_update_objective()
	_update_catalyst()
	_update_team_icons()


func _update_money() -> void:
	money_label.text = "$%d" % money


func _update_hp() -> void:
	hp_label.text = "%d" % hp
	if hp > 50:
		hp_label.add_theme_color_override("font_color", COL_HP_HIGH)
	elif hp > 25:
		hp_label.add_theme_color_override("font_color", COL_HP_MED)
	else:
		hp_label.add_theme_color_override("font_color", COL_HP_LOW)


func _update_ammo() -> void:
	if weapon_idx == 0:
		ammo_label.text = ""
	else:
		ammo_label.text = "%d" % ammo_mag


func _update_timer() -> void:
	if match_state == "WARMUP":
		timer_label.text = "WARMUP"
		timer_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	elif match_state == "MATCH_OVER":
		timer_label.text = "MATCH OVER"
		timer_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		var mins: int = int(round_timer) / 60
		var secs: int = int(round_timer) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
		if round_timer < 10.0 and match_state == "LIVE":
			timer_label.add_theme_color_override("font_color", COL_TIMER_WARN)
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)


func _update_scores() -> void:
	var my_score: int
	var enemy_score: int
	if my_team == Team.Id.ANGELS:
		my_score = score_angels
		enemy_score = score_demons
	else:
		my_score = score_demons
		enemy_score = score_angels
	my_score_label.text = str(my_score)
	enemy_score_label.text = str(enemy_score)


func _update_weapons() -> void:
	for i in range(3):
		var w_idx: int = WEAPON_SLOT_MAP[i]
		var w_name: String = WEAPON_NAMES[w_idx] if w_idx < WEAPON_NAMES.size() else "---"
		weapon_labels[i].text = w_name

		var style: StyleBoxFlat = weapon_panels[i].get_theme_stylebox("panel")
		if weapon_idx == w_idx:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
			style.border_color = Color(1.0, 1.0, 1.0, 0.4)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		else:
			style.bg_color = COL_BG
			style.border_color = Color.TRANSPARENT
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0


func _update_objective() -> void:
	match match_state:
		"FREEZE":
			objective_label.text = "FREEZE TIME"
		"LIVE":
			if portal_state == "activated":
				objective_label.text = "PORTAL ACTIVE"
				objective_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			else:
				objective_label.text = "Round %d" % round_number
				objective_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		"ROUND_OVER":
			objective_label.text = "ROUND OVER"
		"HALFTIME":
			objective_label.text = "HALFTIME"
		"WARMUP":
			objective_label.text = "Waiting for players"
		"MATCH_OVER":
			objective_label.text = ""
		_:
			objective_label.text = ""


func _update_catalyst() -> void:
	if my_team == attack_team:
		catalyst_label.text = "CAT"
		if catalyst_carrier == my_peer_id:
			var style: StyleBoxFlat = catalyst_panel.get_theme_stylebox("panel")
			style.bg_color = Color(0.8, 0.4, 0.1, 0.6)
		else:
			var style: StyleBoxFlat = catalyst_panel.get_theme_stylebox("panel")
			style.bg_color = COL_BG_LIGHT
	else:
		catalyst_label.text = "REL"


func _update_team_icons() -> void:
	if my_team == Team.Id.ANGELS:
		my_team_icon.color = Team.COLOR_ANGELS
		enemy_team_icon.color = Team.COLOR_DEMONS
	elif my_team == Team.Id.DEMONS:
		my_team_icon.color = Team.COLOR_DEMONS
		enemy_team_icon.color = Team.COLOR_ANGELS
	else:
		my_team_icon.color = Color.GRAY
		enemy_team_icon.color = Color.GRAY


# --- Player cards ---

func _rebuild_player_cards() -> void:
	_clear_children(my_players_box)
	_clear_children(enemy_players_box)

	var enemy_team: int = Team.get_opposing(my_team)

	for entry in roster:
		var pid: int = entry.get("id", 0)
		var team: int = entry.get("team", 0)
		var alive: bool = entry.get("alive", false)
		var color_idx: int = entry.get("color", 0)

		if not alive:
			continue

		var card := ColorRect.new()
		card.custom_minimum_size = Vector2(20, 20)
		card.size = Vector2(20, 20)
		card.color = Team.get_player_color(color_idx)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if pid == my_peer_id:
			var border := ColorRect.new()
			border.custom_minimum_size = Vector2(20, 20)
			border.size = Vector2(20, 20)
			border.color = Color.WHITE
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var inner := ColorRect.new()
			inner.position = Vector2(2, 2)
			inner.size = Vector2(16, 16)
			inner.color = Team.get_player_color(color_idx)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			border.add_child(inner)
			if team == my_team:
				my_players_box.add_child(border)
			else:
				enemy_players_box.add_child(border)
		else:
			if team == my_team:
				my_players_box.add_child(card)
			else:
				enemy_players_box.add_child(card)


# --- Helpers ---

func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_rect(color: Color, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = sz
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _make_panel(bg_color: Color, sz: Vector2) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	p.add_theme_stylebox_override("panel", style)
	p.size = sz
	p.custom_minimum_size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _count_visible_cards(box: HBoxContainer) -> int:
	var count := 0
	for child in box.get_children():
		if child.visible and not child.is_queued_for_deletion():
			count += 1
	return count
