extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var world: VoxelWorld
var player: PlayerController

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_spawn_player()

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.unique_name_in_owner = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.50, 0.92)
	sky_material.sky_horizon_color = Color(0.75, 0.84, 0.95)
	sky_material.sky_curve = 0.15
	sky_material.ground_bottom_color = Color(0.20, 0.22, 0.30)
	sky_material.ground_curve = 0.02
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.unique_name_in_owner = true
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(sun)

func _build_terrain() -> void:
	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	# Phase 3 temporary stand-in terrain (deleted when VoxelGenerator lands).
	VoxelTestTerrain.fill(world, 2)
	world.rebuild_all_dirty()

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	var ground_y := float(VoxelTestTerrain.height_at(0, 0))
	player.position = Vector3(0.0, ground_y + 1.5, 0.0)
	add_child(player)
	player.world = world
