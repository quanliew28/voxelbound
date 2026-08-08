extends RefCounted
class_name VoxelGenerator
## Seed-deterministic terrain generation. Canonical spec: docs/ARCHITECTURE.md
## §5.2. Pure data — generates VoxelChunks, never touches nodes, never touches
## engine state. All noise derives from the world seed, so the same seed
## always reproduces the same world.
##
## Height model (Phase 5, extended by biomes Phase 9 / caves Phase 10):
##   BASE_HEIGHT 32, hills ±14 from 4-octave Perlin at frequency 0.02.
##   Surface layers: y == h -> GRASS (SAND when low), h-3..h-1 -> DIRT,
##   below -> STONE. Spawn area (radius 4 around origin) is flattened to
##   BASE_HEIGHT so every world has a walkable, testable spawn point.

const BASE_HEIGHT: int = 32
const HILL_AMPLITUDE: float = 14.0
const SAND_LEVEL: int = 26
const SPAWN_FLAT_RADIUS: float = 4.0

var world_seed: int
var _height_noise: FastNoiseLite

func _init(seed_value: int) -> void:
	world_seed = seed_value
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = world_seed
	_height_noise.frequency = 0.02
	_height_noise.fractal_octaves = 4
	_height_noise.fractal_gain = 0.5
	_height_noise.noise_type = FastNoiseLite.TYPE_PERLIN


## Surface block height at column (x, z). Deterministic, pure.
func height_at(x: int, z: int) -> int:
	if Vector2(x, z).length() <= SPAWN_FLAT_RADIUS:
		return BASE_HEIGHT
	var h := BASE_HEIGHT + _height_noise.get_noise_2d(float(x), float(z)) * HILL_AMPLITUDE
	return clampi(int(round(h)), 8, 64)


## Generates one chunk (all-AIR above surface). Deterministic.
func generate(chunk_coord: Vector3i) -> VoxelChunk:
	var chunk := VoxelChunk.new(chunk_coord)
	var reg := BlockRegistry.shared()
	var grass := reg.get_id(&"GRASS")
	var dirt := reg.get_id(&"DIRT")
	var sand := reg.get_id(&"SAND")
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
				var h := height_at(wx, wz)
				var id := BlockRegistry.AIR_ID
				if wy <= h:
					if wy == h:
						id = sand if h <= SAND_LEVEL else grass
					elif wy >= h - 3:
						id = sand if h <= SAND_LEVEL else dirt
					else:
						id = stone
				if id != BlockRegistry.AIR_ID:
					chunk.set_block_generated(Vector3i(x, y, z), id)
	return chunk


## Fills a cubic block of chunks around center (streaming does this live,
## Phase 6 — this is the startup/test path).
func fill_area(world: VoxelWorld, center: Vector3i, radius: int) -> void:
	for cx in range(center.x - radius, center.x + radius + 1):
		for cy in range(center.y - radius, center.y + radius + 1):
			for cz in range(center.z - radius, center.z + radius + 1):
				world.add_chunk(generate(Vector3i(cx, cy, cz)))
