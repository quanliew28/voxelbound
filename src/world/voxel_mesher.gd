extends RefCounted
class_name VoxelMesher
## Pure function: turns a chunk (+ world for cross-border neighbour reads)
## into a 3-surface MeshData. NO nodes, NO state, NO engine calls.
## Canonical spec: docs/ARCHITECTURE.md §5.2.
##
## Face-visibility rule: a face is visible iff the neighbour cell is AIR,
## OR the neighbour is non-opaque AND has a different block id.
## Face brightness (vertex-color modulation, no textures): top 1.0,
## sides 0.8, bottom 0.55.

## [neighbour offset (Vector3i), normal, tangent1, tangent2, brightness]
## t1 x t2 == normal guarantees CCW winding viewed from outside.
const FACES: Array = [
	[Vector3i(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), 1.0],   # top
	[Vector3i(0, -1, 0), Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.55], # bottom
	[Vector3i(1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), 0.8],    # +x
	[Vector3i(-1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.8],  # -x
	[Vector3i(0, 0, 1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), 0.8],    # +z
	[Vector3i(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0), 0.8],  # -z
]


static func build_mesh(chunk: VoxelChunk, world: VoxelWorld) -> MeshData:
	var data := MeshData.new()
	var reg := BlockRegistry.shared()
	var chunk_origin := chunk.chunk_coord * VoxelChunk.CHUNK_SIZE
	for y in VoxelChunk.CHUNK_SIZE:
		for z in VoxelChunk.CHUNK_SIZE:
			for x in VoxelChunk.CHUNK_SIZE:
				var local := Vector3i(x, y, z)
				var id: int = chunk.get_block(local)
				if id == BlockRegistry.AIR_ID:
					continue
				var surface := _surface_for(reg, id)
				var cell_world := chunk_origin + local
				for face in FACES:
					if not _face_visible(chunk, world, chunk_origin, local, id, cell_world + face[0]):
						continue
					_add_face(data, surface, reg, id, cell_world, face)
	return data


static func _face_visible(chunk: VoxelChunk, world: VoxelWorld, chunk_origin: Vector3i,
		local: Vector3i, id: int, neighbor_pos: Vector3i) -> bool:
	var neighbor_id: int
	var neighbor_local := neighbor_pos - chunk_origin
	if VoxelChunk.is_local_in_bounds(neighbor_local):
		neighbor_id = chunk.get_block(neighbor_local)
	else:
		neighbor_id = world.get_block(neighbor_pos)
	if neighbor_id == BlockRegistry.AIR_ID:
		return true
	if neighbor_id == id:
		return false
	return not BlockRegistry.shared().is_opaque(neighbor_id)


static func _surface_for(reg: BlockRegistry, id: int) -> int:
	var def := reg.get_def(id)
	if bool(def.get("emissive", false)):
		return MeshData.SURFACE_EMISSIVE
	if bool(def.get("transparent", false)):
		return MeshData.SURFACE_TRANSPARENT
	return MeshData.SURFACE_OPAQUE


static func _add_face(data: MeshData, surface: int, reg: BlockRegistry, id: int,
		cell_origin: Vector3i, face: Array) -> void:
	var base: int = data.vertices[surface].size()
	# The face plane sits at cell + max(offset, 0): top/+x/+z faces lie at
	# cell+1, bottom/-x/-z faces lie AT the cell's own boundary.
	var face_base: Vector3i = cell_origin + (face[0] as Vector3i).clamp(Vector3i.ZERO, Vector3i.ONE)
	var o := Vector3(face_base)
	var t1: Vector3 = face[2]
	var t2: Vector3 = face[3]
	var brightness: float = face[4]
	var corners := [
		o, o + t1, o + t1 + t2, o + t2,
	]
	var col := reg.get_color(id)
	col.r *= brightness
	col.g *= brightness
	col.b *= brightness
	for corner in corners:
		data.vertices[surface].append(corner)
		data.normals[surface].append(face[1])
		data.colors[surface].append(col)
	var idx := data.indices[surface]
	# Godot front faces are CLOCKWISE (left-handed convention) — opposite of
	# the right-hand-rule cross product of the tangents. Flip the winding so
	# faces face outward for BOTH the renderer's backface culling and
	# ConcavePolygonShape3D's one-sided collision.
	idx.append(base)
	idx.append(base + 2)
	idx.append(base + 1)
	idx.append(base)
	idx.append(base + 3)
	idx.append(base + 2)
