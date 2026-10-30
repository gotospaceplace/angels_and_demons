extends Control

@onready var menu_panel: CenterContainer = $MenuPanel
@onready var connect_panel: CenterContainer = $ConnectPanel
@onready var options_panel: CenterContainer = $OptionsPanel
@onready var find_servers_btn: Button = $MenuPanel/VBox/FindServersButton
@onready var options_btn: Button = $MenuPanel/VBox/OptionsButton
@onready var quit_btn: Button = $MenuPanel/VBox/QuitButton
@onready var ip_input: LineEdit = $ConnectPanel/VBox/IPInput
@onready var port_input: LineEdit = $ConnectPanel/VBox/PortInput
@onready var connect_button: Button = $ConnectPanel/VBox/ConnectButton
@onready var status_label: Label = $ConnectPanel/VBox/StatusLabel
@onready var back_button: Button = $ConnectPanel/VBox/BackButton

var resolution_option: OptionButton
var window_mode_option: OptionButton
var vsync_check: CheckButton
var sensitivity_slider: HSlider
var sensitivity_value: Label


func _ready() -> void:
	find_servers_btn.pressed.connect(_on_find_servers)
	options_btn.pressed.connect(_on_options)
	quit_btn.pressed.connect(_on_quit)
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	_build_options_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if connect_panel.visible:
			_on_back()
		elif options_panel.visible:
			_on_options_back()


# --- Panel navigation ---

func _on_find_servers() -> void:
	menu_panel.visible = false
	connect_panel.visible = true
	status_label.text = ""


func _on_options() -> void:
	menu_panel.visible = false
	options_panel.visible = true
	_load_options_state()


func _on_quit() -> void:
	get_tree().quit()


func _on_back() -> void:
	connect_panel.visible = false
	menu_panel.visible = true
	NetworkManager.disconnect_from_server()
	connect_button.disabled = false
	status_label.text = ""


func _on_options_back() -> void:
	options_panel.visible = false
	menu_panel.visible = true


# --- Connect ---

func _on_connect_pressed() -> void:
	var address := ip_input.text.strip_edges()
	var port := port_input.text.strip_edges().to_int()
	if address.is_empty():
		status_label.text = "Enter a server address"
		return
	if port <= 0 or port > 65535:
		status_label.text = "Enter a valid port (1-65535)"
		return

	status_label.text = "Connecting to %s:%d..." % [address, port]
	connect_button.disabled = true

	var err := NetworkManager.join_server(address, port)
	if err != OK:
		status_label.text = "Failed to start connection"
		connect_button.disabled = false


func _on_connected() -> void:
	status_label.text = "Connected! (Peer ID: %d)" % multiplayer.get_unique_id()
	get_tree().change_scene_to_file("res://client/scenes/main.tscn")


func _on_connection_failed() -> void:
	status_label.text = "Connection failed — check address and port"
	connect_button.disabled = false


func _on_server_disconnected() -> void:
	status_label.text = "Lost connection to server"
	connect_button.disabled = false


# --- Options UI ---

func _build_options_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	options_panel.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(10))

	# --- Video section ---
	vbox.add_child(_section_label("VIDEO"))

	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(200, 0)
	for res in GameSettings.RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [res.x, res.y])
	vbox.add_child(_setting_row("Resolution", resolution_option))

	window_mode_option = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(200, 0)
	for mode_name in GameSettings.WINDOW_MODES:
		window_mode_option.add_item(mode_name)
	vbox.add_child(_setting_row("Window Mode", window_mode_option))

	vsync_check = CheckButton.new()
	vsync_check.text = "Enabled"
	vbox.add_child(_setting_row("VSync", vsync_check))

	vbox.add_child(_spacer(6))

	# --- Controls section ---
	vbox.add_child(_section_label("CONTROLS"))

	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	var sens_label := Label.new()
	sens_label.text = "Mouse Sensitivity"
	sens_label.custom_minimum_size = Vector2(160, 0)
	sens_row.add_child(sens_label)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.5
	sensitivity_slider.max_value = 5.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.custom_minimum_size = Vector2(180, 0)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	sens_row.add_child(sensitivity_slider)

	sensitivity_value = Label.new()
	sensitivity_value.custom_minimum_size = Vector2(40, 0)
	sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sens_row.add_child(sensitivity_value)
	vbox.add_child(sens_row)

	vbox.add_child(_spacer(16))

	# --- Buttons ---
	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(300, 40)
	apply_btn.pressed.connect(_on_options_apply)
	vbox.add_child(apply_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 40)
	back_btn.pressed.connect(_on_options_back)
	vbox.add_child(back_btn)


func _load_options_state() -> void:
	resolution_option.selected = GameSettings.resolution_index
	window_mode_option.selected = GameSettings.window_mode
	vsync_check.button_pressed = GameSettings.vsync_enabled
	var sens_display := GameSettings.mouse_sensitivity / 0.001
	sensitivity_slider.value = sens_display
	sensitivity_value.text = "%.1f" % sens_display


func _on_sensitivity_changed(value: float) -> void:
	sensitivity_value.text = "%.1f" % value


func _on_options_apply() -> void:
	GameSettings.resolution_index = resolution_option.selected
	GameSettings.window_mode = window_mode_option.selected
	GameSettings.vsync_enabled = vsync_check.button_pressed
	GameSettings.mouse_sensitivity = sensitivity_slider.value * 0.001
	GameSettings.save_settings()
	GameSettings.apply_all()


# --- Helpers ---

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
