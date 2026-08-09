extends RefCounted
## Phase 18 suite: main menu, pause flow, debug overlay, settings.
## Runs headless.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_settings_roundtrip()
	await _check_menu_builds()
	await _check_pause_flow()
	await _check_debug_overlay()
	print("SUITE polish: %d passed, %d failed" % [last_passed, _failed])
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


func _check_settings_roundtrip() -> void:
	DirAccess.remove_absolute(Settings.PATH)
	_check(absf(Settings.load_sensitivity() - Settings.DEFAULT_SENSITIVITY) < 0.0001, "settings default sensitivity")
	Settings.save_sensitivity(0.005)
	_check(absf(Settings.load_sensitivity() - 0.005) < 0.0001, "settings save/load roundtrip", "got %f" % Settings.load_sensitivity())
	Settings.save_sensitivity(Settings.DEFAULT_SENSITIVITY)


func _check_menu_builds() -> void:
	var menu := preload("res://scenes/menu.tscn").instantiate()
	tree.root.add_child(menu)
	await tree.physics_frame
	var buttons := 0
	var labels := 0
	for child in menu.get_children():
		if child is Button:
			buttons += 1
		elif child is Label:
			labels += 1
	_check(buttons >= 2, "main menu has start + quit buttons", "%d buttons" % buttons)
	_check(labels >= 2, "main menu has title + subtitle", "%d labels" % labels)
	menu.queue_free()
	await tree.physics_frame


func _check_pause_flow() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame
	var main_ref = main
	_check(not tree.paused, "game starts unpaused")
	main_ref.pause_game()
	_check(tree.paused, "pause_game pauses the tree")
	_check(main_ref.pause_menu.visible, "pause menu visible when paused")
	main_ref._resume_game()
	_check(not tree.paused, "resume unpauses the tree")
	_check(not main_ref.pause_menu.visible, "pause menu hidden after resume")
	main_ref.queue_free()
	await tree.physics_frame


func _check_debug_overlay() -> void:
	var overlay := DebugOverlay.new()
	tree.root.add_child(overlay)
	await tree.physics_frame
	_check(not overlay.is_showing(), "debug overlay hidden by default")
	overlay.toggle()
	_check(overlay.is_showing(), "debug overlay toggles on")
	overlay._process(0.1)
	_check(not overlay._label.text.is_empty(), "debug overlay fills text", "text=%s" % overlay._label.text)
	overlay.toggle()
	_check(not overlay.is_showing(), "debug overlay toggles off")
	overlay.queue_free()
	await tree.physics_frame
