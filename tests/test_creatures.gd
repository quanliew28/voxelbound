extends RefCounted
## Phase 12 suite: Creature data + AI state machine + spawner.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_type_data()
	_check_body_built()
	_check_wander()
	_check_chase()
	_check_flee()
	_check_return()
	_check_wander_determinism()
	_check_spawner()
	print("SUITE creatures: %d passed, %d failed" % [last_passed, _failed])
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


func _make_creature(creature_type: int, at: Vector3, seed_value: int = 7) -> Creature:
	var creature := Creature.new(creature_type, seed_value)
	creature.position = at
	tree.root.add_child(creature)
	return creature


## Wait until nodes added this frame are fully inside the tree (global
## transforms otherwise read as identity — TECHNICAL_NOTES).
func _settle() -> void:
	await tree.physics_frame


func _check_type_data() -> void:
	_check(Creature.TYPE_COUNT == 5, "creatures five types")
	for t in Creature.TYPE_COUNT:
		var d := Creature.TYPES[t]
		_check(float(d.speed) > 0.0, "type %d has speed" % t)
		_check(float(d.vision) > 0.0, "type %d has vision" % t)
		_check(not str(d.name).is_empty(), "type %d has name" % t)


func _check_body_built() -> void:
	var c := _make_creature(Creature.Type.STONEBACK, Vector3.ZERO)
	await tree.physics_frame
	var body_count := 0
	for child in c.get_children():
		if child is MeshInstance3D:
			body_count += 1
	_check(body_count >= 3, "creature body built from primitives", "%d meshes" % body_count)
	var moth := _make_creature(Creature.Type.GLOW_MOTH, Vector3(5, 0, 5))
	await tree.physics_frame
	_check(moth.def().glow == true, "glow moth marked emissive")
	moth.queue_free()
	c.queue_free()
	await tree.physics_frame


func _check_wander() -> void:
	var c := _make_creature(Creature.Type.BURROWER, Vector3(10, 0, 10))
	await _settle()
	c.home = Vector3(10, 0, 10)
	c._pick_wander_target()
	var before := c.global_position
	c.state = Creature.State.WANDER
	for i in 20:
		c._process(0.1)
	var moved := c.global_position.distance_to(before)
	_check(moved > 0.05, "wander moves creature", "moved %.2f" % moved)
	c.queue_free()
	await tree.physics_frame


func _check_chase() -> void:
	var c := _make_creature(Creature.Type.FOREST_STALKER, Vector3(0, 0, 0))
	var player := Node3D.new()
	player.position = Vector3(4, 0, 0)
	tree.root.add_child(player)
	await _settle()
	c.player = player
	c._process(0.1)
	_check(c.state == Creature.State.CHASE, "aggressive creature chases in vision")
	var before := c.global_position
	for i in 30:
		c._process(0.1)
	_check(c.global_position.distance_to(player.global_position) < before.distance_to(player.global_position) - 0.3,
		"chase closes distance", "%.2f -> %.2f" % [before.distance_to(player.global_position), c.global_position.distance_to(player.global_position)])
	player.queue_free()
	c.queue_free()
	await tree.physics_frame


func _check_flee() -> void:
	var c := _make_creature(Creature.Type.BURROWER, Vector3(0, 0, 0))
	var player := Node3D.new()
	player.position = Vector3(2, 0, 0)
	tree.root.add_child(player)
	await _settle()
	c.player = player
	c._process(0.1)
	_check(c.state == Creature.State.FLEE, "passive creature flees player close")
	var before := c.global_position.distance_to(player.global_position)
	for i in 30:
		c._process(0.1)
	var after := c.global_position.distance_to(player.global_position)
	_check(after > before, "flee increases distance", "%.2f -> %.2f" % [before, after])
	player.queue_free()
	c.queue_free()
	await tree.physics_frame


func _check_return() -> void:
	var c := _make_creature(Creature.Type.STONEBACK, Vector3(20, 0, 20))
	await _settle()
	c.home = Vector3(20, 0, 20)
	var player := Node3D.new()
	player.position = Vector3(24, 0, 20)
	tree.root.add_child(player)
	await _settle()
	c.player = player
	c._process(0.1)
	c.state = Creature.State.RETURN
	c.target = c.home
	c.player = null
	for i in 60:
		c._process(0.1)
	_check(c.global_position.distance_to(c.home) < 1.0, "creature returns home")
	_check(c.state == Creature.State.IDLE, "return ends in idle")
	player.queue_free()
	c.queue_free()
	await tree.physics_frame


func _check_wander_determinism() -> void:
	var a := _make_creature(Creature.Type.BURROWER, Vector3(1, 0, 1), 99)
	var b := _make_creature(Creature.Type.BURROWER, Vector3(1, 0, 1), 99)
	await _settle()
	a.home = Vector3(1, 0, 1)
	b.home = Vector3(1, 0, 1)
	a._pick_wander_target()
	b._pick_wander_target()
	_check(a.target.is_equal_approx(b.target), "same seed -> same wander target")
	a.queue_free()
	b.queue_free()
	await tree.physics_frame


func _check_spawner() -> void:
	var gen := VoxelGenerator.new(4242)
	var world := VoxelWorld.new()
	world.generator = gen
	var spawner := CreatureSpawner.new(4242)
	tree.root.add_child(spawner)
	var player := Node3D.new()
	player.position = Vector3(1.5, 40, 1.5)  # meadow spawn area
	tree.root.add_child(player)
	await _settle()
	spawner.world = world
	spawner.player = player
	spawner.max_creatures = 4
	var pool := CreatureSpawner.pool_for_biome(BiomeRegistry.MEADOW)
	_check(pool == [Creature.Type.BURROWER], "meadow spawns burrowers")
	# force spawns (loop with high chance)
	for i in 30:
		spawner._try_spawn()
	_check(spawner.creatures.size() <= 4, "spawner respects cap", "got %d" % spawner.creatures.size())
	_check(spawner.creatures.size() >= 1, "spawner spawned at least one")
	if spawner.creatures.size() > 0:
		var first: Creature = spawner.creatures[0]
		_check(first.type == Creature.Type.BURROWER, "spawned creature matches biome pool")
	player.queue_free()
	spawner.queue_free()
	await tree.physics_frame
