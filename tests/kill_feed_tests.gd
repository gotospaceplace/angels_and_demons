extends Node

var pass_count: int = 0
var fail_count: int = 0
var total: int = 0


func _ready() -> void:
	print("[KillFeedTests] Starting kill feed test suite")

	_test_pack_kill_event_with_flags()
	_test_pack_kill_event_default_flags()
	_test_unpack_kill_flags()
	_test_add_kill_creates_entry()
	_test_add_kill_max_entries()
	_test_team_color_angels()
	_test_team_color_demons()
	_test_local_player_gold()
	_test_wallbang_icon()
	_test_smoke_icon()
	_test_flash_icon()
	_test_combined_flags()
	_test_headshot_icon()
	_test_headshot_plus_wallbang()
	_test_no_flags_no_icons()
	_test_knife_weapon_label()
	_test_default_params_backward_compat()

	print("[KillFeedTests] Done: %d passed, %d failed out of %d" % [pass_count, fail_count, total])
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


func _make_feed() -> Node:
	var feed := preload("res://client/scripts/kill_feed.gd").new()
	add_child(feed)
	return feed


func _get_entry_text(feed: Node, index: int) -> String:
	if index >= feed.entries.size():
		return ""
	return feed.entries[index]["label"].text


# --- Protocol tests ---

func _test_pack_kill_event_with_flags() -> void:
	var buf := NetProtocol.pack_kill_event(1, 2, 3, true, NetProtocol.KILL_FLAG_WALLBANG | NetProtocol.KILL_FLAG_SMOKE)
	_assert(buf.size() == 9, "pack_kill_size_with_flags",
		"expected 9, got %d" % buf.size())
	_assert(buf[8] == (NetProtocol.KILL_FLAG_WALLBANG | NetProtocol.KILL_FLAG_SMOKE),
		"pack_kill_flags_value",
		"expected %d, got %d" % [NetProtocol.KILL_FLAG_WALLBANG | NetProtocol.KILL_FLAG_SMOKE, buf[8]])


func _test_pack_kill_event_default_flags() -> void:
	var buf := NetProtocol.pack_kill_event(1, 2, 3, false)
	_assert(buf.size() == 9, "pack_kill_size_default",
		"expected 9, got %d" % buf.size())
	_assert(buf[8] == 0, "pack_kill_default_flags_zero",
		"expected 0, got %d" % buf[8])


func _test_unpack_kill_flags() -> void:
	var buf := NetProtocol.pack_kill_event(100, 200, 2, true, NetProtocol.KILL_FLAG_FLASH)
	_assert(buf[2] == NetProtocol.EVT_KILL, "unpack_evt_type")
	var killer_id := buf[3] | (buf[4] << 8)
	_assert(killer_id == 100, "unpack_killer_id",
		"expected 100, got %d" % killer_id)
	var victim_id := buf[5] | (buf[6] << 8)
	_assert(victim_id == 200, "unpack_victim_id",
		"expected 200, got %d" % victim_id)
	var weapon_byte := buf[7]
	var headshot := (weapon_byte & 0x80) != 0
	var weapon_idx := weapon_byte & 0x7F
	_assert(headshot, "unpack_headshot_true")
	_assert(weapon_idx == 2, "unpack_weapon_idx",
		"expected 2, got %d" % weapon_idx)
	_assert(buf[8] == NetProtocol.KILL_FLAG_FLASH, "unpack_flash_flag",
		"expected %d, got %d" % [NetProtocol.KILL_FLAG_FLASH, buf[8]])


# --- Kill feed entry tests ---

func _test_add_kill_creates_entry() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, 0, 0, 0, 99)
	_assert(feed.entries.size() == 1, "add_kill_creates_entry",
		"expected 1, got %d" % feed.entries.size())
	feed.queue_free()


func _test_add_kill_max_entries() -> void:
	var feed := _make_feed()
	for i in range(8):
		feed.add_kill(i, i + 1, 2, false, 0, 0, 0, 99)
	_assert(feed.entries.size() == feed.MAX_ENTRIES, "max_entries_enforced",
		"expected %d, got %d" % [feed.MAX_ENTRIES, feed.entries.size()])
	feed.queue_free()


# --- Team color tests ---

func _test_team_color_angels() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, 0, Team.Id.ANGELS, Team.Id.DEMONS, 99)
	var text := _get_entry_text(feed, 0)
	var angel_color := Team.get_color(Team.Id.ANGELS).to_html(false)
	_assert(text.contains(angel_color.to_lower()) or text.contains(angel_color.to_upper()),
		"angels_blue_color",
		"expected color %s in text" % angel_color)
	feed.queue_free()


func _test_team_color_demons() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, 0, Team.Id.ANGELS, Team.Id.DEMONS, 99)
	var text := _get_entry_text(feed, 0)
	var demon_color := Team.get_color(Team.Id.DEMONS).to_html(false)
	_assert(text.contains(demon_color.to_lower()) or text.contains(demon_color.to_upper()),
		"demons_red_color",
		"expected color %s in text" % demon_color)
	feed.queue_free()


func _test_local_player_gold() -> void:
	var feed := _make_feed()
	feed.add_kill(5, 2, 2, false, 0, Team.Id.ANGELS, Team.Id.DEMONS, 5)
	var text := _get_entry_text(feed, 0)
	_assert(text.contains("#ffda33"), "local_player_gold_color",
		"expected gold #ffda33 for local killer")
	feed.queue_free()


# --- Kill flag icon tests ---

func _test_wallbang_icon() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, NetProtocol.KILL_FLAG_WALLBANG, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("▮" in text, "wallbang_icon_present")
	_assert("#ff9933" in text, "wallbang_icon_color")
	feed.queue_free()


func _test_smoke_icon() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, NetProtocol.KILL_FLAG_SMOKE, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("☁" in text, "smoke_icon_present")
	_assert("#aaddff" in text, "smoke_icon_color")
	feed.queue_free()


func _test_flash_icon() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, NetProtocol.KILL_FLAG_FLASH, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("✦" in text, "flash_icon_present")
	_assert("#ffffaa" in text, "flash_icon_color")
	feed.queue_free()


func _test_combined_flags() -> void:
	var feed := _make_feed()
	var flags := NetProtocol.KILL_FLAG_WALLBANG | NetProtocol.KILL_FLAG_SMOKE | NetProtocol.KILL_FLAG_FLASH
	feed.add_kill(1, 2, 2, false, flags, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("▮" in text, "combined_wallbang_present")
	_assert("☁" in text, "combined_smoke_present")
	_assert("✦" in text, "combined_flash_present")
	feed.queue_free()


func _test_headshot_icon() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, true, 0, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("☠" in text, "headshot_icon_present")
	_assert("#ff3333" in text, "headshot_icon_color")
	feed.queue_free()


func _test_headshot_plus_wallbang() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, true, NetProtocol.KILL_FLAG_WALLBANG, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("☠" in text, "hs_wb_headshot_present")
	_assert("▮" in text, "hs_wb_wallbang_present")
	var hs_pos := text.find("☠")
	var wb_pos := text.find("▮")
	_assert(hs_pos < wb_pos, "headshot_before_wallbang",
		"headshot icon should appear before wallbang icon")
	feed.queue_free()


func _test_no_flags_no_icons() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false, 0, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("▮" not in text, "no_wallbang_without_flag")
	_assert("☁" not in text, "no_smoke_without_flag")
	_assert("✦" not in text, "no_flash_without_flag")
	_assert("☠" not in text, "no_headshot_without_flag")
	feed.queue_free()


func _test_knife_weapon_label() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 0, false, 0, 0, 0, 99)
	var text := _get_entry_text(feed, 0)
	_assert("KNIFE" in text, "knife_label_present")
	feed.queue_free()


func _test_default_params_backward_compat() -> void:
	var feed := _make_feed()
	feed.add_kill(1, 2, 2, false)
	_assert(feed.entries.size() == 1, "default_params_no_crash",
		"add_kill with 4 args should work")
	var text := _get_entry_text(feed, 0)
	_assert("#ffffff" in text, "default_white_when_no_team",
		"expected white names when no team specified")
	feed.queue_free()
