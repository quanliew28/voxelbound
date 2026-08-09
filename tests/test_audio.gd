extends RefCounted
## Phase 15 suite: procedural audio synthesis (pure sample recipes) +
## AudioManager playback lifecycle. Runs headless.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_sample_lengths()
	_check_sample_bounds()
	_check_distinctness()
	_check_oneshot_lifecycle()
	_check_ambient()
	print("SUITE audio: %d passed, %d failed" % [last_passed, _failed])
	return _failed


func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		last_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		var msg := "FAIL: " + name
		if not detail.is_empty():
			msg += " -- " + detail
		print(msg)


func _expect_duration(samples: PackedFloat32Array, seconds: float, name: String) -> void:
	var expected := int(seconds * Synth.SAMPLE_RATE)
	var tol := expected / 3  # recipes may append/trim slightly
	_check(absf(samples.size() - expected) <= tol, name,
		"got %d want ~%d" % [samples.size(), expected])


func _check_sample_lengths() -> void:
	_expect_duration(Synth.footstep(), 0.06, "footstep duration")
	_expect_duration(Synth.block_place(), 0.08, "block_place duration")
	_expect_duration(Synth.jump(), 0.12, "jump duration")
	_expect_duration(Synth.player_damage(), 0.15, "player_damage duration")
	_expect_duration(Synth.melee_hit(), 0.15, "melee_hit duration")
	_expect_duration(Synth.creature_hurt(), 0.2, "creature_hurt duration")
	_expect_duration(Synth.pickup(), 0.1, "pickup duration")
	_expect_duration(Synth.ui_click(), 0.03, "ui_click duration")
	_expect_duration(Synth.ambient_wind(), 4.0, "ambient wind duration")
	_check(Synth.block_break().size() > Synth.footstep().size(), "block_break is a longer crack")


func _check_sample_bounds() -> void:
	var all: Array[PackedFloat32Array] = [
		Synth.footstep(), Synth.block_break(), Synth.block_place(), Synth.jump(),
		Synth.player_damage(), Synth.melee_hit(), Synth.creature_hurt(),
		Synth.pickup(), Synth.ui_click(), Synth.ambient_wind(),
	]
	for samples in all:
		for v in samples:
			if v < -1.0 or v > 1.0:
				_check(false, "samples clamped to [-1, 1]", "v=%f" % v)
				return
	_check(true, "all recipes clamp to [-1, 1]")


func _check_distinctness() -> void:
	_check(Synth.footstep() != Synth.block_place(), "footstep distinct from place")
	_check(Synth.player_damage() != Synth.pickup(), "damage distinct from pickup")
	_check(Synth.ambient_wind() != Synth.footstep(), "ambient distinct from footstep")


func _check_oneshot_lifecycle() -> void:
	var manager := AudioManager.new()
	tree.root.add_child(manager)
	await tree.physics_frame
	manager.footstep()
	_check(manager._oneshots.size() == 1, "oneshot queued")
	await tree.physics_frame
	await tree.physics_frame
	manager._process(0.1)
	manager._process(0.1)
	_check(manager._oneshots.is_empty(), "oneshot drained and freed")
	manager.queue_free()
	await tree.physics_frame


func _check_ambient() -> void:
	var manager := AudioManager.new()
	tree.root.add_child(manager)
	await tree.physics_frame
	manager.start_ambient()
	_check(manager._ambient_active, "ambient active after start")
	_check(manager._ambient_player != null, "ambient player created")
	manager._process(0.1)
	manager.stop_ambient()
	_check(not manager._ambient_active, "ambient stops")
	manager.queue_free()
	await tree.physics_frame
