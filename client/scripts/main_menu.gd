extends Control

@onready var menu_panel: CenterContainer = $MenuPanel
@onready var connect_panel: CenterContainer = $ConnectPanel
@onready var find_servers_btn: Button = $MenuPanel/VBox/FindServersButton
@onready var options_btn: Button = $MenuPanel/VBox/OptionsButton
@onready var quit_btn: Button = $MenuPanel/VBox/QuitButton
@onready var ip_input: LineEdit = $ConnectPanel/VBox/IPInput
@onready var port_input: LineEdit = $ConnectPanel/VBox/PortInput
@onready var connect_button: Button = $ConnectPanel/VBox/ConnectButton
@onready var status_label: Label = $ConnectPanel/VBox/StatusLabel
@onready var back_button: Button = $ConnectPanel/VBox/BackButton


func _ready() -> void:
	find_servers_btn.pressed.connect(_on_find_servers)
	options_btn.pressed.connect(_on_options)
	quit_btn.pressed.connect(_on_quit)
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if connect_panel.visible:
			_on_back()


func _on_find_servers() -> void:
	menu_panel.visible = false
	connect_panel.visible = true
	status_label.text = ""


func _on_options() -> void:
	pass


func _on_quit() -> void:
	get_tree().quit()


func _on_back() -> void:
	connect_panel.visible = false
	menu_panel.visible = true
	NetworkManager.disconnect_from_server()
	connect_button.disabled = false
	status_label.text = ""


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
