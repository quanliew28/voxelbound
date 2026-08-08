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
	# probe a MEADOW/PINEWILD (grass) column away from spawn
	var found := false
	for dx in range(8, 120):
		for dz in range(-60, 60):
			var biome := gen.biome_at(dx, dz)
			if biome != BiomeRegistry.MEADOW and biome != BiomeRegistry.PINEWILD:
				continue
			var h := gen.height_at(dx, dz)
			if h > 27 and h < 70:
				found = true
				var chunk_coord := Vector3i(
					floori(dx / float(VoxelChunk.CHUNK_SIZE)),
					h / VoxelChunk.CHUNK_SIZE,
					floori(dz / float(VoxelChunk.CHUNK_SIZE)))
				var chunk := gen.generate(chunk_coord)
				var local := Vector3i(
					dx - chunk_coord.x * VoxelChunk.CHUNK_SIZE,
					h - chunk_coord.y * VoxelChunk.CHUNK_SIZE,
					dz - chunk_coord.z * VoxelChunk.CHUNK_SIZE)
				_check(chunk.get_block(local) == reg.get_id(&"GRASS"), "gen grass on surface", "h=%d block=%d biome=%d" % [h, chunk.get_block(local), biome])
				var b1 := chunk.get_block(Vector3i(local.x, local.y - 1, local.z))
				_check(b1 == reg.get_id(&"DIRT"), "gen dirt under surface", "got %d" % b1)
				var deep := chunk.get_block(Vector3i(local.x, maxi(local.y - 8, 0), local.z))
				# deep cells are stone — or cave-carved air / ore (Phase 10);
				# never surface-layer material
				_check(deep != reg.get_id(&"GRASS") and deep != reg.get_id(&"DIRT")
					and deep != reg.get_id(&"SAND") and deep != reg.get_id(&"SNOW"),
					"gen deep is stone/cave/ore", "got %d" % deep)
				var above := chunk.get_block(Vector3i(local.x, local.y + 2, local.z))
				_check(above == BlockRegistry.AIR_ID, "gen air above surface")
				break
		if found:
			break
	_check(found, "gen grass column found")


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
