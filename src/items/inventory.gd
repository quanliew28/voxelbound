extends RefCounted
class_name Inventory
## 36-slot inventory; slots 0..8 are the hotbar. Canonical: ARCHITECTURE.md §9.
## Pure data + a `changed` signal for UI refresh. Stacks cap at 64.

signal changed

const SLOT_COUNT: int = 36
const HOTBAR_SIZE: int = 9
const MAX_STACK: int = 64

var slots: Array[ItemStack] = []  # null = empty slot

func _init() -> void:
	slots.resize(SLOT_COUNT)

func _emit() -> void:
	changed.emit()

func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]

func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true

## Adds `amount` of `id` (fills existing partial stacks first, then empty
## slots). Returns the amount that did NOT fit.
func add_item(id: int, amount: int) -> int:
	var max_stack := ItemStack.max_stack_for(id)
	var remaining := amount
	for i in slots.size():
		var s := slots[i]
		if s == null or s.item_id != id or s.count >= max_stack:
			continue
		var put := mini(max_stack - s.count, remaining)
		s.count += put
		remaining -= put
		if remaining == 0:
			_emit()
			return 0
	for i in slots.size():
		if slots[i] != null:
			continue
		var put := mini(max_stack, remaining)
		slots[i] = ItemStack.new(id, put)
		remaining -= put
		if remaining == 0:
			_emit()
			return 0
	_emit()
	return remaining

## Removes `amount` of `id` across slots. Returns how much was removed.
func remove_item(id: int, amount: int) -> int:
	var removed := 0
	for i in slots.size():
		var s := slots[i]
		if s == null or s.item_id != id:
			continue
		removed += s.remove(amount - removed)
		if s.is_empty():
			slots[i] = null
		if removed >= amount:
			break
	if removed > 0:
		_emit()
	return removed

## Removes `amount` from one slot. Returns how much was removed.
func remove_from_slot(index: int, amount: int) -> int:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return 0
	var s := slots[index]
	var removed := s.remove(amount)
	if s.is_empty():
		slots[index] = null
	if removed > 0:
		_emit()
	return removed

func count_item(id: int) -> int:
	var total := 0
	for s in slots:
		if s != null and s.item_id == id:
			total += s.count
	return total

func has_item(id: int, amount: int = 1) -> bool:
	return count_item(id) >= amount

## First slot holding `id`, or -1.
func find_slot(id: int) -> int:
	for i in slots.size():
		if slots[i] != null and slots[i].item_id == id:
			return i
	return -1


## Directly sets a slot (save/load + tests). Clamps to a valid index.
func set_stack(index: int, stack: ItemStack) -> bool:
	if index < 0 or index >= slots.size():
		return false
	slots[index] = stack
	_emit()
	return true
