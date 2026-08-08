extends StaticBody3D
class_name TestTerrain

const GRID_SIZE: int = 64
const VERTEX_COUNT: int = 65
const SIZE_METERS: float = 128.0
const CELL_SIZE: float = SIZE_METERS / float(GRID_SIZE)
const AMPLITUDE: float = 10.0
const FREQUENCY: float = 0.02
const NOISE_SEED: int = 12345

const COLOR_LOW: Color = Color(0.16, 0.42, 0.14)
const COLOR_HIGH: Color = Color(0.70, 0.62, 0.34)

var _noise: FastNoiseLite
var _vertices: PackedVector3Array
var _indices: PackedInt32Array

func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = NOISE_SEED
	_noise.frequency = FREQUENCY
	_noise.fractal_octaves = 3
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func _ready() -> void:
	_build_mesh()
	_build_collision()

func get_height_at(world_x: float, world_z: float) -> float:
	return _noise.get_noise_2d(world_x, world_z) * AMPLITUDE

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_vertices.resize(VERTEX_COUNT * VERTEX_COUNT)
	for iz in VERTEX_COUNT:
		var z := _world_z(iz)
		for ix in VERTEX_COUNT:
			var x := _world_x(ix)
			var pos := Vector3(x, get_height_at(x, z), z)
			var vertex_index := iz * VERTEX_COUNT + ix
			_vertices[vertex_index] = pos
			st.set_normal(_vertex_normal(ix, iz))
			st.set_color(_vertex_color(pos.y))
			st.add_vertex(pos)
	_indices.resize(GRID_SIZE * GRID_SIZE * 6)
	var index_count := 0
	for iz in GRID_SIZE:
		for ix in GRID_SIZE:
			var a := iz * VERTEX_COUNT + ix
			var b := a + 1
			var c := a + VERTEX_COUNT
			var d := c + 1
			_indices[index_count] = b
			_indices[index_count + 1] = a
			_indices[index_count + 2] = c
			_indices[index_count + 3] = b
			_indices[index_count + 4] = c
			_indices[index_count + 5] = d
			index_count += 6
	for vertex_index in _indices:
		st.add_index(vertex_index)
	var mesh := st.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _build_material()
	add_child(mesh_instance)

func _build_collision() -> void:
	var faces := PackedVector3Array()
	faces.resize(_indices.size())
	for i in _indices.size():
		faces[i] = _vertices[_indices[i]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	add_child(collision_shape)

func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material

func _vertex_normal(ix: int, iz: int) -> Vector3:
	var x := _world_x(ix)
	var z := _world_z(iz)
	var x_left := _world_x(maxi(ix - 1, 0))
	var x_right := _world_x(mini(ix + 1, VERTEX_COUNT - 1))
	var z_up := _world_z(maxi(iz - 1, 0))
	var z_down := _world_z(mini(iz + 1, VERTEX_COUNT - 1))
	var dh_dx := (get_height_at(x_right, z) - get_height_at(x_left, z)) / (x_right - x_left)
	var dh_dz := (get_height_at(x, z_down) - get_height_at(x, z_up)) / (z_down - z_up)
	return Vector3(-dh_dx, 1.0, -dh_dz).normalized()

func _vertex_color(height: float) -> Color:
	var t := clampf((height + AMPLITUDE) / (2.0 * AMPLITUDE), 0.0, 1.0)
	return COLOR_LOW.lerp(COLOR_HIGH, t)

func _world_x(ix: int) -> float:
	return float(ix) * CELL_SIZE - SIZE_METERS * 0.5

func _world_z(iz: int) -> float:
	return float(iz) * CELL_SIZE - SIZE_METERS * 0.5
