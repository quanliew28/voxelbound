extends Node
class_name ParticleFX
## Procedural particle effects — zero assets. GPUParticles3D with primitive
## quad/box meshes + StandardMaterial3D colors, built in code. One-shots
## free themselves after their lifetime. Canonical: ROADMAP Phase 16.

const QUAD_SIZE: Vector2 = Vector2(0.25, 0.25)


func _particle(amount: int, lifetime: float, gravity: Vector3, scale: float,
		color: Color, box: bool, velocity: float = 3.0, spread: float = 0.5) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15
	mat.gravity = gravity
	mat.initial_velocity_min = velocity * (1.0 - spread)
	mat.initial_velocity_max = velocity * (1.0 + spread)
	mat.scale_min = scale
	mat.scale_max = scale * 1.8
	mat.color = color
	emitter.process_material = mat
	var mesh: Mesh = QuadMesh.new() if not box else BoxMesh.new()
	if box:
		(mesh as BoxMesh).size = Vector3(0.18, 0.18, 0.18)
	else:
		(mesh as QuadMesh).size = QUAD_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if not box:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	emitter.draw_pass_1 = mesh
	emitter.draw_pass_1.material = material
	return emitter


## One-shot with auto-free after lifetime + margin.
func _burst(pos: Vector3, amount: int, lifetime: float, gravity: Vector3,
		scale: float, color: Color, box: bool = true, velocity: float = 3.0) -> GPUParticles3D:
	var emitter := _particle(amount, lifetime, gravity, scale, color, box, velocity)
	emitter.global_position = pos
	add_child(emitter)
	var t := get_tree().create_timer(lifetime + 0.6)
	t.timeout.connect(emitter.queue_free)
	return emitter


## Block debris burst at a broken block (cube mesh tinted with the block).
func block_break(pos: Vector3, block_id: int) -> void:
	var reg := BlockRegistry.shared()
	var color: Color = reg.get_color(block_id)
	if block_id == reg.get_id(&"CRYSTAL"):
		_burst(pos, 24, 0.7, Vector3(0, -9, 0), 0.25, Color(0.6, 0.9, 1.0), false, 4.0)
		_burst(pos, 12, 0.5, Vector3(0, -2, 0), 0.12, Color(0.8, 1.0, 1.0), false, 2.0)
	else:
		_burst(pos, 16, 0.7, Vector3(0, -9, 0), 0.22, color, true, 3.5)


## Dust puff when a block is placed.
func block_place(pos: Vector3) -> void:
	_burst(pos, 8, 0.5, Vector3(0, -3, 0), 0.3, Color(0.75, 0.72, 0.68, 0.7), false, 1.5)


## Bright impact sparks (melee hits).
func sparks(pos: Vector3) -> void:
	_burst(pos, 12, 0.3, Vector3(0, -1, 0), 0.08, Color(1.0, 0.9, 0.5), false, 5.0)


## Red burst on creature damage.
func damage_hit(pos: Vector3) -> void:
	_burst(pos, 10, 0.4, Vector3(0, -2, 0), 0.15, Color(0.9, 0.2, 0.2), false, 4.0)


## Cyan sparkle for crystal effects.
func crystal_sparkle(pos: Vector3) -> void:
	_burst(pos, 10, 0.6, Vector3(0, -1, 0), 0.1, Color(0.55, 0.9, 1.0), false, 2.0)


## Landing dust (fall damage / hard landings).
func dust(pos: Vector3) -> void:
	_burst(pos, 6, 0.4, Vector3(0, -2, 0), 0.35, Color(0.65, 0.62, 0.58, 0.6), false, 1.0)
