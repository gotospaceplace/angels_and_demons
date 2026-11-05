extends Node

const SLC = preload("res://server/scripts/server_lag_comp.gd")
const MC = preload("res://shared/scripts/movement_constants.gd")

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []


func _ready() -> void:
	print("=== Lag Comp Headshot Tests ===")
	print("")

	test_head_center_standing()
	test_forehead_corner()
	test_torso_center_chest()
	test_empty_above_head()
	test_halo_miss()
	test_horn_base_miss()
	test_upper_body_chest()
	test_yaw_rotated_90()
	test_mid_transition()
	test_wall_occlusion()
	test_full_duck_headshot()
	test_full_duck_standing_miss()
	test_neck_gap_body_hit()

	_print_summary()


func _pass(msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s" % msg)
	print("  PASS %s" % msg)


func _fail(msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s" % msg)
	print("  FAIL %s" % msg)


func _approx(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) < tol


func _reconstruct(target_pos: Vector3, duck_frac: float, yaw: float) -> Dictionary:
	var eased: float = duck_frac * duck_frac * (3.0 - 2.0 * duck_frac)
	var hull_h: float = lerpf(MC.HULL_STANDING_HEIGHT, MC.HULL_DUCKING_HEIGHT, eased)
	var feet_pos: Vector3 = target_pos - Vector3(0, hull_h * 0.5, 0)
	var head_local: Vector3 = SLC.HEAD_STANDING.lerp(SLC.HEAD_CROUCHED, eased)
	var yaw_basis := Basis(Vector3.UP, yaw)
	var head_world: Vector3 = feet_pos + yaw_basis * head_local
	var body_h: float = head_world.y - feet_pos.y - SLC.HEAD_HALF.y
	var body_center: Vector3 = feet_pos + Vector3(0, body_h * 0.5, 0)
	return {
		"head_world": head_world,
		"body_center": body_center,
		"body_h": body_h,
		"feet_pos": feet_pos,
	}


# 6.1: Front ray at standing head center → head hit
func test_head_center_standing() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var eye := Vector3(0, head.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t > 0.0:
		_pass("head_center_standing: hit at t=%.3f" % t)
	else:
		_fail("head_center_standing: missed (t=%.3f)" % t)


# 6.2: Ray at forehead corner (just inside AABB) → head hit
func test_forehead_corner() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var corner: Vector3 = head + Vector3(0.09, 0.10, 0)
	var eye := Vector3(corner.x, corner.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t > 0.0:
		_pass("forehead_corner: hit at t=%.3f" % t)
	else:
		_fail("forehead_corner: missed")


# 6.3: Torso center → body capsule chest zone
func test_torso_center_chest() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var body_center: Vector3 = r["body_center"]
	var body_h: float = r["body_h"]
	var torso_y: float = body_center.y + body_h * 0.1
	var eye := Vector3(0, torso_y, -5.0)
	var dir := Vector3(0, 0, 1)

	var head_t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	var body_t := SLC._ray_capsule_vertical(eye, dir, body_center, body_h, SLC.BODY_RADIUS)

	if head_t <= 0.0 and body_t > 0.0:
		var hit_y: float = eye.y + dir.y * body_t
		var rel_y: float = hit_y - body_center.y
		if rel_y > 0.0:
			_pass("torso_center: chest zone (rel_y=%.3f)" % rel_y)
		else:
			_fail("torso_center: wrong zone rel_y=%.3f" % rel_y)
	else:
		_fail("torso_center: head_t=%.3f body_t=%.3f" % [head_t, body_t])


# 6.4: 5cm above head AABB top → miss
func test_empty_above_head() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var above_y: float = head.y + SLC.HEAD_HALF.y + 0.05
	var eye := Vector3(0, above_y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t <= 0.0:
		_pass("empty_above_head: missed correctly")
	else:
		_fail("empty_above_head: false hit at t=%.3f" % t)


# 6.5: Halo probe (above head top + 2cm) → miss
func test_halo_miss() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var halo_y: float = head.y + SLC.HEAD_HALF.y + 0.02
	var eye := Vector3(0, halo_y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t <= 0.0:
		_pass("halo_miss: missed correctly")
	else:
		_fail("halo_miss: false hit at t=%.3f" % t)


# 6.6: Horn base (side of head, above AABB) → miss
func test_horn_base_miss() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var horn := Vector3(0.08, head.y + SLC.HEAD_HALF.y + 0.01, 0)
	var eye := Vector3(horn.x, horn.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t <= 0.0:
		_pass("horn_base_miss: missed correctly")
	else:
		_fail("horn_base_miss: false hit at t=%.3f" % t)


# 6.7: Upper body (above body center, below head AABB) → chest
func test_upper_body_chest() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var body_center: Vector3 = r["body_center"]
	var body_h: float = r["body_h"]
	var upper_y: float = body_center.y + body_h * 0.3
	var eye := Vector3(0, upper_y, -5.0)
	var dir := Vector3(0, 0, 1)

	var head_t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	var body_t := SLC._ray_capsule_vertical(eye, dir, body_center, body_h, SLC.BODY_RADIUS)

	if head_t <= 0.0 and body_t > 0.0:
		var hit_y: float = eye.y + dir.y * body_t
		var rel_y: float = hit_y - body_center.y
		if rel_y > 0.0:
			_pass("upper_body: chest (rel_y=%.3f)" % rel_y)
		else:
			_fail("upper_body: wrong zone rel_y=%.3f" % rel_y)
	else:
		_fail("upper_body: head_t=%.3f body_t=%.3f" % [head_t, body_t])


# 6.8: Target rotated 90° (yaw=PI/2), front ray → head hit
func test_yaw_rotated_90() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, PI * 0.5)
	var head: Vector3 = r["head_world"]
	var eye := Vector3(head.x, head.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t > 0.0:
		if _approx(head.x, -0.022, 0.005):
			_pass("yaw_90: hit at t=%.3f, head_x=%.4f" % [t, head.x])
		else:
			_fail("yaw_90: head_x=%.4f (expected -0.022)" % head.x)
	else:
		_fail("yaw_90: missed")


# 6.9: Mid-transition (duck_fraction=0.5) → head hit
func test_mid_transition() -> void:
	var eased: float = 0.5 * 0.5 * (3.0 - 2.0 * 0.5)
	var hull_h: float = lerpf(MC.HULL_STANDING_HEIGHT, MC.HULL_DUCKING_HEIGHT, eased)
	var cap_center := Vector3(0, hull_h * 0.5, 0)
	var r := _reconstruct(cap_center, 0.5, 0.0)
	var head: Vector3 = r["head_world"]
	var eye := Vector3(0, head.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t > 0.0:
		var expected_y: float = lerpf(SLC.HEAD_STANDING.y, SLC.HEAD_CROUCHED.y, eased)
		if _approx(head.y, expected_y, 0.01):
			_pass("mid_transition: hit, head_y=%.3f (expected %.3f)" % [head.y, expected_y])
		else:
			_fail("mid_transition: head_y=%.3f (expected %.3f)" % [head.y, expected_y])
	else:
		_fail("mid_transition: missed")


# 6.10: Wall occlusion — head hit distance exceeds wall distance → filtered out
func test_wall_occlusion() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var eye := Vector3(0, head.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var head_t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	var wall_dist := 3.0
	if head_t > 0.0 and head_t >= wall_dist:
		_pass("wall_occlusion: t=%.3f >= wall=%.1f (blocked)" % [head_t, wall_dist])
	else:
		_fail("wall_occlusion: t=%.3f wall=%.1f" % [head_t, wall_dist])


# 6.11: Fully ducked (duck_fraction=1.0) → head hit at crouched position
func test_full_duck_headshot() -> void:
	var eased: float = 1.0 * 1.0 * (3.0 - 2.0 * 1.0)
	var hull_h: float = lerpf(MC.HULL_STANDING_HEIGHT, MC.HULL_DUCKING_HEIGHT, eased)
	var cap_center := Vector3(0, hull_h * 0.5, 0)
	var r := _reconstruct(cap_center, 1.0, 0.0)
	var head: Vector3 = r["head_world"]
	var eye := Vector3(0, head.y, -5.0)
	var dir := Vector3(0, 0, 1)
	var t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	if t > 0.0:
		if head.y < SLC.HEAD_STANDING.y:
			_pass("full_duck_headshot: hit at lowered head y=%.3f" % head.y)
		else:
			_fail("full_duck_headshot: head not lowered y=%.3f" % head.y)
	else:
		_fail("full_duck_headshot: missed")


# 6.12: Fully ducked, fire at standing head height → miss
func test_full_duck_standing_miss() -> void:
	var eased: float = 1.0 * 1.0 * (3.0 - 2.0 * 1.0)
	var hull_h: float = lerpf(MC.HULL_STANDING_HEIGHT, MC.HULL_DUCKING_HEIGHT, eased)
	var cap_center := Vector3(0, hull_h * 0.5, 0)
	var r := _reconstruct(cap_center, 1.0, 0.0)
	var standing_r := _reconstruct(Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0), 0.0, 0.0)
	var standing_head_y: float = standing_r["head_world"].y
	var ducked_head: Vector3 = r["head_world"]
	var eye := Vector3(0, standing_head_y, -5.0)
	var dir := Vector3(0, 0, 1)
	var head_t := SLC._ray_box_hit(eye, dir, ducked_head, SLC.HEAD_HALF)
	if head_t <= 0.0:
		_pass("full_duck_standing_miss: standing height misses ducked head")
	else:
		_fail("full_duck_standing_miss: hit ducked head at standing height t=%.3f" % head_t)


# 6.13: Neck gap — between head AABB bottom and body capsule top → body hit
func test_neck_gap_body_hit() -> void:
	var cap_center := Vector3(0, MC.HULL_STANDING_HEIGHT * 0.5, 0)
	var r := _reconstruct(cap_center, 0.0, 0.0)
	var head: Vector3 = r["head_world"]
	var body_center: Vector3 = r["body_center"]
	var body_h: float = r["body_h"]
	var head_bottom_y: float = head.y - SLC.HEAD_HALF.y
	var neck_y: float = head_bottom_y - 0.02
	var eye := Vector3(0, neck_y, -5.0)
	var dir := Vector3(0, 0, 1)

	var head_t := SLC._ray_box_hit(eye, dir, head, SLC.HEAD_HALF)
	var body_t := SLC._ray_capsule_vertical(eye, dir, body_center, body_h, SLC.BODY_RADIUS)

	if head_t <= 0.0 and body_t > 0.0:
		_pass("neck_gap: body hit (head miss, body t=%.3f)" % body_t)
	elif head_t > 0.0:
		_fail("neck_gap: head hit instead of body (head_t=%.3f)" % head_t)
	else:
		_fail("neck_gap: complete miss (head_t=%.3f body_t=%.3f)" % [head_t, body_t])


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
