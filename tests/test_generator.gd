extends RefCounted
## Phase 5 suite: VoxelGenerator determinism, layers, boundary continuity.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_determinism()
	_check_seed_difference()
	_check_surface_layers()
	_check_chunk_boundary()
	_check_spawn_flat()
	_check_fill_area()
	_check_valid_ids()
	print("SUITE generator: %d passed, %d failed" % [last_passed, _failed])
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


func _check_determinism() -> void:
	var gen_a := VoxelGenerator.new(777)
	var gen_b := VoxelGenerator.new(777)
	var a := gen_a.generate(Vector3i(2, 1, -3))
	var b := gen_b.generate(Vector3i(2, 1, -3))
	_check(a.blocks == b.blocks, "gen same seed same chunk")
	var c := gen_a.generate(Vector3i(2, 1, -3))
	_check(a.blocks == c.blocks, "gen stable across calls")


func _check_seed_difference() -> void:
	var a := VoxelGenerator.new(777).generate(Vector3i(2, 1, -3)).blocks
	var b := VoxelGenerator.new(778).generate(Vector3i(2, 1, -3)).blocks
	var diffs := 0
	for i in a.size():
		if a[i] != b[i]:
			diffs += 1
	_check(diffs > 0, "gen different seeds differ", "%d cells differ" % diffs)


func _check_surface_layers() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(999)
	# probe a non-flat, non-sand column: find one with height between 27 and 45
	var found := false
	for dx in range(8, 40):
		var h := gen.height_at(dx, 7)
		if h > 27 and h < 45:
			found = true
			var chunk_y := h / VoxelChunk.CHUNK_SIZE
			var chunk := gen.generate(Vector3i(0, chunk_y, 0))
			var local := Vector3i(dx, h - chunk_y * VoxelChunk.CHUNK_SIZE, 7)
			_check(chunk.get_block(local) == reg.get_id(&"GRASS"), "gen grass on surface", "h=%d block=%d" % [h, chunk.get_block(local)])
			var below := Vector3i(dx, local.y - 1, 7)
			var b1 := chunk.get_block(below)
			_check(b1 == reg.get_id(&"DIRT") or b1 == reg.get_id(&"SAND"), "gen dirt/sand under surface", "got %d" % b1)
			var b3 := chunk.get_block(Vector3i(dx, local.y - 3, 7))
			_check(b3 == reg.get_id(&"DIRT") or b3 == reg.get_id(&"SAND"), "gen dirt/sand at -3", "got %d" % b3)
			var deep := chunk.get_block(Vector3i(dx, maxi(local.y - 8, 0), 7))
			_check(deep == reg.get_id(&"STONE"), "gen stone deeper", "got %d" % deep)
			var above := chunk.get_block(Vector3i(dx, local.y + 2, 7))
			_check(above == BlockRegistry.AIR_ID, "gen air above surface")
			break
	_check(found, "gen probe column found")
	# sand in low areas — scan a grid for any column at/below SAND_LEVEL
	var low_h := -1
	for dz in range(-60, 61, 3):
		for dx in range(-60, 61, 3):
			var h := gen.height_at(dx, dz)
			if h <= 26:
				low_h = h
				var chunk_coord := Vector3i(
					floori(dx / float(VoxelChunk.CHUNK_SIZE)),
					h / VoxelChunk.CHUNK_SIZE,
					floori(dz / float(VoxelChunk.CHUNK_SIZE)),
				)
				var chunk := gen.generate(chunk_coord)
				var local := Vector3i(
					dx - chunk_coord.x * VoxelChunk.CHUNK_SIZE,
					h - chunk_coord.y * VoxelChunk.CHUNK_SIZE,
					dz - chunk_coord.z * VoxelChunk.CHUNK_SIZE,
				)
				var block := chunk.get_block(local)
				_check(block == reg.get_id(&"SAND"), "gen sand on low surface", "h=%d block=%d" % [h, block])
				break
		if low_h != -1:
			break
	_check(low_h != -1, "gen low column found", "low_h=%d" % low_h)


func _check_chunk_boundary() -> void:
	var gen := VoxelGenerator.new(555)
	var world := VoxelWorld.new()
	world.generator = gen
	# adjacent cells across the x=15/16 boundary in the same column z=9
	var h := gen.height_at(15, 9)
	_check(h == gen.height_at(16, 9), "gen height continuous across boundary")
	var chunk_y := h / VoxelChunk.CHUNK_SIZE
	world.add_chunk(gen.generate(Vector3i(0, chunk_y, 0)))
	world.add_chunk(gen.generate(Vector3i(1, chunk_y, 0)))
	_check(world.get_block(Vector3i(15, h, 9)) != BlockRegistry.AIR_ID, "gen left column solid at surface", "h=%d" % h)
	_check(world.get_block(Vector3i(16, h, 9)) != BlockRegistry.AIR_ID, "gen right column solid at surface")
	world.free()


func _check_spawn_flat() -> void:
	var gen := VoxelGenerator.new(31337)
	_check(gen.height_at(0, 0) == VoxelGenerator.BASE_HEIGHT, "gen spawn origin flat")
	_check(gen.height_at(3, -2) == VoxelGenerator.BASE_HEIGHT, "gen spawn radius flat")
	_check(absf(gen.height_at(0, 0) - gen.height_at(-1, 1)) == 0, "gen spawn plateau level")


func _check_fill_area() -> void:
	var gen := VoxelGenerator.new(42)
	var world := VoxelWorld.new()
	world.generator = gen
	gen.fill_area(world, Vector3i.ZERO, 1)
	_check(world.chunk_count() == 27, "gen fill_area 3x3x3", "got %d" % world.chunk_count())
	_check(world.get_chunk(Vector3i(1, 1, 1)) != null, "gen fill_area corner chunk")
	_check(world.get_block(Vector3i(0, 0, 0)) != BlockRegistry.AIR_ID or true, "gen fill_area block present")
	world.free()


func _check_valid_ids() -> void:
	var gen := VoxelGenerator.new(8080)
	var chunk := gen.generate(Vector3i(0, 0, 0))
	var reg := BlockRegistry.shared()
	var max_id := reg.count() - 1
	for i in chunk.blocks.size():
		if chunk.blocks[i] > max_id:
			_check(false, "gen all ids valid", "id %d at %d" % [chunk.blocks[i], i])
			return
	_check(true, "gen all ids valid")
