class_name MatchConfig
extends RefCounted

var _settings: Dictionary = {}


func register(setting_name: String, default_value: Variant, description: String, plugin: StringName) -> void:
	_settings[setting_name] = {
		"value": default_value,
		"default": default_value,
		"type": typeof(default_value),
		"description": description,
		"plugin": plugin,
	}


func get_value(setting_name: String) -> Variant:
	if _settings.has(setting_name):
		return _settings[setting_name]["value"]
	return null


func get_int(setting_name: String) -> int:
	return int(get_value(setting_name))


func get_float(setting_name: String) -> float:
	return float(get_value(setting_name))


func get_bool(setting_name: String) -> bool:
	return bool(get_value(setting_name))


func set_value(setting_name: String, value: Variant) -> bool:
	if not _settings.has(setting_name):
		return false
	_settings[setting_name]["value"] = value
	return true


func apply_lobby_overrides(overrides: Dictionary) -> void:
	for key in overrides:
		if _settings.has(key):
			_settings[key]["value"] = overrides[key]


func list_settings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for setting_name in _settings:
		var s: Dictionary = _settings[setting_name]
		result.append({
			"name": setting_name,
			"value": s["value"],
			"default": s["default"],
			"description": s["description"],
			"plugin": s["plugin"],
		})
	return result


func has_setting(setting_name: String) -> bool:
	return _settings.has(setting_name)
