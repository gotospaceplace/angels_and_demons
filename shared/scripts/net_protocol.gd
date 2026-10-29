class_name NetProtocol
extends RefCounted

# Message types
const MSG_INPUT    := 1  # Client → server: input commands
const MSG_SNAPSHOT := 2  # Server → client: world state
const MSG_EVENT    := 3  # Server → client: game events (reliable)
const MSG_ADMIN    := 4  # Client → server: admin commands (reliable)

# Event subtypes (MSG_EVENT payload)
const EVT_KILL       := 1
const EVT_SPAWN      := 2
const EVT_CHAT       := 3
const EVT_SERVER_MSG := 4
const EVT_HIT        := 5
const EVT_SESSION    := 6

# Admin subtypes (MSG_ADMIN payload)
const ADMIN_REJOIN   := 1

# Packet header: version (1) + msg_type (1) = 2 bytes
const HEADER_SIZE := 2


# --- Input packet: client → server ---
# Header (2) + ack_tick (4) + input_count (1) + InputCommands (10 × count)

static func pack_input_packet(commands: Array, ack_tick: int = 0) -> PackedByteArray:
	var count := mini(commands.size(), NetConstants.INPUT_REDUNDANCY)
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 5)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_INPUT
	buf[2] = ack_tick & 0xFF
	buf[3] = (ack_tick >> 8) & 0xFF
	buf[4] = (ack_tick >> 16) & 0xFF
	buf[5] = (ack_tick >> 24) & 0xFF
	buf[6] = count
	for i in range(count):
		buf.append_array(commands[i].to_bytes())
	return buf


static func unpack_input_packet(buf: PackedByteArray) -> Dictionary:
	# Returns {ack_tick: int, commands: Array[NetInput]}
	var result := {"ack_tick": 0, "commands": []}
	if buf.size() < HEADER_SIZE + 5:
		return result
	if buf[0] != NetConstants.PROTOCOL_VERSION:
		return result
	if buf[1] != MSG_INPUT:
		return result
	result["ack_tick"] = buf[2] | (buf[3] << 8) | (buf[4] << 16) | (buf[5] << 24)
	var count: int = buf[6]
	var commands: Array = []
	var offset := HEADER_SIZE + 5
	for i in range(count):
		if offset + NetInput.SIZE > buf.size():
			break
		commands.append(NetInput.from_bytes(buf, offset))
		offset += NetInput.SIZE
	result["commands"] = commands
	return result


# --- Snapshot packet: server → client ---
# Header (2) + server_tick (4) + player_count (1) + is_delta (1)
# If delta: + base_tick (4)
# Then: player states (full or delta)

static func pack_snapshot_full(server_tick: int, states: Array) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 6)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_SNAPSHOT
	# server_tick: u32
	buf[2] = server_tick & 0xFF
	buf[3] = (server_tick >> 8) & 0xFF
	buf[4] = (server_tick >> 16) & 0xFF
	buf[5] = (server_tick >> 24) & 0xFF
	# player_count: u8
	buf[6] = states.size()
	# is_delta: u8 (0 = full)
	buf[7] = 0
	for state in states:
		buf.append_array(state.to_full_bytes())
	return buf


static func pack_snapshot_delta(server_tick: int, base_tick: int, states: Array, bases: Dictionary) -> PackedByteArray:
	# bases: Dictionary[int peer_id → NetSnapshot base_state]
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 10)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_SNAPSHOT
	# server_tick: u32
	buf[2] = server_tick & 0xFF
	buf[3] = (server_tick >> 8) & 0xFF
	buf[4] = (server_tick >> 16) & 0xFF
	buf[5] = (server_tick >> 24) & 0xFF
	# player_count: u8
	buf[6] = states.size()
	# is_delta: u8 (1 = delta)
	buf[7] = 1
	# base_tick: u32
	buf[8] = base_tick & 0xFF
	buf[9] = (base_tick >> 8) & 0xFF
	buf[10] = (base_tick >> 16) & 0xFF
	buf[11] = (base_tick >> 24) & 0xFF
	for state in states:
		var base: NetSnapshot = bases.get(state.peer_id)
		if base:
			buf.append_array(state.to_delta_bytes(base))
		else:
			buf.append_array(state.to_full_bytes())
	return buf


static func unpack_snapshot(buf: PackedByteArray, bases: Dictionary = {}) -> Dictionary:
	# Returns {tick: int, is_delta: bool, base_tick: int, states: Array[NetSnapshot]}
	var result := {"tick": 0, "is_delta": false, "base_tick": 0, "states": []}
	if buf.size() < HEADER_SIZE + 6:
		return result
	if buf[0] != NetConstants.PROTOCOL_VERSION or buf[1] != MSG_SNAPSHOT:
		return result
	result["tick"] = buf[2] | (buf[3] << 8) | (buf[4] << 16) | (buf[5] << 24)
	var player_count: int = buf[6]
	var is_delta: bool = buf[7] == 1
	result["is_delta"] = is_delta
	var offset := HEADER_SIZE + 6
	if is_delta:
		if buf.size() < offset + 4:
			return result
		result["base_tick"] = buf[offset] | (buf[offset + 1] << 8) | (buf[offset + 2] << 16) | (buf[offset + 3] << 24)
		offset += 4
	var states: Array = []
	for _i in range(player_count):
		if is_delta:
			# Peek peer_id to find base
			if offset + 2 > buf.size():
				break
			var pid := buf[offset] | (buf[offset + 1] << 8)
			var base: NetSnapshot = bases.get(pid)
			if base:
				var arr := NetSnapshot.from_delta_bytes(buf, base, offset)
				states.append(arr[0])
				offset += arr[1]
			else:
				if offset + NetSnapshot.FULL_SIZE > buf.size():
					break
				states.append(NetSnapshot.from_full_bytes(buf, offset))
				offset += NetSnapshot.FULL_SIZE
		else:
			if offset + NetSnapshot.FULL_SIZE > buf.size():
				break
			states.append(NetSnapshot.from_full_bytes(buf, offset))
			offset += NetSnapshot.FULL_SIZE
	result["states"] = states
	return result


# --- Event packet: server → client (reliable) ---

static func pack_kill_event(killer_id: int, victim_id: int, weapon_idx: int, headshot: bool) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 6)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_EVENT
	buf[2] = EVT_KILL
	buf[3] = killer_id & 0xFF
	buf[4] = (killer_id >> 8) & 0xFF
	buf[5] = victim_id & 0xFF
	buf[6] = (victim_id >> 8) & 0xFF
	buf[7] = (weapon_idx & 0x7F) | (0x80 if headshot else 0)
	return buf


static func pack_spawn_event(peer_id: int, pos: Vector3) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 15)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_EVENT
	buf[2] = EVT_SPAWN
	buf[3] = peer_id & 0xFF
	buf[4] = (peer_id >> 8) & 0xFF
	# Position as 3 × i32 quantized
	var i := 5
	i = NetSnapshot._write_i32(buf, i, int(pos.x / NetConstants.POS_PRECISION))
	i = NetSnapshot._write_i32(buf, i, int(pos.y / NetConstants.POS_PRECISION))
	i = NetSnapshot._write_i32(buf, i, int(pos.z / NetConstants.POS_PRECISION))
	return buf


static func pack_hit_event(victim_id: int, damage: int, headshot: bool) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 5)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_EVENT
	buf[2] = EVT_HIT
	buf[3] = victim_id & 0xFF
	buf[4] = (victim_id >> 8) & 0xFF
	buf[5] = clampi(damage, 0, 255)
	buf[6] = 1 if headshot else 0
	return buf


static func pack_session_event(token: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 5)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_EVENT
	buf[2] = EVT_SESSION
	buf[3] = token & 0xFF
	buf[4] = (token >> 8) & 0xFF
	buf[5] = (token >> 16) & 0xFF
	buf[6] = (token >> 24) & 0xFF
	return buf


static func pack_server_msg_event(message: String) -> PackedByteArray:
	var msg_bytes := message.to_utf8_buffer()
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 3)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_EVENT
	buf[2] = EVT_SERVER_MSG
	buf[3] = msg_bytes.size() & 0xFF
	buf[4] = (msg_bytes.size() >> 8) & 0xFF
	buf.append_array(msg_bytes)
	return buf


static func pack_rejoin_request(token: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(HEADER_SIZE + 5)
	buf[0] = NetConstants.PROTOCOL_VERSION
	buf[1] = MSG_ADMIN
	buf[2] = ADMIN_REJOIN
	buf[3] = token & 0xFF
	buf[4] = (token >> 8) & 0xFF
	buf[5] = (token >> 16) & 0xFF
	buf[6] = (token >> 24) & 0xFF
	return buf
