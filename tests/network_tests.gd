extends Node

var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var results: Array[String] = []


func _ready() -> void:
	test_queue = [
		&"test_input_serialize_roundtrip",
		&"test_input_buttons_all",
		&"test_input_negative_pitch",
		&"test_snapshot_full_roundtrip",
		&"test_snapshot_negative_values",
		&"test_snapshot_flags",
		&"test_delta_smaller_than_full",
		&"test_delta_single_field",
		&"test_delta_all_fields_changed",
		&"test_delta_no_change",
		&"test_input_packet_roundtrip",
		&"test_snapshot_packet_full_roundtrip",
		&"test_snapshot_packet_multi_player",
		&"test_input_size",
		&"test_snapshot_size",
	]

	print("=== Network Serialization Tests ===")
	print("Tests to run: %d" % test_queue.size())
	print("")
	_run_all()


func _run_all() -> void:
	for test_name in test_queue:
		current_test = test_name
		print("  RUN  %s" % current_test)
		call(test_name)
	_print_summary()


func _pass(msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [current_test, msg])
	print("  PASS %s" % msg)


func _fail(msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [current_test, msg])
	print("  FAIL %s" % msg)


func _approx(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) < tolerance


func _print_summary() -> void:
	print("")
	print("=== Results ===")
	for r in results:
		print(r)
	print("")
	var total := tests_passed + tests_failed
	print("%d/%d passed, %d failed" % [tests_passed, total, tests_failed])
	if tests_failed > 0:
		print("FAILED")
		get_tree().quit(1)
	else:
		print("ALL PASSED")
		get_tree().quit(0)


# --- InputCommand tests ---

func test_input_serialize_roundtrip() -> void:
	var cmd := NetInput.create(12345, 0b0000_0001_0010_0101, 187.5, 45.0)
	var buf := cmd.to_bytes()
	var out := NetInput.from_bytes(buf)
	if out.tick != 12345:
		_fail("tick: got %d, expected 12345" % out.tick)
		return
	if out.buttons != cmd.buttons:
		_fail("buttons: got %d, expected %d" % [out.buttons, cmd.buttons])
		return
	if not _approx(out.yaw, 187.5, 0.01):
		_fail("yaw: got %.4f, expected 187.5" % out.yaw)
		return
	if not _approx(out.pitch, 45.0, 0.01):
		_fail("pitch: got %.4f, expected 45.0" % out.pitch)
		return
	_pass("tick=%d buttons=%d yaw=%.2f pitch=%.2f" % [out.tick, out.buttons, out.yaw, out.pitch])


func test_input_buttons_all() -> void:
	var cmd := NetInput.new()
	cmd.tick = 1
	for bit in range(14):
		cmd.set_button(bit, true)
	var buf := cmd.to_bytes()
	var out := NetInput.from_bytes(buf)
	for bit in range(14):
		if not out.has_button(bit):
			_fail("button %d missing after roundtrip" % bit)
			return
	_pass("all 14 buttons survived roundtrip")


func test_input_negative_pitch() -> void:
	var cmd := NetInput.create(1, 0, 0.0, -89.5)
	var buf := cmd.to_bytes()
	var out := NetInput.from_bytes(buf)
	if not _approx(out.pitch, -89.5, 0.01):
		_fail("pitch: got %.4f, expected -89.5" % out.pitch)
		return
	_pass("negative pitch=%.4f" % out.pitch)


# --- Snapshot tests ---

func test_snapshot_full_roundtrip() -> void:
	var s := NetSnapshot.new()
	s.peer_id = 42
	s.tick = 999999
	s.position = Vector3(10.55, 2.33, -7.89)
	s.velocity = Vector3(5.3, -1.2, 3.7)
	s.yaw = 270.0
	s.pitch = -45.0
	s.flags = 0b00000101  # on_ground + is_scoped
	s.hp = 87
	s.armor = 50
	s.weapon_idx = 2
	s.ammo_mag = 15

	var buf := s.to_full_bytes()
	var out := NetSnapshot.from_full_bytes(buf)

	if out.peer_id != 42:
		_fail("peer_id: %d" % out.peer_id); return
	if out.tick != 999999:
		_fail("tick: %d" % out.tick); return
	if not _approx(out.position.x, 10.55, 0.02):
		_fail("pos.x: %.4f" % out.position.x); return
	if not _approx(out.position.y, 2.33, 0.02):
		_fail("pos.y: %.4f" % out.position.y); return
	if not _approx(out.position.z, -7.89, 0.02):
		_fail("pos.z: %.4f" % out.position.z); return
	if not _approx(out.velocity.x, 5.3, 0.2):
		_fail("vel.x: %.2f" % out.velocity.x); return
	if not _approx(out.velocity.y, -1.2, 0.2):
		_fail("vel.y: %.2f" % out.velocity.y); return
	if not _approx(out.velocity.z, 3.7, 0.2):
		_fail("vel.z: %.2f" % out.velocity.z); return
	if not _approx(out.yaw, 270.0, 0.01):
		_fail("yaw: %.4f" % out.yaw); return
	if not _approx(out.pitch, -45.0, 0.01):
		_fail("pitch: %.4f" % out.pitch); return
	if out.hp != 87:
		_fail("hp: %d" % out.hp); return
	if out.armor != 50:
		_fail("armor: %d" % out.armor); return
	if out.weapon_idx != 2:
		_fail("weapon_idx: %d" % out.weapon_idx); return
	if out.ammo_mag != 15:
		_fail("ammo_mag: %d" % out.ammo_mag); return
	_pass("all fields match (buf=%d bytes)" % buf.size())


func test_snapshot_negative_values() -> void:
	var s := NetSnapshot.new()
	s.peer_id = 1
	s.tick = 1
	s.position = Vector3(-100.0, -50.0, -200.0)
	s.velocity = Vector3(-6.0, -20.0, -3.0)
	s.pitch = -90.0

	var buf := s.to_full_bytes()
	var out := NetSnapshot.from_full_bytes(buf)

	if not _approx(out.position.x, -100.0, 0.02):
		_fail("pos.x: %.4f" % out.position.x); return
	if not _approx(out.position.y, -50.0, 0.02):
		_fail("pos.y: %.4f" % out.position.y); return
	if not _approx(out.velocity.x, -6.0, 0.2):
		_fail("vel.x: %.2f" % out.velocity.x); return
	if not _approx(out.pitch, -90.0, 0.01):
		_fail("pitch: %.4f" % out.pitch); return
	_pass("negative position/velocity/pitch roundtrip OK")


func test_snapshot_flags() -> void:
	var s := NetSnapshot.new()
	s.peer_id = 1
	s.tick = 1
	s.set_flag(NetSnapshot.FLAG_ON_GROUND, true)
	s.set_flag(NetSnapshot.FLAG_IS_DUCKED, false)
	s.set_flag(NetSnapshot.FLAG_IS_SCOPED, true)
	s.set_flag(NetSnapshot.FLAG_IS_DEAD, true)

	var buf := s.to_full_bytes()
	var out := NetSnapshot.from_full_bytes(buf)

	if not out.get_flag(NetSnapshot.FLAG_ON_GROUND):
		_fail("FLAG_ON_GROUND should be true"); return
	if out.get_flag(NetSnapshot.FLAG_IS_DUCKED):
		_fail("FLAG_IS_DUCKED should be false"); return
	if not out.get_flag(NetSnapshot.FLAG_IS_SCOPED):
		_fail("FLAG_IS_SCOPED should be true"); return
	if not out.get_flag(NetSnapshot.FLAG_IS_DEAD):
		_fail("FLAG_IS_DEAD should be true"); return
	_pass("flags 0b%s" % String.num_int64(out.flags, 2))


# --- Delta compression tests ---

func test_delta_smaller_than_full() -> void:
	var base := NetSnapshot.new()
	base.peer_id = 1
	base.tick = 100
	base.position = Vector3(10.0, 2.0, 5.0)
	base.velocity = Vector3(3.0, 0.0, -1.0)
	base.yaw = 90.0
	base.pitch = 0.0
	base.hp = 100
	base.armor = 50

	var current := base.duplicate_state()
	current.tick = 102
	current.position = Vector3(10.05, 2.0, 5.1)  # Small move

	var full_buf := current.to_full_bytes()
	var delta_buf := current.to_delta_bytes(base)

	if delta_buf.size() < full_buf.size():
		_pass("delta=%d bytes < full=%d bytes" % [delta_buf.size(), full_buf.size()])
	else:
		_fail("delta=%d >= full=%d" % [delta_buf.size(), full_buf.size()])


func test_delta_single_field() -> void:
	var base := NetSnapshot.new()
	base.peer_id = 5
	base.tick = 100
	base.position = Vector3(10.0, 2.0, 5.0)
	base.velocity = Vector3.ZERO
	base.hp = 100

	var current := base.duplicate_state()
	current.hp = 73

	var delta_buf := current.to_delta_bytes(base)
	# peer_id(2) + changed_mask(1) + hp(1) = 4 bytes
	if delta_buf.size() != 4:
		_fail("expected 4 bytes for HP-only delta, got %d" % delta_buf.size())
		return

	var arr := NetSnapshot.from_delta_bytes(delta_buf, base)
	var out: NetSnapshot = arr[0]
	if out.hp != 73:
		_fail("hp: got %d, expected 73" % out.hp); return
	if not _approx(out.position.x, 10.0, 0.02):
		_fail("position.x changed: %.4f" % out.position.x); return
	_pass("single-field delta: %d bytes, hp=%d pos unchanged" % [delta_buf.size(), out.hp])


func test_delta_all_fields_changed() -> void:
	var base := NetSnapshot.new()
	base.peer_id = 1
	base.tick = 100
	base.position = Vector3(10.0, 2.0, 5.0)
	base.velocity = Vector3(1.0, 0.0, 0.0)
	base.yaw = 90.0
	base.pitch = 0.0
	base.flags = 1
	base.hp = 100
	base.armor = 50
	base.weapon_idx = 0
	base.ammo_mag = 30

	var current := NetSnapshot.new()
	current.peer_id = 1
	current.tick = 102
	current.position = Vector3(20.0, 3.0, -5.0)
	current.velocity = Vector3(-2.0, 5.0, 1.0)
	current.yaw = 180.0
	current.pitch = -30.0
	current.flags = 6
	current.hp = 50
	current.armor = 25
	current.weapon_idx = 2
	current.ammo_mag = 15

	var delta_buf := current.to_delta_bytes(base)
	var arr := NetSnapshot.from_delta_bytes(delta_buf, base)
	var out: NetSnapshot = arr[0]

	if out.hp != 50 or out.armor != 25 or out.weapon_idx != 2 or out.ammo_mag != 15:
		_fail("scalar fields wrong"); return
	if not _approx(out.position.x, 20.0, 0.02):
		_fail("pos.x: %.4f" % out.position.x); return
	if not _approx(out.yaw, 180.0, 0.01):
		_fail("yaw: %.4f" % out.yaw); return
	_pass("all-changed delta: %d bytes (full would be %d)" % [delta_buf.size(), NetSnapshot.FULL_SIZE])


func test_delta_no_change() -> void:
	var base := NetSnapshot.new()
	base.peer_id = 1
	base.tick = 100
	base.position = Vector3(10.0, 2.0, 5.0)
	base.hp = 100

	var current := base.duplicate_state()
	var delta_buf := current.to_delta_bytes(base)
	# peer_id(2) + changed_mask(1) = 3 bytes (mask=0)
	if delta_buf.size() != 3:
		_fail("expected 3 bytes for no-change delta, got %d" % delta_buf.size())
		return
	_pass("no-change delta: %d bytes" % delta_buf.size())


# --- Protocol packet tests ---

func test_input_packet_roundtrip() -> void:
	var cmd1 := NetInput.create(100, 0b101, 90.0, 10.0)
	var cmd2 := NetInput.create(99, 0b010, 89.0, 9.0)
	var cmd3 := NetInput.create(98, 0b001, 88.0, 8.0)

	var packet := NetProtocol.pack_input_packet([cmd1, cmd2, cmd3], 4200)
	var result := NetProtocol.unpack_input_packet(packet)
	var commands: Array = result["commands"]

	if commands.size() != 3:
		_fail("expected 3 commands, got %d" % commands.size()); return
	if commands[0].tick != 100 or commands[1].tick != 99 or commands[2].tick != 98:
		_fail("tick mismatch"); return
	if result["ack_tick"] != 4200:
		_fail("ack_tick: %d expected 4200" % result["ack_tick"]); return
	_pass("3-command packet roundtrip, %d bytes, ack=%d" % [packet.size(), result["ack_tick"]])


func test_snapshot_packet_full_roundtrip() -> void:
	var s := NetSnapshot.new()
	s.peer_id = 1
	s.tick = 5000
	s.position = Vector3(5.0, 1.0, -3.0)
	s.hp = 100
	s.armor = 50
	s.weapon_idx = 1
	s.ammo_mag = 12

	var packet := NetProtocol.pack_snapshot_full(5000, [s])
	var result := NetProtocol.unpack_snapshot(packet)

	if result["tick"] != 5000:
		_fail("tick: %d" % result["tick"]); return
	if result["is_delta"]:
		_fail("should not be delta"); return
	var states: Array = result["states"]
	if states.size() != 1:
		_fail("expected 1 state, got %d" % states.size()); return
	var out: NetSnapshot = states[0]
	if out.peer_id != 1 or out.hp != 100:
		_fail("peer_id=%d hp=%d" % [out.peer_id, out.hp]); return
	_pass("full snapshot packet: %d bytes, tick=%d" % [packet.size(), result["tick"]])


func test_snapshot_packet_multi_player() -> void:
	var states: Array = []
	for i in range(10):
		var s := NetSnapshot.new()
		s.peer_id = i + 1
		s.tick = 10000
		s.position = Vector3(float(i) * 5.0, 1.0, 0.0)
		s.hp = 100 - i * 5
		s.weapon_idx = i % 5
		s.ammo_mag = 30 - i
		states.append(s)

	var packet := NetProtocol.pack_snapshot_full(10000, states)
	var result := NetProtocol.unpack_snapshot(packet)
	var out_states: Array = result["states"]

	if out_states.size() != 10:
		_fail("expected 10 states, got %d" % out_states.size()); return
	var ok := true
	for i in range(10):
		var out: NetSnapshot = out_states[i]
		if out.peer_id != i + 1 or out.hp != 100 - i * 5:
			ok = false; break
	if not ok:
		_fail("10-player data mismatch"); return
	_pass("10-player snapshot: %d bytes (%.1f bytes/player)" % [packet.size(), float(packet.size()) / 10.0])


# --- Size measurement ---

func test_input_size() -> void:
	var cmd := NetInput.create(1, 0, 0.0, 0.0)
	var buf := cmd.to_bytes()
	if buf.size() == NetInput.SIZE:
		_pass("InputCommand = %d bytes" % buf.size())
	else:
		_fail("InputCommand = %d bytes, expected %d" % [buf.size(), NetInput.SIZE])


func test_snapshot_size() -> void:
	var s := NetSnapshot.new()
	s.peer_id = 1
	s.tick = 1
	var buf := s.to_full_bytes()
	if buf.size() == NetSnapshot.FULL_SIZE:
		_pass("PlayerState = %d bytes" % buf.size())
	else:
		_fail("PlayerState = %d bytes, expected %d" % [buf.size(), NetSnapshot.FULL_SIZE])
