extends Node3D
class_name CreatureSpawner
## Spawns creatures around the player by biome (canonical: ARCHITECTURE.md
## §9.1). Seeded tick (2 s), 50% spawn chance per tick, capped population,
## despawn beyond the despawn radius. Biome -> spawn pool is data.

var world: VoxelWorld = null
var player: Node3D = null

var creatures: Array[Node] = []
var max_creatures: int = 12
var spawn_radius: float = 28.0
var despawn_radius: float = 64.0

var _rng: RandomNumberGenerator
var _tick: float = 0.0


func _init(seed_value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func _process(delta: float) -> void:
	_despawn_far()
	_tick += delta
	if _tick >= 2.0:
		_tick = 0.0
		_try_spawn()


## Spawn pool per biome (original creature spread, GAME_DESIGN.md).
static func pool_for_biome(biome: int) -> Array:
	match biome:
		BiomeRegistry.MEADOW:
			return [Creature.Type.BURROWER]
		BiomeRegistry.PINEWILD:
			return [Creature.Type.BURROWER, Creature.Type.FOREST_STALKER]
		BiomeRegistry.REDSTONE_DESERT:
			return [Creature.Type.STONEBACK]
		BiomeRegistry.FROSTLANDS:
			return [Creature.Type.GLOW_MOTH]
		BiomeRegistry.CRYSTAL_HIGHLANDS:
			return [Creature.Type.STONEBACK, Creature.Type.GLOW_MOTH]
	return []


func _try_spawn() -> void:
	if player == null or world == null or world.generator == null:
		return
	if creatures.size() >= max_creatures:
		return
	var biome := world.generator.biome_at(floori(player.global_position.x), floori(player.global_position.z))
	var pool := pool_for_biome(biome)
	if pool.is_empty():
		return
	if _rng.randf() > 0.5:
		return
	var creature_type: int = pool[_rng.randi_range(0, pool.size() - 1)]
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(16.0, spawn_radius)
	var pos := player.global_position
	pos += Vector3(sin(angle) * dist, 0.0, cos(angle) * dist)
	pos.y = float(world.generator.height_at(floori(pos.x), floori(pos.z))) + 0.1
	var creature := Creature.new(creature_type, _rng.randi())
	creature.world = world
	creature.player = player
	add_child(creature)
	creature.global_position = pos  # after add_child — global reads need the tree
	creatures.append(creature)


func _despawn_far() -> void:
	if player == null:
		return
	for creature in creatures.duplicate():
		if creature.global_position.distance_to(player.global_position) > despawn_radius:
			creatures.erase(creature)
			creature.queue_free()
