extends CharacterBody3D
class_name PlayerController

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 22.0
@export var mouse_sensitivity: float = 0.0022
@export var interact_range: float = 6.0

## The voxel world this player edits (wired by the composition root).
var world: VoxelWorld = null
## Player inventory: 36 slots, slots 0..8 are the hotbar (Phase 7).
var inventory: Inventory = Inventory.new()
var selected_slot: int = 0
## Whether the inventory screen is open (input routing handled by HUD).
var inventory_open: bool = false

const STAND_HEIGHT: float = 1.8
const STAND_HEAD_Y: float = 1.62
const CROUCH_HEIGHT: float = 1.0
const CROUCH_HEAD_Y: float = 0.9
const ACCELERATION: float = 12.0
const CROUCH_LERP_SPEED: float = 10.0
const MAX_LOOK_DEGREES: float = 89.0

@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D

var _override_direction: Vector2 = Vector2.ZERO
var _override_sprint: bool = false
var _override_crouch: bool = false
var _override_jump: bool = false
var _overrides_active: bool = false

func simulate_for_test(direction: Vector2, sprint: bool, crouch: bool, jump: bool) -> void:
	_overrides_active = true
	_override_direction = direction
	_override_sprint = sprint
	_override_crouch = crouch
	_override_jump = jump

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -deg_to_rad(MAX_LOOK_DEGREES), deg_to_rad(MAX_LOOK_DEGREES))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact_primary") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact_secondary") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_place()
	elif event.is_action_pressed("drop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		drop_selected()
	elif event.is_action_pressed("inventory"):
		inventory_open = not inventory_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_open else Input.MOUSE_MODE_CAPTURED
	else:
		for i in Inventory.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				selected_slot = i
				break

func _physics_process(delta: float) -> void:
	var direction: Vector2
	var sprint: bool
	var crouch: bool
	var jump: bool
	if _overrides_active:
		direction = _override_direction
		sprint = _override_sprint
		crouch = _override_crouch
		jump = _override_jump
	else:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint = Input.is_action_pressed("sprint")
		crouch = Input.is_action_pressed("crouch")
		jump = Input.is_action_just_pressed("jump")

	if not is_on_floor():
		velocity.y -= gravity * delta
	if jump and is_on_floor():
		velocity.y = jump_velocity

	var target_speed: float = walk_speed
	if crouch:
		target_speed = crouch_speed
	elif sprint and direction.y < 0.0:
		target_speed = sprint_speed

	var input_axis := Vector3(direction.x, 0.0, direction.y)
	if input_axis.length_squared() > 0.0:
		input_axis = input_axis.normalized()
	var wish_direction := global_transform.basis * input_axis
	velocity.x = lerpf(velocity.x, wish_direction.x * target_speed, ACCELERATION * delta)
	velocity.z = lerpf(velocity.z, wish_direction.z * target_speed, ACCELERATION * delta)

	_update_crouch(crouch, delta)
	_handle_mining(delta)
	move_and_slide()

func _update_crouch(crouch: bool, delta: float) -> void:
	var target_height: float = CROUCH_HEIGHT
	var target_head_y: float = CROUCH_HEAD_Y
	if not crouch and (capsule_shape.height >= STAND_HEIGHT - 0.1 or _has_headroom()):
		target_height = STAND_HEIGHT
		target_head_y = STAND_HEAD_Y
	capsule_shape.height = lerpf(capsule_shape.height, target_height, CROUCH_LERP_SPEED * delta)
	# Keep the capsule bottom at the body origin so crouching doesn't lift the player.
	collision_shape.position.y = capsule_shape.height * 0.5
	head.position.y = lerpf(head.position.y, target_head_y, CROUCH_LERP_SPEED * delta)

func _has_headroom() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var standing_capsule := CapsuleShape3D.new()
	standing_capsule.radius = capsule_shape.radius
	standing_capsule.height = STAND_HEIGHT
	query.shape = standing_capsule
	query.transform = collision_shape.global_transform
	query.exclude = [self]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


# --- Block interaction (Phase 4) ---

func try_mine() -> void:
	if world == null:
		return
	var hit := _raycast()
	if hit.is_empty():
		return
	var id: int = world.get_block(hit.block_pos)
	if id == BlockRegistry.AIR_ID or BlockRegistry.shared().get_hardness(id) <= 0.0:
		return
	world.set_block(hit.block_pos, BlockRegistry.AIR_ID)
	# drops go to the inventory (Phase 7)
	for drop_name in BlockRegistry.shared().get_drops(id):
		inventory.add_item(BlockRegistry.shared().get_id(drop_name), 1)


func try_place() -> void:
	if world == null:
		return
	var hit := _raycast()
	if hit.is_empty():
		return
	var target: Vector3i = hit.prev_pos
	if world.get_block(target) != BlockRegistry.AIR_ID:
		return
	if cell_overlaps_player(target):
		return
	var stack := inventory.get_slot(selected_slot)
	if stack == null:
		return  # nothing selected to place
	world.set_block(target, stack.item_id)
	inventory.remove_from_slot(selected_slot, 1)


## Drops one unit of the selected hotbar item as a world pickup (Q).
func drop_selected() -> void:
	var stack := inventory.get_slot(selected_slot)
	if stack == null:
		return
	var removed := inventory.remove_from_slot(selected_slot, 1)
	if removed > 0:
		_spawn_pickup(stack.item_id, 1)


func _spawn_pickup(item_id: int, amount: int) -> void:
	if world == null or get_parent() == null:
		return
	var pickup := PickupEntity.new(item_id, amount)
	pickup.position = global_position + Vector3(0, 0.6, 0) - global_transform.basis.z * 1.2
	get_parent().add_child(pickup)


# --- Crafting (Phase 8) ---

func craft(recipe_index: int) -> bool:
	return CraftingRegistry.craft(inventory, recipe_index)


# --- Hold-to-mine with tools (Phase 8) ---

var _mine_target := Vector3i(0, -99999, 0)
var _mine_progress: float = 0.0

func _handle_mining(delta: float) -> void:
	var mining := Input.is_action_pressed("interact_primary") \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inventory_open
	if not mining or world == null:
		_mine_progress = 0.0
		return
	var hit := _raycast()
	if hit.is_empty():
		_mine_progress = 0.0
		return
	var target: Vector3i = hit.block_pos
	if target != _mine_target:
		_mine_target = target
		_mine_progress = 0.0
	var id: int = world.get_block(target)
	if id == BlockRegistry.AIR_ID or BlockRegistry.shared().get_hardness(id) <= 0.0:
		_mine_progress = 0.0
		return
	_mine_progress += delta * _mining_speed(id)
	if _mine_progress >= BlockRegistry.shared().get_hardness(id):
		_complete_mine(target, id)


## Blocks/second this player can mine `block_id` with the selected tool.
func _mining_speed(block_id: int) -> float:
	var stack := inventory.get_slot(selected_slot)
	if stack == null or not ToolRegistry.check_tool(stack.item_id):
		return 1.0
	var tool_id := stack.item_id
	var block_affinity := BlockRegistry.shared().get_tool(block_id)
	if block_affinity == &"none" or block_affinity == ToolRegistry.get_affinity(tool_id):
		return ToolRegistry.get_speed(tool_id)
	return ToolRegistry.get_speed(tool_id) * 0.5  # wrong tool: slow


func _complete_mine(target: Vector3i, id: int) -> void:
	world.set_block(target, BlockRegistry.AIR_ID)
	for drop_name in BlockRegistry.shared().get_drops(id):
		inventory.add_item(BlockRegistry.shared().get_id(drop_name), 1)
	_drain_tool()
	_mine_progress = 0.0


func _drain_tool() -> void:
	var stack := inventory.get_slot(selected_slot)
	if stack == null or not ToolRegistry.check_tool(stack.item_id):
		return
	stack.durability -= 1
	if stack.durability <= 0:
		inventory.remove_from_slot(selected_slot, 1)  # tool broke


func _raycast() -> Dictionary:
	if world == null:
		return {}
	return VoxelRaycaster.cast_ray(world, camera.global_position,
		-camera.global_transform.basis.z, interact_range)


## Conservative capsule-vs-cell AABB test — placement is rejected when the
## target cell intersects the player's body (never place inside yourself).
func cell_overlaps_player(cell: Vector3i) -> bool:
	var radius: float = capsule_shape.radius
	var p_min := Vector3(global_position.x - radius, global_position.y, global_position.z - radius)
	var p_max := Vector3(global_position.x + radius, global_position.y + capsule_shape.height, global_position.z + radius)
	var c_min := Vector3(cell)
	var c_max := c_min + Vector3.ONE
	return p_min.x < c_max.x and p_max.x > c_min.x \
		and p_min.y < c_max.y and p_max.y > c_min.y \
		and p_min.z < c_max.z and p_max.z > c_min.z
