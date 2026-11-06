extends Node

var _flash: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.6)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.visible = false
	root.add_child(_flash)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		_take_screenshot()
		get_viewport().set_input_as_handled()


func _take_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	if not image:
		return

	var dir_path := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/screenshot_%s.png" % [dir_path, timestamp]
	var err := image.save_png(file_path)
	if err == OK:
		print("[Screenshot] Saved: %s" % file_path)
		_show_flash()
	else:
		print("[Screenshot] Failed to save: %s" % error_string(err))


func _show_flash() -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_flash.set_visible.bind(false))
