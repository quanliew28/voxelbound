extends CharacterBody3D
class_name PlayerController

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 22.0
@export var mouse_sensitivity: float = 0.0022

const STAND_HEIGHT: float = 1.8
const STAND_HEAD_Y: float = 1.62
const CROUCH_HEIGHT: float = 1.0
const CROUCH_HEAD_Y: float = 0.9
const ACCELERATION: float = 12.0
const CROUCH_LERP_SPEED: float = 10.0
const MAX_LOOK_DEGREES: float = 89.0

@onready var head: Node3D = %Head
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
