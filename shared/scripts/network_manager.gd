extends Node

signal connection_succeeded
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const DEFAULT_PORT := 27050
const MAX_CLIENTS := 16

var peer: ENetMultiplayerPeer

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
