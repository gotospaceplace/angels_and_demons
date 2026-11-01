extends Node

## Validates all GDScript files in full project context.
## Runs after autoloads are initialized, so singleton references resolve correctly.
## Invoked via: godot --headless --path . -- --validate-scripts

const EXCLUDE_DIRS := [".godot", "Angels_Demons_Character_Prototypes"]

var errors := 0
var checked := 0
var failed_scripts: Array[String] = []


func _ready() -> void:
	print("=== GDScript Project Validator ===")
	print("Validating all .gd files with autoloads active")
	print("")

	var scripts := _find_scripts("res://")
	for path in scripts:
		checked += 1
		if not _validate_script(path):
			errors += 1
			failed_scripts.append(path)

	print("")
	print("=== Results ===")
	print("Checked %d scripts, %d error(s)" % [checked, errors])
	if errors > 0:
		print("")
		print("Failed scripts:")
		for s in failed_scripts:
			print("  FAIL  %s" % s)
		print("")
		print("FAILED")
		get_tree().quit(1)
	else:
		print("ALL PASSED")
		get_tree().quit(0)


func _validate_script(path: String) -> bool:
	# Read source and compile a fresh GDScript in the running engine context.
	# Autoloads are registered, so GameSettings/NetworkManager/etc. resolve.
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty() and FileAccess.get_open_error() != OK:
		print("  FAIL  %s — cannot read file" % path)
		return false

	var gds := GDScript.new()
	gds.source_code = source
	gds.resource_path = path
	var err := gds.reload()
	if err != OK:
		print("  FAIL  %s — compilation error (code %d)" % [path, err])
		return false
	return true


func _find_scripts(base_dir: String) -> Array[String]:
	var result: Array[String] = []
	_scan_dir(base_dir, result)
	result.sort()
	return result


func _scan_dir(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name not in EXCLUDE_DIRS and not name.begins_with("."):
				_scan_dir(path.path_join(name), out)
		elif name.ends_with(".gd"):
			out.append(path.path_join(name))
		name = dir.get_next()
