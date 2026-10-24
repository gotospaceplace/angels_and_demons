extends Node

func _ready() -> void:
	var is_server := OS.has_feature("dedicated_server")
	print("EntryPoint: dedicated_server=%s" % is_server)
	if is_server:
		get_tree().change_scene_to_file.call_deferred("res://server/scenes/server_main.tscn")
	else:
		get_tree().change_scene_to_file.call_deferred("res://client/scenes/main_menu.tscn")
