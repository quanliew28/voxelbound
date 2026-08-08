extends RefCounted
## Phase 9 suite: BiomeRegistry + biome-aware generation + trees.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

const SEED: int = 4242

func run() -> int:
	_check_biome_data()
	_check_biome_determinism()
	_check_all_biomes_exist()
	_check_biome_layers()
	_check_spawn_safety()
	_check_trees_exist()
	_check_tree_structure()
	_check_tree_border_consistency()
	print("SUITE biomes: %d passed, %d failed" % [last_passed, _failed])
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


## generate() is expensive (tree margin pass) — cache per-chunk results in
## scan loops so each unique chunk is generated exactly once.
func _cached(gen: VoxelGenerator, cache: Dictionary, chunk_coord: Vector3i) -> VoxelChunk:
	if not cache.has(chunk_coord):
		cache[chunk_coord] = gen.generate(chunk_coord)
	return cache[chunk_coord]


func _check_biome_data() -> void:
	_check(BiomeRegistry.BIOME_COUNT == 5, "biomes five surface biomes")
	var reg := BlockRegistry.shared()
	_check(reg.has_block(&"SNOW"), "biomes snow block registered")
	for i in BiomeRegistry.BIOME_COUNT:
		var def := BiomeRegistry.BIOMES[i]
		_check(reg.has_block(StringName(def.surface)), "biome %d surface block exists" % i)
		_check(reg.has_block(StringName(def.subsurface)), "biome %d subsurface block exists" % i)
	_check(BiomeRegistry.display_name(BiomeRegistry.MEADOW) == "Meadow", "biomes display name")
	_check(BiomeRegistry.display_name(99) == "Unknown", "biomes bad id display")


func _check_biome_determinism() -> void:
	var a := VoxelGenerator.new(SEED)
	var b := VoxelGenerator.new(SEED)
	var same := true
	for i in range(0, 200, 7):
		for j in range(0, 200, 7):
			if a.biome_at(i, j) != b.biome_at(i, j):
				same = false
	_check(same, "biomes deterministic across instances")


func _check_all_biomes_exist() -> void:
	var gen := VoxelGenerator.new(SEED)
	var found := {}
	for dz in range(-300, 301, 6):
		for dx in range(-300, 301, 6):
			found[gen.biome_at(dx, dz)] = true
	_check(found.size() == BiomeRegistry.BIOME_COUNT, "biomes all five occur in world",
		"found %s" % str(found.keys()))


func _check_biome_layers() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var desert_h := -1
	var frost_h := -1
	var high_h := -1
	for dz in range(-300, 301, 4):
		for dx in range(-300, 301, 4):
			var biome := gen.biome_at(dx, dz)
			var h := gen.height_at(dx, dz)
			var chunk_coord := Vector3i(floori(dx / 16.0), h / 16, floori(dz / 16.0))
			var chunk := _cached(gen, cache, chunk_coord)
			var local := Vector3i(dx - chunk_coord.x * 16, h - chunk_coord.y * 16, dz - chunk_coord.z * 16)
			if biome == BiomeRegistry.REDSTONE_DESERT and desert_h == -1:
				desert_h = h
				_check(chunk.get_block(local) == reg.get_id(&"SAND"), "desert sand surface", "h=%d" % h)
				_check(chunk.get_block(Vector3i(local.x, local.y - 2, local.z)) == reg.get_id(&"SAND"), "desert sand subsurface")
			elif biome == BiomeRegistry.FROSTLANDS and frost_h == -1:
				frost_h = h
				_check(chunk.get_block(local) == reg.get_id(&"SNOW"), "frostlands snow surface")
				_check(chunk.get_block(Vector3i(local.x, local.y - 2, local.z)) == reg.get_id(&"DIRT"), "frostlands dirt subsurface")
			elif biome == BiomeRegistry.CRYSTAL_HIGHLANDS and high_h == -1:
				high_h = h
				_check(h >= 40, "highlands elevated terrain", "h=%d" % h)
				_check(chunk.get_block(local) == reg.get_id(&"STONE"), "highlands stone surface")
			if desert_h != -1 and frost_h != -1 and high_h != -1:
				break
		if desert_h != -1 and frost_h != -1 and high_h != -1:
			break
	_check(desert_h != -1 and frost_h != -1 and high_h != -1, "biomes probe columns found",
		"desert=%d frost=%d high=%d" % [desert_h, frost_h, high_h])


func _check_spawn_safety() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	_check(gen.biome_at(0, 0) == BiomeRegistry.MEADOW, "spawn biome meadow")
	_check(gen.height_at(0, 0) == VoxelGenerator.BASE_HEIGHT, "spawn height flat")
	# no trees/crystals within radius 4 of origin (a tree at spawn traps the player)
	var chunk := gen.generate(Vector3i(0, 2, 0))
	var wood := reg.get_id(&"WOOD")
	var crystal := reg.get_id(&"CRYSTAL")
	var blocked := false
	for x in 16:
		for z in 16:
			var wx := x
			var wz := z
			if Vector2(wx, wz).length() > 4.0:
				continue
			for y in 16:
				var id: int = chunk.get_block(Vector3i(x, y, z))
				if id == wood or id == crystal:
					blocked = true
	_check(not blocked, "spawn area free of trees/crystals")


func _check_trees_exist() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var wood := reg.get_id(&"WOOD")
	var found_broadleaf := false
	var found_pine := false
	for dz in range(-120, 121, 2):
		for dx in range(-120, 121, 2):
			var biome := gen.biome_at(dx, dz)
			var h := gen.height_at(dx, dz)
			var chunk_coord := Vector3i(floori(dx / 16.0), h / 16, floori(dz / 16.0))
			var chunk := _cached(gen, cache, chunk_coord)
			var local := Vector3i(dx - chunk_coord.x * 16, h + 1 - chunk_coord.y * 16, dz - chunk_coord.z * 16)
			if biome == BiomeRegistry.MEADOW and not found_broadleaf:
				if chunk.get_block(local) == wood:
					found_broadleaf = true
			elif biome == BiomeRegistry.PINEWILD and not found_pine:
				if chunk.get_block(local) == wood:
					found_pine = true
			if found_broadleaf and found_pine:
				break
		if found_broadleaf and found_pine:
			break
	_check(found_broadleaf, "meadow grows broadleaf trees")
	_check(found_pine, "pinewild grows pines")


func _check_tree_structure() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	var cache := {}
	var wood := reg.get_id(&"WOOD")
	var leaf := reg.get_id(&"LEAF")
	var found := false
	for dz in range(-100, 101, 2):
		for dx in range(-100, 101, 2):
			if gen.biome_at(dx, dz) != BiomeRegistry.MEADOW:
				continue
			if not TreeGenerator.tree_at(dx, dz, float(BiomeRegistry.BIOMES[BiomeRegistry.MEADOW].tree_density)):
				continue
			var h := gen.height_at(dx, dz)
			var chunk_coord := Vector3i(floori(dx / 16.0), h / 16, floori(dz / 16.0))
			var chunk := _cached(gen, cache, chunk_coord)
			var local := Vector3i(dx - chunk_coord.x * 16, h + 1 - chunk_coord.y * 16, dz - chunk_coord.z * 16)
			if chunk.get_block(local) == wood:
				found = true
				_check(chunk.get_block(Vector3i(local.x, local.y + 3, local.z)) == wood, "tree trunk rises")
				var canopy := chunk.get_block(Vector3i(local.x, local.y + 4, local.z))
				_check(canopy == leaf, "tree canopy above trunk", "got %d" % canopy)
				break
		if found:
			break
	_check(found, "tree structure probe found tree")


func _check_tree_border_consistency() -> void:
	var reg := BlockRegistry.shared()
	var gen := VoxelGenerator.new(SEED)
	# find a tree with trunk at x = 16 (chunk border) and grass surface
	var tree_col := Vector2i(-1, -1)
	for dz in range(-100, 101, 2):
		for dx in range(-60, 61, 2):
			if dx <= 0:
				continue
			if gen.biome_at(dx, dz) != BiomeRegistry.MEADOW:
				continue
			if not TreeGenerator.tree_at(dx, dz, float(BiomeRegistry.BIOMES[BiomeRegistry.MEADOW].tree_density)):
				continue
			if String(BiomeRegistry.BIOMES[gen.biome_at(dx, dz)].surface) != "GRASS":
				continue
			tree_col = Vector2i(dx, dz)
			break
		if tree_col.x != -1:
			break
	_check(tree_col.x != -1, "border tree probe found column")
	if tree_col.x == -1:
		return
	# every tree cell must exist in the world exactly as the generator says
	var h := gen.height_at(tree_col.x, tree_col.y)
	var cells := TreeGenerator.tree_cells("broadleaf", Vector3i(tree_col.x, h, tree_col.y))
	var world := VoxelWorld.new()
	var chunk_coords := {}
	for cell in cells:
		var pos: Vector3i = cell.pos
		chunk_coords[VoxelWorld.world_to_chunk(pos)] = true
	for coord in chunk_coords:
		world.add_chunk(gen.generate(coord))
	var mismatches := 0
	for cell in cells:
		var pos: Vector3i = cell.pos
		if world.get_block(pos) != cell.id:
			mismatches += 1
	_check(mismatches == 0, "border tree cells consistent across chunks", "%d mismatches" % mismatches)
	world.free()
