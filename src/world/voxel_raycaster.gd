extends RefCounted
class_name VoxelRaycaster
## Amanatides & Woo voxel DDA over a VoxelWorld. Pure math, no nodes.
## Canonical spec: docs/ARCHITECTURE.md §5.2.
##
## Returns on hit: {hit, block_pos, prev_pos, normal, distance}
##   block_pos  Vector3i  the solid cell hit
##   prev_pos   Vector3i  the AIR cell the ray came from (placement target)
##   normal     Vector3   face normal of the hit (points back along the ray)
##   distance   float     ray distance travelled
## Returns {} (empty dict) on miss or out of range.
##
## Rules: the ORIGIN cell is never reported as a hit (the player's own cell);
## cells at distance > max_distance are never hit.

static func cast_ray(world: VoxelWorld, origin: Vector3, direction: Vector3,
		max_distance: float) -> Dictionary:
	var dir := direction.normalized()
	var current := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(signi(dir.x), signi(dir.y), signi(dir.z))
	var t_max := Vector3(
		_first_boundary(origin.x, dir.x),
		_first_boundary(origin.y, dir.y),
		_first_boundary(origin.z, dir.z),
	)
	var t_delta := Vector3(
		_axis_delta(dir.x),
		_axis_delta(dir.y),
		_axis_delta(dir.z),
	)
	var distance := 0.0
	var normal := Vector3.ZERO
	var first_cell := true
	while distance <= max_distance:
		if not first_cell and world.get_block(current) != BlockRegistry.AIR_ID:
			return {
				"hit": true,
				"block_pos": current,
				"prev_pos": current - step,
				"normal": normal,
				"distance": distance,
			}
		first_cell = false
		# advance to the next voxel boundary (smallest t_max wins)
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			current.x += step.x
			distance = t_max.x
			t_max.x += t_delta.x
			normal = Vector3(-step.x, 0.0, 0.0)
		elif t_max.y <= t_max.z:
			current.y += step.y
			distance = t_max.y
			t_max.y += t_delta.y
			normal = Vector3(0.0, -step.y, 0.0)
		else:
			current.z += step.z
			distance = t_max.z
			t_max.z += t_delta.z
			normal = Vector3(0.0, 0.0, -step.z)
	return {}


## Distance from origin_component to the first voxel boundary along dir.
static func _first_boundary(origin_component: float, dir_component: float) -> float:
	if dir_component == 0.0:
		return INF
	var cell := floori(origin_component)
	if dir_component > 0.0:
		return (float(cell) + 1.0 - origin_component) / dir_component
	return (float(cell) - origin_component) / dir_component


static func _axis_delta(dir_component: float) -> float:
	if dir_component == 0.0:
		return INF
	return absf(1.0 / dir_component)
