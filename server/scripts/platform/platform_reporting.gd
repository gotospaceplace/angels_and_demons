class_name PlatformReporting
extends GamePlugin


func get_plugin_name() -> StringName: return &"platform_reporting"
func get_description() -> String: return "Player report handling and feedback loop"


func on_console_command(cmd: String, args: String) -> bool:
	if cmd == "reports":
		# TODO: List pending player reports
		print("[Reports] No pending reports (stub)")
		return true
	return false
