extends RefCounted
class_name CraftingRegistry
## Data-driven crafting. ORIGINAL recipes (never Minecraft copies).
## Canonical: ARCHITECTURE.md §9 / GAME_DESIGN.md §Crafting.
##
## Recipe shape:
##   { "name": String, "result": StringName, "result_count": int,
##     "ingredients": [{ "item": StringName, "count": int }, ...] }
## Items are block names (BlockRegistry) or tool names (ToolRegistry).

const RECIPES: Array[Dictionary] = [
	{"name": "Crude Pick", "result": "CRUDE_PICK", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "STONE", "count": 3}]},
	{"name": "Copper Pick", "result": "COPPER_PICK", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "COPPER", "count": 3}]},
	{"name": "Crystal Pick", "result": "CRYSTAL_PICK", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "CRYSTAL", "count": 3}]},
	{"name": "Crude Axe", "result": "CRUDE_AXE", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "STONE", "count": 2}]},
	{"name": "Copper Axe", "result": "COPPER_AXE", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "COPPER", "count": 2}]},
	{"name": "Crystal Axe", "result": "CRYSTAL_AXE", "result_count": 1,
		"ingredients": [{"item": "WOOD", "count": 2}, {"item": "CRYSTAL", "count": 2}]},
]


static func recipe_count() -> int:
	return RECIPES.size()


static func _item_id(item_name: StringName) -> int:
	var block_id := BlockRegistry.shared().get_id(item_name)
	if block_id != BlockRegistry.AIR_ID or item_name == &"AIR":
		return block_id
	return ToolRegistry.id_of(item_name)


## True when the inventory holds every ingredient.
static func can_craft(inventory: Inventory, recipe_index: int) -> bool:
	if recipe_index < 0 or recipe_index >= RECIPES.size():
		return false
	for ing in RECIPES[recipe_index].ingredients:
		if inventory.count_item(_item_id(StringName(ing.item))) < int(ing.count):
			return false
	return true


## Consumes ingredients, adds the result (tools start at full durability).
## Returns true on success.
static func craft(inventory: Inventory, recipe_index: int) -> bool:
	if not can_craft(inventory, recipe_index):
		return false
	var recipe := RECIPES[recipe_index]
	for ing in recipe.ingredients:
		inventory.remove_item(_item_id(StringName(ing.item)), int(ing.count))
	var result_id := _item_id(StringName(recipe.result))
	var left := inventory.add_item(result_id, int(recipe.result_count))
	if left > 0:
		# no room — refund ingredients and abort (should not happen; UI disables)
		for ing in recipe.ingredients:
			inventory.add_item(_item_id(StringName(ing.item)), int(ing.count))
		return false
	if ToolRegistry.check_tool(result_id):
		var slot := inventory.find_slot(result_id)
		if slot != -1 and inventory.get_slot(slot) != null:
			inventory.get_slot(slot).durability = ToolRegistry.get_durability(result_id)
	return true


## Indices of recipes craftable from the inventory (UI list).
static func list_craftable(inventory: Inventory) -> Array[int]:
	var out: Array[int] = []
	for i in RECIPES.size():
		if can_craft(inventory, i):
			out.append(i)
	return out


## All recipe indices (UI shows every recipe, disabled when not craftable).
static func all_recipe_indices() -> Array[int]:
	var out: Array[int] = []
	for i in RECIPES.size():
		out.append(i)
	return out
