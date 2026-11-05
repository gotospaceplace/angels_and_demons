extends Control

const TARGET_SCENE := "res://client/scenes/mp_client.tscn"

@onready var progress_bar: ProgressBar = $ContentCenter/VBox/ProgressBar
@onready var status_label: Label = $ContentCenter/VBox/StatusLabel
@onready var map_label: Label = $ContentCenter/VBox/MapName

var _load_started: bool = false
var _min_display_time := 1.5
var _elapsed: float = 0.0
var _scene_ready: bool = false
var _loaded_scene: PackedScene


func _ready() -> void:
	if NetworkManager.loading_map_name != "":
		map_label.text = NetworkManager.loading_map_name
	ResourceLoader.load_threaded_request(TARGET_SCENE)
	_load_started = true


func _process(delta: float) -> void:
	_elapsed += delta

	if not _load_started:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(TARGET_SCENE, progress)
	if progress.size() > 0:
		progress_bar.value = progress[0] * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if not _scene_ready:
				_scene_ready = true
				_loaded_scene = ResourceLoader.load_threaded_get(TARGET_SCENE) as PackedScene
				progress_bar.value = 100.0
				status_label.text = "Ready"
			if _elapsed >= _min_display_time:
				get_tree().change_scene_to_packed(_loaded_scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Failed to load map"
			_load_started = false
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			status_label.text = "Invalid map resource"
			_load_started = false
