class_name NetInput
extends RefCounted

# InputCommand: 10 bytes packed
#   tick:    u32 (4 bytes)
#   buttons: u16 (2 bytes)
#   yaw:     u16 (2 bytes)
#   pitch:   i16 (2 bytes)

const SIZE := 10

# Button bitmask positions
const BIT_FORWARD  := 0
const BIT_BACK     := 1
const BIT_LEFT     := 2
const BIT_RIGHT    := 3
const BIT_JUMP     := 4
const BIT_DUCK     := 5
const BIT_FIRE     := 6
const BIT_FIRE2    := 7
const BIT_RELOAD   := 8
const BIT_WEAPON1  := 9
const BIT_WEAPON2  := 10
const BIT_WEAPON3  := 11
const BIT_WEAPON4  := 12
const BIT_USE      := 13

var tick: int = 0
var buttons: int = 0
var yaw: float = 0.0    # Degrees [0, 360)
var pitch: float = 0.0  # Degrees [-90, 90]


static func create(p_tick: int, p_buttons: int, p_yaw: float, p_pitch: float) -> NetInput:
	var cmd := NetInput.new()
	cmd.tick = p_tick
	cmd.buttons = p_buttons
	cmd.yaw = p_yaw
	cmd.pitch = p_pitch
	return cmd


func has_button(bit: int) -> bool:
	return (buttons & (1 << bit)) != 0


func set_button(bit: int, value: bool) -> void:
	if value:
		buttons |= (1 << bit)
	else:
		buttons &= ~(1 << bit)


func get_move_dir() -> Vector2:
	var x := 0.0
	var y := 0.0
	if has_button(BIT_FORWARD):
		y -= 1.0
	if has_button(BIT_BACK):
		y += 1.0
	if has_button(BIT_LEFT):
		x -= 1.0
	if has_button(BIT_RIGHT):
		x += 1.0
	var v := Vector2(x, y)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


# --- Serialization ---

func to_bytes() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(SIZE)
	# tick: u32 little-endian
	buf[0] = tick & 0xFF
	buf[1] = (tick >> 8) & 0xFF
	buf[2] = (tick >> 16) & 0xFF
	buf[3] = (tick >> 24) & 0xFF
	# buttons: u16 little-endian
	buf[4] = buttons & 0xFF
	buf[5] = (buttons >> 8) & 0xFF
	# yaw: float → u16 [0, 65535]
	var yaw_q := int(fmod(yaw, 360.0) * NetConstants.YAW_SCALE) & 0xFFFF
	buf[6] = yaw_q & 0xFF
	buf[7] = (yaw_q >> 8) & 0xFF
	# pitch: float → i16 [-16384, 16384]
	var pitch_q := clampi(int(pitch * NetConstants.PITCH_SCALE), -32768, 32767)
	buf[8] = pitch_q & 0xFF
	buf[9] = (pitch_q >> 8) & 0xFF
	return buf


static func from_bytes(buf: PackedByteArray, offset: int = 0) -> NetInput:
	var cmd := NetInput.new()
	cmd.tick = buf[offset] | (buf[offset + 1] << 8) | (buf[offset + 2] << 16) | (buf[offset + 3] << 24)
	cmd.buttons = buf[offset + 4] | (buf[offset + 5] << 8)
	var yaw_q := buf[offset + 6] | (buf[offset + 7] << 8)
	cmd.yaw = float(yaw_q) / NetConstants.YAW_SCALE
	var pitch_raw := buf[offset + 8] | (buf[offset + 9] << 8)
	if pitch_raw >= 32768:
		pitch_raw -= 65536
	cmd.pitch = float(pitch_raw) / NetConstants.PITCH_SCALE
	return cmd


func duplicate() -> NetInput:
	return NetInput.create(tick, buttons, yaw, pitch)
