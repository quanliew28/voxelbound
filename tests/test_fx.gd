extends RefCounted
## Phase 16 suite: procedural particle effects (one-shot emitters,
## block-colored debris, auto-free). Runs headless.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	await _check_emitters_spawn()
	await _check_auto_free()
	await _check_block_color()
	await _check_crystal_burst()
	print("SUITE fx: %d passed, %d failed" % [last_passed, _failed])
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


func _check_emitters_spawn() -> void:
	var fx := ParticleFX.new()
	tree.root.add_child(fx)
	await tree.physics_frame
	fx.block_break(Vector3(1, 2, 3), BlockRegistry.shared().get_id(&"STONE"))
	fx.block_place(Vector3(1, 2, 3))
	fx.sparks(Vector3(1, 2, 3))
	fx.damage_hit(Vector3(1, 2, 3))
	fx.crystal_sparkle(Vector3(1, 2, 3))
	fx.dust(Vector3(1, 2, 3))
	await tree.physics_frame
	var emitters := 0
	for child in fx.get_children():
		if child is GPUParticles3D:
			emitters += 1
	_check(emitters >= 6, "each effect spawns a particle emitter", "got %d" % emitters)
	fx.queue_free()
	await tree.physics_frame


func _check_auto_free() -> void:
	var fx := ParticleFX.new()
	tree.root.add_child(fx)
	await tree.physics_frame
	fx.sparks(Vector3.ZERO)
	await tree.physics_frame
	var before := fx.get_child_count()
	# wait past the emitter lifetime (0.3 + 0.6 margin)
	for i in 90:
		await tree.physics_frame
	var after := fx.get_child_count()
	_check(after < before, "one-shot emitters auto-free", "%d -> %d" % [before, after])
	fx.queue_free()
	await tree.physics_frame


func _check_block_color() -> void:
	var fx := ParticleFX.new()
	tree.root.add_child(fx)
	await tree.physics_frame
	var stone := BlockRegistry.shared().get_id(&"STONE")
	fx.block_break(Vector3.ZERO, stone)
	await tree.physics_frame
	var found := false
	for child in fx.get_children():
		if child is GPUParticles3D:
			var emitter := child as GPUParticles3D
			var mat := emitter.draw_pass_1.material as StandardMaterial3D
			if mat != null and mat.albedo_color.is_equal_approx(BlockRegistry.shared().get_color(stone)):
				found = true
	_check(found, "debris tinted with block color")
	fx.queue_free()
	await tree.physics_frame


func _check_crystal_burst() -> void:
	var fx := ParticleFX.new()
	tree.root.add_child(fx)
	await tree.physics_frame
	fx.block_break(Vector3.ZERO, BlockRegistry.shared().get_id(&"CRYSTAL"))
	await tree.physics_frame
	_check(fx.get_child_count() >= 2, "crystal break spawns double burst")
	fx.queue_free()
	await tree.physics_frame
