extends RefCounted
## Phase 14 suite: SaveManager binary save/load (seed + time + player +
## inventory + modified-chunk diffs only). Runs headless.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

const SAVE_PATH := "user://test_save.vb"

func run() -> int:
	await _check_roundtrip()
	_check_diff_only()
	_check_corrupt_magic()
	_check_wrong_version()
	_check_missing_file()
	await _check_apply_load()
	_check_has_save()
	print("SUITE save: %d passed, %d failed" % [last_passed, _failed])
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


func _build_world() -> VoxelWorld:
	var world := VoxelWorld.new()
	world.world_seed = 123456
	world.generator = VoxelGenerator.new(123456)
	world.add_chunk(world.generator.generate(Vector3i(0, 2, 0)))
	world.add_chunk(world.generator.generate(Vector3i(1, 2, 0)))
	return world


func _make_player() -> PlayerController:
	var player := preload("res://scenes/player.tscn").instantiate() as PlayerController
	player.position = Vector3(3.5, 40.0, 2.5)
	player.spawn_point = Vector3(0.5, 33.5, 0.5)
	player.hp = 64.0
	player.inventory.add_item(BlockRegistry.shared().get_id(&"STONE"), 12)
	player.inventory.add_item(ToolRegistry.id_of(&"COPPER_PICK"), 1)
	var tool_stack := player.inventory.get_slot(1)
	if tool_stack != null:
		tool_stack.durability = 77
	return player


func _check_roundtrip() -> void:
	var world := _build_world()
	var player := _make_player()
	tree.root.add_child(player)
	await tree.physics_frame
	# modify chunk (0,2,0): place a block; leave (1,2,0) untouched
	world.set_block(Vector3i(5, 33, 5), BlockRegistry.shared().get_id(&"COAL"))
	var ok := SaveManager.save_game(SAVE_PATH, world, player, 0.42)
	_check(ok, "save writes file")
	var data := SaveManager.load_game(SAVE_PATH)
	_check(not data.is_empty(), "load reads save")
	if data.is_empty():
		player.queue_free()
		return
	_check(data["seed"] == 123456, "seed roundtrips", "got %d" % data["seed"])
	_check(absf(float(data["time"]) - 0.42) < 0.001, "world time roundtrips")
	var pos: Vector3 = data["player_pos"]
	_check(pos.distance_to(Vector3(3.5, 40.0, 2.5)) < 0.01, "player position roundtrips")
	_check(absf(float(data["hp"]) - 64.0) < 0.001, "player hp roundtrips")
	var inv: Array = data["inventory"]
	var s0: Dictionary = inv[0]
	var s1: Dictionary = inv[1]
	_check(int(s0.item) == BlockRegistry.shared().get_id(&"STONE") and int(s0.count) == 12, "inventory slot 0 roundtrips")
	_check(int(s1.item) == ToolRegistry.id_of(&"COPPER_PICK") and int(s1.durability) == 77, "inventory tool + durability roundtrips")
	var chunks: Dictionary = data["chunks"]
	_check(chunks.size() == 1, "only modified chunk saved", "got %d" % chunks.size())
	_check(chunks.has(Vector3i(0, 2, 0)), "modified chunk coord present")
	var restored: VoxelChunk = chunks[Vector3i(0, 2, 0)]
	_check(restored.get_block(Vector3i(5, 33 - 32, 5)) == BlockRegistry.shared().get_id(&"COAL"), "modified block data roundtrips")
	player.queue_free()
	await tree.physics_frame


func _check_diff_only() -> void:
	var world := _build_world()
	var player := _make_player()
	# no modifications at all -> zero chunks in save
	SaveManager.save_game(SAVE_PATH, world, player, 0.1)
	var data := SaveManager.load_game(SAVE_PATH)
	_check(int(data["chunks"].size()) == 0, "unmodified world saves zero chunks")
	player.free()


func _check_corrupt_magic() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_buffer("XX9".to_ascii_buffer())
	f.close()
	_check(SaveManager.load_game(SAVE_PATH).is_empty(), "corrupt magic rejected")


func _check_wrong_version() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_buffer(SaveManager.MAGIC.to_ascii_buffer())
	f.store_8(99)
	f.close()
	_check(SaveManager.load_game(SAVE_PATH).is_empty(), "wrong version rejected")


func _check_missing_file() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	_check(SaveManager.load_game(SAVE_PATH).is_empty(), "missing file returns empty")


func _check_apply_load() -> void:
	var world := _build_world()
	var player := _make_player()
	tree.root.add_child(player)
	await tree.physics_frame
	# save, then rebuild a fresh world+player and apply
	world.set_block(Vector3i(2, 34, 2), BlockRegistry.shared().get_id(&"GRASS"))
	SaveManager.save_game(SAVE_PATH, world, player, 0.25)
	var data := SaveManager.load_game(SAVE_PATH)
	var world2 := VoxelWorld.new()
	world2.world_seed = 999
	var player2 := _make_player()
	tree.root.add_child(player2)
	await tree.physics_frame
	player2.set_physics_process(false)  # don't fall during the check
	SaveManager.apply_load(world2, player2, data)
	_check(world2.get_block(Vector3i(2, 34, 2)) == BlockRegistry.shared().get_id(&"GRASS"), "apply restores modified chunk")
	_check(player2.global_position.distance_to(Vector3(3.5, 40.0, 2.5)) < 0.01, "apply restores player position",
		"pos=%s data=%s" % [str(player2.global_position), str(data["player_pos"])])
	var tool: ItemStack = player2.inventory.get_slot(1)
	_check(tool != null and tool.durability == 77, "apply restores tool durability")
	player2.queue_free()
	await tree.physics_frame


func _check_has_save() -> void:
	SaveManager.save_game(SAVE_PATH, _build_world(), _make_player(), 0.5)
	_check(SaveManager.has_save(SAVE_PATH), "has_save true after write")
	DirAccess.remove_absolute(SAVE_PATH)
	_check(not SaveManager.has_save(SAVE_PATH), "has_save false after remove")
