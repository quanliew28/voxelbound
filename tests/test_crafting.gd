extends RefCounted
## Phase 8 suite: ToolRegistry + CraftingRegistry + tool mining.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_tool_registry()
	_check_recipe_data()
	_check_crafting()
	_check_tool_mine_speed()
	_check_tool_durability()
	print("SUITE crafting: %d passed, %d failed" % [last_passed, _failed])
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


func _check_tool_registry() -> void:
	_check(ToolRegistry.check_tool(ToolRegistry.id_of(&"CRUDE_PICK")), "tool registry crude pick id")
	_check(not ToolRegistry.check_tool(BlockRegistry.shared().get_id(&"STONE")), "tool registry block is not tool")
	_check(ToolRegistry.get_affinity(ToolRegistry.id_of(&"CRUDE_PICK")) == &"pick", "tool registry pick affinity")
	_check(ToolRegistry.get_affinity(ToolRegistry.id_of(&"CRYSTAL_AXE")) == &"axe", "tool registry axe affinity")
	_check(ToolRegistry.get_speed(ToolRegistry.id_of(&"CRYSTAL_PICK")) == 7.0, "tool registry crystal speed")
	_check(ToolRegistry.get_durability(ToolRegistry.id_of(&"COPPER_PICK")) == 160, "tool registry durability")
	_check(ToolRegistry.display_name(ToolRegistry.id_of(&"COPPER_AXE")) == "Copper Axe", "tool registry display name")
	_check(ToolRegistry.get_def(5).is_empty(), "tool registry bad id -> empty")
	_check(ItemStack.max_stack_for(ToolRegistry.id_of(&"CRUDE_PICK")) == 1, "tools stack to 1")
	_check(ItemStack.max_stack_for(BlockRegistry.shared().get_id(&"STONE")) == 64, "blocks stack to 64")


func _check_recipe_data() -> void:
	var reg := BlockRegistry.shared()
	for i in CraftingRegistry.recipe_count():
		var recipe := CraftingRegistry.RECIPES[i]
		_check(not String(recipe.name).is_empty(), "recipe %d has name" % i)
		# result must resolve (block or tool)
		var result_id := CraftingRegistry._item_id(StringName(recipe.result))
		_check(result_id >= 0, "recipe %d result resolves" % i, "result %s" % String(recipe.result))
		for ing in recipe.ingredients:
			var ing_id := CraftingRegistry._item_id(StringName(ing.item))
			_check(ing_id >= 0, "recipe %d ingredient %s resolves" % [i, String(ing.item)])
	# every recipe is original (no Minecraft recipe shapes) — sanity: none is
	# a 2x2/3x3 classic grid with 4+ identical planks etc.
	_check(CraftingRegistry.recipe_count() == 6, "six original recipes")


func _check_crafting() -> void:
	var inv := Inventory.new()
	var wood := BlockRegistry.shared().get_id(&"WOOD")
	var stone := BlockRegistry.shared().get_id(&"STONE")
	var crude_pick := ToolRegistry.id_of(&"CRUDE_PICK")
	_check(not CraftingRegistry.can_craft(inv, 0), "craft requires ingredients")
	_check(not CraftingRegistry.craft(inv, 0), "craft fails without ingredients")
	inv.add_item(wood, 2)
	inv.add_item(stone, 3)
	_check(CraftingRegistry.can_craft(inv, 0), "craft can_craft with ingredients")
	_check(CraftingRegistry.craft(inv, 0), "craft succeeds")
	_check(inv.count_item(wood) == 0 and inv.count_item(stone) == 0, "craft consumes ingredients")
	_check(inv.count_item(crude_pick) == 1, "craft adds result")
	# crafted tool starts at full durability
	var slot := inv.find_slot(crude_pick)
	_check(slot != -1 and inv.get_slot(slot).durability == ToolRegistry.get_durability(crude_pick),
		"crafted tool full durability", "durability %d" % (inv.get_slot(slot).durability if slot != -1 else -2))
	# tools don't stack: crafting a second one goes to a new slot
	inv.add_item(wood, 2)
	inv.add_item(stone, 3)
	CraftingRegistry.craft(inv, 0)
	var first := inv.find_slot(crude_pick)
	_check(inv.count_item(crude_pick) == 2, "tools occupy separate slots")
	_check(inv.get_slot(first).count == 1, "tool stack size 1")
	# list_craftable
	inv.add_item(wood, 2)
	inv.add_item(stone, 2)
	var craftable := CraftingRegistry.list_craftable(inv)
	_check(craftable.has(3), "list_craftable includes crude axe", "got %s" % str(craftable))
	_check(not craftable.has(0), "list_craftable excludes crude pick (needs 3 stone)")


func _check_tool_mine_speed() -> void:
	var reg := BlockRegistry.shared()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)
	var stone := reg.get_id(&"STONE")
	var wood := reg.get_id(&"WOOD")
	var crude_pick := ToolRegistry.id_of(&"CRUDE_PICK")
	var crude_axe := ToolRegistry.id_of(&"CRUDE_AXE")
	_check(player._mining_speed(stone) == 1.0, "barehand speed 1.0")
	player.inventory.add_item(crude_pick, 1)
	_check(player._mining_speed(stone) == 2.0, "pick on stone full speed")
	_check(player._mining_speed(wood) == 1.0, "pick on wood half speed (wrong affinity)", "got %f" % player._mining_speed(wood))
	player.inventory.add_item(crude_axe, 1)
	player.selected_slot = player.inventory.find_slot(crude_axe)
	_check(player._mining_speed(wood) == 2.0, "axe on wood full speed")
	_check(player._mining_speed(stone) == 1.0, "axe on stone half speed")
	player.queue_free()
	await tree.physics_frame


func _check_tool_durability() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	tree.root.add_child(world)
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	# a column of 8 dirt blocks to mine
	for y in 8:
		chunk.set_block_generated(Vector3i(0, y, 0), reg.get_id(&"DIRT"))
	world.add_chunk(chunk)
	world.rebuild_all_dirty()
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player := scene.instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(0.5, 10, 0.5)
	player.world = world
	# a pick with 3 durability: mines 3 blocks then breaks
	var crude_pick := ToolRegistry.id_of(&"CRUDE_PICK")
	player.inventory.add_item(crude_pick, 1)
	var slot := player.inventory.find_slot(crude_pick)
	player.inventory.get_slot(slot).durability = 3
	player.selected_slot = slot
	# simulate hold-mining completion 3 times via _complete_mine
	for i in 3:
		player._complete_mine(Vector3i(0, 7 - i, 0), reg.get_id(&"DIRT"))
	_check(world.get_block(Vector3i(0, 7, 0)) == BlockRegistry.AIR_ID, "durability: mining removes blocks")
	_check(player.inventory.get_slot(slot) == null, "durability: tool breaks after 3 uses")
	_check(player.inventory.count_item(crude_pick) == 0, "durability: broken tool removed")
	# drops were collected
	_check(player.inventory.count_item(reg.get_id(&"DIRT")) == 3, "durability: drops collected", "got %d" % player.inventory.count_item(reg.get_id(&"DIRT")))
	player.queue_free()
	world.queue_free()
	await tree.physics_frame
