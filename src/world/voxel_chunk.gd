extends RefCounted
class_name VoxelChunk
## Pure-data chunk storage. Canonical spec: docs/ARCHITECTURE.md §5.1, §5.2.
##
## Holds NO nodes. Storage is one byte per block (max 255 block types, id 0 =
## AIR). The ONLY valid index mapping is `x + z * 16 + y * 256` (x fastest).
## Two flags drive the pipeline:
##   is_dirty    -> needs a mesh rebuild (checked by the mesher phase)
##   is_modified -> touched by gameplay edits -> must be persisted by the save
##                  system (Phase 14). Procedurally generated chunks are never
##                  marked modified.

const CHUNK_SIZE: int = 16
const SIZE2: int = 256   # 16 * 16
const SIZE3: int = 4096  # 16 * 16 * 16
const SERIALIZE_VERSION: int = 1

var chunk_coord: Vector3i = Vector3i.ZERO
var blocks: PackedByteArray = PackedByteArray()
var is_dirty: bool = true
var is_modified: bool = false

func _init(coord: Vector3i = Vector3i.ZERO) -> void:
	chunk_coord = coord
	blocks.resize(SIZE3)  # zero-filled -> all AIR


## The ONLY valid index mapping (ARCHITECTURE.md §5.1). No bounds check —
## callers must validate with is_local_in_bounds() first.
static func index_of(x: int, y: int, z: int) -> int:
	return x + z * CHUNK_SIZE + y * SIZE2


static func is_local_in_bounds(local: Vector3i) -> bool:
	return local.x >= 0 and local.x < CHUNK_SIZE \
		and local.y >= 0 and local.y < CHUNK_SIZE \
		and local.z >= 0 and local.z < CHUNK_SIZE


## Bounds-checked get. Out-of-range reads return AIR (never crashes).
func get_block(local: Vector3i) -> int:
	if not is_local_in_bounds(local):
		return BlockRegistry.AIR_ID
	return blocks[index_of(local.x, local.y, local.z)]


## Bounds-checked set. Returns true if the block actually changed (sets
## is_dirty + is_modified). Returns false if out of bounds or the value is
## unchanged (no flag churn). Setting AIR to AIR is a no-op.
func set_block(local: Vector3i, id: int) -> bool:
	if not is_local_in_bounds(local):
		return false
	var idx := index_of(local.x, local.y, local.z)
	var current: int = blocks[idx]
	if current == id:
		return false
	blocks[idx] = id
	is_dirty = true
	is_modified = true
	return true


## Fills the entire chunk with one block id (generation convenience).
func fill(id: int) -> void:
	blocks.fill(id)
	is_dirty = true
	# fill() is used by generation; do NOT mark is_modified.


## Generation/loading path: writes a block WITHOUT marking the chunk modified
## (only gameplay edits via VoxelWorld.set_block must mark modified — that is
## the save-diff contract, ARCHITECTURE.md §10). Still dirties for meshing.
func set_block_generated(local: Vector3i, id: int) -> bool:
	if not is_local_in_bounds(local):
		return false
	var idx := index_of(local.x, local.y, local.z)
	if blocks[idx] == id:
		return false
	blocks[idx] = id
	is_dirty = true
	return true


## Serialization hooks (Phase 14 consumes these; format frozen now).
## Format: [u8 version][i32 cx][i32 cy][i32 cz][4096 raw block bytes]
func serialize() -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u8(SERIALIZE_VERSION)
	stream.put_32(chunk_coord.x)
	stream.put_32(chunk_coord.y)
	stream.put_32(chunk_coord.z)
	stream.put_data(blocks)
	return stream.data_array


## Restores state from serialize() output. Returns false on any mismatch
## (version, coord, or length) WITHOUT mutating the chunk. On success the
## chunk is marked clean (is_modified = false — freshly loaded data is by
## definition already saved) but is_dirty = true (it still needs meshing).
func deserialize(bytes: PackedByteArray) -> bool:
	var expected_len: int = 1 + 12 + SIZE3
	if bytes.size() != expected_len:
		return false
	var stream := StreamPeerBuffer.new()
	stream.data_array = bytes
	var version: int = stream.get_u8()
	if version != SERIALIZE_VERSION:
		return false
	var coord := Vector3i(stream.get_32(), stream.get_32(), stream.get_32())
	var data: PackedByteArray = stream.get_data(SIZE3)[1]
	if data.size() != SIZE3:
		return false
	chunk_coord = coord
	blocks = data
	is_modified = false
	is_dirty = true
	return true
