extends RefCounted
## Phase 11 suite: DayNight cycle + Weather state machine + fog.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_elevation_math()
	await _check_time_advances()
	_check_sun_moon_opposition()
	_check_light_energies()
	_check_ambient_cycle()
	await _check_weather_states()
	_check_weather_determinism()
	_check_cold_biome_snow()
	print("SUITE daynight: %d passed, %d failed" % [last_passed, _failed])
	return _failed


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


func _check_elevation_math() -> void:
	_check(absf(DayNight.sun_elevation_deg(0.5) - 90.0) < 0.001, "elevation noon ~90", "got %f" % DayNight.sun_elevation_deg(0.5))
	_check(absf(DayNight.sun_elevation_deg(0.0) + 90.0) < 0.001, "elevation midnight ~-90", "got %f" % DayNight.sun_elevation_deg(0.0))
	_check(absf(DayNight.sun_elevation_deg(0.25)) < 0.001, "elevation sunrise ~0")
	_check(absf(DayNight.sun_elevation_deg(0.75)) < 0.001, "elevation sunset ~0")
	_check(DayNight.sun_elevation_deg(0.5) > DayNight.sun_elevation_deg(0.25), "elevation rises morning")


func _check_time_advances() -> void:
	var dn := DayNight.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	dn.setup(sun, moon, env, null)
	tree.root.add_child(dn)
	dn.day_length_seconds = 60.0
	var before := dn.day_time
	await tree.physics_frame
	await tree.physics_frame
	_check(dn.day_time > before, "day time advances", "%.3f -> %.3f" % [before, dn.day_time])
	dn.queue_free()
	await tree.physics_frame


func _check_sun_moon_opposition() -> void:
	var dn := DayNight.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	dn.setup(sun, moon, env, null)
	dn.day_time = 0.5
	dn._update()
	var diff := absf(sun.rotation_degrees.x - moon.rotation_degrees.x)
	_check(absf(diff - 180.0) < 0.001, "moon opposite sun", "diff %f" % diff)
	sun.free()
	moon.free()
	env.free()
	dn.free()


func _check_light_energies() -> void:
	var dn := DayNight.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	dn.setup(sun, moon, env, null)
	dn.day_time = 0.5
	dn._update()
	var noon_sun := sun.light_energy
	var noon_moon := moon.light_energy
	dn.day_time = 0.0
	dn._update()
	var midnight_sun := sun.light_energy
	var midnight_moon := moon.light_energy
	_check(noon_sun > midnight_sun, "sun brighter at noon", "%.2f vs %.2f" % [noon_sun, midnight_sun])
	_check(midnight_moon > noon_moon, "moon brighter at midnight", "%.2f vs %.2f" % [midnight_moon, noon_moon])
	sun.free()
	moon.free()
	env.free()
	dn.free()


func _check_ambient_cycle() -> void:
	var dn := DayNight.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	dn.setup(sun, moon, env, null)
	dn.day_time = 0.5
	dn._update()
	var noon_ambient := env.environment.ambient_light_energy
	dn.day_time = 0.0
	dn._update()
	var midnight_ambient := env.environment.ambient_light_energy
	_check(noon_ambient > midnight_ambient, "ambient brighter by day", "%.2f vs %.2f" % [noon_ambient, midnight_ambient])
	_check(midnight_ambient > 0.1, "night still faintly lit", "%.2f" % midnight_ambient)
	sun.free()
	moon.free()
	env.free()
	dn.free()


func _check_weather_states() -> void:
	var weather := Weather.new(42)
	tree.root.add_child(weather)
	await tree.physics_frame
	var env := Environment.new()
	weather.environment = env
	weather.force_state(Weather.State.CLEAR)
	_check(not weather.is_precipitating(), "clear: no precipitation")
	_check(not env.fog_enabled, "clear: fog off")
	weather.force_state(Weather.State.RAIN)
	_check(weather.is_precipitating() and not weather.is_snowing(), "rain: precipitating")
	_check(env.fog_enabled and absf(env.fog_density - Weather.RAIN_FOG_DENSITY) < 0.001, "rain: fog density")
	weather.force_state(Weather.State.SNOW)
	_check(weather.is_precipitating() and weather.is_snowing(), "snow: snowing")
	_check(env.fog_enabled and absf(env.fog_density - Weather.SNOW_FOG_DENSITY) < 0.001, "snow: denser fog")
	weather.queue_free()
	await tree.physics_frame


func _check_weather_determinism() -> void:
	var a := Weather.new(777)
	var b := Weather.new(777)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 5:
		a._pick_next_state()
		b._pick_next_state()
		seq_a.append(a.state)
		seq_b.append(b.state)
	_check(seq_a == seq_b, "weather schedule deterministic per seed", "a=%s b=%s" % [str(seq_a), str(seq_b)])


func _check_cold_biome_snow() -> void:
	var gen := VoxelGenerator.new(4242)
	var frost_col := Vector2i(0, 0)
	var found := false
	for dz in range(-300, 301, 6):
		for dx in range(-300, 301, 6):
			if gen.biome_at(dx, dz) == BiomeRegistry.FROSTLANDS:
				frost_col = Vector2i(dx, dz)
				found = true
				break
		if found:
			break
	_check(found, "frostlands column located")
	if not found:
		return
	var world := VoxelWorld.new()
	world.generator = gen
	var weather := Weather.new(1)
	weather.world = world
	var player := Node3D.new()
	player.position = Vector3(frost_col.x, 40, frost_col.y)
	weather.player = player
	tree.root.add_child(player)  # global_position needs a tree
	_check(weather._cold_biome(), "frostlands biome triggers snow")
	player.queue_free()
	weather.free()
