extends RefCounted
## Phase 4 suite: VoxelRaycaster DDA + player block interaction.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_axis_hits()
	_check_miss_and_range()
	_check_inside_solid()
	_check_overlap_guard()
	_check_interaction()
	print("SUITE raycaster: %d passed, %d failed" % [last_passed, _failed])
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


func _check_axis_hits() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	# +x ray: hits the -x face of (0,0,0)
	var hx := VoxelRaycaster.cast_ray(world, Vector3(-5, 0.5, 0.5), Vector3(1, 0, 0), 10.0)
	_check(not hx.is_empty() and hx.block_pos == Vector3i(0, 0, 0), "ray +x hits block", "got %s" % str(hx))
	_check(hx.prev_pos == Vector3i(-1, 0, 0), "ray +x prev is placement cell")
	_check(hx.normal.is_equal_approx(Vector3(-1, 0, 0)), "ray +x normal -x")
	_check(absf(hx.distance - 5.0) < 0.001, "ray +x distance", "got %f" % hx.distance)
	# -y ray: hits the TOP face
	var hy := VoxelRaycaster.cast_ray(world, Vector3(0.5, 4, 0.5), Vector3(0, -1, 0), 10.0)
	_check(not hy.is_empty() and hy.block_pos == Vector3i(0, 0, 0), "ray -y hits block")
	_check(hy.normal.is_equal_approx(Vector3(0, 1, 0)), "ray -y normal +y")
	_check(hy.prev_pos == Vector3i(0, 1, 0), "ray -y prev above block")
	# +z ray
	var hz := VoxelRaycaster.cast_ray(world, Vector3(0.5, 0.5, -5), Vector3(0, 0, 1), 10.0)
	_check(not hz.is_empty() and hz.block_pos == Vector3i(0, 0, 0), "ray +z hits block")
	_check(hz.normal.is_equal_approx(Vector3(0, 0, -1)), "ray +z normal -z")
	# nearest of two blocks
	var world2 := VoxelWorld.new()
	var chunk2 := VoxelChunk.new(Vector3i.ZERO)
	chunk2.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	chunk2.set_block_generated(Vector3i(3, 0, 0), reg.get_id(&"STONE"))
	world2.add_chunk(chunk2)
	var h := VoxelRaycaster.cast_ray(world2, Vector3(-5, 0.5, 0.5), Vector3(1, 0, 0), 10.0)
	_check(h.block_pos == Vector3i(0, 0, 0), "ray nearest block wins", "got %s" % str(h.block_pos))
	world2.free()
	world.free()


func _check_miss_and_range() -> void:
	var reg := BlockRegistry.shared()
	# empty world -> miss
	var empty := VoxelWorld.new()
	var h := VoxelRaycaster.cast_ray(empty, Vector3(0, 0, 0), Vector3(1, 0, 0), 10.0)
	_check(h.is_empty(), "ray empty world misses")
	empty.free()
	# block beyond max distance -> miss
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	var far := VoxelRaycaster.cast_ray(world, Vector3(-10, 0.5, 0.5), Vector3(1, 0, 0), 5.0)
	_check(far.is_empty(), "ray beyond range misses")
	# zero-length-ish direction (axis-aligned degenerate handled)
	var dx := VoxelRaycaster.cast_ray(world, Vector3(-5, 0.5, 0.5), Vector3(0.0001, 1, 0.0001), 30.0)
	_check(dx.is_empty(), "ray steep direction no false hit", "got %s" % str(dx))
	world.free()


func _check_inside_solid() -> void:
	# origin inside a solid cell: origin cell is skipped, next solid hit
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	chunk.set_block_generated(Vector3i(1, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	var h := VoxelRaycaster.cast_ray(world, Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), 10.0)
	_check(not h.is_empty() and h.block_pos == Vector3i(1, 0, 0), "ray inside solid skips origin cell", "got %s" % str(h))
	# inside a lone block with nothing beyond -> miss
	var world2 := VoxelWorld.new()
	var chunk2 := VoxelChunk.new(Vector3i.ZERO)
	chunk2.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world2.add_chunk(chunk2)
	var h2 := VoxelRaycaster.cast_ray(world2, Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), 10.0)
	_check(h2.is_empty(), "ray inside lone block misses")
	world.free()
	world2.free()


func _check_overlap_guard() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.global_position = Vector3(0, 1.0, 0)  # feet at y=1, capsule 1..2.8
	# the cell the body occupies (0,1,0) must be rejected
	_check(player.cell_overlaps_player(Vector3i(0, 1, 0)), "overlap: body cell rejected")
	_check(player.cell_overlaps_player(Vector3i(0, 2, 0)), "overlap: head cell rejected")
	_check(player.cell_overlaps_player(Vector3i(1, 1, 0)), "overlap: adjacent side cell rejected")
	# block below feet and far cells accepted
	_check(not player.cell_overlaps_player(Vector3i(0, 0, 0)), "overlap: below-feet cell allowed")
	_check(not player.cell_overlaps_player(Vector3i(0, 1, 3)), "overlap: distant cell allowed")
	# crouched: capsule shrinks -> head cell no longer overlaps
	player.simulate_for_test(Vector2.ZERO, false, true, false)
	for i in 30:
		await tree.physics_frame
	_check(not player.cell_overlaps_player(Vector3i(0, 2, 0)), "overlap: crouched head cell allowed")
	player.queue_free()
	await tree.physics_frame


func _check_interaction() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	world.name = "W"
	tree.root.add_child(world)
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	world.rebuild_all_dirty()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)  # keep the test player exactly where we put it
	player.global_position = Vector3(0, 2.5, 0)
	player.world = world
	player.selected_block_id = reg.get_id(&"GRASS")
	var head := player.get_node("Head") as Node3D
	head.rotation.x = -PI / 2  # look straight down at the stone
	# place: ray hits stone at (0,0,0), placement cell (0,1,0) is above it
	player.try_place()
	_check(world.get_block(Vector3i(0, 1, 0)) == reg.get_id(&"GRASS"), "interact: place fills air cell", "got %d" % world.get_block(Vector3i(0, 1, 0)))
	# next place: ray hits the grass, target (0,2,0) overlaps the player body -> rejected
	player.try_place()
	_check(world.get_block(Vector3i(0, 2, 0)) == BlockRegistry.AIR_ID, "interact: no placement inside player")
	# mine the grass, then the stone
	player.try_mine()
	_check(world.get_block(Vector3i(0, 1, 0)) == BlockRegistry.AIR_ID, "interact: mining removes grass")
	player.try_mine()
	_check(world.get_block(Vector3i(0, 0, 0)) == BlockRegistry.AIR_ID, "interact: mining removes stone")
	# no world -> no crash
	player.world = null
	player.try_mine()
	player.try_place()
	player.queue_free()
	world.queue_free()
	await tree.physics_frame
