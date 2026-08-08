extends Node3D
class_name Weather
## Procedural weather: clear / rain / snow + fog. Canonical: ROADMAP Phase 11.
##
## The schedule is driven by a SEEDED RNG (world seed) so a given seed always
## produces the same weather timeline. Snow replaces rain in cold biomes
## (Frostlands / Crystal Highlands). Rain/snow are GPUParticles3D systems
## with a procedurally generated 1x1 texture; fog (Environment) thickens
## while precipitating.

enum State { CLEAR, RAIN, SNOW }

var world: VoxelWorld = null
var player: Node3D = null
var environment: Environment = null

var state: int = State.CLEAR
var _rng: RandomNumberGenerator
var _state_remaining: float = 0.0
var _rain_emitter: GPUParticles3D
var _snow_emitter: GPUParticles3D

const CLEAR_MIN: float = 120.0
const CLEAR_MAX: float = 400.0
const PRECIP_MIN: float = 60.0
const PRECIP_MAX: float = 180.0
const RAIN_FOG_DENSITY: float = 0.02
const SNOW_FOG_DENSITY: float = 0.035

func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func _ready() -> void:
	_build_emitters()
	state = State.CLEAR
	_state_remaining = _rng.randf_range(CLEAR_MIN, CLEAR_MAX)
	_apply_state()


func _process(delta: float) -> void:
	_state_remaining -= delta
	if _state_remaining <= 0.0:
		_pick_next_state()
	if _rain_emitter != null:
		_follow_player(_rain_emitter)
	if _snow_emitter != null:
		_follow_player(_snow_emitter)


func is_precipitating() -> bool:
	return state != State.CLEAR


func is_snowing() -> bool:
	return state == State.SNOW


## Player is in a cold biome -> snow instead of rain.
func _cold_biome() -> bool:
	if world == null or world.generator == null or player == null:
		return false
	var p := player.global_position
	var biome := world.generator.biome_at(floori(p.x), floori(p.z))
	return biome == BiomeRegistry.FROSTLANDS or biome == BiomeRegistry.CRYSTAL_HIGHLANDS


func _pick_next_state() -> void:
	if _rng.randf() < 0.35:
		state = State.SNOW if _cold_biome() else State.RAIN
		_state_remaining = _rng.randf_range(PRECIP_MIN, PRECIP_MAX)
	else:
		state = State.CLEAR
		_state_remaining = _rng.randf_range(CLEAR_MIN, CLEAR_MAX)
	_apply_state()


## For tests: jump straight to a state.
func force_state(new_state: int) -> void:
	state = new_state
	_apply_state()


func _apply_state() -> void:
	if environment != null:
		match state:
			State.CLEAR:
				environment.fog_enabled = false
			State.RAIN:
				environment.fog_enabled = true
				environment.fog_density = RAIN_FOG_DENSITY
			State.SNOW:
				environment.fog_enabled = true
				environment.fog_density = SNOW_FOG_DENSITY
	if _rain_emitter != null:
		var raining := state == State.RAIN
		_rain_emitter.emitting = raining
		_rain_emitter.visible = raining
	if _snow_emitter != null:
		var snowing := state == State.SNOW
		_snow_emitter.emitting = snowing
		_snow_emitter.visible = snowing


func _build_emitters() -> void:
	var texture := _white_texture()
	_rain_emitter = _make_emitter(texture, 900, 2.0, Vector3(-18, -20, -18), 0.12, Color(0.75, 0.85, 1.0, 0.5))
	_snow_emitter = _make_emitter(texture, 400, 4.0, Vector3(-1.2, -0.4, -1.2), 0.3, Color(1, 1, 1, 0.9))
	add_child(_rain_emitter)
	add_child(_snow_emitter)
	_apply_state()


func _make_emitter(texture: ImageTexture, amount: int, lifetime: float,
		gravity: Vector3, scale: float, color: Color) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.emitting = false
	emitter.visible = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(24, 2, 24)
	mat.gravity = gravity
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 12.0
	mat.scale_min = scale
	mat.scale_max = scale * 1.5
	mat.color = color
	emitter.process_material = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = _particle_material(texture)
	emitter.draw_pass_1 = mesh
	return emitter


func _particle_material(texture: ImageTexture) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return mat


func _white_texture() -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


func _follow_player(emitter: GPUParticles3D) -> void:
	if player == null:
		return
	emitter.global_position = player.global_position + Vector3(0, 14, 0)
