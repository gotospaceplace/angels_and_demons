class_name ClientBuyMenu
extends CanvasLayer

signal buy_requested(item_index: int)
signal weapon_requested(item_index: int)

var is_open: bool = false
var money: int = 800
var team: int = 0
var attack_team: int = 0
var current_weapon_idx: int = 0
var current_armor: int = 0

var _overlay: ColorRect
var _panel: PanelContainer
var _money_label: Label
var _category_buttons: Dictionary = {}
var _items_container: VBoxContainer
var _request_label: Label
var _request_timer: float = 0.0
var _selected_category: StringName = &"rifles"
var _item_rows: Array = []


func _ready() -> void:
	layer = 15
	_build_ui()
	visible = false


func _process(delta: float) -> void:
	if _request_timer > 0.0:
		_request_timer -= delta
		if _request_timer <= 0.0:
			_request_label.text = ""
			_request_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("buy_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx := event.keycode - KEY_1
			_quick_buy(idx)
			get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_items()


func close_menu() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update_money(new_money: int) -> void:
	money = new_money
	if _money_label:
		_money_label.text = "$%d" % money
	if is_open:
		_refresh_items()


func update_state(p_team: int, p_attack_team: int, p_weapon_idx: int, p_armor: int) -> void:
	team = p_team
	attack_team = p_attack_team
	current_weapon_idx = p_weapon_idx
	current_armor = p_armor
	if is_open:
		_refresh_items()


func show_request(requester_id: int, item_index: int) -> void:
	var item := BuyCatalog.get_item(item_index)
	if item.is_empty():
		return
	_request_label.text = "Player %d requests %s ($%d)" % [
		requester_id, item["name"], item["price"]]
	_request_label.visible = true
	_request_timer = 8.0


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_overlay)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(700, 500)
	center.add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(main_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "BUY MENU"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_money_label = Label.new()
	_money_label.text = "$%d" % money
	_money_label.add_theme_font_size_override("font_size", 28)
	_money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_money_label)

	# Category tabs
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tab_bar)

	for cat in BuyCatalog.CATEGORIES:
		var btn := Button.new()
		btn.text = BuyCatalog.CATEGORY_NAMES[cat]
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_category_pressed.bind(cat))
		_category_buttons[cat] = btn
		tab_bar.add_child(btn)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	main_vbox.add_child(sep)

	# Items area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 8)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_container)

	# Request notification
	_request_label = Label.new()
	_request_label.add_theme_font_size_override("font_size", 16)
	_request_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_request_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_request_label.visible = false
	main_vbox.add_child(_request_label)

	# Footer
	var footer := Label.new()
	footer.text = "Press B or ESC to close  |  Number keys to quick-buy"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(footer)

	_update_tab_styles()


func _on_category_pressed(category: StringName) -> void:
	_selected_category = category
	_update_tab_styles()
	_refresh_items()


func _update_tab_styles() -> void:
	for cat in _category_buttons:
		var btn: Button = _category_buttons[cat]
		if cat == _selected_category:
			var active := StyleBoxFlat.new()
			active.bg_color = Color(0.25, 0.25, 0.4)
			active.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", active)
			btn.add_theme_stylebox_override("hover", active)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			var inactive := StyleBoxFlat.new()
			inactive.bg_color = Color(0.12, 0.12, 0.18)
			inactive.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", inactive)
			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.18, 0.18, 0.28)
			hover.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))


func _refresh_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()
	_item_rows.clear()

	var items := BuyCatalog.get_items_for_category(_selected_category)
	for entry in items:
		var idx: int = entry["index"]
		var data: Dictionary = entry["data"]
		var card := _create_item_card(idx, data)
		_items_container.add_child(card)
		_item_rows.append({"index": idx, "card": card})


func _create_item_card(item_index: int, data: Dictionary) -> PanelContainer:
	var check := BuyCatalog.can_buy(item_index, money, team, attack_team,
		current_weapon_idx, current_armor)
	var can_afford: bool = check["ok"]
	var reason: String = check["reason"]

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.18) if can_afford else Color(0.08, 0.08, 0.1)
	card_style.border_color = Color(0.25, 0.25, 0.35) if can_afford else Color(0.15, 0.15, 0.2)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(12)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	# Item info (left side)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	var name_color := Color(0.9, 0.9, 0.95) if can_afford else Color(0.4, 0.4, 0.45)
	name_label.add_theme_color_override("font_color", name_color)
	info.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "$%d" % data["price"]
	price_label.add_theme_font_size_override("font_size", 16)
	var price_color := Color(0.4, 0.85, 0.4) if can_afford else Color(0.5, 0.3, 0.3)
	price_label.add_theme_color_override("font_color", price_color)
	info.add_child(price_label)

	if not can_afford and reason != "":
		var reason_label := Label.new()
		reason_label.text = reason
		reason_label.add_theme_font_size_override("font_size", 12)
		reason_label.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
		info.add_child(reason_label)

	# Buttons (right side)
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	hbox.add_child(btn_box)

	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(80, 32)
	buy_btn.disabled = not can_afford
	buy_btn.pressed.connect(_on_buy_pressed.bind(item_index))
	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = Color(0.2, 0.5, 0.3) if can_afford else Color(0.15, 0.15, 0.2)
	buy_style.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", buy_style)
	var buy_hover := StyleBoxFlat.new()
	buy_hover.bg_color = Color(0.25, 0.6, 0.35)
	buy_hover.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("hover", buy_hover)
	btn_box.add_child(buy_btn)

	var req_btn := Button.new()
	req_btn.text = "REQUEST"
	req_btn.custom_minimum_size = Vector2(80, 28)
	req_btn.add_theme_font_size_override("font_size", 12)
	req_btn.pressed.connect(_on_request_pressed.bind(item_index))
	var req_style := StyleBoxFlat.new()
	req_style.bg_color = Color(0.15, 0.15, 0.25)
	req_style.set_corner_radius_all(4)
	req_btn.add_theme_stylebox_override("normal", req_style)
	var req_hover := StyleBoxFlat.new()
	req_hover.bg_color = Color(0.2, 0.2, 0.35)
	req_hover.set_corner_radius_all(4)
	req_btn.add_theme_stylebox_override("hover", req_hover)
	btn_box.add_child(req_btn)

	return card


func _on_buy_pressed(item_index: int) -> void:
	buy_requested.emit(item_index)


func _on_request_pressed(item_index: int) -> void:
	weapon_requested.emit(item_index)


func _quick_buy(category_index: int) -> void:
	if category_index >= _item_rows.size():
		return
	var idx: int = _item_rows[category_index]["index"]
	buy_requested.emit(idx)
