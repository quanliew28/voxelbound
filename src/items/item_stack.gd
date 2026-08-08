extends RefCounted
class_name ItemStack
## One inventory stack: an item id + count. Canonical: ARCHITECTURE.md §9.
## Item ids are BLOCK ids for now (Phase 7); standalone items (tools, etc.)
## arrive Phase 8 and reuse this shape.

const MAX_STACK: int = 64

var item_id: int
var count: int
## Per-instance durability for tools (-1 = not durability-tracked, e.g. blocks).
var durability: int = -1

func _init(id: int, amount: int = 1) -> void:
	item_id = id
	count = amount

## Tools never stack (one per slot); blocks stack to 64.
static func max_stack_for(item_id: int) -> int:
	return 1 if ToolRegistry.check_tool(item_id) else MAX_STACK

func is_empty() -> bool:
	return count <= 0

## How much of `amount` fits in this stack (0 if different item or full).
func can_add(amount: int) -> bool:
	return count + amount <= MAX_STACK

func add(amount: int) -> int:
	## Adds, returns what did NOT fit (0 = all fit).
	var overflow := maxi(count + amount - MAX_STACK, 0)
	count = mini(count + amount, MAX_STACK)
	return overflow

func remove(amount: int) -> int:
	## Removes, returns what was actually removed.
	var removed := mini(amount, count)
	count -= removed
	return removed

func display_name() -> String:
	if ToolRegistry.check_tool(item_id):
		return ToolRegistry.display_name(item_id)
	return BlockRegistry.shared().get_def(item_id).get("name", "Item")
