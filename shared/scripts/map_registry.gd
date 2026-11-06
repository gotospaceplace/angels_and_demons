class_name MapRegistry
extends RefCounted

const MAPS: Dictionary = {
	"MAP_DM_AIM": "res://shared/scenes/map_dm_aim.tscn",
	"MAP_TD_CSAIMMAP": "res://maps/Prototypes/MAP_TD_CSAIMMAP/MAP_TD_CSAIMMAP.tscn",
}


static func get_scene_path(map_name: String) -> String:
	return MAPS.get(map_name.to_upper(), "")


static func get_all_names() -> Array:
	return MAPS.keys()


static func is_valid(map_name: String) -> bool:
	return MAPS.has(map_name.to_upper())
