extends Area3D
class_name PickupEntity
## A dropped item floating in the world. Picked up by walking over it
## (PlayerController). Built entirely from primitives — zero assets.

var item_id: int
var count: int

var _age: float = 0.0
const LIFETIME: float = 60.0

func _init(id: int, amount: int = 1) -> void:
	item_id = id
	count = amount
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BlockRegistry.shared().get_color(id)
	mat.roughness = 0.8
	box.material = mat
	mesh_instance.mesh = box
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_age += delta
	rotate_y(delta * 2.0)
	if _age > LIFETIME:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		var overflow := player.inventory.add_item(item_id, count)
		if player.audio != null:
			player.audio.pickup()
		if overflow == 0:
			queue_free()
		else:
			count = overflow
