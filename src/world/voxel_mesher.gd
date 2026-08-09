extends RefCounted
class_name VoxelMesher
## Pure function: turns a chunk (+ world for cross-border neighbour reads)
## into a 3-surface MeshData. NO nodes, NO state, NO engine calls.
## Canonical spec: docs/ARCHITECTURE.md §5.2.
##
## Phase 17 — GREEDY MESHING: coplanar visible faces of the same block id
## are merged into rectangles before emission (5-20x fewer triangles on open
## terrain). Same public API (build_mesh -> MeshData), same rules:
##   - Face-visibility rule: a face is visible iff the neighbour cell is
##     AIR, OR the neighbour is non-opaque AND has a different block id.
##   - Face brightness (vertex-color modulation, no textures): top 1.0,
##     sides 0.8, bottom 0.55.
##   - Winding: triangle cross products OPPOSE the face normal (Godot's
##     clockwise-front convention) — enforced per quad from the u x v sign.

## [dir (Vector3i), u_axis, v_axis, brightness]
## u/v tangent axes per face; the emitter derives the index pattern from
## the sign of (u_vec x v_vec) . dir, so winding is always correct.
const FACES: Array = [
	[Vector3i(0, 1, 0), 0, 2, 1.0],    # top    (u=x, v=z)
	[Vector3i(0, -1, 0), 0, 2, 0.55],  # bottom (u=x, v=z)
	[Vector3i(1, 0, 0), 2, 1, 0.8],    # +x     (u=z, v=y)
	[Vector3i(-1, 0, 0), 2, 1, 0.8],   # -x     (u=z, v=y)
	[Vector3i(0, 0, 1), 0, 1, 0.8],    # +z     (u=x, v=y)
	[Vector3i(0, 0, -1), 0, 1, 0.8],   # -z     (u=x, v=y)
]

const AXES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]


static func build_mesh(chunk: VoxelChunk, world: VoxelWorld) -> MeshData:
	var data := MeshData.new()
	var reg := BlockRegistry.shared()
	var chunk_origin := chunk.chunk_coord * VoxelChunk.CHUNK_SIZE
	for face in FACES:
		_greedy_pass(data, reg, chunk, world, chunk_origin, face)
	return data


## One greedy pass over all 16 slices along a face direction.
static func _greedy_pass(data: MeshData, reg: BlockRegistry, chunk: VoxelChunk,
		world: VoxelWorld, chunk_origin: Vector3i, face: Array) -> void:
	var dir: Vector3i = face[0]
	var ui: int = face[1]
	var vi: int = face[2]
	var brightness: float = face[3]
	var n_axis := _axis_index(dir)
	for s in VoxelChunk.CHUNK_SIZE:
		var mask := _build_mask(reg, chunk, world, chunk_origin, dir, n_axis, ui, vi, s)
		_greedy_emit(data, reg, chunk_origin, dir, ui, vi, brightness, n_axis, s, mask)


## 16x16 grid of block ids for visible faces in one slice (-1 = none).
static func _build_mask(reg: BlockRegistry, chunk: VoxelChunk, world: VoxelWorld,
		chunk_origin: Vector3i, dir: Vector3i, n_axis: int, ui: int, vi: int, s: int) -> Array:
	var mask: Array = []
	for u in VoxelChunk.CHUNK_SIZE:
		var row: Array = []
		for v in VoxelChunk.CHUNK_SIZE:
			row.append(-1)
		mask.append(row)
	for u in VoxelChunk.CHUNK_SIZE:
		for v in VoxelChunk.CHUNK_SIZE:
			var local := Vector3i.ZERO
			local[n_axis] = s
			local[ui] = u
			local[vi] = v
			var id: int = chunk.get_block(local)
			if id == BlockRegistry.AIR_ID:
				continue
			var cell_world := chunk_origin + local
			if _face_visible(chunk, world, chunk_origin, local, id, cell_world + dir):
				mask[u][v] = id
	return mask


## 2D greedy rectangle packing over the mask, emitting one quad per run.
static func _greedy_emit(data: MeshData, reg: BlockRegistry, chunk_origin: Vector3i,
		dir: Vector3i, ui: int, vi: int, brightness: float, n_axis: int, s: int, mask: Array) -> void:
	var covered: Array = []
	for u in VoxelChunk.CHUNK_SIZE:
		var row: Array = []
		for v in VoxelChunk.CHUNK_SIZE:
			row.append(false)
		covered.append(row)
	for u in VoxelChunk.CHUNK_SIZE:
		for v in VoxelChunk.CHUNK_SIZE:
			var id: int = mask[u][v]
			if id == -1 or covered[u][v]:
				continue
			var w := 1
			while u + w < VoxelChunk.CHUNK_SIZE and mask[u + w][v] == id and not covered[u + w][v]:
				w += 1
			var h := 1
			while v + h < VoxelChunk.CHUNK_SIZE and _row_matches(mask, covered, u, v + h, w, id):
				h += 1
			_emit_quad(data, reg, chunk_origin, dir, ui, vi, brightness, n_axis, s, u, v, w, h, id)
			for du in w:
				for dv in h:
					covered[u + du][v + dv] = true


static func _row_matches(mask: Array, covered: Array, u: int, v: int, w: int, id: int) -> bool:
	for du in w:
		if mask[u + du][v] != id or covered[u + du][v]:
			return false
	return true


## One rectangle -> 4 vertices + 6 indices on the block's surface.
static func _emit_quad(data: MeshData, reg: BlockRegistry, chunk_origin: Vector3i,
		dir: Vector3i, ui: int, vi: int, brightness: float, n_axis: int, s: int,
		u: int, v: int, w: int, h: int, id: int) -> void:
	var surface := _surface_for(reg, id)
	var n := Vector3(dir)
	var plane := Vector3i.ZERO
	plane[n_axis] = s + (1 if dir[n_axis] > 0 else 0)  # top/+ faces at cell+1
	var base := Vector3(chunk_origin + plane) + Vector3(AXES[ui]) * u + Vector3(AXES[vi]) * v
	var u_vec := Vector3(AXES[ui]) * w
	var v_vec := Vector3(AXES[vi]) * h
	var corners := [base, base + u_vec, base + u_vec + v_vec, base + v_vec]
	var base_i: int = data.vertices[surface].size()
	var col := reg.get_color(id)
	col.r *= brightness
	col.g *= brightness
	col.b *= brightness
	for corner in corners:
		data.vertices[surface].append(corner)
		data.normals[surface].append(n)
		data.colors[surface].append(col)
	# winding: triangle crosses must oppose the normal (Godot CW rule)
	if u_vec.cross(v_vec).dot(n) > 0.0:
		data.indices[surface].append_array([base_i, base_i + 2, base_i + 1, base_i, base_i + 3, base_i + 2])
	else:
		data.indices[surface].append_array([base_i, base_i + 1, base_i + 2, base_i, base_i + 2, base_i + 3])


static func _axis_index(dir: Vector3i) -> int:
	for i in 3:
		if dir[i] != 0:
			return i
	return 1


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
