class_name NetSnapshot
extends RefCounted

# PlayerState: ~33 bytes full
#   peer_id:    u16  (2)
#   tick:       u32  (4)
#   pos x/y/z:  i32×3 (12) — quantized to 0.01m
#   vel x/y/z:  i16×3 (6)  — quantized to 0.1 m/s
#   yaw:        u16  (2)
#   pitch:      i16  (2)
#   flags:      u8   (1)
#   hp:         u8   (1)
#   armor:      u8   (1)
#   weapon_idx: u8   (1)
#   ammo_mag:   u8   (1)

const FULL_SIZE := 33

# Flags bitmask
const FLAG_ON_GROUND := 0
const FLAG_IS_DUCKED := 1
const FLAG_IS_SCOPED := 2
const FLAG_IS_DEAD   := 3

# Delta changed-fields bitmask
const DELTA_POSITION   := 0
const DELTA_VELOCITY   := 1
const DELTA_YAW        := 2
const DELTA_PITCH      := 3
const DELTA_FLAGS      := 4
const DELTA_HP         := 5
const DELTA_ARMOR      := 6
const DELTA_WEAPON_AMMO := 7

var peer_id: int = 0
var tick: int = 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var flags: int = 0
var hp: int = 100
var armor: int = 0
var weapon_idx: int = 0
var ammo_mag: int = 0


func set_flag(bit: int, value: bool) -> void:
	if value:
		flags |= (1 << bit)
	else:
		flags &= ~(1 << bit)


func get_flag(bit: int) -> bool:
	return (flags & (1 << bit)) != 0


func to_full_bytes() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(FULL_SIZE)
	var i := 0
	# peer_id: u16
	buf[i] = peer_id & 0xFF; i += 1
	buf[i] = (peer_id >> 8) & 0xFF; i += 1
	# tick: u32
	buf[i] = tick & 0xFF; i += 1
	buf[i] = (tick >> 8) & 0xFF; i += 1
	buf[i] = (tick >> 16) & 0xFF; i += 1
	buf[i] = (tick >> 24) & 0xFF; i += 1
	# position: 3 × i32 (quantized)
	i = _write_i32(buf, i, int(position.x / NetConstants.POS_PRECISION))
	i = _write_i32(buf, i, int(position.y / NetConstants.POS_PRECISION))
	i = _write_i32(buf, i, int(position.z / NetConstants.POS_PRECISION))
	# velocity: 3 × i16 (quantized)
	i = _write_i16(buf, i, clampi(int(velocity.x / NetConstants.VEL_PRECISION), -32768, 32767))
	i = _write_i16(buf, i, clampi(int(velocity.y / NetConstants.VEL_PRECISION), -32768, 32767))
	i = _write_i16(buf, i, clampi(int(velocity.z / NetConstants.VEL_PRECISION), -32768, 32767))
	# yaw: u16
	var yaw_q := int(fmod(yaw, 360.0) * NetConstants.YAW_SCALE) & 0xFFFF
	buf[i] = yaw_q & 0xFF; i += 1
	buf[i] = (yaw_q >> 8) & 0xFF; i += 1
	# pitch: i16
	i = _write_i16(buf, i, clampi(int(pitch * NetConstants.PITCH_SCALE), -32768, 32767))
	# flags, hp, armor, weapon_idx, ammo_mag
	buf[i] = flags & 0xFF; i += 1
	buf[i] = clampi(hp, 0, 255); i += 1
	buf[i] = clampi(armor, 0, 255); i += 1
	buf[i] = weapon_idx & 0xFF; i += 1
	buf[i] = ammo_mag & 0xFF; i += 1
	return buf


static func from_full_bytes(buf: PackedByteArray, offset: int = 0) -> NetSnapshot:
	var s := NetSnapshot.new()
	var i := offset
	s.peer_id = buf[i] | (buf[i + 1] << 8); i += 2
	s.tick = buf[i] | (buf[i + 1] << 8) | (buf[i + 2] << 16) | (buf[i + 3] << 24); i += 4
	var px := _read_i32_s(buf, i); i += 4
	var py := _read_i32_s(buf, i); i += 4
	var pz := _read_i32_s(buf, i); i += 4
	s.position = Vector3(float(px), float(py), float(pz)) * NetConstants.POS_PRECISION
	var vx := _read_i16_s(buf, i); i += 2
	var vy := _read_i16_s(buf, i); i += 2
	var vz := _read_i16_s(buf, i); i += 2
	s.velocity = Vector3(float(vx), float(vy), float(vz)) * NetConstants.VEL_PRECISION
	var yaw_q := buf[i] | (buf[i + 1] << 8); i += 2
	s.yaw = float(yaw_q) / NetConstants.YAW_SCALE
	s.pitch = float(_read_i16_s(buf, i)) / NetConstants.PITCH_SCALE; i += 2
	s.flags = buf[i]; i += 1
	s.hp = buf[i]; i += 1
	s.armor = buf[i]; i += 1
	s.weapon_idx = buf[i]; i += 1
	s.ammo_mag = buf[i]; i += 1
	return s


func to_delta_bytes(base: NetSnapshot) -> PackedByteArray:
	var changed := 0
	var body := PackedByteArray()
	# Compare fields and build body
	if not _pos_eq(position, base.position):
		changed |= (1 << DELTA_POSITION)
		var idx := body.size()
		body.resize(idx + 12)
		_write_i32(body, idx, int(position.x / NetConstants.POS_PRECISION))
		_write_i32(body, idx + 4, int(position.y / NetConstants.POS_PRECISION))
		_write_i32(body, idx + 8, int(position.z / NetConstants.POS_PRECISION))
	if not _vel_eq(velocity, base.velocity):
		changed |= (1 << DELTA_VELOCITY)
		var idx := body.size()
		body.resize(idx + 6)
		_write_i16(body, idx, clampi(int(velocity.x / NetConstants.VEL_PRECISION), -32768, 32767))
		_write_i16(body, idx + 2, clampi(int(velocity.y / NetConstants.VEL_PRECISION), -32768, 32767))
		_write_i16(body, idx + 4, clampi(int(velocity.z / NetConstants.VEL_PRECISION), -32768, 32767))
	var yaw_q := int(fmod(yaw, 360.0) * NetConstants.YAW_SCALE) & 0xFFFF
	var base_yaw_q := int(fmod(base.yaw, 360.0) * NetConstants.YAW_SCALE) & 0xFFFF
	if yaw_q != base_yaw_q:
		changed |= (1 << DELTA_YAW)
		var idx := body.size()
		body.resize(idx + 2)
		body[idx] = yaw_q & 0xFF
		body[idx + 1] = (yaw_q >> 8) & 0xFF
	var pitch_q := clampi(int(pitch * NetConstants.PITCH_SCALE), -32768, 32767)
	var base_pitch_q := clampi(int(base.pitch * NetConstants.PITCH_SCALE), -32768, 32767)
	if pitch_q != base_pitch_q:
		changed |= (1 << DELTA_PITCH)
		var idx := body.size()
		body.resize(idx + 2)
		_write_i16(body, idx, pitch_q)
	if flags != base.flags:
		changed |= (1 << DELTA_FLAGS)
		body.append(flags & 0xFF)
	if hp != base.hp:
		changed |= (1 << DELTA_HP)
		body.append(clampi(hp, 0, 255))
	if armor != base.armor:
		changed |= (1 << DELTA_ARMOR)
		body.append(clampi(armor, 0, 255))
	if weapon_idx != base.weapon_idx or ammo_mag != base.ammo_mag:
		changed |= (1 << DELTA_WEAPON_AMMO)
		body.append(weapon_idx & 0xFF)
		body.append(ammo_mag & 0xFF)
	# Header: peer_id (2) + changed mask (1) + body
	var out := PackedByteArray()
	out.resize(3 + body.size())
	out[0] = peer_id & 0xFF
	out[1] = (peer_id >> 8) & 0xFF
	out[2] = changed
	for j in range(body.size()):
		out[3 + j] = body[j]
	return out


static func from_delta_bytes(buf: PackedByteArray, base: NetSnapshot, offset: int = 0) -> Array:
	# Returns [NetSnapshot, bytes_consumed]
	var s := NetSnapshot.new()
	s.peer_id = buf[offset] | (buf[offset + 1] << 8)
	var changed: int = buf[offset + 2]
	var i := offset + 3
	# Copy base state then overwrite changed fields
	s.tick = base.tick
	s.position = base.position
	s.velocity = base.velocity
	s.yaw = base.yaw
	s.pitch = base.pitch
	s.flags = base.flags
	s.hp = base.hp
	s.armor = base.armor
	s.weapon_idx = base.weapon_idx
	s.ammo_mag = base.ammo_mag
	if changed & (1 << DELTA_POSITION):
		var px := _read_i32_s(buf, i); i += 4
		var py := _read_i32_s(buf, i); i += 4
		var pz := _read_i32_s(buf, i); i += 4
		s.position = Vector3(float(px), float(py), float(pz)) * NetConstants.POS_PRECISION
	if changed & (1 << DELTA_VELOCITY):
		var vx := _read_i16_s(buf, i); i += 2
		var vy := _read_i16_s(buf, i); i += 2
		var vz := _read_i16_s(buf, i); i += 2
		s.velocity = Vector3(float(vx), float(vy), float(vz)) * NetConstants.VEL_PRECISION
	if changed & (1 << DELTA_YAW):
		var yaw_q := buf[i] | (buf[i + 1] << 8); i += 2
		s.yaw = float(yaw_q) / NetConstants.YAW_SCALE
	if changed & (1 << DELTA_PITCH):
		s.pitch = float(_read_i16_s(buf, i)) / NetConstants.PITCH_SCALE; i += 2
	if changed & (1 << DELTA_FLAGS):
		s.flags = buf[i]; i += 1
	if changed & (1 << DELTA_HP):
		s.hp = buf[i]; i += 1
	if changed & (1 << DELTA_ARMOR):
		s.armor = buf[i]; i += 1
	if changed & (1 << DELTA_WEAPON_AMMO):
		s.weapon_idx = buf[i]; i += 1
		s.ammo_mag = buf[i]; i += 1
	return [s, i - offset]


func duplicate_state() -> NetSnapshot:
	var s := NetSnapshot.new()
	s.peer_id = peer_id
	s.tick = tick
	s.position = position
	s.velocity = velocity
	s.yaw = yaw
	s.pitch = pitch
	s.flags = flags
	s.hp = hp
	s.armor = armor
	s.weapon_idx = weapon_idx
	s.ammo_mag = ammo_mag
	return s


# --- Helpers ---

static func _pos_eq(a: Vector3, b: Vector3) -> bool:
	return int(a.x / NetConstants.POS_PRECISION) == int(b.x / NetConstants.POS_PRECISION) \
		and int(a.y / NetConstants.POS_PRECISION) == int(b.y / NetConstants.POS_PRECISION) \
		and int(a.z / NetConstants.POS_PRECISION) == int(b.z / NetConstants.POS_PRECISION)


static func _vel_eq(a: Vector3, b: Vector3) -> bool:
	return clampi(int(a.x / NetConstants.VEL_PRECISION), -32768, 32767) == clampi(int(b.x / NetConstants.VEL_PRECISION), -32768, 32767) \
		and clampi(int(a.y / NetConstants.VEL_PRECISION), -32768, 32767) == clampi(int(b.y / NetConstants.VEL_PRECISION), -32768, 32767) \
		and clampi(int(a.z / NetConstants.VEL_PRECISION), -32768, 32767) == clampi(int(b.z / NetConstants.VEL_PRECISION), -32768, 32767)


static func _write_i32(buf: PackedByteArray, idx: int, val: int) -> int:
	buf[idx] = val & 0xFF
	buf[idx + 1] = (val >> 8) & 0xFF
	buf[idx + 2] = (val >> 16) & 0xFF
	buf[idx + 3] = (val >> 24) & 0xFF
	return idx + 4


static func _write_i16(buf: PackedByteArray, idx: int, val: int) -> int:
	buf[idx] = val & 0xFF
	buf[idx + 1] = (val >> 8) & 0xFF
	return idx + 2


static func _read_i32_s(buf: PackedByteArray, idx: int) -> int:
	var v := buf[idx] | (buf[idx + 1] << 8) | (buf[idx + 2] << 16) | (buf[idx + 3] << 24)
	if v >= 2147483648:
		v -= 4294967296
	return v


static func _read_i16_s(buf: PackedByteArray, idx: int) -> int:
	var v := buf[idx] | (buf[idx + 1] << 8)
	if v >= 32768:
		v -= 65536
	return v
