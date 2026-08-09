extends Control
class_name MainMenu
## Title screen — entirely Control nodes (zero assets). Start -> game scene,
## Quit -> exit.

func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "VOXELBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	title.position = Vector2(0, 130)
	title.size = Vector2(1280, 120)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "a fully procedural voxel sandbox"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.position = Vector2(0, 250)
	subtitle.size = Vector2(1280, 40)
	add_child(subtitle)
	var start := Button.new()
	start.text = "Start Game"
	start.position = Vector2(540, 400)
	start.size = Vector2(200, 48)
	start.pressed.connect(_on_start)
	add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.position = Vector2(540, 460)
	quit.size = Vector2(200, 48)
	quit.pressed.connect(_on_quit)
	add_child(quit)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit() -> void:
	get_tree().quit()
