extends CanvasLayer

const RoundIconScene = preload("res://client/scripts/round_icon.gd")

# TODO: Implement Casual 10v10 scoreboard (scrollable rows)

var mode: StringName = &""
var my_peer_id: int = 0
var my_team: int = 0
var match_state: String = "WARMUP"
var round_number: int = 0
var score_angels: int = 0
var score_demons: int = 0
var round_timer: float = 0.0
var attack_team: int = 0
var roster: Array = []
var round_history: Array = []
var loss_streak_angels: int = 0
var loss_streak_demons: int = 0

const PANEL_W := 880.0
const HEADER_H := 40.0
const COL_HDR_Y := 44.0
const COL_HDR_H := 20.0
const TEAM_Y := 68.0
const ROW_H := 28.0
const MAX_ROWS := 5
const SCORE_BOX_X := 4.0
const SCORE_BOX_W := 72.0
const SCORE_BOX_H := 140.0
const TABLE_X := 82.0
const MIDDLE_H := 56.0
const GAP := 8.0
const MAX_ROUND_MARKERS := 24

const CX_PING := 0.0;      const CW_PING := 40.0
const CX_COLOR := 44.0;    const CW_COLOR := 16.0
const CX_NAME := 66.0;     const CW_NAME := 210.0
const CX_MONEY := 345.0;   const CW_MONEY := 65.0
const CX_KILLS := 420.0;   const CW_KILLS := 50.0
const CX_DEATHS := 480.0;  const CW_DEATHS := 55.0
const CX_ASSISTS := 545.0; const CW_ASSISTS := 55.0
const CX_DMG := 610.0;     const CW_DMG := 70.0

const FFA_MAX_ROWS := 12
const FFA_TABLE_X := 12.0
const FFA_ROW_H := 26.0
const FFA_HDR_Y := 44.0
const FFA_BODY_Y := 66.0
const FFA_CX_RANK := 0.0;     const FFA_CW_RANK := 36.0
const FFA_CX_NAME := 40.0;    const FFA_CW_NAME := 220.0
const FFA_CX_KILLS := 270.0;  const FFA_CW_KILLS := 60.0
const FFA_CX_DEATHS := 340.0; const FFA_CW_DEATHS := 60.0
const FFA_CX_ASSIST := 410.0; const FFA_CW_ASSIST := 60.0
const FFA_CX_KDR := 480.0;    const FFA_CW_KDR := 60.0
const FFA_CX_DMG := 550.0;    const FFA_CW_DMG := 70.0
const FFA_CX_SCORE := 630.0;  const FFA_CW_SCORE := 60.0
const COL_FFA_ROW := Color(0.15, 0.15, 0.18, 0.5)
const COL_FFA_ROW_ALT := Color(0.15, 0.15, 0.18, 0.33)

const COL_BG := Color(0.06, 0.06, 0.08, 0.94)
const COL_HDR_BG := Color(0.1, 0.1, 0.12, 0.98)
const COL_A_ROW := Color(0.18, 0.22, 0.45, 0.5)
const COL_A_ROW_ALT := Color(0.18, 0.22, 0.45, 0.33)
const COL_D_ROW := Color(0.45, 0.18, 0.18, 0.5)
const COL_D_ROW_ALT := Color(0.45, 0.18, 0.18, 0.33)
const COL_LOCAL := Color(0.9, 0.82, 0.2, 0.22)
const COL_TEXT := Color.WHITE
const COL_DIM := Color(0.55, 0.55, 0.55)
const COL_HDR_TEXT := Color(0.72, 0.72, 0.72)
const COL_MONEY_G := Color(0.4, 0.9, 0.3)

const TDM_MAX_ROWS := 6
const TDM_TABLE_X := 82.0
const TDM_ROW_H := 28.0
const TDM_TEAM_Y := 68.0
const TDM_CX_NAME := 0.0;     const TDM_CW_NAME := 250.0
const TDM_CX_KILLS := 260.0;  const TDM_CW_KILLS := 60.0
const TDM_CX_DEATHS := 330.0; const TDM_CW_DEATHS := 60.0
const TDM_CX_ASSIST := 400.0; const TDM_CW_ASSIST := 60.0
const TDM_CX_KDR := 470.0;    const TDM_CW_KDR := 60.0
const TDM_CX_DMG := 540.0;    const TDM_CW_DMG := 70.0

var panel: Panel
var _hdr_mode: Label
var _hdr_time: Label
var _col_hdrs: Array[Label] = []
var _score_boxes := {}
var _score_labels := {}
var _team_name_labels := {}
var _rows := {}
var _middle: Control
var _half_labels: Array[Label] = []
var _round_markers: Array = []
var _loss_label: Label
var _fallback_label: Label
var _competitive_root: Control
var _fallback_root: Control
var _ffa_root: Control
var _ffa_hdr_mode: Label
var _ffa_hdr_time: Label
var _ffa_rows: Array = []
var _tdm_root: Control
var _tdm_hdr_mode: Label
var _tdm_hdr_time: Label
var _tdm_score_boxes := {}
var _tdm_score_labels := {}
var _tdm_rows := {}


func _ready() -> void:
	layer = 12
	_build_panel()
	_build_competitive()
	_build_ffa()
	_build_tdm()
	_build_fallback()
	panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		panel.visible = event.pressed
		if event.pressed:
			_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func update_mode(new_mode: StringName) -> void:
	mode = new_mode


func update_from_match_state(state: Dictionary) -> void:
	match_state = state.get("state", "WARMUP")
	round_number = state.get("round", 0)
	score_angels = state.get("score_angels", 0)
	score_demons = state.get("score_demons", 0)
	round_timer = state.get("timer", 0.0)
	attack_team = state.get("attack_team", 0)
	my_team = state.get("my_team", my_team)
	roster = state.get("roster", roster)
	round_history = state.get("round_history", round_history)
	loss_streak_angels = state.get("loss_streak_angels", 0)
	loss_streak_demons = state.get("loss_streak_demons", 0)


func _build_panel() -> void:
	panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)


func _build_competitive() -> void:
	_competitive_root = Control.new()
	_competitive_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_competitive_root)
	var root := _competitive_root

	var hdr_bg := _rect(COL_HDR_BG, Vector2(PANEL_W, HEADER_H))
	hdr_bg.position = Vector2.ZERO
	root.add_child(hdr_bg)

	_hdr_mode = _lbl(16, COL_TEXT)
	_hdr_mode.position = Vector2(12, 10)
	_hdr_mode.size = Vector2(400, 24)
	root.add_child(_hdr_mode)

	_hdr_time = _lbl(16, COL_DIM)
	_hdr_time.position = Vector2(PANEL_W - 200, 10)
	_hdr_time.size = Vector2(188, 24)
	_hdr_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_hdr_time)

	var col_names := ["Ping", "", "", "Money", "Kills", "Deaths", "Assists", "DMG"]
	var col_xs := [CX_PING, CX_COLOR, CX_NAME, CX_MONEY, CX_KILLS, CX_DEATHS, CX_ASSISTS, CX_DMG]
	var col_ws := [CW_PING, CW_COLOR, CW_NAME, CW_MONEY, CW_KILLS, CW_DEATHS, CW_ASSISTS, CW_DMG]
	for i in range(col_names.size()):
		if col_names[i] == "":
			_col_hdrs.append(null)
			continue
		var l := _lbl(11, COL_HDR_TEXT)
		l.text = col_names[i]
		l.position = Vector2(TABLE_X + col_xs[i], COL_HDR_Y)
		l.size = Vector2(col_ws[i], COL_HDR_H)
		if i >= 3:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
		_col_hdrs.append(l)

	_build_team_section(root, Team.Id.ANGELS, TEAM_Y)
	var demons_y := TEAM_Y + MAX_ROWS * ROW_H + GAP + MIDDLE_H + GAP
	_build_team_section(root, Team.Id.DEMONS, demons_y)
	_build_middle(root, TEAM_Y + MAX_ROWS * ROW_H + GAP)


func _build_team_section(root: Control, team: int, y: float) -> void:
	var box := _make_panel(Color.WHITE, Vector2(SCORE_BOX_W, SCORE_BOX_H))
	box.position = Vector2(SCORE_BOX_X, y)
	root.add_child(box)
	_score_boxes[team] = box

	var num := _lbl(44, Color(0.1, 0.1, 0.1))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.position = Vector2(0, 10)
	num.size = Vector2(SCORE_BOX_W, 70)
	box.add_child(num)
	_score_labels[team] = num

	var tname := _lbl(12, Color(0.1, 0.1, 0.1))
	tname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tname.position = Vector2(0, 85)
	tname.size = Vector2(SCORE_BOX_W, 18)
	tname.text = Team.get_team_name(team)
	box.add_child(tname)
	_team_name_labels[team] = tname

	_rows[team] = []
	for i in range(MAX_ROWS):
		var row_y := y + i * ROW_H
		var row_color: Color
		if team == Team.Id.ANGELS:
			row_color = COL_A_ROW if i % 2 == 0 else COL_A_ROW_ALT
		else:
			row_color = COL_D_ROW if i % 2 == 0 else COL_D_ROW_ALT
		var r := _build_row(root, row_y, row_color)
		_rows[team].append(r)


func _build_row(root: Control, y: float, bg_color: Color) -> Dictionary:
	var bg := _rect(bg_color, Vector2(PANEL_W - TABLE_X + 4, ROW_H))
	bg.position = Vector2(TABLE_X - 4, y)
	root.add_child(bg)

	var highlight := _rect(COL_LOCAL, Vector2(PANEL_W - TABLE_X + 4, ROW_H))
	highlight.position = Vector2(TABLE_X - 4, y)
	highlight.visible = false
	root.add_child(highlight)

	var ping := _lbl(12, COL_DIM)
	ping.position = Vector2(TABLE_X + CX_PING, y + 6)
	ping.size = Vector2(CW_PING, 16)
	root.add_child(ping)

	var color_sq := _rect(Color.WHITE, Vector2(CW_COLOR, CW_COLOR))
	color_sq.position = Vector2(TABLE_X + CX_COLOR, y + 6)
	root.add_child(color_sq)

	var name_lbl := _lbl(13, COL_TEXT)
	name_lbl.position = Vector2(TABLE_X + CX_NAME, y + 5)
	name_lbl.size = Vector2(CW_NAME, 18)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(name_lbl)

	var money := _lbl(12, COL_MONEY_G)
	money.position = Vector2(TABLE_X + CX_MONEY, y + 6)
	money.size = Vector2(CW_MONEY, 16)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(money)

	var kills := _stat_lbl(root, CX_KILLS, CW_KILLS, y)
	var deaths := _stat_lbl(root, CX_DEATHS, CW_DEATHS, y)
	var assists := _stat_lbl(root, CX_ASSISTS, CW_ASSISTS, y)
	var dmg := _stat_lbl(root, CX_DMG, CW_DMG, y)

	return {
		"bg": bg, "highlight": highlight, "ping": ping, "color": color_sq,
		"name": name_lbl, "money": money, "kills": kills, "deaths": deaths,
		"assists": assists, "dmg": dmg,
	}


func _stat_lbl(root: Control, cx: float, cw: float, y: float) -> Label:
	var l := _lbl(12, COL_TEXT)
	l.position = Vector2(TABLE_X + cx, y + 6)
	l.size = Vector2(cw, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return l


func _build_middle(root: Control, y: float) -> void:
	_middle = Control.new()
	_middle.position = Vector2(0, y)
	_middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_middle)

	var half_x := SCORE_BOX_X + 4
	var labels_text := ["1ST", "2ND"]
	for i in range(2):
		var l := _lbl(11, COL_DIM)
		l.position = Vector2(half_x + i * 36, 0)
		l.size = Vector2(32, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text = labels_text[i]
		_middle.add_child(l)
		_half_labels.append(l)

	for team_idx in range(2):
		var team: int = Team.Id.ANGELS if team_idx == 0 else Team.Id.DEMONS
		for half in range(2):
			var l := _lbl(13, Team.get_color(team))
			l.position = Vector2(half_x + half * 36, 16 + team_idx * 18)
			l.size = Vector2(32, 16)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.text = "0"
			_middle.add_child(l)
			_half_labels.append(l)

	var marker_x := TABLE_X + 30
	var marker_size := Vector2(18, 18)
	var marker_gap := 3.0
	for i in range(MAX_ROUND_MARKERS):
		var bg := _rect(Color(0.2, 0.2, 0.2, 0.5), marker_size)
		bg.position = Vector2(marker_x + i * (marker_size.x + marker_gap) + (8.0 if i >= 12 else 0.0), 18)
		bg.visible = false
		_middle.add_child(bg)
		var icon := RoundIconScene.new()
		icon.position = bg.position + Vector2(1, 1)
		icon.size = marker_size - Vector2(2, 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		_middle.add_child(icon)
		_round_markers.append({"bg": bg, "icon": icon})

	_loss_label = _lbl(11, COL_DIM)
	_loss_label.position = Vector2(PANEL_W - 140, 16)
	_loss_label.size = Vector2(130, 32)
	_loss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_middle.add_child(_loss_label)


func _build_ffa() -> void:
	_ffa_root = Control.new()
	_ffa_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_ffa_root)
	var root := _ffa_root

	var hdr_bg := _rect(COL_HDR_BG, Vector2(PANEL_W, HEADER_H))
	hdr_bg.position = Vector2.ZERO
	root.add_child(hdr_bg)

	_ffa_hdr_mode = _lbl(16, COL_TEXT)
	_ffa_hdr_mode.position = Vector2(12, 10)
	_ffa_hdr_mode.size = Vector2(400, 24)
	root.add_child(_ffa_hdr_mode)

	_ffa_hdr_time = _lbl(16, COL_DIM)
	_ffa_hdr_time.position = Vector2(PANEL_W - 200, 10)
	_ffa_hdr_time.size = Vector2(188, 24)
	_ffa_hdr_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_ffa_hdr_time)

	var col_names := ["#", "Name", "Kills", "Deaths", "Assists", "K/D", "DMG", "Score"]
	var col_xs := [FFA_CX_RANK, FFA_CX_NAME, FFA_CX_KILLS, FFA_CX_DEATHS,
		FFA_CX_ASSIST, FFA_CX_KDR, FFA_CX_DMG, FFA_CX_SCORE]
	var col_ws := [FFA_CW_RANK, FFA_CW_NAME, FFA_CW_KILLS, FFA_CW_DEATHS,
		FFA_CW_ASSIST, FFA_CW_KDR, FFA_CW_DMG, FFA_CW_SCORE]
	for i in range(col_names.size()):
		var l := _lbl(11, COL_HDR_TEXT)
		l.text = col_names[i]
		l.position = Vector2(FFA_TABLE_X + col_xs[i], FFA_HDR_Y)
		l.size = Vector2(col_ws[i], COL_HDR_H)
		if i >= 2:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)

	for i in range(FFA_MAX_ROWS):
		var row_y := FFA_BODY_Y + i * FFA_ROW_H
		var bg_color := COL_FFA_ROW if i % 2 == 0 else COL_FFA_ROW_ALT
		var r := _build_ffa_row(root, row_y, bg_color)
		_ffa_rows.append(r)


func _build_ffa_row(root: Control, y: float, bg_color: Color) -> Dictionary:
	var bg := _rect(bg_color, Vector2(PANEL_W - FFA_TABLE_X * 2, FFA_ROW_H))
	bg.position = Vector2(FFA_TABLE_X, y)
	root.add_child(bg)

	var highlight := _rect(COL_LOCAL, Vector2(PANEL_W - FFA_TABLE_X * 2, FFA_ROW_H))
	highlight.position = Vector2(FFA_TABLE_X, y)
	highlight.visible = false
	root.add_child(highlight)

	var rank := _lbl(12, COL_DIM)
	rank.position = Vector2(FFA_TABLE_X + FFA_CX_RANK, y + 5)
	rank.size = Vector2(FFA_CW_RANK, 16)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(rank)

	var name_lbl := _lbl(13, COL_TEXT)
	name_lbl.position = Vector2(FFA_TABLE_X + FFA_CX_NAME, y + 4)
	name_lbl.size = Vector2(FFA_CW_NAME, 18)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(name_lbl)

	var kills := _ffa_stat(root, FFA_CX_KILLS, FFA_CW_KILLS, y)
	var deaths := _ffa_stat(root, FFA_CX_DEATHS, FFA_CW_DEATHS, y)
	var assists := _ffa_stat(root, FFA_CX_ASSIST, FFA_CW_ASSIST, y)
	var kdr := _ffa_stat(root, FFA_CX_KDR, FFA_CW_KDR, y)
	var dmg := _ffa_stat(root, FFA_CX_DMG, FFA_CW_DMG, y)
	var score := _ffa_stat(root, FFA_CX_SCORE, FFA_CW_SCORE, y)

	return {
		"bg": bg, "highlight": highlight, "rank": rank, "name": name_lbl,
		"kills": kills, "deaths": deaths, "assists": assists,
		"kdr": kdr, "dmg": dmg, "score": score,
	}


func _ffa_stat(root: Control, cx: float, cw: float, y: float) -> Label:
	var l := _lbl(12, COL_TEXT)
	l.position = Vector2(FFA_TABLE_X + cx, y + 5)
	l.size = Vector2(cw, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return l


func _refresh_ffa() -> void:
	_ffa_hdr_mode.text = "Deathmatch | Map"
	_ffa_hdr_time.text = match_state

	var sorted := roster.duplicate()
	sorted.sort_custom(func(a, b): return a.get("kills", 0) > b.get("kills", 0))

	var local_ping := _get_local_ping()
	for i in range(FFA_MAX_ROWS):
		var r: Dictionary = _ffa_rows[i]
		if i < sorted.size():
			var entry: Dictionary = sorted[i]
			var pid: int = entry.get("id", 0)
			var is_local := pid == my_peer_id
			var k: int = entry.get("kills", 0)
			var d: int = entry.get("deaths", 0)

			r["bg"].visible = true
			r["highlight"].visible = is_local
			r["rank"].text = str(i + 1)
			r["rank"].visible = true
			r["name"].text = "Player %d" % pid
			if is_local:
				r["name"].add_theme_color_override("font_color", Color(0.95, 0.88, 0.3))
			else:
				r["name"].add_theme_color_override("font_color", COL_TEXT)
			r["name"].visible = true
			r["kills"].text = str(k)
			r["deaths"].text = str(d)
			r["assists"].text = str(entry.get("assists", 0))
			r["kdr"].text = "%.1f" % (float(k) / maxf(float(d), 1.0))
			r["dmg"].text = str(entry.get("damage", 0))
			r["score"].text = str(k)
			r["kills"].visible = true
			r["deaths"].visible = true
			r["assists"].visible = true
			r["kdr"].visible = true
			r["dmg"].visible = true
			r["score"].visible = true
		else:
			r["bg"].visible = false
			r["highlight"].visible = false
			r["rank"].visible = false
			r["name"].visible = false
			r["kills"].visible = false
			r["deaths"].visible = false
			r["assists"].visible = false
			r["kdr"].visible = false
			r["dmg"].visible = false
			r["score"].visible = false


func _build_tdm() -> void:
	_tdm_root = Control.new()
	_tdm_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_tdm_root)
	var root := _tdm_root

	var hdr_bg := _rect(COL_HDR_BG, Vector2(PANEL_W, HEADER_H))
	hdr_bg.position = Vector2.ZERO
	root.add_child(hdr_bg)

	_tdm_hdr_mode = _lbl(16, COL_TEXT)
	_tdm_hdr_mode.position = Vector2(12, 10)
	_tdm_hdr_mode.size = Vector2(400, 24)
	root.add_child(_tdm_hdr_mode)

	_tdm_hdr_time = _lbl(16, COL_DIM)
	_tdm_hdr_time.position = Vector2(PANEL_W - 200, 10)
	_tdm_hdr_time.size = Vector2(188, 24)
	_tdm_hdr_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_tdm_hdr_time)

	var col_names := ["Name", "Kills", "Deaths", "Assists", "K/D", "DMG"]
	var col_xs := [TDM_CX_NAME, TDM_CX_KILLS, TDM_CX_DEATHS,
		TDM_CX_ASSIST, TDM_CX_KDR, TDM_CX_DMG]
	var col_ws := [TDM_CW_NAME, TDM_CW_KILLS, TDM_CW_DEATHS,
		TDM_CW_ASSIST, TDM_CW_KDR, TDM_CW_DMG]
	for i in range(col_names.size()):
		var l := _lbl(11, COL_HDR_TEXT)
		l.text = col_names[i]
		l.position = Vector2(TDM_TABLE_X + col_xs[i], COL_HDR_Y)
		l.size = Vector2(col_ws[i], COL_HDR_H)
		if i >= 1:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)

	for team in [Team.Id.ANGELS, Team.Id.DEMONS]:
		var section_y: float
		if team == Team.Id.ANGELS:
			section_y = TDM_TEAM_Y
		else:
			section_y = TDM_TEAM_Y + TDM_MAX_ROWS * TDM_ROW_H + GAP
		_build_tdm_team(root, team, section_y)


func _build_tdm_team(root: Control, team: int, y: float) -> void:
	var box := _make_panel(Color.WHITE, Vector2(SCORE_BOX_W, TDM_MAX_ROWS * TDM_ROW_H))
	box.position = Vector2(SCORE_BOX_X, y)
	root.add_child(box)
	_tdm_score_boxes[team] = box

	var num := _lbl(36, Color(0.1, 0.1, 0.1))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.position = Vector2(0, 10)
	num.size = Vector2(SCORE_BOX_W, 60)
	box.add_child(num)
	_tdm_score_labels[team] = num

	var tname := _lbl(11, Color(0.1, 0.1, 0.1))
	tname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tname.position = Vector2(0, 75)
	tname.size = Vector2(SCORE_BOX_W, 16)
	tname.text = Team.get_team_name(team)
	box.add_child(tname)

	_tdm_rows[team] = []
	for i in range(TDM_MAX_ROWS):
		var row_y := y + i * TDM_ROW_H
		var row_color: Color
		if team == Team.Id.ANGELS:
			row_color = COL_A_ROW if i % 2 == 0 else COL_A_ROW_ALT
		else:
			row_color = COL_D_ROW if i % 2 == 0 else COL_D_ROW_ALT
		var r := _build_tdm_row(root, row_y, row_color)
		_tdm_rows[team].append(r)


func _build_tdm_row(root: Control, y: float, bg_color: Color) -> Dictionary:
	var bg := _rect(bg_color, Vector2(PANEL_W - TDM_TABLE_X + 4, TDM_ROW_H))
	bg.position = Vector2(TDM_TABLE_X - 4, y)
	root.add_child(bg)

	var highlight := _rect(COL_LOCAL, Vector2(PANEL_W - TDM_TABLE_X + 4, TDM_ROW_H))
	highlight.position = Vector2(TDM_TABLE_X - 4, y)
	highlight.visible = false
	root.add_child(highlight)

	var name_lbl := _lbl(13, COL_TEXT)
	name_lbl.position = Vector2(TDM_TABLE_X + TDM_CX_NAME, y + 5)
	name_lbl.size = Vector2(TDM_CW_NAME, 18)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(name_lbl)

	var kills := _tdm_stat(root, TDM_CX_KILLS, TDM_CW_KILLS, y)
	var deaths := _tdm_stat(root, TDM_CX_DEATHS, TDM_CW_DEATHS, y)
	var assists := _tdm_stat(root, TDM_CX_ASSIST, TDM_CW_ASSIST, y)
	var kdr := _tdm_stat(root, TDM_CX_KDR, TDM_CW_KDR, y)
	var dmg := _tdm_stat(root, TDM_CX_DMG, TDM_CW_DMG, y)

	return {
		"bg": bg, "highlight": highlight, "name": name_lbl,
		"kills": kills, "deaths": deaths, "assists": assists,
		"kdr": kdr, "dmg": dmg,
	}


func _tdm_stat(root: Control, cx: float, cw: float, y: float) -> Label:
	var l := _lbl(12, COL_TEXT)
	l.position = Vector2(TDM_TABLE_X + cx, y + 6)
	l.size = Vector2(cw, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return l


func _build_fallback() -> void:
	_fallback_root = Control.new()
	_fallback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_fallback_root)

	_fallback_label = _lbl(14, COL_TEXT)
	_fallback_label.position = Vector2(20, 20)
	_fallback_label.size = Vector2(PANEL_W - 40, 400)
	_fallback_root.add_child(_fallback_label)


func _refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1920, 1080)

	_competitive_root.visible = false
	_ffa_root.visible = false
	_tdm_root.visible = false
	_fallback_root.visible = false

	if mode == &"competitive":
		_competitive_root.visible = true
		var ph := TEAM_Y + MAX_ROWS * ROW_H + GAP + MIDDLE_H + GAP + MAX_ROWS * ROW_H + GAP
		panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - ph) * 0.5)
		panel.size = Vector2(PANEL_W, ph)
		_refresh_competitive()
	elif mode == &"deathmatch":
		_ffa_root.visible = true
		var ph := FFA_BODY_Y + FFA_MAX_ROWS * FFA_ROW_H + GAP
		panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - ph) * 0.5)
		panel.size = Vector2(PANEL_W, ph)
		_refresh_ffa()
	elif mode == &"team_deathmatch":
		_tdm_root.visible = true
		var ph := TDM_TEAM_Y + TDM_MAX_ROWS * TDM_ROW_H + GAP + TDM_MAX_ROWS * TDM_ROW_H + GAP
		panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - ph) * 0.5)
		panel.size = Vector2(PANEL_W, ph)
		_refresh_tdm()
	else:
		_fallback_root.visible = true
		var ph := 360.0
		panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - ph) * 0.5)
		panel.size = Vector2(PANEL_W, ph)
		_refresh_fallback()


func _refresh_competitive() -> void:
	_hdr_mode.text = "Competitive | Map"
	_hdr_time.text = "Round %d  •  %s" % [round_number, match_state]

	_score_labels[Team.Id.ANGELS].text = str(score_angels)
	_score_labels[Team.Id.DEMONS].text = str(score_demons)

	var angels_roster := _get_sorted_team_roster(Team.Id.ANGELS)
	var demons_roster := _get_sorted_team_roster(Team.Id.DEMONS)

	_fill_rows(Team.Id.ANGELS, angels_roster)
	_fill_rows(Team.Id.DEMONS, demons_roster)
	_refresh_round_history()
	_refresh_loss_bonus()


func _get_sorted_team_roster(team: int) -> Array:
	var result: Array = []
	for entry in roster:
		if entry.get("team", 0) == team:
			result.append(entry)
	result.sort_custom(func(a, b): return a.get("kills", 0) > b.get("kills", 0))
	return result


func _fill_rows(team: int, team_roster: Array) -> void:
	var rows: Array = _rows[team]
	var local_ping := _get_local_ping()
	for i in range(MAX_ROWS):
		var r: Dictionary = rows[i]
		if i < team_roster.size():
			var entry: Dictionary = team_roster[i]
			var pid: int = entry.get("id", 0)
			var color_idx: int = entry.get("color", 0)
			var is_local := pid == my_peer_id

			r["bg"].visible = true
			r["highlight"].visible = is_local
			r["ping"].text = "%d" % local_ping if is_local else "---"
			r["color"].color = Team.get_player_color(color_idx)
			r["color"].visible = true
			r["name"].text = "Player %d" % pid
			if is_local:
				r["name"].add_theme_color_override("font_color", Color(0.95, 0.88, 0.3))
			else:
				r["name"].add_theme_color_override("font_color", COL_TEXT)
			r["name"].visible = true

			if team == my_team:
				r["money"].text = "$%d" % entry.get("money", 0)
				r["money"].visible = true
			else:
				r["money"].text = ""
				r["money"].visible = false

			r["kills"].text = str(entry.get("kills", 0))
			r["deaths"].text = str(entry.get("deaths", 0))
			r["assists"].text = str(entry.get("assists", 0))
			r["dmg"].text = str(entry.get("damage", 0))
			r["kills"].visible = true
			r["deaths"].visible = true
			r["assists"].visible = true
			r["dmg"].visible = true
		else:
			r["bg"].visible = false
			r["highlight"].visible = false
			r["ping"].text = ""
			r["color"].visible = false
			r["name"].visible = false
			r["money"].visible = false
			r["kills"].visible = false
			r["deaths"].visible = false
			r["assists"].visible = false
			r["dmg"].visible = false


func _refresh_round_history() -> void:
	var first_a := 0; var first_d := 0
	var second_a := 0; var second_d := 0
	for i in range(round_history.size()):
		var entry: Dictionary = round_history[i]
		var winner: int = entry.get("winner", 0)
		if i < 12:
			if winner == Team.Id.ANGELS: first_a += 1
			elif winner == Team.Id.DEMONS: first_d += 1
		else:
			if winner == Team.Id.ANGELS: second_a += 1
			elif winner == Team.Id.DEMONS: second_d += 1

	if _half_labels.size() >= 6:
		_half_labels[2].text = str(first_a)
		_half_labels[3].text = str(second_a)
		_half_labels[4].text = str(first_d)
		_half_labels[5].text = str(second_d)

	for i in range(MAX_ROUND_MARKERS):
		var m: Dictionary = _round_markers[i]
		if i < round_history.size():
			var entry: Dictionary = round_history[i]
			var winner: int = entry.get("winner", 0)
			var reason: String = entry.get("reason", "")
			m["bg"].color = Team.get_color(winner) if Team.is_playing_team(winner) else COL_DIM
			m["bg"].visible = true
			m["icon"].set_icon(reason, COL_TEXT)
			m["icon"].visible = true
		else:
			m["bg"].visible = false
			m["icon"].visible = false


func _refresh_loss_bonus() -> void:
	var my_streak: int
	if my_team == Team.Id.ANGELS:
		my_streak = loss_streak_angels
	else:
		my_streak = loss_streak_demons
	if my_streak > 0:
		var bonus := Economy.get_loss_bonus(my_streak)
		_loss_label.text = "Loss Bonus\n$%d (%d)" % [bonus, my_streak]
	else:
		_loss_label.text = ""


func _refresh_tdm() -> void:
	_tdm_hdr_mode.text = "Team Deathmatch | Map"
	_tdm_hdr_time.text = match_state

	_tdm_score_labels[Team.Id.ANGELS].text = str(score_angels)
	_tdm_score_labels[Team.Id.DEMONS].text = str(score_demons)

	var angels := _get_sorted_team_roster(Team.Id.ANGELS)
	var demons := _get_sorted_team_roster(Team.Id.DEMONS)
	_fill_tdm_rows(Team.Id.ANGELS, angels)
	_fill_tdm_rows(Team.Id.DEMONS, demons)


func _fill_tdm_rows(team: int, team_roster: Array) -> void:
	var rows: Array = _tdm_rows[team]
	for i in range(TDM_MAX_ROWS):
		var r: Dictionary = rows[i]
		if i < team_roster.size():
			var entry: Dictionary = team_roster[i]
			var pid: int = entry.get("id", 0)
			var is_local := pid == my_peer_id
			var k: int = entry.get("kills", 0)
			var d: int = entry.get("deaths", 0)

			r["bg"].visible = true
			r["highlight"].visible = is_local
			r["name"].text = "Player %d" % pid
			if is_local:
				r["name"].add_theme_color_override("font_color", Color(0.95, 0.88, 0.3))
			else:
				r["name"].add_theme_color_override("font_color", COL_TEXT)
			r["name"].visible = true
			r["kills"].text = str(k)
			r["deaths"].text = str(d)
			r["assists"].text = str(entry.get("assists", 0))
			r["kdr"].text = "%.1f" % (float(k) / maxf(float(d), 1.0))
			r["dmg"].text = str(entry.get("damage", 0))
			r["kills"].visible = true
			r["deaths"].visible = true
			r["assists"].visible = true
			r["kdr"].visible = true
			r["dmg"].visible = true
		else:
			r["bg"].visible = false
			r["highlight"].visible = false
			r["name"].visible = false
			r["kills"].visible = false
			r["deaths"].visible = false
			r["assists"].visible = false
			r["kdr"].visible = false
			r["dmg"].visible = false


func _refresh_fallback() -> void:
	var cg := get_tree().get_first_node_in_group("client_game")
	if not cg:
		_fallback_label.text = "Not connected"
		return

	var known: Dictionary = {}
	if cg.snapshot_buffer.size() > 0:
		var latest: Dictionary = cg.snapshot_buffer[cg.snapshot_buffer.size() - 1]
		for s in latest["states"]:
			known[s.peer_id] = true
	for pid in cg.player_stats:
		known[pid] = true
	if cg.my_peer_id > 0:
		known[cg.my_peer_id] = true

	var entries: Array = []
	for pid in known:
		var stats: Dictionary = cg.player_stats.get(pid, {})
		entries.append({
			"peer_id": pid,
			"kills": stats.get("kills", 0),
			"deaths": stats.get("deaths", 0),
		})
	entries.sort_custom(func(a, b): return a["kills"] > b["kills"])

	var local_ping := _get_local_ping()
	var text := "%-18s %6s %6s %6s %8s\n" % ["Player", "Kills", "Deaths", "K/D", "Ping"]
	text += "—".repeat(50) + "\n"
	for entry in entries:
		var pid: int = entry["peer_id"]
		var k: int = entry["kills"]
		var d: int = entry["deaths"]
		var kd := "%.1f" % (float(k) / maxf(float(d), 1.0))
		var ping := "%d ms" % local_ping if pid == cg.my_peer_id else "---"
		var name_str := "Player %d" % pid
		if pid == cg.my_peer_id:
			name_str += " *"
		text += "%-18s %6d %6d %6s %8s\n" % [name_str, k, d, kd, ping]
	_fallback_label.text = text


func _get_local_ping() -> int:
	if not NetworkManager.peer:
		return 0
	var server_peer := NetworkManager.peer.get_peer(1)
	if server_peer:
		return int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return 0


func _lbl(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rect(color: Color, sz: Vector2) -> ColorRect:
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
