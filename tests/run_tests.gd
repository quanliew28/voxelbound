extends SceneTree

const SUITES: Array[String] = [
	"res://tests/test_smoke.gd",
	"res://tests/test_voxel.gd",
	"res://tests/test_mesher.gd",
	"res://tests/test_raycaster.gd",
	"res://tests/test_generator.gd",
	"res://tests/test_streaming.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_crafting.gd",
	"res://tests/test_biomes.gd",
	"res://tests/test_caves.gd",
	"res://tests/test_daynight.gd",
	"res://tests/test_creatures.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_save.gd",
	"res://tests/test_audio.gd",
	"res://tests/test_fx.gd",
	"res://tests/test_polish.gd",
]

func _initialize() -> void:
	var total_failures: int = 0
	var total_passed: int = 0
	for path in SUITES:
		var script: GDScript = load(path) as GDScript
		var suite: RefCounted = script.new()
		suite.set("tree", self)
		# Suites are coroutines (they await physics frames). Awaiting the call
		# directly works for both coroutine and plain-int returns in Godot 4.
		var result: int = await suite.run()
		total_failures += result
		var passed: Variant = suite.get("last_passed")
		if typeof(passed) == TYPE_INT:
			total_passed += passed as int
	print("TESTS: %d passed, %d failed" % [total_passed, total_failures])
	quit(total_failures)
