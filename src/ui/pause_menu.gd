extends PanelContainer
class_name PauseMenu
## Pause overlay (ESC): resume, sensitivity setting, save & quit to menu,
## quit to desktop. Built from Control nodes; runs while the tree is paused.

signal resume_pressed
signal quit_to_menu_pressed
signal quit_pressed
signal sensitivity_changed(value: float)
signal ui_scale_changed(value: float)

var _sensitivity_slider: HSlider
var _ui_scale_slider: HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(340, 280)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	vbox.add_child(resume)
	# sensitivity setting
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Sensitivity"
	row.add_child(label)
	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = 0.0005
	_sensitivity_slider.max_value = 0.008
	_sensitivity_slider.step = 0.0001
	_sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sensitivity_slider.value = Settings.load_sensitivity()
	_sensitivity_slider.value_changed.connect(_on_sensitivity)
	row.add_child(_sensitivity_slider)
	vbox.add_child(row)
	# ui scale setting
	var scale_row := HBoxContainer.new()
	var scale_label := Label.new()
	scale_label.text = "UI Scale"
	scale_row.add_child(scale_label)
	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = Settings.UI_SCALE_MIN
	_ui_scale_slider.max_value = Settings.UI_SCALE_MAX
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_scale_slider.value = Settings.load_ui_scale()
	_ui_scale_slider.value_changed.connect(_on_ui_scale)
	scale_row.add_child(_ui_scale_slider)
	vbox.add_child(scale_row)
	var to_menu := Button.new()
	to_menu.text = "Save & Quit to Menu"
	to_menu.pressed.connect(func() -> void: quit_to_menu_pressed.emit())
	vbox.add_child(to_menu)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	vbox.add_child(quit)


func _on_sensitivity(value: float) -> void:
	Settings.save_sensitivity(value)
	sensitivity_changed.emit(value)


func _on_ui_scale(value: float) -> void:
	Settings.save_ui_scale(value)
	ui_scale_changed.emit(value)
