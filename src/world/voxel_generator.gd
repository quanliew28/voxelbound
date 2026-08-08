extends RefCounted
class_name VoxelGenerator
## Seed-deterministic terrain generation. Canonical spec: docs/ARCHITECTURE.md
## §5.2. Pure data — generates VoxelChunks, never touches nodes or engine
## state. All noise derives from the world seed, so the same seed always
## reproduces the same world.
##
## Pipeline (Phase 9): column biome (Voronoi over temperature/humidity noise)
## -> biome height -> biome surface/subsurface layers -> deterministic trees
## (broadleaf/pine per biome, chunk-border-safe via a 1-chunk margin pass,
## written idempotently by every covering chunk) -> surface crystal clusters
## (Crystal Highlands). Spawn area (radius 4 around origin) is flattened
## Meadow so every world has a walkable, testable spawn — no trees there.

const BASE_HEIGHT: int = 32
const SPAWN_FLAT_RADIUS: float = 4.0
const TREE_MARGIN: int = VoxelChunk.CHUNK_SIZE  # one chunk of margin

var world_seed: int
var _height_noise: FastNoiseLite
var _temp_noise: FastNoiseLite
var _humid_noise: FastNoiseLite
# Phase 10 cave/ore noises (all seeded -> deterministic; sampled at WORLD
# coordinates so carving is chunk-border-safe by construction)
var _cave_noise: FastNoiseLite
var _chamber_noise: FastNoiseLite
var _shaft_noise: FastNoiseLite
var _crystal_region_noise: FastNoiseLite
var _ore_coal_noise: FastNoiseLite
var _ore_copper_noise: FastNoiseLite

func _init(seed_value: int) -> void:
	world_seed = seed_value
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = world_seed
	_height_noise.frequency = 0.02
	_height_noise.fractal_octaves = 4
	_height_noise.fractal_gain = 0.5
	_height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_temp_noise = FastNoiseLite.new()
	_temp_noise.seed = world_seed + 101
	_temp_noise.frequency = 0.0015
	_temp_noise.fractal_octaves = 2
	_humid_noise = FastNoiseLite.new()
	_humid_noise.seed = world_seed + 202
	_humid_noise.frequency = 0.0015
	_humid_noise.fractal_octaves = 2
	_cave_noise = _noise(world_seed + 303, 0.055, 3)
	_chamber_noise = _noise(world_seed + 404, 0.016, 2)
	_shaft_noise = _noise(world_seed + 505, 0.05, 2)
	_crystal_region_noise = _noise(world_seed + 606, 0.008, 2)
	_ore_coal_noise = _noise(world_seed + 707, 0.03, 2)
	_ore_copper_noise = _noise(world_seed + 808, 0.03, 2)


static func _noise(seed_value: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	return n


## Biome id for a column (Meadow in the flattened spawn area).
## Noise is widened to [-0.2, 1.2] so every Voronoi center — including the
## cold/dry corners (Frostlands, Redstone Desert) — gets reachable territory.
func biome_at(x: int, z: int) -> int:
	if Vector2(x, z).length() <= SPAWN_FLAT_RADIUS:
		return BiomeRegistry.MEADOW
	var temp := _temp_noise.get_noise_2d(float(x), float(z)) * 0.7 + 0.5
	var humid := _humid_noise.get_noise_2d(float(x), float(z)) * 0.7 + 0.5
	return BiomeRegistry.biome_by_temp_humid(temp, humid)


## Surface block height at column (x, z). Deterministic, pure.
func height_at(x: int, z: int) -> int:
	if Vector2(x, z).length() <= SPAWN_FLAT_RADIUS:
		return BASE_HEIGHT
	var biome := biome_at(x, z)
	var def := BiomeRegistry.BIOMES[biome]
	var h := float(def.base) + _height_noise.get_noise_2d(float(x), float(z)) * float(def.amp)
	return clampi(int(round(h)), 8, 96)


## Generates one chunk (all-AIR above surface). Deterministic.
func generate(chunk_coord: Vector3i) -> VoxelChunk:
	var chunk := VoxelChunk.new(chunk_coord)
	var reg := BlockRegistry.shared()
	var stone := reg.get_id(&"STONE")
	var ox := chunk_coord.x * VoxelChunk.CHUNK_SIZE
	var oy := chunk_coord.y * VoxelChunk.CHUNK_SIZE
	var oz := chunk_coord.z * VoxelChunk.CHUNK_SIZE
	for y in VoxelChunk.CHUNK_SIZE:
		var wy := oy + y
		for z in VoxelChunk.CHUNK_SIZE:
			var wz := oz + z
			for x in VoxelChunk.CHUNK_SIZE:
				var wx := ox + x
				var biome := biome_at(wx, wz)
				var def := BiomeRegistry.BIOMES[biome]
				var h := height_at(wx, wz)
				var id := BlockRegistry.AIR_ID
				if wy <= h:
					if wy == h:
						id = reg.get_id(StringName(def.surface))
					elif wy >= h - 3:
						id = reg.get_id(StringName(def.subsurface))
					else:
						id = stone
				if id != BlockRegistry.AIR_ID:
					id = _carve_and_ore(wx, wy, wz, h, id, stone)
				if id != BlockRegistry.AIR_ID:
					chunk.set_block_generated(Vector3i(x, y, z), id)
	_tree_pass(chunk, ox, oy, oz)
	_crystal_pass(chunk, ox, oy, oz)
	return chunk


## Phase 10: 3D-noise cave carving + ore deposits for one cell.
## Carving only happens at least 4 blocks below the surface (surface layers
## always stay solid). All noise is sampled at WORLD coordinates, so carving
## is identical for every chunk covering the same cell — border-safe by
## construction. Deep crystal-cave regions (the "Deep Caverns" feature) are
## rare, very deep, and sprinkle CRYSTAL inside the carved space.
## Thresholds are calibrated to FastNoiseLite FBM output ranges (~±0.55 for
## 3 octaves, ~±0.5 for 2) — see TECHNICAL_NOTES.
func _carve_and_ore(wx: int, wy: int, wz: int, surface_h: int, id: int, stone: int) -> int:
	var reg := BlockRegistry.shared()
	if wy <= surface_h - 4:
		var n := _cave_noise.get_noise_3d(float(wx), float(wy), float(wz))
		var carved := absf(n) > 0.30  # spaghetti tunnels
		if not carved and _chamber_noise.get_noise_3d(float(wx), float(wy), float(wz)) > 0.25:
			carved = true  # large chambers
		if not carved and _shaft_noise.get_noise_3d(float(wx), float(wy * 0.25), float(wz)) > 0.30:
			carved = true  # vertical shafts
		if carved:
			if wy <= surface_h - 18 and _crystal_region_noise.get_noise_3d(float(wx), float(wy), float(wz)) > 0.18:
				# Deep Caverns: sparse crystals inside the cave
				if TreeGenerator.column_hash(wx, wy ^ wz) % 7 == 0:
					return reg.get_id(&"CRYSTAL")
			return BlockRegistry.AIR_ID
	if id == stone:
		if wy <= surface_h - 4 and _ore_coal_noise.get_noise_3d(float(wx), float(wy), float(wz)) > 0.22:
			return reg.get_id(&"COAL")
		if wy <= surface_h - 14 and _ore_copper_noise.get_noise_3d(float(wx), float(wy), float(wz)) > 0.27:
			return reg.get_id(&"COPPER")
	return id


## Fills a cubic block of chunks around center (startup/test path only —
## streaming uses generate() per chunk).
func fill_area(world: VoxelWorld, center: Vector3i, radius: int) -> void:
	for cx in range(center.x - radius, center.x + radius + 1):
		for cy in range(center.y - radius, center.y + radius + 1):
			for cz in range(center.z - radius, center.z + radius + 1):
				world.add_chunk(generate(Vector3i(cx, cy, cz)))


## Margin pass: scans columns within one chunk of this chunk and writes any
## tree cells that fall inside this chunk. The SAME column hash is used by
## neighbouring chunks, so overlapping trees are written identically
## (idempotent by construction).
func _tree_pass(chunk: VoxelChunk, ox: int, oy: int, oz: int) -> void:
	for mx in range(-TREE_MARGIN, TREE_MARGIN * 2):
		var wx := ox + mx
		for mz in range(-TREE_MARGIN, TREE_MARGIN * 2):
			var wz := oz + mz
			if Vector2(wx, wz).length() <= SPAWN_FLAT_RADIUS:
				continue  # never grow trees in the spawn area
			var biome := biome_at(wx, wz)
			var def := BiomeRegistry.BIOMES[biome]
			var tree_type := String(def.tree)
			if tree_type.is_empty():
				continue
			if not TreeGenerator.tree_at(wx, wz, float(def.tree_density)):
				continue
			# trees only root in grass surfaces
			if String(def.surface) != "GRASS":
				continue
			# spacing rule: within any 5x5 column cluster, only the tree with
			# the SMALLEST column hash survives — deterministic, order-
			# independent, and guarantees no trunk/canopy conflicts between
			# neighbouring trees (which would make chunk-border results
			# depend on generation order).
			if not _tree_is_lone(wx, wz, float(def.tree_density)):
				continue
			var base_h := height_at(wx, wz)
			var cells := TreeGenerator.tree_cells(tree_type, Vector3i(wx, base_h, wz))
			for cell in cells:
				var pos: Vector3i = cell.pos
				if pos.x < ox or pos.x >= ox + VoxelChunk.CHUNK_SIZE \
						or pos.z < oz or pos.z >= oz + VoxelChunk.CHUNK_SIZE:
					continue
				var local := Vector3i(pos.x - ox, pos.y - oy, pos.z - oz)
				if VoxelChunk.is_local_in_bounds(local):
					chunk.set_block_generated(local, cell.id)


## A tree at (wx, wz) survives only if no other tree column within
## Chebyshev distance 2 has a smaller hash (see _tree_pass).
func _tree_is_lone(wx: int, wz: int, density: float) -> bool:
	var my_hash := TreeGenerator.column_hash(wx, wz)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if dx == 0 and dz == 0:
				continue
			if TreeGenerator.tree_at(wx + dx, wz + dz, density) \
					and TreeGenerator.column_hash(wx + dx, wz + dz) < my_hash:
				return false
	return true


func _crystal_pass(chunk: VoxelChunk, ox: int, oy: int, oz: int) -> void:
	var reg := BlockRegistry.shared()
	var crystal := reg.get_id(&"CRYSTAL")
	for x in VoxelChunk.CHUNK_SIZE:
		var wx := ox + x
		for z in VoxelChunk.CHUNK_SIZE:
			var wz := oz + z
			if Vector2(wx, wz).length() <= SPAWN_FLAT_RADIUS:
				continue
			if not bool(BiomeRegistry.BIOMES[biome_at(wx, wz)].crystals):
				continue
			if TreeGenerator.column_hash(wx, wz) % 7 != 0:
				continue
			var h := height_at(wx, wz)
			var wy := h + 1
			var local := Vector3i(x, wy - oy, z)
			if VoxelChunk.is_local_in_bounds(local):
				chunk.set_block_generated(local, crystal)
