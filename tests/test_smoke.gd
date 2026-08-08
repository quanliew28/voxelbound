extends RefCounted

const FORBIDDEN_SUFFIXES: Array[String] = [
	".png", ".jpg", ".jpeg", ".svg", ".fbx", ".obj",
	".gltf", ".glb", ".wav", ".ogg", ".mp3", ".ttf", ".otf",
]

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0
var _instance: Node

func run() -> int:
	_load_scene()
	await _step_frames(5)
	_check_player()
	await _check_gravity()
	await _check_movement()
	await _check_terrain()
	_check_environment()
	_check_zero_assets()
	_cleanup()
	print("SUITE smoke: %d passed, %d failed" % [last_passed, _failed])
	return _failed

func _step_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		last_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		var msg := "FAIL: " + name
		if not detail.is_empty():
			msg += " -- " + detail
		print(msg)

func _load_scene() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_instance = scene.instantiate()
	tree.root.add_child(_instance)

func _check_player() -> void:
	var player := _find_node(_instance, "Player")
	_check(player != null, "player exists")
	if player == null:
		return
	_check(player.has_method("simulate_for_test"), "player has simulate_for_test")

func _check_gravity() -> void:
	var player := _find_node(_instance, "Player") as Node3D
	if player == null:
		return
	var start_y: float = player.global_position.y
	await _step_frames(20)
	var end_y: float = player.global_position.y
	_check(end_y < start_y, "gravity", "y %f -> %f" % [start_y, end_y])

func _check_movement() -> void:
	var player := _find_node(_instance, "Player") as PlayerController
	if player == null:
		return
	var start := player.global_position
	player.simulate_for_test(Vector2(0, -1), true, false, false)
	await _step_frames(40)
	var moved: float = (player.global_position - start).length()
	_check(moved > 0.5, "movement", "distance %f" % moved)
	player.simulate_for_test(Vector2.ZERO, false, false, false)

func _check_terrain() -> void:
	var world := _find_node(_instance, "VoxelWorld") as VoxelWorld
	_check(world != null, "voxel world exists")
	if world == null:
		return
	_check(world.chunk_count() > 0, "voxel world has chunks", "got %d" % world.chunk_count())
	var found_mesh := false
	var found_collision := false
	for child in world.get_children():
		if not child.name.begins_with("ChunkNode_"):
			continue
		var mi := child.get_node_or_null("Mesh") as MeshInstance3D
		if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			found_mesh = true
		var cs := child.get_node_or_null("Collision/Shape") as CollisionShape3D
		if cs != null and cs.shape is ConcavePolygonShape3D:
			found_collision = true
	_check(found_mesh, "voxel world has meshed chunk")
	_check(found_collision, "voxel world has chunk collision")
	# player lands on the voxel terrain and rests at the surface
	var player := _find_node(_instance, "Player") as CharacterBody3D
	await _step_frames(60)
	_check(player != null and player.is_on_floor(), "player lands on voxel terrain")
	if player != null:
		var ground_y := float(VoxelTestTerrain.height_at(0, 0))
		_check(absf(player.global_position.y - (ground_y + 1.0)) < 1.0,
			"player rests at surface", "y %f ground %f" % [player.global_position.y, ground_y])

func _check_environment() -> void:
	var world_environment := _find_node(_instance, "WorldEnvironment")
	_check(world_environment is WorldEnvironment, "environment exists")
	var sun := _find_node(_instance, "Sun")
	_check(sun is DirectionalLight3D, "sun exists")

func _check_zero_assets() -> void:
	var violations: Array[String] = []
	_scan_assets("res://", violations)
	_check(violations.is_empty(), "zero assets", ", ".join(violations))

func _scan_assets(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_assets(full_path, violations)
		else:
			var lower := entry.to_lower()
			for suffix in FORBIDDEN_SUFFIXES:
				if lower.ends_with(suffix):
					violations.append(full_path)
					break
		entry = dir.get_next()
	dir.list_dir_end()

func _find_node(from: Node, name: String) -> Node:
	if from.name == name:
		return from
	for child in from.get_children():
		var found := _find_node(child, name)
		if found != null:
			return found
	return null

func _cleanup() -> void:
	tree.root.remove_child(_instance)
	_instance.queue_free()
	_instance = null
