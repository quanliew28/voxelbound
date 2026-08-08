extends RefCounted
class_name BlockRegistry
## Block ID registry — the single source of truth for block definitions.
## Canonical spec: docs/ARCHITECTURE.md §5.2.
##
## AIR is always id 0. IDs are assigned at registration time in registration
## order. Gameplay code must NEVER hardcode numeric block ids — always resolve
## through this class. Implementation is a lazy static singleton (NOT an
## autoload) so headless tests and the game share one instance deterministically;
## see docs/TECHNICAL_NOTES.md (2026-08-08).

const AIR_ID: int = 0
const MAX_BLOCK_TYPES: int = 255

static var _shared: BlockRegistry = null

## Keys per definition dictionary:
##   "name"       String        display name
##   "opaque"     bool          blocks light / hides adjacent faces
##   "transparent" bool         alpha-blended (e.g. leaves)
##   "emissive"   bool          emits light (rendered on emissive surface)
##   "emissive_energy" float    emission strength (emissive blocks only)
##   "hardness"   float         mining time multiplier (1.0 = baseline)
##   "tool"       StringName    preferred tool affinity ("none", "pick", "axe", "shovel")
##   "color"      Color         base albedo for procedural materials
##   "drops"      Array[StringName] block names dropped when mined
##   "falling"    bool          sand/gravel-style (later phase)
##   "strength"   float         resistance to explosions (later phase)

static func shared() -> BlockRegistry:
	if _shared == null:
		_shared = BlockRegistry.new()
	return _shared


var _ids: Dictionary = {}          # StringName -> int
var _names: Array[StringName] = [] # index -> StringName (index == id)
var _defs: Array[Dictionary] = []  # index -> definition dict

func _init() -> void:
	_register_defaults()


## Registers a block. Returns its id. Fails (returns -1) if the name is
## already registered or the id space is exhausted.
func register_block(name: StringName, def: Dictionary) -> int:
	if _ids.has(name):
		push_error("BlockRegistry: block '%s' already registered" % name)
		return -1
	if _names.size() >= MAX_BLOCK_TYPES:
		push_error("BlockRegistry: id space exhausted (%d)" % MAX_BLOCK_TYPES)
		return -1
	var id := _names.size()
	_ids[name] = id
	_names.append(name)
	_defs.append(def.duplicate(true))
	return id


## Returns the id for a block name, or AIR_ID if unknown (never crashes).
func get_id(name: StringName) -> int:
	return int(_ids.get(name, AIR_ID))


## Returns the name for an id, or &"AIR" if the id is out of range.
func get_name(id: int) -> StringName:
	if id < 0 or id >= _names.size():
		return &"AIR"
	return _names[id]


## Returns a COPY of the definition for an id (callers may not mutate registry data).
func get_def(id: int) -> Dictionary:
	if id < 0 or id >= _defs.size():
		return {}
	return _defs[id].duplicate(true)


func get_def_by_name(name: StringName) -> Dictionary:
	return get_def(get_id(name))


func has_block(name: StringName) -> bool:
	return _ids.has(name)


func count() -> int:
	return _names.size()


## --- Convenience accessors (safe defaults for unknown ids) ---

func is_opaque(id: int) -> bool:
	return bool(get_def(id).get("opaque", false))

func is_transparent(id: int) -> bool:
	return bool(get_def(id).get("transparent", false))

func is_emissive(id: int) -> bool:
	return bool(get_def(id).get("emissive", false))

func get_color(id: int) -> Color:
	return Color(get_def(id).get("color", Color.WHITE))

func get_hardness(id: int) -> float:
	return float(get_def(id).get("hardness", 1.0))

func get_tool(id: int) -> StringName:
	return StringName(get_def(id).get("tool", &"none"))

func get_drops(id: int) -> Array[StringName]:
	var drops: Variant = get_def(id).get("drops", [])
	var result: Array[StringName] = []
	for d in drops:
		result.append(StringName(d))
	return result


## Resets ALL state and re-registers defaults. For tests only.
func reset() -> void:
	_ids.clear()
	_names.clear()
	_defs.clear()
	_register_defaults()


func _register_defaults() -> void:
	# Order matters: AIR must be registered first (id 0).
	register_block(&"AIR", {
		"name": "Air", "opaque": false, "transparent": true, "emissive": false,
		"hardness": 0.0, "tool": &"none", "color": Color(0, 0, 0, 0),
		"drops": [], "falling": false, "strength": 0.0,
	})
	register_block(&"GRASS", {
		"name": "Grass", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 0.6, "tool": &"shovel", "color": Color(0.35, 0.62, 0.22),
		"drops": [&"DIRT"], "falling": false, "strength": 0.6,
	})
	register_block(&"DIRT", {
		"name": "Dirt", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 0.5, "tool": &"shovel", "color": Color(0.45, 0.31, 0.20),
		"drops": [&"DIRT"], "falling": false, "strength": 0.5,
	})
	register_block(&"STONE", {
		"name": "Stone", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 1.5, "tool": &"pick", "color": Color(0.55, 0.55, 0.58),
		"drops": [&"STONE"], "falling": false, "strength": 3.0,
	})
	register_block(&"SAND", {
		"name": "Sand", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 0.5, "tool": &"shovel", "color": Color(0.82, 0.75, 0.53),
		"drops": [&"SAND"], "falling": true, "strength": 0.5,
	})
	register_block(&"WOOD", {
		"name": "Wood", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 2.0, "tool": &"axe", "color": Color(0.42, 0.28, 0.15),
		"drops": [&"WOOD"], "falling": false, "strength": 2.0,
	})
	register_block(&"LEAF", {
		"name": "Leaves", "opaque": false, "transparent": true, "emissive": false,
		"hardness": 0.2, "tool": &"none", "color": Color(0.20, 0.48, 0.16, 0.9),
		"drops": [], "falling": false, "strength": 0.2,
	})
	register_block(&"COAL", {
		"name": "Coal Ore", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 3.0, "tool": &"pick", "color": Color(0.35, 0.35, 0.38),
		"drops": [&"COAL"], "falling": false, "strength": 3.0,
	})
	register_block(&"COPPER", {
		"name": "Copper Ore", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 3.0, "tool": &"pick", "color": Color(0.55, 0.36, 0.24),
		"drops": [&"COPPER"], "falling": false, "strength": 3.0,
	})
	register_block(&"CRYSTAL", {
		"name": "Crystal", "opaque": false, "transparent": true, "emissive": true,
		"emissive_energy": 2.5, "hardness": 2.5, "tool": &"pick",
		"color": Color(0.55, 0.85, 1.0, 0.6), "drops": [&"CRYSTAL"],
		"falling": false, "strength": 1.5,
	})
	register_block(&"SNOW", {
		"name": "Snow", "opaque": true, "transparent": false, "emissive": false,
		"hardness": 0.4, "tool": &"shovel", "color": Color(0.92, 0.94, 0.98),
		"drops": [&"SNOW"], "falling": false, "strength": 0.4,
	})
