extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const WORLD_SEED: int = 424242
const SAVE_PATH := "user://world_save.vb"

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world: VoxelWorld
var chunk_manager: ChunkManager
var player: PlayerController
var hud: HUD
var day_night: DayNight
var weather: Weather
var creature_spawner: CreatureSpawner
var audio: AudioManager
var fx: ParticleFX

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_spawn_player()
	_build_hud()
	_build_day_night()
	_build_weather()
	_build_creatures()
	_build_audio()
	_build_fx()

func _build_hud() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.player = player
	player.damaged.connect(hud.on_player_damaged)

func _build_day_night() -> void:
	# moon: dim bluish light opposite the sun (driven by DayNight)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.unique_name_in_owner = true
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)
	# procedural star sphere (zero assets — shader-drawn stars)
	var stars := MeshInstance3D.new()
	stars.name = "Stars"
	var sphere := SphereMesh.new()
	sphere.radius = 600.0
	sphere.height = 1200.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var star_mat := ShaderMaterial.new()
	star_mat.shader = preload("res://src/environment/shaders/sky_stars.gdshader")
	sphere.material = star_mat
	stars.mesh = sphere
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, world_environment, star_mat)

func _build_weather() -> void:
	weather = Weather.new(WORLD_SEED)
	weather.name = "Weather"
	add_child(weather)
	weather.world = world
	weather.player = player
	weather.environment = world_environment.environment

func _build_creatures() -> void:
	creature_spawner = CreatureSpawner.new(WORLD_SEED)
	creature_spawner.name = "CreatureSpawner"
	add_child(creature_spawner)
	creature_spawner.world = world
	creature_spawner.player = player

func _build_audio() -> void:
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	player.audio = audio
	hud.audio = audio
	creature_spawner.audio = audio
	audio.start_ambient()

func _build_fx() -> void:
	fx = ParticleFX.new()
	fx.name = "FX"
	add_child(fx)
	player.fx = fx

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
	world.world_seed = WORLD_SEED
	world.generator = VoxelGenerator.new(WORLD_SEED)
	add_child(world)
	# Streaming (Phase 6): pre-fill the spawn area synchronously so the
	# player never spawns over air, then let ChunkManager keep the world
	# loaded around the player.
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	world.add_child(chunk_manager)
	chunk_manager.generate_sync(Vector3i.ZERO, 2)
	world.rebuild_all_dirty()

func _process(_delta: float) -> void:
	if chunk_manager != null and player != null:
		chunk_manager.set_player_position(player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		_save_game()
	elif event.is_action_pressed("load_game"):
		_load_game()


func _save_game() -> void:
	if day_night != null and SaveManager.save_game(SAVE_PATH, world, player, day_night.day_time):
		print("VOXELBOUND: game saved")
	else:
		print("VOXELBOUND: save failed")


func _load_game() -> void:
	var data := SaveManager.load_game(SAVE_PATH)
	if data.is_empty():
		print("VOXELBOUND: no save found")
		return
	SaveManager.apply_load(world, player, data)
	if day_night != null and data.has("time"):
		day_night.day_time = float(data["time"])
	print("VOXELBOUND: game loaded")


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	var ground_y := float(world.generator.height_at(0, 0))
	player.position = Vector3(0.0, ground_y + 1.5, 0.0)
	player.spawn_point = player.position
	add_child(player)
	player.world = world
