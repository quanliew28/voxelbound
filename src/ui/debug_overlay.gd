extends CanvasLayer
class_name DebugOverlay
## F3 debug overlay: FPS, position, HP, biome, chunk count, day time,
## weather. Pure Control nodes; hidden until toggled.

var player: PlayerController = null
var world: VoxelWorld = null
var day_night: DayNight = null
var weather: Weather = null

var _visible_state: bool = false
var _label: Label


func _ready() -> void:
	layer = 90
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.9))
	_label.visible = false
	add_child(_label)


func toggle() -> void:
	_visible_state = not _visible_state
	_label.visible = _visible_state


func is_showing() -> bool:
	return _visible_state


func _process(_delta: float) -> void:
	if not _visible_state or _label == null:
		return
	var lines: Array[String] = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if player != null:
		var p := player.global_position
		lines.append("Pos: %.1f %.1f %.1f" % [p.x, p.y, p.z])
		lines.append("HP: %.0f/%d" % [player.hp, PlayerController.MAX_HP])
		if world != null and world.generator != null:
			var biome := world.generator.biome_at(floori(p.x), floori(p.z))
			lines.append("Biome: %s" % BiomeRegistry.display_name(biome))
	if world != null:
		lines.append("Chunks: %d" % world.get_loaded_chunk_coords().size())
	if day_night != null:
		lines.append("Day time: %.2f" % day_night.day_time)
	if weather != null:
		lines.append("Weather: %s" % ["CLEAR", "RAIN", "SNOW"][weather.state])
	_label.text = "\n".join(lines)
