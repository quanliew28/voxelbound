extends RefCounted
class_name TreeGenerator
## Deterministic procedural tree shapes. Canonical: ARCHITECTURE.md §5.2.
##
## Placement is a pure function of the column hash, so ANY chunk generation
## covering a tree's cells writes identical blocks — chunk-border trees are
## consistent by construction (neighbouring chunks duplicate the same cells,
## idempotently). Cells outside a chunk are simply not written by that chunk.

## Deterministic per-column hash in [0, 2^31).
static func column_hash(x: int, z: int) -> int:
	var h := x * 73856093 ^ z * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h)


## True when a tree of `density` grows at this column.
static func tree_at(x: int, z: int, density: float) -> bool:
	return float(column_hash(x, z) % 10000) / 10000.0 < density


## Returns Array[Dictionary] of {pos: Vector3i (world), id: int} for a tree
## of the given type rooted at `origin` (the column's surface block).
static func tree_cells(tree_type: String, origin: Vector3i) -> Array:
	var cells: Array = []
	var wood := BlockRegistry.shared().get_id(&"WOOD")
	var leaf := BlockRegistry.shared().get_id(&"LEAF")
	if tree_type == "broadleaf":
		# trunk 4 tall, 3x3x2 canopy + cap
		for i in 4:
			cells.append({"pos": origin + Vector3i(0, 1 + i, 0), "id": wood})
		for dy in [4, 5]:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					cells.append({"pos": origin + Vector3i(dx, 1 + dy, dz), "id": leaf})
		cells.append({"pos": origin + Vector3i(0, 7, 0), "id": leaf})
	elif tree_type == "pine":
		# trunk 6 tall, three shrinking cone layers + cap
		for i in 6:
			cells.append({"pos": origin + Vector3i(0, 1 + i, 0), "id": wood})
		for dy in [4, 5, 6]:
			var r := 1
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if absi(dx) == r and absi(dz) == r and dy < 6:
						continue  # trim corners on lower layers
					cells.append({"pos": origin + Vector3i(dx, 1 + dy, dz), "id": leaf})
		cells.append({"pos": origin + Vector3i(0, 8, 0), "id": leaf})
	return cells
