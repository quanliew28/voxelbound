extends RefCounted
class_name ToolRegistry
## Tool definitions — data-driven, ORIGINAL tools (GAME_DESIGN.md §Tools).
## Canonical: ARCHITECTURE.md §9. Tool item ids live ABOVE the block id space
## (TOOL_ID_BASE = 100) so block ids and tool ids never collide in inventory.
##
## Static data is built via STATIC VAR INITIALIZERS (not a lazy _ensure()):
## lazy `_ensure()` patterns can fail with "Expected 0 argument(s)" when a
## static function is called from another class before this script's statics
## were touched in that process. Initializers run deterministically at class
## load.

const TOOL_ID_BASE: int = 100

## Def keys:
##   name, speed (mine speed multiplier), damage, durability,
##   affinity (matches BlockRegistry "tool": "pick"/"axe"/"shovel"/"none"),
##   description
const TOOLS: Array[Dictionary] = [
	{"name": "Crude Pick", "affinity": "pick", "speed": 2.0, "damage": 2, "durability": 60,
		"description": "Stone head, wood handle. Mines stone and ores."},
	{"name": "Copper Pick", "affinity": "pick", "speed": 4.0, "damage": 3, "durability": 160,
		"description": "Copper head. Mines hard stone comfortably."},
	{"name": "Crystal Pick", "affinity": "pick", "speed": 7.0, "damage": 5, "durability": 400,
		"description": "Crystal-edged. Cuts through almost anything."},
	{"name": "Crude Axe", "affinity": "axe", "speed": 2.0, "damage": 3, "durability": 60,
		"description": "Fells wood efficiently."},
	{"name": "Copper Axe", "affinity": "axe", "speed": 4.0, "damage": 4, "durability": 160,
		"description": "A solid woodman's tool."},
	{"name": "Crystal Axe", "affinity": "axe", "speed": 7.0, "damage": 6, "durability": 400,
		"description": "Splits trunks like paper."},
]

static var _defs: Array[Dictionary] = _build_defs()
static var _ids: Dictionary = _build_ids()


static func _build_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in TOOLS:
		out.append(t.duplicate(true))
	return out


static func _build_ids() -> Dictionary:
	var ids := {}
	for i in _defs.size():
		ids[StringName(_defs[i].name.to_upper().replace(" ", "_"))] = TOOL_ID_BASE + i
	return ids


static func id_of(tool_name: StringName) -> int:
	return int(_ids.get(tool_name, -1))


static func check_tool(item_id: int) -> bool:
	return item_id >= TOOL_ID_BASE and item_id - TOOL_ID_BASE < _defs.size()


static func get_def(item_id: int) -> Dictionary:
	if not check_tool(item_id):
		return {}
	return _defs[item_id - TOOL_ID_BASE]


static func display_name(item_id: int) -> String:
	return str(get_def(item_id).get("name", "Tool"))


static func get_speed(item_id: int) -> float:
	return float(get_def(item_id).get("speed", 1.0))


static func get_damage(item_id: int) -> int:
	return int(get_def(item_id).get("damage", 1))


static func get_durability(item_id: int) -> int:
	return int(get_def(item_id).get("durability", 0))


static func get_affinity(item_id: int) -> StringName:
	return StringName(get_def(item_id).get("affinity", &"none"))
