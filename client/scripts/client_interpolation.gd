extends Node3D

const RemotePlayer = preload("res://client/scripts/remote_player.gd")
const STATE_BUFFER_SIZE := 32

var remote_players: Dictionary = {}
var server_time: float = 0.0
var interp_delay: float = NetConstants.INTERP_DELAY_SEC
var my_peer_id: int = 0


func on_snapshot(snapshot_result: Dictionary, p_my_peer_id: int) -> void:
	my_peer_id = p_my_peer_id
	var tick: int = snapshot_result["tick"]
	server_time = float(tick) * NetConstants.TICK_INTERVAL

	var active_peers := {}
	for state in snapshot_result["states"]:
		if state.peer_id == my_peer_id:
			continue
		active_peers[state.peer_id] = true

		if not remote_players.has(state.peer_id):
			_spawn_remote(state.peer_id)

		var rp: Dictionary = remote_players[state.peer_id]
		rp["states"].append({
			"time": float(tick) * NetConstants.TICK_INTERVAL,
			"position": state.position,
			"yaw": state.yaw,
			"pitch": state.pitch,
			"is_ducked": state.get_flag(NetSnapshot.FLAG_IS_DUCKED),
			"is_dead": state.get_flag(NetSnapshot.FLAG_IS_DEAD),
		})
		if rp["states"].size() > STATE_BUFFER_SIZE:
			rp["states"].pop_front()

	for pid in remote_players.keys():
		if not active_peers.has(pid):
			_despawn_remote(pid)


func _process(delta: float) -> void:
	server_time += delta
	var render_time := server_time - interp_delay

	for rp in remote_players.values():
		_interpolate(rp, render_time)


func _interpolate(rp: Dictionary, render_time: float) -> void:
	var states: Array = rp["states"]
	if states.is_empty():
		return

	if states.size() == 1:
		var s: Dictionary = states[0]
		rp["node"].apply_state(s["position"], s["yaw"], s["pitch"], s["is_ducked"])
		return

	var a: Dictionary = {}
	var b: Dictionary = {}

	for i in range(states.size() - 1):
		if states[i]["time"] <= render_time and states[i + 1]["time"] >= render_time:
			a = states[i]
			b = states[i + 1]
			break

	if a.is_empty():
		if render_time < states[0]["time"]:
			var s: Dictionary = states[0]
			rp["node"].apply_state(s["position"], s["yaw"], s["pitch"], s["is_ducked"])
			return

		a = states[states.size() - 2]
		b = states[states.size() - 1]
		var past: float = render_time - b["time"]
		if past > NetConstants.INTERP_MAX_EXTRAPOLATE_MS / 1000.0:
			rp["node"].apply_state(b["position"], b["yaw"], b["pitch"], b["is_ducked"])
			return

	var duration: float = b["time"] - a["time"]
	var t := 0.0
	if duration > 0.0001:
		t = clampf((render_time - a["time"]) / duration, 0.0, 1.5)

	var pos: Vector3 = a["position"].lerp(b["position"], t)
	var yaw_rad := lerp_angle(deg_to_rad(a["yaw"]), deg_to_rad(b["yaw"]), t)
	var pitch_val: float = lerpf(a["pitch"], b["pitch"], t)
	var ducked: bool = b["is_ducked"] if t >= 0.5 else a["is_ducked"]

	rp["node"].apply_state(pos, rad_to_deg(yaw_rad), pitch_val, ducked)
	rp["node"].visible = not b["is_dead"]


func _spawn_remote(pid: int) -> void:
	var node := Node3D.new()
	node.set_script(RemotePlayer)
	node.create(pid)
	add_child(node)
	remote_players[pid] = {"node": node, "states": []}
	print("[Interp] Spawned remote player %d" % pid)


func _despawn_remote(pid: int) -> void:
	if remote_players.has(pid):
		remote_players[pid]["node"].queue_free()
		remote_players.erase(pid)
		print("[Interp] Despawned remote player %d" % pid)


func get_remote_count() -> int:
	return remote_players.size()
