extends RefCounted
class_name VoxelTestTerrain
## TEMPORARY Phase 3–4 block-based stand-in terrain (NOT the generator).
## Canonical spec: docs/ARCHITECTURE.md §7. Deleted when VoxelGenerator lands
## (Phase 5). Must not grow features.
##
## Shape: flat plateau (height 12) within FLAT_RADIUS of the origin — keeps
## the player spawn and smoke-test movement deterministic — rolling hills
## beyond. Ore sprinkle + sparse surface crystals demonstrate the mesher's
## three surfaces.

const FLAT_RADIUS: float = 14.0
const BASE_HEIGHT: int = 12
const HILL_AMPLITUDE: float = 12.0

static var _noise: FastNoiseLite = null


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4242
		_noise.frequency = 0.03
		_noise.fractal_octaves = 3
	return _noise


## Surface block height at world column (x, z). Deterministic.
static func height_at(x: int, z: int) -> int:
	if Vector2(x, z).length() <= FLAT_RADIUS:
		return BASE_HEIGHT
	var h := BASE_HEIGHT + _get_noise().get_noise_2d(x, z) * HILL_AMPLITUDE
	return maxi(BASE_HEIGHT, int(floor(h)))


## Fills a rectangular block of chunks around the origin with terrain.
static func fill(world: VoxelWorld, radius_chunks: int = 2) -> void:
	var reg := BlockRegistry.shared()
	var grass := reg.get_id(&"GRASS")
	var dirt := reg.get_id(&"DIRT")
	var stone := reg.get_id(&"STONE")
	var coal := reg.get_id(&"COAL")
	var copper := reg.get_id(&"COPPER")
	var crystal := reg.get_id(&"CRYSTAL")
	for cx in range(-radius_chunks, radius_chunks + 1):
		for cz in range(-radius_chunks, radius_chunks + 1):
			for cy in range(0, 2):  # y chunks 0..1 cover surface heights 0..31
				var chunk := VoxelChunk.new(Vector3i(cx, cy, cz))
				for y in VoxelChunk.CHUNK_SIZE:
					for z in VoxelChunk.CHUNK_SIZE:
						for x in VoxelChunk.CHUNK_SIZE:
							var wx := cx * VoxelChunk.CHUNK_SIZE + x
							var wy := cy * VoxelChunk.CHUNK_SIZE + y
							var wz := cz * VoxelChunk.CHUNK_SIZE + z
							var h := height_at(wx, wz)
							var id := BlockRegistry.AIR_ID
							if wy > h:
								id = BlockRegistry.AIR_ID
							elif wy == h:
								id = grass
							elif wy >= h - 3:
								id = dirt
							else:
								id = stone
								var h1 := (wx * 73856093) ^ (wz * 19349663) ^ (wy * 83492791)
								if h1 % 17 == 0:
									id = coal
								elif h1 % 29 == 0:
									id = copper
							if id != BlockRegistry.AIR_ID:
								chunk.set_block_generated(Vector3i(x, y, z), id)
							# sparse surface crystals (emissive demo) — but never
							# near spawn: a crystal at the origin would trap the
							# player (feet pass through the y = h+1 layer)
							if wy == h + 1 and (wx * 31 + wz * 17) % 53 == 0 \
									and Vector2(wx, wz).length() > 4.0:
								chunk.set_block_generated(Vector3i(x, y, z), crystal)
				world.add_chunk(chunk)
