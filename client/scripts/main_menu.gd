extends Control

@onready var ip_input: LineEdit = $CenterContainer/VBox/IPInput
@onready var port_input: LineEdit = $CenterContainer/VBox/PortInput
@onready var connect_button: Button = $CenterContainer/VBox/ConnectButton
@onready var status_label: Label = $CenterContainer/VBox/StatusLabel

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

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
