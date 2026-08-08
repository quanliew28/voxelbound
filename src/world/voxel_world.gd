extends Node3D
class_name VoxelWorld
## Owns the chunk map, world-space block access, AND (Phase 3+) the per-chunk
## mesh/collision nodes. Canonical spec: docs/ARCHITECTURE.md §5.2, §5.3.
##
## Chunk map: Dictionary[Vector3i, VoxelChunk]. World->chunk mapping uses
## floor division so negative coordinates behave (ARCHITECTURE.md §5.1).
##
## set_block() is the GAMEPLAY mutation API (mining/placing): it marks the
## chunk modified (save-relevant), dirties the owning chunk + any bordering
## neighbour chunks, and emits block_changed. Procedural generation fills
## chunks via VoxelChunk.set_block_generated() and hands them to add_chunk()
## — generated chunks are never marked modified.
##
## Meshing: dirty chunks are rebuilt through a deduplicated queue with a
## per-frame budget (MESH_BUDGET_PER_FRAME). rebuild_all_dirty() is the
## synchronous path for startup/tests. Until ChunkManager lands (Phase 6),
## mesh nodes (ChunkNode_* > MeshInstance3D + StaticBody3D) are owned here.

signal block_changed(world_pos: Vector3i, old_id: int, new_id: int)

const MESH_BUDGET_PER_FRAME: int = 4

## World identity (persisted by the save system, Phase 14). All terrain in
## this world derives from this seed via VoxelGenerator.
var world_seed: int = 0
## The generator for this world (set by the composition root; used by
## ChunkManager streaming in Phase 6).
var generator: VoxelGenerator = null

var _chunks: Dictionary = {}        # Vector3i -> VoxelChunk
var _mesh_nodes: Dictionary = {}    # Vector3i -> Node3D
var _dirty_queue: Array[Vector3i] = []
var _dirty_set: Dictionary = {}     # dedupe for _dirty_queue
var _materials: Array[Material] = []


# --- Coordinate mapping (static, canonical) ---

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


# --- Chunk map ---

func has_chunk(coord: Vector3i) -> bool:
	return _chunks.has(coord)


func chunk_count() -> int:
	return _chunks.size()


## Snapshot of loaded chunk coords (streaming unload + save system use this).
func get_loaded_chunk_coords() -> Array[Vector3i]:
	var coords: Array[Vector3i] = []
	for coord in _chunks:
		coords.append(coord)
	return coords


## Returns the chunk at coord, or null. No creation side effects.
func get_chunk(coord: Vector3i) -> VoxelChunk:
	return _chunks.get(coord, null)


## Inserts a chunk (freshly generated or loaded) and queues its mesh rebuild.
## Returns true if a chunk already existed at that coord (caller may inspect).
func add_chunk(chunk: VoxelChunk) -> bool:
	var had := _chunks.has(chunk.chunk_coord)
	_chunks[chunk.chunk_coord] = chunk
	_queue_rebuild(chunk.chunk_coord)
	return had


## Removes the chunk AND frees its mesh node (unload path for Phase 6).
func remove_chunk(coord: Vector3i) -> VoxelChunk:
	var chunk: VoxelChunk = _chunks.get(coord, null)
	if chunk == null:
		return null
	_chunks.erase(coord)
	_dequeue_rebuild(coord)
	var node: Node3D = _mesh_nodes.get(coord, null)
	if node != null:
		node.queue_free()
		_mesh_nodes.erase(coord)
	return chunk


## Returns the existing chunk at coord, or creates an empty (all-AIR) chunk
## queued for a (no-op) rebuild. Empty chunks are NOT marked modified.
func get_or_create_chunk(coord: Vector3i) -> VoxelChunk:
	var chunk := get_chunk(coord)
	if chunk == null:
		chunk = VoxelChunk.new(coord)
		_chunks[coord] = chunk
		_queue_rebuild(coord)
	return chunk


# --- World-space block access ---

## World-space block read. Missing chunks read as AIR.
func get_block(world_pos: Vector3i) -> int:
	var chunk := get_chunk(world_to_chunk(world_pos))
	if chunk == null:
		return BlockRegistry.AIR_ID
	return chunk.get_block(world_to_local(world_pos))


## World-space block write (gameplay edits only). Returns true if the world
## state changed. Marks the chunk modified, dirties the owning chunk and any
## border-sharing neighbour chunks (face-culling correctness, §5.3), and
## emits block_changed.
func set_block(world_pos: Vector3i, id: int) -> bool:
	var chunk_coord := world_to_chunk(world_pos)
	var chunk := get_or_create_chunk(chunk_coord)
	var local := world_to_local(world_pos)
	var old_id: int = chunk.get_block(local)
	var changed := chunk.set_block(local, id)
	if changed:
		block_changed.emit(world_pos, old_id, id)
		_queue_rebuild(chunk_coord)
		# Border edits change neighbour face visibility — flag and queue the
		# bordering chunk IF it exists (never create chunks just to rebuild).
		for axis in 3:
			if local[axis] == 0:
				_dirty_neighbour(chunk_coord, axis, -1)
			elif local[axis] == VoxelChunk.CHUNK_SIZE - 1:
				_dirty_neighbour(chunk_coord, axis, 1)
	return changed


func _dirty_neighbour(chunk_coord: Vector3i, axis: int, direction: int) -> void:
	var n := chunk_coord
	n[axis] += direction
	var neighbour: VoxelChunk = get_chunk(n)
	if neighbour == null:
		return
	neighbour.is_dirty = true
	_queue_rebuild(n)


# --- Meshing ---

## Synchronous rebuild of every dirty chunk (startup + tests).
func rebuild_all_dirty() -> void:
	while not _dirty_queue.is_empty():
		var coord: Vector3i = _dirty_queue.pop_front()
		_dirty_set.erase(coord)
		rebuild_chunk_mesh(coord)


func _process(_delta: float) -> void:
	var budget := MESH_BUDGET_PER_FRAME
	while budget > 0 and not _dirty_queue.is_empty():
		var coord: Vector3i = _dirty_queue.pop_front()
		_dirty_set.erase(coord)
		rebuild_chunk_mesh(coord)
		budget -= 1


func _queue_rebuild(coord: Vector3i) -> void:
	if _dirty_set.has(coord):
		return
	_dirty_set[coord] = true
	_dirty_queue.append(coord)


func _dequeue_rebuild(coord: Vector3i) -> void:
	if not _dirty_set.has(coord):
		return
	_dirty_set.erase(coord)
	var i := _dirty_queue.find(coord)
	if i != -1:
		_dirty_queue.remove_at(i)


## Rebuilds the mesh + collision for one chunk. Missing chunk -> frees any
## stale mesh node. Clears is_dirty on success.
func rebuild_chunk_mesh(coord: Vector3i) -> void:
	_ensure_materials()
	var chunk := get_chunk(coord)
	var node: Node3D = _mesh_nodes.get(coord, null)
	if chunk == null:
		if node != null:
			node.queue_free()
			_mesh_nodes.erase(coord)
		return
	var data := VoxelMesher.build_mesh(chunk, self)
	if node == null:
		node = _create_chunk_node(coord)
	var mesh := data.to_array_mesh()
	var mesh_instance := node.get_node("Mesh") as MeshInstance3D
	mesh_instance.mesh = mesh
	for s in MeshData.SURFACE_COUNT:
		if s < mesh.get_surface_count():
			mesh.surface_set_material(s, _materials[s])
	var shape_node := node.get_node("Collision/Shape") as CollisionShape3D
	var opaque_verts: PackedVector3Array = data.vertices[MeshData.SURFACE_OPAQUE]
	var opaque_idx: PackedInt32Array = data.indices[MeshData.SURFACE_OPAQUE]
	if opaque_idx.is_empty():
		shape_node.shape = null
	else:
		# ConcavePolygonShape3D wants a triangle soup (len % 3 == 0):
		# expand the indexed quad geometry through the index buffer.
		var faces := PackedVector3Array()
		faces.resize(opaque_idx.size())
		for i in opaque_idx.size():
			faces[i] = opaque_verts[opaque_idx[i]]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape_node.shape = shape
	chunk.is_dirty = false


func _create_chunk_node(coord: Vector3i) -> Node3D:
	var node := Node3D.new()
	node.name = "ChunkNode_%d_%d_%d" % [coord.x, coord.y, coord.z]
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	node.add_child(mesh_instance)
	var body := StaticBody3D.new()
	body.name = "Collision"
	node.add_child(body)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	body.add_child(shape_node)
	add_child(node)
	_mesh_nodes[coord] = node
	return node


func _ensure_materials() -> void:
	if _materials.size() == MeshData.SURFACE_COUNT:
		return
	_materials.resize(MeshData.SURFACE_COUNT)
	# Opaque: lit, vertex-color albedo, rough.
	var opaque := StandardMaterial3D.new()
	opaque.vertex_color_use_as_albedo = true
	opaque.roughness = 1.0
	_materials[MeshData.SURFACE_OPAQUE] = opaque
	# Transparent (leaves): alpha blend, double-sided.
	var transparent := StandardMaterial3D.new()
	transparent.vertex_color_use_as_albedo = true
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.cull_mode = BaseMaterial3D.CULL_DISABLED
	transparent.roughness = 1.0
	_materials[MeshData.SURFACE_TRANSPARENT] = transparent
	# Emissive (crystal): alpha blend, double-sided, vertex color -> emission
	# via a tiny procedural shader (StandardMaterial3D lost vertex-color
	# emission in Godot 4.x — see TECHNICAL_NOTES).
	var emissive := ShaderMaterial.new()
	emissive.shader = preload("res://src/world/shaders/emissive.gdshader")
	emissive.set_shader_parameter("emission_energy", 2.0)
	_materials[MeshData.SURFACE_EMISSIVE] = emissive
