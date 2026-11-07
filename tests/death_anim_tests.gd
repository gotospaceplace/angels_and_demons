extends Node

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []
var cm: CharacterModel


func _ready() -> void:
	print("=== Death Animation Tests ===")
	print("Death state, animation trigger, deathcam visibility")
	print("")

	cm = CharacterModel.new()
	cm.name = "TestCharModel"
	add_child(cm)
	cm.setup("angels")

	test_death_duration_constant()
	test_not_dead_by_default()
	test_play_death_sets_flag()
	test_play_death_stops_anim_tree()
	test_play_death_idempotent()
	test_is_dead_getter()

	cm.queue_free()

	test_remote_player_apply_death()

	_print_summary()


func _pass(test_name: String, msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  PASS %s" % msg)


func _fail(test_name: String, msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  FAIL %s" % msg)


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


func test_death_duration_constant() -> void:
	if CharacterModel.DEATH_DURATION > 0.0 and CharacterModel.DEATH_DURATION <= 1.5:
		_pass("test_death_duration_constant",
			"DEATH_DURATION = %.1fs (within 0-1.5s range)" % CharacterModel.DEATH_DURATION)
	else:
		_fail("test_death_duration_constant",
			"DEATH_DURATION = %.1f, expected 0-1.5s" % CharacterModel.DEATH_DURATION)


func test_not_dead_by_default() -> void:
	if not cm._is_dead:
		_pass("test_not_dead_by_default",
			"character starts alive")
	else:
		_fail("test_not_dead_by_default",
			"_is_dead should be false initially")


func test_play_death_sets_flag() -> void:
	var cm2 := CharacterModel.new()
	cm2.name = "TestDeath"
	add_child(cm2)
	cm2.setup("angels")
	cm2.play_death()
	if cm2._is_dead:
		_pass("test_play_death_sets_flag",
			"play_death() sets _is_dead = true")
	else:
		_fail("test_play_death_sets_flag",
			"_is_dead still false after play_death()")
	cm2.queue_free()


func test_play_death_stops_anim_tree() -> void:
	var cm2 := CharacterModel.new()
	cm2.name = "TestDeathAnim"
	add_child(cm2)
	cm2.setup("angels")
	cm2.play_death()
	var tree_active := cm2.anim_tree != null and cm2.anim_tree.active
	if not tree_active:
		_pass("test_play_death_stops_anim_tree",
			"AnimationTree deactivated on death")
	else:
		_fail("test_play_death_stops_anim_tree",
			"AnimationTree still active after death")
	cm2.queue_free()


func test_play_death_idempotent() -> void:
	var cm2 := CharacterModel.new()
	cm2.name = "TestDeathIdem"
	add_child(cm2)
	cm2.setup("angels")
	cm2.play_death()
	cm2.play_death()
	if cm2._is_dead:
		_pass("test_play_death_idempotent",
			"double play_death() is safe")
	else:
		_fail("test_play_death_idempotent",
			"unexpected state after double play_death()")
	cm2.queue_free()


func test_is_dead_getter() -> void:
	var cm2 := CharacterModel.new()
	cm2.name = "TestDeadGetter"
	add_child(cm2)
	cm2.setup("angels")
	var before := cm2.is_dead()
	cm2.play_death()
	var after := cm2.is_dead()
	if not before and after:
		_pass("test_is_dead_getter",
			"is_dead() returns false then true")
	else:
		_fail("test_is_dead_getter",
			"before=%s after=%s" % [before, after])
	cm2.queue_free()


func test_remote_player_apply_death() -> void:
	const RemotePlayer = preload("res://client/scripts/remote_player.gd")
	var rp := Node3D.new()
	rp.set_script(RemotePlayer)
	rp.create(999)
	add_child(rp)
	rp.apply_death()
	var dead := rp.character_model._is_dead
	var label_hidden := not rp.name_label.visible
	if dead and label_hidden:
		_pass("test_remote_player_apply_death",
			"apply_death() triggers model death + hides label")
	else:
		_fail("test_remote_player_apply_death",
			"dead=%s label_hidden=%s" % [dead, label_hidden])
	rp.queue_free()
