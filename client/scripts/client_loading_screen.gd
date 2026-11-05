extends Control

const TARGET_SCENE := "res://client/scenes/mp_client.tscn"

@onready var progress_bar: ProgressBar = $ContentCenter/VBox/ProgressBar
@onready var status_label: Label = $ContentCenter/VBox/StatusLabel
@onready var map_label: Label = $ContentCenter/VBox/MapName

var _min_display_time := 1.5
var _elapsed: float = 0.0
var _loaded_scene: PackedScene


func _ready() -> void:
	if NetworkManager.loading_map_name != "":
		map_label.text = NetworkManager.loading_map_name
	_loaded_scene = load(TARGET_SCENE) as PackedScene
	if _loaded_scene:
		progress_bar.value = 100.0
		status_label.text = "Ready"
	else:
		push_error("[LoadingScreen] Failed to load: %s" % TARGET_SCENE)
		status_label.text = "Failed to load map"


func _process(delta: float) -> void:
	_elapsed += delta
	if _loaded_scene and _elapsed >= _min_display_time:
		get_tree().change_scene_to_packed(_loaded_scene)
