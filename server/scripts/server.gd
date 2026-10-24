extends Node

func _ready() -> void:
	var port := DEFAULT_PORT
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()

	var err := NetworkManager.host_server(port)
	if err != OK:
		push_error("Server failed to start")
		get_tree().quit(1)
		return

	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	print("Angels and Demons dedicated server running")

const DEFAULT_PORT := 27050

func _on_peer_connected(peer_id: int) -> void:
	print("[Server] Player joined — peer ID: %d (total: %d)" % [
		peer_id,
		multiplayer.get_peers().size()
	])

func _on_peer_disconnected(peer_id: int) -> void:
	print("[Server] Player left — peer ID: %d (total: %d)" % [
		peer_id,
		multiplayer.get_peers().size()
	])
