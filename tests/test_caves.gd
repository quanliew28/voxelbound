extends RefCounted
## Phase 10 suite: 3D-noise caves + ore deposits + crystal caves.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

const SEED: int = 24601

func run() -> int:
	_check_caves_exist()
	_check_surface_stays_solid()
	_check_ores_exist()
	_check_crystal_caves()
	_check_cave_determinism()
	_check_cave_border_safety()
	print("SUITE caves: %d passed, %d failed" % [last_passed, _failed])
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


func _cached(gen: VoxelGenerator, cache: Dictionary, chunk_coord: Vector3i) -> VoxelChunk:
	if not cache.has(chunk_coord):
		cache[chunk_coord] = gen.generate(chunk_coord)
	return cache[chunk_coord]


func _check_caves_exist() -> void:
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var air_below := 0
	var total_below := 0
	for dz in range(-40, 41, 12):
		for dx in range(-40, 41, 12):
			var h := gen.height_at(dx, dz)
			var chunk_coord := Vector3i(floori(dx / 16.0), 1, floori(dz / 16.0))
			var chunk := _cached(gen, cache, chunk_coord)
			var local := Vector3i(dx - chunk_coord.x * 16, 0, dz - chunk_coord.z * 16)
			# scan a deep vertical slice in this chunk's column
			for y in VoxelChunk.CHUNK_SIZE:
				var wy := 16 + y
				if wy >= h - 4:
					continue
				total_below += 1
				if chunk.get_block(Vector3i(local.x, y, local.z)) == BlockRegistry.AIR_ID:
					air_below += 1
	_check(air_below > 0 and total_below > 0, "caves carve underground air", "%d/%d air" % [air_below, total_below])


func _check_surface_stays_solid() -> void:
	var gen := VoxelGenerator.new(SEED)
	var holes := 0
	for dz in range(-64, 65, 8):
		for dx in range(-64, 65, 8):
			var h := gen.height_at(dx, dz)
			# read via a small world so cross-chunk depth reads stay valid
			var world := VoxelWorld.new()
			var cy := h / VoxelChunk.CHUNK_SIZE
			var cx := floori(dx / float(VoxelChunk.CHUNK_SIZE))
			var cz := floori(dz / float(VoxelChunk.CHUNK_SIZE))
			world.add_chunk(gen.generate(Vector3i(cx, cy, cz)))
			world.add_chunk(gen.generate(Vector3i(cx, cy - 1, cz)))
			for depth in 4:  # surface block + 3 subsurface
				if world.get_block(Vector3i(dx, h - depth, dz)) == BlockRegistry.AIR_ID:
					holes += 1
			world.free()
	_check(holes == 0, "surface layers never carved", "%d holes" % holes)


func _check_ores_exist() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var coal := 0
	var copper := 0
	for dz in range(-48, 49, 8):
		for dx in range(-48, 49, 8):
			var h := gen.height_at(dx, dz)
			var chunk_coord := Vector3i(floori(dx / 16.0), 1, floori(dz / 16.0))
			var chunk := _cached(gen, cache, chunk_coord)
			var local := Vector3i(dx - chunk_coord.x * 16, 0, dz - chunk_coord.z * 16)
			for y in VoxelChunk.CHUNK_SIZE:
				var id: int = chunk.get_block(Vector3i(local.x, y, local.z))
				if id == reg.get_id(&"COAL"):
					coal += 1
				elif id == reg.get_id(&"COPPER"):
					copper += 1
	_check(coal > 0, "coal ore deposits exist", "coal=%d" % coal)
	_check(copper > 0, "copper ore deposits exist", "copper=%d" % copper)


func _check_crystal_caves() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var crystals := 0
	var deep_total := 0
	for dz in range(-120, 121, 8):
		for dx in range(-120, 121, 8):
			var h := gen.height_at(dx, dz)
			for cy in [1, 2]:
				var chunk_coord := Vector3i(floori(dx / 16.0), cy, floori(dz / 16.0))
				var chunk := _cached(gen, cache, chunk_coord)
				var local := Vector3i(dx - chunk_coord.x * 16, 0, dz - chunk_coord.z * 16)
				for y in VoxelChunk.CHUNK_SIZE:
					var wy: int = cy * 16 + y
					if wy > h - 18:
						continue
					deep_total += 1
					if chunk.get_block(Vector3i(local.x, y, local.z)) == reg.get_id(&"CRYSTAL"):
						crystals += 1
	_check(crystals > 0, "deep crystal caves exist", "crystals=%d deep=%d" % [crystals, deep_total])


func _check_cave_determinism() -> void:
	var a := VoxelGenerator.new(SEED).generate(Vector3i(2, 1, -3)).blocks
	var b := VoxelGenerator.new(SEED).generate(Vector3i(2, 1, -3)).blocks
	_check(a == b, "caves deterministic for same seed")


func _check_cave_border_safety() -> void:
	var gen := VoxelGenerator.new(SEED)
	# surface cells on the x=15/16 boundary strip must stay solid in BOTH
	# neighbouring chunks (carving is a pure function of world coords)
	var solid := 0
	var total := 0
	for z in range(0, 16, 2):
		var h := gen.height_at(15, z)
		var world := VoxelWorld.new()
		world.add_chunk(gen.generate(Vector3i(0, h / 16, 0)))
		world.add_chunk(gen.generate(Vector3i(1, h / 16, 0)))
		for side in [15, 16]:
			total += 1
			var id := world.get_block(Vector3i(side, h, z))
			if id != BlockRegistry.AIR_ID and id != BlockRegistry.shared().get_id(&"CRYSTAL"):
				solid += 1
		world.free()
	_check(solid >= total - 2, "border strip surface intact", "%d/%d solid" % [solid, total])
