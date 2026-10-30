extends Node

const POOL_SIZE := 8

var sounds: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []

var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL := 0.4
const FOOTSTEP_RUN_INTERVAL := 0.32
const FOOTSTEP_SPEED_THRESHOLD := 0.5


func _ready() -> void:
	sounds["knife_slash"] = load("res://assets/sounds/knife_slash.mp3")
	sounds["usp_fire"] = load("res://assets/sounds/usp_fire.mp3")
	sounds["ak47_fire"] = load("res://assets/sounds/ak47_fire.mp3")
	sounds["m4a1_fire"] = load("res://assets/sounds/m4a1_fire.wav")
	sounds["awp_fire"] = load("res://assets/sounds/awp_fire.mp3")
	sounds["footstep"] = load("res://assets/sounds/footstep.ogg")
	sounds["hurt"] = load("res://assets/sounds/Hurt.ogg")
	sounds["death"] = load("res://assets/sounds/Death.wav")
	sounds["hit_confirm"] = load("res://assets/sounds/hit_confirm.ogg")
	sounds["headshot"] = load("res://assets/sounds/headshot.ogg")
	sounds["reload"] = load("res://assets/sounds/reload.mp3")
	sounds["weapon_switch"] = load("res://assets/sounds/weapon_Switch.mp3")

	for i in POOL_SIZE:
		var asp := AudioStreamPlayer.new()
		asp.bus = "Master"
		add_child(asp)
		pool.append(asp)


func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(sound_name):
		return
	for asp in pool:
		if not asp.playing:
			asp.stream = sounds[sound_name]
			asp.volume_db = volume_db
			asp.pitch_scale = pitch
			asp.play()
			return


const WEAPON_SOUNDS := ["knife_slash", "usp_fire", "ak47_fire", "m4a1_fire", "awp_fire"]

func play_fire(weapon_idx: int) -> void:
	if weapon_idx < 0 or weapon_idx >= WEAPON_SOUNDS.size():
		return
	play(WEAPON_SOUNDS[weapon_idx])


func play_footstep() -> void:
	var pitch := randf_range(0.85, 1.15)
	play("footstep", -6.0, pitch)


func play_hit_confirm(headshot: bool) -> void:
	if headshot:
		play("headshot", 2.0)
	else:
		play("hit_confirm")


func play_hurt() -> void:
	play("hurt")


func play_death() -> void:
	play("death")


func play_reload() -> void:
	play("reload", -3.0)


func play_weapon_switch() -> void:
	play("weapon_switch", -3.0)


func update_footsteps(delta: float, on_ground: bool, speed: float, on_ladder: bool) -> void:
	if not on_ground and not on_ladder:
		footstep_timer = 0.0
		return
	if speed < FOOTSTEP_SPEED_THRESHOLD:
		footstep_timer = 0.0
		return

	var interval := FOOTSTEP_RUN_INTERVAL if speed > 3.0 else FOOTSTEP_INTERVAL
	footstep_timer += delta
	if footstep_timer >= interval:
		footstep_timer -= interval
		play_footstep()
