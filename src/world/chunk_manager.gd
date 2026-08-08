extends Node3D
class_name ChunkManager
## Streaming: keeps a chunk neighbourhood around the player alive.
## Canonical spec: docs/ARCHITECTURE.md §5.2 (ChunkManager).
##
## Responsibilities:
##   - load: all columns (cx, cz) within load_radius_xz of the player chunk,
##     for cy in [0, top_chunk_y], are generated (missing chunks only)
##   - priority: generation dispatched nearest-first (Chebyshev xz distance)
##   - threads: generation runs on WorkerThreadPool; each task creates its OWN
##     VoxelGenerator from the world seed (no shared mutable state — safe by
##     construction); results return to the main thread via call_deferred
##   - budget: gen_budget_per_frame dispatches per frame, max_in_flight cap
##   - unload: chunks farther than unload_radius_xz are removed periodically
##     (frees their mesh nodes via VoxelWorld.remove_chunk)
##   - startup: generate_sync() pre-fills the spawn column block so the
##     player never spawns over air before streaming catches up
##
## MESHING stays in VoxelWorld (dirty queue + per-chunk nodes); this manager
## feeds it by calling world.add_chunk().

@export var load_radius_xz: int = 4
@export var unload_radius_xz: int = 6
@export var top_chunk_y: int = 4
@export var gen_budget_per_frame: int = 2
@export var max_in_flight: int = 6
@export var enabled: bool = true

var world: VoxelWorld = null
var player_chunk := Vector3i.ZERO

var _in_flight: Dictionary = {}  # Vector3i -> true
var _unload_timer: int = 0

const UNLOAD_INTERVAL_FRAMES: int = 20


func _ready() -> void:
	if world == null:
		world = get_parent() as VoxelWorld


func set_player_position(world_pos: Vector3) -> void:
	player_chunk = VoxelWorld.world_to_chunk(Vector3i(world_pos.floor()))


## Synchronous initial fill (spawn area) — startup path only.
func generate_sync(center: Vector3i, radius_xz: int) -> void:
	var gen := VoxelGenerator.new(world.world_seed)
	for dx in range(-radius_xz, radius_xz + 1):
		for dz in range(-radius_xz, radius_xz + 1):
			for cy in range(0, top_chunk_y + 1):
				var coord := Vector3i(center.x + dx, cy, center.z + dz)
				if not world.has_chunk(coord):
					world.add_chunk(gen.generate(coord))


func _process(_delta: float) -> void:
	if not enabled or world == null:
		return
	_unload_timer += 1
	if _unload_timer >= UNLOAD_INTERVAL_FRAMES:
		_unload_timer = 0
		_unload_far_chunks()
	_dispatch_generation()


func _dispatch_generation() -> void:
	var to_generate: Array[Vector3i] = []
	for dx in range(-load_radius_xz, load_radius_xz + 1):
		for dz in range(-load_radius_xz, load_radius_xz + 1):
			for cy in range(0, top_chunk_y + 1):
				var coord := Vector3i(player_chunk.x + dx, cy, player_chunk.z + dz)
				if not world.has_chunk(coord) and not _in_flight.has(coord):
					to_generate.append(coord)
	if to_generate.is_empty():
		return
	to_generate.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _dist(a) < _dist(b))
	var budget := gen_budget_per_frame
	for coord in to_generate:
		if budget <= 0 or _in_flight.size() >= max_in_flight:
			break
		_in_flight[coord] = true
		budget -= 1
		WorkerThreadPool.add_task(_generate_worker.bind(coord, world.world_seed), true)


func _dist(coord: Vector3i) -> int:
	return maxi(absi(coord.x - player_chunk.x), absi(coord.z - player_chunk.z))


## Runs on a worker thread. Touches only locals (the seed is captured at
## dispatch time); the chunk is handed back to the main thread via
## call_deferred (thread-safe). The is_instance_valid guard prevents
## shutdown-time errors when the manager is freed mid-task.
func _generate_worker(coord: Vector3i, seed: int) -> void:
	var gen := VoxelGenerator.new(seed)
	var chunk := gen.generate(coord)
	if is_instance_valid(self):
		call_deferred(&"_on_chunk_generated", chunk)


func _on_chunk_generated(chunk: VoxelChunk) -> void:
	if _in_flight.has(chunk.chunk_coord):
		_in_flight.erase(chunk.chunk_coord)
	if not enabled or world == null or not is_instance_valid(world):
		return
	if _dist(chunk.chunk_coord) > unload_radius_xz:
		return  # player moved away while generating — discard
	world.add_chunk(chunk)


func _unload_far_chunks() -> void:
	for coord in world.get_loaded_chunk_coords():
		if _dist(coord) > unload_radius_xz:
			world.remove_chunk(coord)
