extends Node3D
class_name Creature
## Voxelbound creatures (Phase 12). Canonical: ARCHITECTURE.md §9.1.
## Kinematic Node3D: position-driven movement, y snapped to the terrain
## surface (no navmesh on block terrain). All 5 types are DATA; bodies are
## built from Godot primitives (zero assets).
##
## State machine: IDLE -> WANDER -> (CHASE | FLEE) -> RETURN -> IDLE.

enum Type { BURROWER, STONEBACK, GLOW_MOTH, NIGHTCRAWLER, FOREST_STALKER }
enum State { IDLE, WANDER, CHASE, FLEE, RETURN }

const TYPE_COUNT: int = 5

const TYPES: Array[Dictionary] = [
	{"name": "Burrower", "speed": 2.2, "vision": 6.0, "flee_range": 4.0,
		"aggression": 0.0, "height": 0.6, "body_color": Color(0.55, 0.42, 0.30),
		"glow": false, "home_radius": 12.0, "hp": 6.0, "damage": 1.0,
		"drops": [{"id": "DIRT", "min": 1, "max": 2}]},
	{"name": "Stoneback", "speed": 1.4, "vision": 8.0, "flee_range": 0.0,
		"aggression": 1.0, "height": 1.4, "body_color": Color(0.45, 0.45, 0.50),
		"glow": false, "home_radius": 16.0, "hp": 20.0, "damage": 3.0,
		"drops": [{"id": "STONE", "min": 1, "max": 3}]},
	{"name": "Glow Moth", "speed": 3.0, "vision": 10.0, "flee_range": 3.0,
		"aggression": 0.0, "height": 0.5, "body_color": Color(0.60, 0.80, 1.00),
		"glow": true, "home_radius": 10.0, "hp": 3.0, "damage": 0.0,
		"drops": [{"id": "CRYSTAL", "min": 1, "max": 1}]},
	{"name": "Nightcrawler", "speed": 1.8, "vision": 9.0, "flee_range": 0.0,
		"aggression": 0.5, "height": 0.7, "body_color": Color(0.35, 0.20, 0.45),
		"glow": false, "home_radius": 14.0, "hp": 10.0, "damage": 2.0,
		"drops": [{"id": "COAL", "min": 1, "max": 2}]},
	{"name": "Forest Stalker", "speed": 3.4, "vision": 14.0, "flee_range": 0.0,
		"aggression": 1.0, "height": 1.1, "body_color": Color(0.25, 0.50, 0.30),
		"glow": false, "home_radius": 20.0, "hp": 12.0, "damage": 3.0,
		"drops": [{"id": "WOOD", "min": 1, "max": 2}]},
]

signal died(creature: Node)

var type: int = Type.BURROWER
var world: VoxelWorld = null
var player: Node3D = null
var home: Vector3
var state: int = State.IDLE
var target: Vector3
var hp: float = 10.0
var _knockback: Vector3 = Vector3.ZERO
var _attack_cooldown: float = 0.0
var _rng: RandomNumberGenerator
var _state_timer: float = 0.0
var _bob: float = 0.0


func _init(creature_type: int, seed_value: int) -> void:
	type = creature_type
	hp = float(TYPES[type].hp)
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func _ready() -> void:
	_build_body()
	add_to_group("creatures")
	home = global_position
	target = home


func _process(delta: float) -> void:
	_state_timer -= delta
	_attack_cooldown -= delta
	_update_state(delta)
	_move(delta)
	_attack_player(delta)


func def() -> Dictionary:
	return TYPES[type]


func def_name() -> String:
	return str(def().name)


## Distance to the player (INF when no player set).
func player_distance() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


func _update_state(_delta: float) -> void:
	var dist := player_distance()
	var d := def()
	var aggression := float(d.aggression)
	# perception: aggressive creatures chase; passive ones flee
	if aggression > 0.0 and dist < float(d.vision):
		state = State.CHASE
		target = player.global_position
		return
	if aggression <= 0.0 and dist < float(d.flee_range):
		state = State.FLEE
		target = global_position + (global_position - player.global_position).normalized() * 6.0
		return
	match state:
		State.IDLE:
			if _state_timer <= 0.0:
				state = State.WANDER
				_pick_wander_target()
		State.WANDER:
			if _state_timer <= 0.0 or global_position.distance_to(target) < 0.5:
				state = State.IDLE
				_state_timer = _rng.randf_range(2.0, 5.0)
		State.CHASE:
			if dist > float(d.vision) * 1.5:
				state = State.RETURN
				target = home
			else:
				target = player.global_position
		State.FLEE:
			# run away from the player, biased toward home
			var away := (global_position - player.global_position).normalized()
			target = global_position + away * 6.0
			if dist > float(d.flee_range) * 2.0:
				state = State.IDLE
				_state_timer = _rng.randf_range(2.0, 5.0)
		State.RETURN:
			if global_position.distance_to(home) < 1.0:
				state = State.IDLE
				_state_timer = _rng.randf_range(2.0, 5.0)


func _pick_wander_target() -> void:
	var d := def()
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(2.0, float(d.home_radius) * 0.5)
	target = home + Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
	_state_timer = _rng.randf_range(3.0, 8.0)


func _move(delta: float) -> void:
	var d := def()
	var pos := global_position
	var to_target := target - pos
	to_target.y = 0.0
	if to_target.length() > 0.25:
		var step: float = float(d.speed) * delta
		pos += to_target.normalized() * minf(step, to_target.length())
	_bob += delta
	if bool(d.glow):
		pos.y = _surface_y(pos.x, pos.z) + 2.0 + sin(_bob * 2.0) * 0.4  # hover
	else:
		pos.y = _surface_y(pos.x, pos.z) + float(d.height) * 0.5
	if _knockback.length() > 0.01:
		pos += _knockback * delta
		_knockback = _knockback.lerp(Vector3.ZERO, delta * 4.0)
	global_position = pos


## Player melee hit: applies damage + knockback. Returns true when the
## creature died (spawner handles drops via the died signal).
func take_damage(amount: float, knockback_dir: Vector3) -> bool:
	if hp <= 0.0:
		return false
	hp -= amount
	if knockback_dir.length() > 0.01:
		_knockback = knockback_dir.normalized() * 5.0
	if hp <= 0.0:
		hp = 0.0
		died.emit(self)
		queue_free()
		return true
	return false


## Aggressive creatures in contact hit the player (1 s cooldown).
func _attack_player(_delta: float) -> void:
	if player == null or _attack_cooldown > 0.0:
		return
	if state != State.CHASE:
		return
	var d := def()
	if float(d.damage) <= 0.0:
		return
	if player_distance() > 1.8:
		return
	_attack_cooldown = 1.0
	if player.has_method("take_damage"):
		player.take_damage(float(d.damage), global_position)


func _surface_y(x: float, z: float) -> float:
	if world == null or world.generator == null:
		return 0.0
	return float(world.generator.height_at(floori(x), floori(z)))


## Body from primitives: capsule + two eyes; glow moth gets emissive wings.
func _build_body() -> void:
	var d := def()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = float(d.height)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d.body_color
	if bool(d.glow):
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.0
	body.mesh = capsule
	body.material_override = mat
	body.name = "Body"
	add_child(body)
	# eyes
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.1, 0.1)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		eye.mesh = sphere
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.16, float(d.height) * 0.55, 0.42)
		add_child(eye)
	if bool(d.glow):
		var wings := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.9, 0.04, 0.5)
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mat.emission_enabled = true
		wing_mat.emission = Color(0.6, 0.9, 1.0)
		wings.mesh = wing_mesh
		wings.material_override = wing_mat
		wings.position = Vector3(0, float(d.height) * 0.8, 0)
		add_child(wings)
