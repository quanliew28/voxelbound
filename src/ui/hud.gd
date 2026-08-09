extends CanvasLayer
class_name HUD
## In-game UI built entirely from Godot Control nodes (zero assets):
## crosshair, 9-slot hotbar with selection highlight, full inventory screen
## (E). Polls the player each frame and only touches labels when text
## changes.

var player: PlayerController = null
## Procedural audio manager (wired by main; null is fine).
var audio: AudioManager = null

var _hotbar_slots: Array[PanelContainer] = []
var _hotbar_names: Array[Label] = []
var _hotbar_counts: Array[Label] = []
var _inv_slots: Array[PanelContainer] = []
var _inv_labels: Array[Label] = []
var _craft_buttons: Array[Button] = []
var _hp_bar: ColorRect
var _hp_bg: PanelContainer
var _flash: ColorRect
var _flash_alpha: float = 0.0
var _inventory_panel: PanelContainer

const SLOT_SIZE: Vector2 = Vector2(36, 36)
const HOTBAR_Y_OFFSET: float = -56.0


func _ready() -> void:
	_build_crosshair()
	_build_hotbar()
	_build_health_ui()
	_build_inventory_panel()


func _process(delta: float) -> void:
	if player == null:
		return
	_refresh_hotbar()
	if _inventory_panel.visible != player.inventory_open:
		_inventory_panel.visible = player.inventory_open
	_refresh_inventory()
	_refresh_health()
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 2.5)
		_flash.color.a = _flash_alpha


func on_player_damaged(_amount: float) -> void:
	_flash_alpha = 0.4


# --- construction ---

func _build_health_ui() -> void:
	_hp_bg = PanelContainer.new()
	_hp_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_bg.position = Vector2(16, -36)
	_hp_bg.custom_minimum_size = Vector2(140, 12)
	var hp_frame := ColorRect.new()
	hp_frame.color = Color(0, 0, 0, 0.6)
	hp_frame.size = Vector2(140, 12)
	_hp_bg.add_child(hp_frame)
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.85, 0.2, 0.2)
	_hp_bar.position = Vector2(2, 2)
	_hp_bar.size = Vector2(136, 8)
	hp_frame.add_child(_hp_bar)
	add_child(_hp_bg)
	# full-screen damage flash (fades via _process)
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _refresh_health() -> void:
	if _hp_bar == null:
		return
	var ratio := clampf(player.hp / PlayerController.MAX_HP, 0.0, 1.0)
	_hp_bar.size.x = 136.0 * ratio

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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(grid)
	# crafting panel (Phase 8) — one button per data-driven recipe
	var craft_box := VBoxContainer.new()
	craft_box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = "Craft"
	title.add_theme_font_size_override("font_size", 14)
	craft_box.add_child(title)
	for i in CraftingRegistry.recipe_count():
		var btn := Button.new()
		btn.text = _recipe_label(i)
		btn.custom_minimum_size = Vector2(180, 0)
		btn.pressed.connect(_on_craft_pressed.bind(i))
		craft_box.add_child(btn)
		_craft_buttons.append(btn)
	row.add_child(craft_box)
	_inventory_panel.add_child(row)
	add_child(_inventory_panel)


func _recipe_label(index: int) -> String:
	var recipe := CraftingRegistry.RECIPES[index]
	var parts: Array[String] = []
	for ing in recipe.ingredients:
		parts.append("%s x%d" % [String(ing.item).capitalize(), int(ing.count)])
	return "%s  (%s)" % [String(recipe.name), ", ".join(parts)]


func _on_craft_pressed(index: int) -> void:
	if player != null:
		if audio != null:
			audio.ui_click()
		player.craft(index)
		_refresh_inventory()


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
	for i in _craft_buttons.size():
		var craftable := CraftingRegistry.can_craft(player.inventory, i)
		if _craft_buttons[i].disabled == craftable:
			_craft_buttons[i].disabled = not craftable
