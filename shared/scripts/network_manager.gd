extends Node

signal connection_succeeded
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const DEFAULT_PORT := 27050
const MAX_CLIENTS := 16

var peer: ENetMultiplayerPeer
var last_server_address: String = ""
var last_server_port: int = DEFAULT_PORT
var loading_map_name: String = ""
var current_map_path: String = "res://shared/scenes/map_dm_aim.tscn"


func _ready() -> void:
	multiplayer.peer_packet.connect(_on_raw_peer_packet)


func _on_raw_peer_packet(_peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < 5:
		return
	if packet[0] != NetConstants.PROTOCOL_VERSION:
		return
	if packet[1] != NetProtocol.MSG_EVENT:
		return
	if packet[2] != NetProtocol.EVT_MAP_CHANGE:
		return
	var name_len := packet[3] | (packet[4] << 8)
	if packet.size() < 5 + name_len:
		return
	var map_name := packet.slice(5, 5 + name_len).get_string_from_utf8()
	var map_path := MapRegistry.get_scene_path(map_name)
	if not map_path.is_empty():
		current_map_path = map_path
		loading_map_name = map_name


func host_server(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create server on port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Server listening on port %d" % port)
	return OK

func join_server(address: String, port: int = DEFAULT_PORT) -> Error:
	last_server_address = address
	last_server_port = port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Failed to create client: %s" % error_string(err))
		connection_failed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK

func disconnect_from_server() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		peer = null
		print("Disconnected")

func _on_connected_to_server() -> void:
	print("Connected to server (peer ID: %d)" % multiplayer.get_unique_id())
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("Connection failed")
	peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected")
	peer = null
	server_disconnected.emit()

func _on_peer_connected(id: int) -> void:
	print("Peer connected: %d" % id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: %d" % id)
	peer_disconnected.emit(id)
