extends Node3D
class_name DayNight
## Day/night cycle driving the Phase 1 sky rig (canonical: ARCHITECTURE.md §8).
## day_time is 0..1: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon,
## 0.75 = sunset. Sun + moon are opposite directional lights; sky colors,
## ambient energy, sun energy and the procedural star field all derive from
## the sun elevation — a pure function of day_time.

@export var day_length_seconds: float = 600.0
@export var start_time: float = 0.20

var day_time: float = 0.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_environment: WorldEnvironment
var star_material: ShaderMaterial = null

const DAY_SKY: Color = Color(0.30, 0.50, 0.92)
const NIGHT_SKY: Color = Color(0.015, 0.025, 0.07)
const DAY_AMBIENT: float = 1.0
const NIGHT_AMBIENT: float = 0.22
const SUN_AZIMUTH_DEG: float = -30.0


## Sun elevation above the horizon in degrees: -90 (midnight) .. +90 (noon).
## Pure function — unit-testable without nodes.
static func sun_elevation_deg(day_time: float) -> float:
	return 90.0 * sin((day_time - 0.25) * TAU)


func _ready() -> void:
	day_time = start_time


func setup(sun_light: DirectionalLight3D, moon_light: DirectionalLight3D,
		env: WorldEnvironment, stars: ShaderMaterial) -> void:
	sun = sun_light
	moon = moon_light
	world_environment = env
	star_material = stars


func _process(delta: float) -> void:
	if sun == null or world_environment == null:
		return
	day_time = fmod(day_time + delta / day_length_seconds, 1.0)
	_update()


func _update() -> void:
	var elev := sun_elevation_deg(day_time)
	var day_factor := clampf(sin(deg_to_rad(elev)), 0.0, 1.0)
	var night_factor := clampf(-sin(deg_to_rad(elev)), 0.0, 1.0)
	sun.rotation_degrees = Vector3(elev - 90.0, SUN_AZIMUTH_DEG, 0.0)
	moon.rotation_degrees = Vector3(elev + 90.0, SUN_AZIMUTH_DEG, 0.0)  # opposite sun
	sun.light_energy = 0.15 + day_factor * 1.05
	moon.light_energy = night_factor * 0.35
	var sky := world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = DAY_SKY.lerp(NIGHT_SKY, night_factor)
	sky.energy_multiplier = 0.35 + 0.65 * day_factor
	world_environment.environment.ambient_light_energy = lerpf(NIGHT_AMBIENT, DAY_AMBIENT, day_factor)
	if star_material != null:
		star_material.set_shader_parameter("night", night_factor)
