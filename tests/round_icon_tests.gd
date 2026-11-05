extends Node

const RoundIconScript = preload("res://client/scripts/round_icon.gd")

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[RoundIconTests] Starting round icon test suite")

	_test_icon_initial_state()
	_test_set_icon_elimination()
	_test_set_icon_portal_opened()
	_test_set_icon_portal_sealed()
	_test_set_icon_time_expired()
	_test_set_icon_unknown_reason()
	_test_icon_color_assignment()
	_test_scoreboard_markers_use_icon()
	_test_scoreboard_marker_visibility()
	_test_scoreboard_marker_hidden_when_no_history()

	print("[RoundIconTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
	if fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	total += 1
	if condition:
		pass_count += 1
		print("  PASS %s" % test_name)
	else:
		fail_count += 1
		var msg := "  FAIL %s" % test_name
		if detail != "":
			msg += " — %s" % detail
		print(msg)


# --- RoundIcon unit tests ---

func _test_icon_initial_state() -> void:
	var icon := RoundIconScript.new()
	add_child(icon)
	_assert(icon.reason == "", "icon_initial_reason_empty")
	_assert(icon.icon_color == Color.WHITE, "icon_initial_color_white")
	icon.queue_free()


func _test_set_icon_elimination() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	icon.set_icon("elimination", Color.RED)
	_assert(icon.reason == "elimination", "icon_reason_elimination")
	_assert(icon.icon_color == Color.RED, "icon_color_set")
	icon.queue_free()


func _test_set_icon_portal_opened() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	icon.set_icon("portal_opened", Color.BLUE)
	_assert(icon.reason == "portal_opened", "icon_reason_portal_opened")
	icon.queue_free()


func _test_set_icon_portal_sealed() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	icon.set_icon("portal_sealed", Color.GREEN)
	_assert(icon.reason == "portal_sealed", "icon_reason_portal_sealed")
	icon.queue_free()


func _test_set_icon_time_expired() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	icon.set_icon("time_expired", Color.YELLOW)
	_assert(icon.reason == "time_expired", "icon_reason_time_expired")
	icon.queue_free()


func _test_set_icon_unknown_reason() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	icon.set_icon("something_else", Color.WHITE)
	_assert(icon.reason == "something_else", "icon_unknown_reason_stored")
	icon.queue_free()


func _test_icon_color_assignment() -> void:
	var icon := RoundIconScript.new()
	icon.size = Vector2(16, 16)
	add_child(icon)
	var c := Color(0.5, 0.7, 0.2)
	icon.set_icon("elimination", c)
	_assert(icon.icon_color.is_equal_approx(c), "icon_custom_color",
		"expected (0.5,0.7,0.2), got %s" % icon.icon_color)
	icon.queue_free()


# --- Scoreboard integration tests ---

func _test_scoreboard_markers_use_icon() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.round_history = [
		{"winner": Team.Id.ANGELS, "reason": "elimination"},
		{"winner": Team.Id.DEMONS, "reason": "portal_opened"},
		{"winner": Team.Id.ANGELS, "reason": "time_expired"},
	]
	ClientScoreboard._refresh_round_history()
	_assert(ClientScoreboard._round_markers[0].has("icon"), "marker_has_icon_key",
		"expected 'icon' key in marker dict")
	var icon0 = ClientScoreboard._round_markers[0]["icon"]
	_assert(icon0.reason == "elimination", "marker_0_reason",
		"expected elimination, got %s" % icon0.reason)
	var icon1 = ClientScoreboard._round_markers[1]["icon"]
	_assert(icon1.reason == "portal_opened", "marker_1_reason",
		"expected portal_opened, got %s" % icon1.reason)
	var icon2 = ClientScoreboard._round_markers[2]["icon"]
	_assert(icon2.reason == "time_expired", "marker_2_reason",
		"expected time_expired, got %s" % icon2.reason)


func _test_scoreboard_marker_visibility() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.round_history = [
		{"winner": Team.Id.ANGELS, "reason": "elimination"},
	]
	ClientScoreboard._refresh_round_history()
	_assert(ClientScoreboard._round_markers[0]["icon"].visible, "first_marker_visible")
	_assert(ClientScoreboard._round_markers[0]["bg"].visible, "first_marker_bg_visible")
	_assert(not ClientScoreboard._round_markers[1]["icon"].visible, "second_marker_hidden")
	_assert(not ClientScoreboard._round_markers[1]["bg"].visible, "second_marker_bg_hidden")


func _test_scoreboard_marker_hidden_when_no_history() -> void:
	ClientScoreboard.update_mode(&"competitive")
	ClientScoreboard.round_history = []
	ClientScoreboard._refresh_round_history()
	for i in range(ClientScoreboard.MAX_ROUND_MARKERS):
		_assert(not ClientScoreboard._round_markers[i]["icon"].visible,
			"marker_%d_hidden_empty_history" % i)
