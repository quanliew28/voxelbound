extends RefCounted
## Phase 13 suite: player/creature combat, health, knockback, death, drops,
## fall damage, head bob. Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_fall_damage_formula()
	_check_melee_damage()
	await _check_player_damage()
	await _check_player_death_respawn()
	await _check_creature_damage()
	await _check_creature_death_drops()
	await _check_creature_attacks_player()
	await _check_head_bob()
	print("SUITE combat: %d passed, %d failed" % [last_passed, _failed])
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


func _settle() -> void:
	await tree.physics_frame


func _check_fall_damage_formula() -> void:
	_check(PlayerController.calc_fall_damage(5.0) == 0.0, "no fall damage below threshold")
	_check(PlayerController.calc_fall_damage(14.0) == 0.0, "no fall damage at threshold")
	_check(absf(PlayerController.calc_fall_damage(24.0) - 20.0) < 0.001, "fall damage scales above threshold")


func _check_melee_damage() -> void:
	var player := PlayerController.new()
	player.inventory.add_item(BlockRegistry.shared().get_id(&"STONE"), 1)
	_check(player.melee_damage() == 1, "barehand melee damage 1")
	player.inventory.add_item(ToolRegistry.id_of(&"COPPER_PICK"), 1)  # slot 1 (stone holds 0)
	player.selected_slot = 1
	_check(player.melee_damage() == ToolRegistry.get_damage(ToolRegistry.id_of(&"COPPER_PICK")),
		"tool melee damage from registry", "got %d" % player.melee_damage())
	player.free()


const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _make_player(at: Vector3) -> PlayerController:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.position = at
	tree.root.add_child(player)
	return player


func _check_player_damage() -> void:
	var player := _make_player(Vector3.ZERO)
	await _settle()
	var got_signal := [false]  # lambda capture is by value — use a mutable ref
	player.damaged.connect(func(_a: float) -> void: got_signal[0] = true)
	var before := player.hp
	player.take_damage(10.0, Vector3(5, 0, 0))
	_check(player.hp == before - 10.0, "player hp reduced", "%.1f -> %.1f" % [before, player.hp])
	_check(got_signal[0], "damaged signal emitted")
	player.queue_free()
	await _settle()


func _check_player_death_respawn() -> void:
	var player := _make_player(Vector3(20, 4, 20))
	await _settle()
	player.spawn_point = Vector3(3, 4, 5)
	player.take_damage(PlayerController.MAX_HP + 5.0, Vector3.ZERO)
	_check(player.hp == PlayerController.MAX_HP, "respawn restores hp")
	_check(player.global_position.distance_to(player.spawn_point) < 0.01, "respawn returns to spawn point")
	player.queue_free()
	await _settle()


func _check_creature_damage() -> void:
	var c := Creature.new(Creature.Type.STONEBACK, 1)
	c.position = Vector3(5, 0, 5)
	tree.root.add_child(c)
	await _settle()
	var before := c.hp
	var died := c.take_damage(3.0, Vector3(1, 0, 0))
	_check(c.hp == before - 3.0 and not died, "creature hp reduced without death")
	_check(c.take_damage(999.0, Vector3.ZERO), "creature dies at zero hp")
	c.queue_free()
	await _settle()


func _check_creature_death_drops() -> void:
	var spawner := CreatureSpawner.new(1)
	tree.root.add_child(spawner)
	await _settle()
	var c := Creature.new(Creature.Type.BURROWER, 2)
	c.position = Vector3(0, 0, 0)
	spawner.add_child(c)
	c.died.connect(spawner._on_creature_died)
	await _settle()
	var pickups_before := 0
	for child in tree.root.get_children():
		if child is PickupEntity:
			pickups_before += 1
	c.take_damage(999.0, Vector3.ZERO)
	await _settle()
	var pickups_after := 0
	for child in tree.root.get_children():
		if child is PickupEntity:
			pickups_after += 1
	_check(pickups_after > pickups_before, "creature death spawns pickup drops",
		"%d -> %d" % [pickups_before, pickups_after])
	spawner.queue_free()
	await _settle()


func _check_creature_attacks_player() -> void:
	var c := Creature.new(Creature.Type.FOREST_STALKER, 3)
	c.position = Vector3(0, 0, 0)
	tree.root.add_child(c)
	await _settle()
	var player := _make_player(Vector3(1.2, 0, 0))
	await _settle()
	c.player = player
	c.state = Creature.State.CHASE
	var before := player.hp
	c._process(0.1)  # _process already attacks once (cooldown 1s)
	_check(player.hp < before, "creature attack damages player", "%.1f -> %.1f" % [before, player.hp])
	player.queue_free()
	c.queue_free()
	await _settle()


func _check_head_bob() -> void:
	_check(absf(PlayerController.bob_offset(0.0)) < 0.001, "bob offset zero at phase 0")
	_check(absf(PlayerController.bob_offset(PI / 2.0) - PlayerController.BOB_AMPLITUDE) < 0.001, "bob offset peaks at PI/2")
	var player := _make_player(Vector3.ZERO)
	await _settle()
	player.velocity = Vector3(5, 0, 0)
	player._update_head_bob(0.1)
	_check(player._bob_phase > 0.0, "head bob phase advances while walking", "phase=%f" % player._bob_phase)
	player.queue_free()
	await _settle()
