extends RefCounted
class_name SaveManager
## Save/load (Phase 14). Canonical: ARCHITECTURE.md §10.
## Binary, versioned, diff-only: world seed + time + player (position,
## spawn, hp, 36-slot inventory) + SERIALIZED DATA ONLY FOR MODIFIED CHUNKS
## (VoxelChunk.is_modified). Untouched procedural terrain is never written —
## it regenerates from the seed.

const MAGIC := "VB1"
const VERSION: int = 1
const SLOT_COUNT: int = 36


## Returns true on success (versioned binary; see load_game for the layout).
static func save_game(path: String, world: VoxelWorld, player: PlayerController, day_time: float) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_8(VERSION)
	f.store_64(world.world_seed)
	f.store_float(day_time)
	# player
	var p := player.global_position
	f.store_float(p.x)
	f.store_float(p.y)
	f.store_float(p.z)
	f.store_float(player.spawn_point.x)
	f.store_float(player.spawn_point.y)
	f.store_float(player.spawn_point.z)
	f.store_float(player.hp)
	# inventory: 36 slots, each flagged empty(0)/filled(1) + id + count + durability
	for i in SLOT_COUNT:
		var stack := player.inventory.get_slot(i)
		if stack == null:
			f.store_8(0)
		else:
			f.store_8(1)
			f.store_32(stack.item_id)
			f.store_16(stack.count)
			f.store_32(stack.durability)
	# modified chunk diffs only
	var modified: Array = []
	for coord in world.get_loaded_chunk_coords():
		var chunk := world.get_chunk(coord)
		if chunk != null and chunk.is_modified:
			modified.append(coord)
	f.store_16(modified.size())
	for coord in modified:
		var chunk := world.get_chunk(coord)
		f.store_32(coord.x)
		f.store_32(coord.y)
		f.store_32(coord.z)
		f.store_buffer(chunk.serialize())
	f.close()
	return true


## Reads a save. Returns {} when the file is missing, corrupt, or a newer
## version. Layout: magic "VB1" (3 bytes) + version (1) + seed (8) + time (4)
## + player pos/spawn (6*4) + hp (4) + 36 inventory slots + u16 chunk count +
## per chunk: coord (3*4) + 4096-byte chunk payload.
static func load_game(path: String) -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(path):
		return result
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return result
	if f.get_buffer(3) != MAGIC.to_ascii_buffer():
		f.close()
		return result
	var version := f.get_8()
	if version != VERSION:
		f.close()
		return result
	result["seed"] = f.get_64()
	result["time"] = f.get_float()
	result["player_pos"] = Vector3(f.get_float(), f.get_float(), f.get_float())
	result["spawn_point"] = Vector3(f.get_float(), f.get_float(), f.get_float())
	result["hp"] = f.get_float()
	var slots: Array = []
	for i in SLOT_COUNT:
		if f.get_8() == 1:
			slots.append({"item": f.get_32(), "count": f.get_16(), "durability": f.get_32()})
		else:
			slots.append(null)
	result["inventory"] = slots
	var chunk_count := f.get_16()
	var chunks := {}
	for i in chunk_count:
		var coord := Vector3i(f.get_32(), f.get_32(), f.get_32())
		var chunk := VoxelChunk.new(coord)
		# serialize() = [u8 version][3 x i32 coord][SIZE3 raw bytes]
		var payload_len: int = 1 + 12 + VoxelChunk.SIZE3
		if not chunk.deserialize(f.get_buffer(payload_len)):
			f.close()
			return {}
		chunks[coord] = chunk
	f.close()
	result["chunks"] = chunks
	return result


## Applies a loaded save to a live world + player.
static func apply_load(world: VoxelWorld, player: PlayerController, data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("chunks"):
		for coord in data["chunks"]:
			world.add_chunk(data["chunks"][coord])
	if player != null and data.has("player_pos"):
		player.global_position = data["player_pos"]
		player.spawn_point = data["spawn_point"]
		player.hp = data["hp"]
		if data.has("inventory"):
			for i in SLOT_COUNT:
				var slot = data["inventory"][i]  # untyped: empty slots are null
				if slot == null or (slot is Dictionary and slot.is_empty()):
					player.inventory.set_stack(i, null)
				else:
					var stack := ItemStack.new(int(slot.item), int(slot.count))
					stack.durability = int(slot.durability)
					player.inventory.set_stack(i, stack)


static func has_save(path: String) -> bool:
	return FileAccess.file_exists(path)
