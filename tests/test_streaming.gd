extends RefCounted
## Phase 6 suite: ChunkManager streaming (load, unload, threading, determinism).
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

const SEED: int = 777

func run() -> int:
	await _check_stream_load()
	await _check_stream_unload()
	await _check_stream_determinism()
	await _check_mesh_nodes_freed()
	print("SUITE streaming: %d passed, %d failed" % [last_passed, _failed])
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


func _make_world() -> VoxelWorld:
	var world := VoxelWorld.new()
	world.name = "W"
	world.world_seed = SEED
	world.generator = VoxelGenerator.new(SEED)
	tree.root.add_child(world)
	return world


func _make_manager(world: VoxelWorld) -> ChunkManager:
	var cm := ChunkManager.new()
	cm.name = "ChunkManager"
	cm.load_radius_xz = 2
	cm.unload_radius_xz = 4
	cm.top_chunk_y = 2
	cm.gen_budget_per_frame = 4
	cm.max_in_flight = 8
	world.add_child(cm)
	cm.world = world
	return cm


func _check_stream_load() -> void:
	var world := _make_world()
	var cm := _make_manager(world)
	cm.generate_sync(Vector3i.ZERO, 1)  # 3x3x3 = 27 chunks instantly
	cm.set_player_position(Vector3(0, 40, 0))
	# stream fills the rest of the 5x5x3 load column (75 - 27 = 48 chunks)
	for i in 400:
		await tree.physics_frame
	_check(world.chunk_count() >= 75, "stream load fills load radius", "got %d" % world.chunk_count())
	var missing: Array[Vector3i] = []
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for cy in range(0, 3):
				if not world.has_chunk(Vector3i(dx, cy, dz)):
					missing.append(Vector3i(dx, cy, dz))
	_check(missing.is_empty(), "stream all load chunks present", "missing %s" % str(missing))
	# meshing caught up (4/frame budget)
	_check(world.get_node_or_null("ChunkNode_0_0_0") != null, "stream chunk meshed")
	world.queue_free()
	await tree.physics_frame


func _check_stream_unload() -> void:
	var world := _make_world()
	var cm := _make_manager(world)
	cm.generate_sync(Vector3i.ZERO, 2)
	cm.set_player_position(Vector3(0, 40, 0))
	for i in 120:
		await tree.physics_frame
	_check(world.chunk_count() >= 75, "unload test: loaded before move")
	var node := world.get_node_or_null("ChunkNode_0_0_0")
	_check(node != null, "unload test: node exists before move")
	# teleport far away (chunk 12,2,12); old area must unload, new area loads
	cm.set_player_position(Vector3(200, 40, 200))
	for i in 400:
		await tree.physics_frame
	_check(not world.has_chunk(Vector3i(0, 0, 0)), "stream unloads far chunks")
	_check(not world.has_chunk(Vector3i(-2, 0, 2)), "stream unloads corner chunk")
	_check(world.has_chunk(Vector3i(12, 0, 12)), "stream loads new area", "got count %d" % world.chunk_count())
	_check(world.chunk_count() <= 100, "stream world stays bounded", "got %d" % world.chunk_count())
	world.queue_free()
	await tree.physics_frame


func _check_stream_determinism() -> void:
	var world := _make_world()
	var cm := _make_manager(world)
	cm.set_player_position(Vector3(200, 40, 200))
	for i in 300:
		await tree.physics_frame
	# compare a block in a streamed chunk against a fresh direct generation
	var gen := VoxelGenerator.new(SEED)
	var coord := Vector3i(12, 1, 12)
	var reference := gen.generate(coord)
	var local := Vector3i(2, 4, 14)
	var world_pos := coord * VoxelChunk.CHUNK_SIZE + local
	_check(world.get_block(world_pos) == reference.get_block(local),
		"stream chunk matches direct generation", "got %d vs %d" % [world.get_block(world_pos), reference.get_block(local)])
	world.queue_free()
	await tree.physics_frame


func _check_mesh_nodes_freed() -> void:
	var world := _make_world()
	var cm := _make_manager(world)
	cm.generate_sync(Vector3i.ZERO, 2)
	cm.set_player_position(Vector3(0, 40, 0))
	for i in 120:
		await tree.physics_frame
	var node := world.get_node_or_null("ChunkNode_0_0_0")
	_check(node != null, "free test: node exists")
	cm.set_player_position(Vector3(400, 40, 400))
	for i in 200:
		await tree.physics_frame
	_check(not is_instance_valid(node), "free test: unloaded mesh node freed")
	world.queue_free()
	await tree.physics_frame
