extends Node

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTIONS := [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless"]

var resolution_index: int = 1
var window_mode: int = 0
var vsync_enabled: bool = false
var mouse_sensitivity: float = 0.002


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	resolution_index = cfg.get_value("video", "resolution_index", 1)
	window_mode = cfg.get_value("video", "window_mode", 0)
	vsync_enabled = cfg.get_value("video", "vsync", false)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 0.002)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution_index", resolution_index)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "vsync", vsync_enabled)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(SETTINGS_PATH)


func apply_all() -> void:
	apply_window_mode()
	apply_resolution()
	apply_vsync()


func apply_resolution() -> void:
	var res: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = res


func apply_window_mode() -> void:
	match window_mode:
		0:
			get_window().mode = Window.MODE_WINDOWED
		1:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			get_window().mode = Window.MODE_FULLSCREEN


func apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
