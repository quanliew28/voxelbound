extends Node3D
class_name VoxelWorld
## Owns the chunk map and exposes world-space block access.
## Canonical spec: docs/ARCHITECTURE.md §5.2.
##
## Chunk map: Dictionary[Vector3i, VoxelChunk]. World->chunk mapping uses
## floor division so negative coordinates behave (ARCHITECTURE.md §5.1).
##
## set_block() is the GAMEPLAY mutation API (mining/placing): it marks the
## chunk modified (save-relevant) and emits block_changed. Procedural
## generation fills chunks directly via VoxelGenerator and hands them to
## add_chunk() — generated chunks are never marked modified.

signal block_changed(world_pos: Vector3i, old_id: int, new_id: int)

var _chunks: Dictionary = {}  # Vector3i -> VoxelChunk


## Floor-division chunk coord of a world position.
static func world_to_chunk(world_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / float(VoxelChunk.CHUNK_SIZE)),
		floori(world_pos.y / float(VoxelChunk.CHUNK_SIZE)),
		floori(world_pos.z / float(VoxelChunk.CHUNK_SIZE)),
	)


## Local (0..15) coordinate within the owning chunk.
static func world_to_local(world_pos: Vector3i) -> Vector3i:
	var chunk := world_to_chunk(world_pos)
	return world_pos - chunk * VoxelChunk.CHUNK_SIZE


func has_chunk(coord: Vector3i) -> bool:
	return _chunks.has(coord)


## Returns the chunk at coord, or null. No creation side effects.
func get_chunk(coord: Vector3i) -> VoxelChunk:
	return _chunks.get(coord, null)


## Inserts a chunk (typically freshly generated or loaded). Returns true if a
## chunk already existed at that coord (caller may inspect/replace).
func add_chunk(chunk: VoxelChunk) -> bool:
	var had := _chunks.has(chunk.chunk_coord)
	_chunks[chunk.chunk_coord] = chunk
	return had


## Removes and returns the chunk at coord (or null). Unload path for Phase 6.
func remove_chunk(coord: Vector3i) -> VoxelChunk:
	var chunk: VoxelChunk = _chunks.get(coord, null)
	if chunk != null:
		_chunks.erase(coord)
	return chunk


## Returns the existing chunk at coord, or creates an empty (all-AIR) chunk.
## Empty chunks are NOT marked modified. Convenience for tests/editors;
## generation should use VoxelGenerator instead (Phase 5).
func get_or_create_chunk(coord: Vector3i) -> VoxelChunk:
	var chunk := get_chunk(coord)
	if chunk == null:
		chunk = VoxelChunk.new(coord)
		_chunks[coord] = chunk
	return chunk


## World-space block read. Missing chunks read as AIR.
func get_block(world_pos: Vector3i) -> int:
	var chunk := get_chunk(world_to_chunk(world_pos))
	if chunk == null:
		return BlockRegistry.AIR_ID
	return chunk.get_block(world_to_local(world_pos))


## World-space block write (gameplay edits only). Returns true if the world
## state changed. Marks the chunk modified and emits block_changed.
func set_block(world_pos: Vector3i, id: int) -> bool:
	var chunk_coord := world_to_chunk(world_pos)
	var chunk := get_or_create_chunk(chunk_coord)
	var local := world_to_local(world_pos)
	var old_id: int = chunk.get_block(local)
	var changed := chunk.set_block(local, id)
	if changed:
		block_changed.emit(world_pos, old_id, id)
	return changed
