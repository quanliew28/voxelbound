extends RefCounted
class_name MeshData
## Result container for VoxelMesher — three parallel geometry sets.
## Canonical spec: docs/ARCHITECTURE.md §5.2 (VoxelMesher / MeshData).
## Pure data; no nodes, no materials (materials live in VoxelWorld).

const SURFACE_OPAQUE: int = 0
const SURFACE_TRANSPARENT: int = 1
const SURFACE_EMISSIVE: int = 2
const SURFACE_COUNT: int = 3
const SURFACE_NAMES: Array[String] = ["opaque", "transparent", "emissive"]

var vertices: Array[PackedVector3Array]
var normals: Array[PackedVector3Array]
var colors: Array[PackedColorArray]
var indices: Array[PackedInt32Array]

func _init() -> void:
	for i in SURFACE_COUNT:
		vertices.append(PackedVector3Array())
		normals.append(PackedVector3Array())
		colors.append(PackedColorArray())
		indices.append(PackedInt32Array())


func surface_empty(surface: int) -> bool:
	return indices[surface].is_empty()


func surface_vertex_count(surface: int) -> int:
	return vertices[surface].size()


func surface_triangle_count(surface: int) -> int:
	return indices[surface].size() / 3


## Builds a multi-surface ArrayMesh (surfaces with no geometry are omitted).
func to_array_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in SURFACE_COUNT:
		if surface_empty(s):
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices[s]
		arrays[Mesh.ARRAY_NORMAL] = normals[s]
		arrays[Mesh.ARRAY_COLOR] = colors[s]
		arrays[Mesh.ARRAY_INDEX] = indices[s]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
