extends RefCounted
## Phase 7 suite: Inventory, ItemStack, pickup/drop, mining drops.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_add_and_stack()
	_check_remove()
	_check_counts()
	_check_mine_drops()
	_check_place_consumes()
	_check_drop_pickup()
	print("SUITE inventory: %d passed, %d failed" % [last_passed, _failed])
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


func _check_add_and_stack() -> void:
	var inv := Inventory.new()
	_check(inv.SLOT_COUNT == 36 and inv.HOTBAR_SIZE == 9, "inventory 36 slots / 9 hotbar")
	var stone := BlockRegistry.shared().get_id(&"STONE")
	var left := inv.add_item(stone, 100)
	_check(left == 0, "inventory 100 items fit in 2 stacks", "left %d" % left)
	_check(inv.get_slot(0).count == 64, "inventory first stack capped at 64")
	_check(inv.get_slot(1).count == 36, "inventory second stack holds remainder")
	# overflow only when all 36 slots are full
	var full := Inventory.new()
	var overflow := full.add_item(stone, 36 * 64 + 7)
	_check(overflow == 7, "inventory overflow past 36 full slots", "got %d" % overflow)
	_check(full.count_item(stone) == 36 * 64, "inventory full storage exact")
	# stacking into partial stacks
	var inv2 := Inventory.new()
	inv2.add_item(stone, 10)
	inv2.add_item(stone, 10)
	_check(inv2.get_slot(0).count == 20, "inventory stacks into existing stack")
	# different item goes to a new slot
	var dirt := BlockRegistry.shared().get_id(&"DIRT")
	inv2.add_item(dirt, 5)
	_check(inv2.get_slot(1) != null and inv2.get_slot(1).item_id == dirt, "inventory different item new slot")
	_check(inv2.count_item(dirt) == 5, "inventory count item")


func _check_remove() -> void:
	var inv := Inventory.new()
	var stone := BlockRegistry.shared().get_id(&"STONE")
	inv.add_item(stone, 10)
	_check(inv.remove_item(stone, 4) == 4 and inv.count_item(stone) == 6, "inventory remove partial")
	_check(inv.remove_item(stone, 6) == 6 and inv.count_item(stone) == 0, "inventory remove all")
	_check(inv.remove_item(stone, 1) == 0, "inventory remove empty -> 0")
	inv.add_item(stone, 3)
	_check(inv.remove_from_slot(0, 2) == 2 and inv.get_slot(0).count == 1, "inventory remove from slot")
	_check(inv.remove_from_slot(0, 5) == 1 and inv.get_slot(0) == null, "inventory remove empties slot")
	_check(inv.remove_from_slot(99, 1) == 0, "inventory remove bad slot -> 0")


func _check_counts() -> void:
	var inv := Inventory.new()
	var stone := BlockRegistry.shared().get_id(&"STONE")
	inv.add_item(stone, 10)
	inv.add_item(BlockRegistry.shared().get_id(&"DIRT"), 3)
	_check(inv.has_item(stone, 10) and not inv.has_item(stone, 11), "inventory has_item")
	_check(inv.find_slot(stone) == 0 and inv.find_slot(BlockRegistry.shared().get_id(&"DIRT")) == 1, "inventory find_slot")
	_check(inv.find_slot(BlockRegistry.shared().get_id(&"SAND")) == -1, "inventory find_slot missing")
	_check(not inv.is_empty(), "inventory not empty")
	var empty := Inventory.new()
	_check(empty.is_empty(), "inventory empty")


func _check_mine_drops() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	tree.root.add_child(world)
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	chunk.set_block_generated(Vector3i(1, 0, 0), reg.get_id(&"GRASS"))
	world.add_chunk(chunk)
	world.rebuild_all_dirty()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(0, 2.5, 0)
	player.world = world
	var head := player.get_node("Head") as Node3D
	head.rotation.x = -PI / 2
	player.try_mine()  # stone -> STONE drop
	_check(player.inventory.count_item(reg.get_id(&"STONE")) == 1, "mine stone drops stone")
	# move to the grass column and mine it (drops DIRT per registry)
	player.global_position = Vector3(1.5, 2.5, 0)
	player.try_mine()
	_check(player.inventory.count_item(reg.get_id(&"DIRT")) == 1, "mine grass drops dirt", "got %d" % player.inventory.count_item(reg.get_id(&"DIRT")))
	player.queue_free()
	world.queue_free()
	await tree.physics_frame


func _check_place_consumes() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	tree.root.add_child(world)
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	world.rebuild_all_dirty()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(0, 2.5, 0)
	player.world = world
	var head := player.get_node("Head") as Node3D
	head.rotation.x = -PI / 2
	player.inventory.add_item(reg.get_id(&"GRASS"), 1)
	player.try_place()  # places grass at (0,1,0), consumes the only unit
	_check(world.get_block(Vector3i(0, 1, 0)) == reg.get_id(&"GRASS"), "place uses selected item")
	_check(player.inventory.count_item(reg.get_id(&"GRASS")) == 0, "place consumes item")
	# empty hotbar cannot place
	player.try_place()
	_check(world.get_block(Vector3i(0, 2, 0)) == BlockRegistry.AIR_ID, "place with empty slot does nothing")
	# mining the placed grass gives DIRT back
	player.try_mine()
	_check(world.get_block(Vector3i(0, 1, 0)) == BlockRegistry.AIR_ID, "mine removes placed grass")
	player.queue_free()
	world.queue_free()
	await tree.physics_frame


func _check_drop_pickup() -> void:
	var reg := BlockRegistry.shared()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(0, 1.0, 0)
	var stone := reg.get_id(&"STONE")
	player.inventory.add_item(stone, 3)
	player.drop_selected()
	_check(player.inventory.count_item(stone) == 2, "drop removes one from inventory")
	var pickup := player.get_parent().get_node_or_null("PickupEntity")
	_check(pickup != null, "drop spawns pickup entity")
	if pickup == null:
		player.queue_free()
		await tree.physics_frame
		return
	# walk the player into the pickup -> collected
	var before := player.inventory.count_item(stone)
	pickup.global_position = player.global_position + Vector3(0, 0.5, 0)
	for i in 20:
		await tree.physics_frame
	_check(player.inventory.count_item(stone) == before + 1, "pickup collected on overlap")
	_check(not is_instance_valid(pickup), "pickup freed after collection")
	player.queue_free()
	await tree.physics_frame
