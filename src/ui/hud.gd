extends CanvasLayer
class_name HUD
## In-game UI built entirely from Godot Control nodes (zero assets):
## crosshair, 9-slot hotbar with selection highlight, full inventory screen
## (E). Polls the player each frame and only touches labels when text
## changes.

var player: PlayerController = null

var _hotbar_slots: Array[PanelContainer] = []
var _hotbar_names: Array[Label] = []
var _hotbar_counts: Array[Label] = []
var _inv_slots: Array[PanelContainer] = []
var _inv_labels: Array[Label] = []
var _inventory_panel: PanelContainer

const SLOT_SIZE: Vector2 = Vector2(36, 36)
const HOTBAR_Y_OFFSET: float = -56.0


func _ready() -> void:
	_build_crosshair()
	_build_hotbar()
	_build_inventory_panel()


func _process(_delta: float) -> void:
	if player == null:
		return
	_refresh_hotbar()
	if _inventory_panel.visible != player.inventory_open:
		_inventory_panel.visible = player.inventory_open
	_refresh_inventory()


# --- construction ---

func _build_crosshair() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for vertical in [true, false]:
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.9)
		if vertical:
			line.size = Vector2(2, 10)
		else:
			line.size = Vector2(10, 2)
		line.position = -line.size / 2.0
		holder.add_child(line)
	add_child(holder)


func _build_hotbar() -> void:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -Inventory.HOTBAR_SIZE * SLOT_SIZE.x / 2.0 - 4.0
	bar.offset_top = HOTBAR_Y_OFFSET
	bar.offset_right = Inventory.HOTBAR_SIZE * SLOT_SIZE.x / 2.0 + 4.0
	bar.offset_bottom = HOTBAR_Y_OFFSET + SLOT_SIZE.y + 4.0
	bar.add_theme_constant_override("separation", 2)
	for i in Inventory.HOTBAR_SIZE:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		var vbox := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = str(i + 1)
		name_label.add_theme_font_size_override("font_size", 10)
		var count_label := Label.new()
		count_label.text = ""
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(name_label)
		vbox.add_child(count_label)
		slot.add_child(vbox)
		bar.add_child(slot)
		_hotbar_slots.append(slot)
		_hotbar_names.append(name_label)
		_hotbar_counts.append(count_label)
	add_child(bar)


func _build_inventory_panel() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.anchor_left = 0.5
	_inventory_panel.anchor_right = 0.5
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.offset_left = -9 * SLOT_SIZE.x / 2.0 - 16.0
	_inventory_panel.offset_top = -4 * SLOT_SIZE.y - 16.0
	_inventory_panel.offset_right = 9 * SLOT_SIZE.x / 2.0 + 16.0
	_inventory_panel.offset_bottom = 16.0
	_inventory_panel.visible = false
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	for i in Inventory.SLOT_COUNT:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 11)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(label)
		grid.add_child(slot)
		_inv_slots.append(slot)
		_inv_labels.append(label)
	_inventory_panel.add_child(grid)
	add_child(_inventory_panel)


# --- refresh ---

func _refresh_hotbar() -> void:
	for i in Inventory.HOTBAR_SIZE:
		var stack := player.inventory.get_slot(i)
		var name_text := ""
		var count_text := ""
		if stack != null:
			name_text = stack.display_name()
			count_text = str(stack.count)
		if _hotbar_names[i].text != name_text:
			_hotbar_names[i].text = name_text
		if _hotbar_counts[i].text != count_text:
			_hotbar_counts[i].text = count_text
		var selected := i == player.selected_slot
		var target := Color(1, 1, 1, 1.0) if selected else Color(0.6, 0.6, 0.6, 0.8)
		if _hotbar_slots[i].modulate != target:
			_hotbar_slots[i].modulate = target


func _refresh_inventory() -> void:
	for i in Inventory.SLOT_COUNT:
		var stack := player.inventory.get_slot(i)
		var text := ""
		if stack != null:
			text = stack.display_name() + " x" + str(stack.count)
		if _inv_labels[i].text != text:
			_inv_labels[i].text = text
