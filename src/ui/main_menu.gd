extends Control
class_name MainMenu
## Title screen — entirely Control nodes (zero assets). Start -> game scene,
## Quit -> exit.

func _ready() -> void:
	get_window().content_scale_factor = Settings.load_ui_scale()
	size = get_viewport_rect().size  # initial fill (see _process)
	_build()


func _process(_delta: float) -> void:
	# Explicitly fill the visible canvas (see PauseMenu._process).
	size = get_viewport_rect().size


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# dim background + centered column so the layout stays centered at any
	# content_scale_factor (UI scaling)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "VOXELBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "a fully procedural voxel sandbox"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	vbox.add_child(subtitle)
	var start := Button.new()
	start.text = "Start Game"
	start.custom_minimum_size = Vector2(200, 48)
	start.pressed.connect(_on_start)
	vbox.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(200, 48)
	quit.pressed.connect(_on_quit)
	vbox.add_child(quit)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit() -> void:
	get_tree().quit()
