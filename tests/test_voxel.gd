extends RefCounted
## Phase 2 suite: BlockRegistry, VoxelChunk, VoxelWorld.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_registry()
	_check_chunk_index_math()
	_check_chunk_get_set()
	_check_chunk_flags()
	_check_serialization()
	_check_world_mapping()
	_check_world_get_set()
	_check_world_signal()
	print("SUITE voxel: %d passed, %d failed" % [last_passed, _failed])
	return _failed


func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		last_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		var msg := "FAIL: " + name
		if not detail.is_empty():
			msg += " -- " + detail
		print(msg)


# --- BlockRegistry ---

func _check_registry() -> void:
	var reg := BlockRegistry.shared()
	_check(reg.get_id(&"AIR") == 0, "registry air id 0")
	_check(reg.get_id(&"GRASS") > 0, "registry grass id assigned")
	_check(reg.get_id(&"NOT_A_BLOCK") == 0, "registry unknown -> air", "got %d" % reg.get_id(&"NOT_A_BLOCK"))
	_check(reg.get_name(0) == &"AIR", "registry id->name roundtrip")
	_check(reg.get_name(999) == &"AIR", "registry out-of-range name -> air")
	_check(reg.has_block(&"CRYSTAL"), "registry has crystal")
	_check(reg.count() == 11, "registry default blocks", "count %d" % reg.count())
	_check(reg.is_opaque(reg.get_id(&"GRASS")), "registry grass opaque")
	_check(not reg.is_opaque(reg.get_id(&"LEAF")), "registry leaf not opaque")
	_check(reg.is_transparent(reg.get_id(&"LEAF")), "registry leaf transparent")
	_check(reg.is_emissive(reg.get_id(&"CRYSTAL")), "registry crystal emissive")
	_check(reg.get_color(reg.get_id(&"SAND")).is_equal_approx(Color(0.82, 0.75, 0.53)), "registry sand color")
	_check(reg.get_tool(reg.get_id(&"STONE")) == &"pick", "registry stone tool affinity")
	var drops := reg.get_drops(reg.get_id(&"GRASS"))
	_check(drops.size() == 1 and drops[0] == &"DIRT", "registry grass drops dirt")
	_check(reg.get_def(reg.get_id(&"GRASS")).get("opaque") == true, "registry def dict copy")
	_check(reg.get_def(-1).is_empty(), "registry negative id def -> empty")
	# duplicate registration is refused
	var before := reg.count()
	var dup_id := reg.register_block(&"GRASS", {"name": "Dup"})
	_check(dup_id == -1 and reg.count() == before, "registry duplicate refused")
	# AIR id stability across reset
	reg.reset()
	_check(reg.get_id(&"AIR") == 0, "registry air id 0 after reset")
	_check(reg.count() == 11, "registry blocks after reset")
	reg.reset()  # leave shared registry pristine for other suites


# --- VoxelChunk: index math ---

func _check_chunk_index_math() -> void:
	_check(VoxelChunk.index_of(0, 0, 0) == 0, "index origin 0")
	_check(VoxelChunk.index_of(15, 0, 0) == 15, "index x max")
	_check(VoxelChunk.index_of(0, 0, 15) == 240, "index z max", "got %d" % VoxelChunk.index_of(0, 0, 15))
	_check(VoxelChunk.index_of(0, 15, 0) == 3840, "index y max", "got %d" % VoxelChunk.index_of(0, 15, 0))
	_check(VoxelChunk.index_of(15, 15, 15) == 4095, "index corner max")
	_check(VoxelChunk.SIZE3 == 4096, "chunk capacity 4096")
	_check(VoxelChunk.is_local_in_bounds(Vector3i(0, 0, 0)), "bounds corner in")
	_check(VoxelChunk.is_local_in_bounds(Vector3i(15, 15, 15)), "bounds far corner in")
	_check(not VoxelChunk.is_local_in_bounds(Vector3i(16, 0, 0)), "bounds x out")
	_check(not VoxelChunk.is_local_in_bounds(Vector3i(0, -1, 0)), "bounds y negative out")


# --- VoxelChunk: get/set ---

func _check_chunk_get_set() -> void:
	var chunk := VoxelChunk.new(Vector3i(2, -1, 5))
	_check(chunk.chunk_coord == Vector3i(2, -1, 5), "chunk stores coord")
	_check(chunk.get_block(Vector3i(0, 0, 0)) == 0, "chunk fresh block is air")
	_check(chunk.set_block(Vector3i(3, 4, 5), 3), "chunk set returns true")
	_check(chunk.get_block(Vector3i(3, 4, 5)) == 3, "chunk get roundtrip")
	_check(not chunk.set_block(Vector3i(3, 4, 5), 3), "chunk set same id -> false")
	_check(not chunk.set_block(Vector3i(99, 0, 0), 1), "chunk set out of bounds -> false")
	_check(chunk.get_block(Vector3i(99, 0, 0)) == 0, "chunk get out of bounds -> air")
	_check(chunk.get_block(Vector3i(-1, 0, 0)) == 0, "chunk get negative local -> air")
	chunk.fill(7)
	_check(chunk.get_block(Vector3i(0, 0, 0)) == 7 and chunk.get_block(Vector3i(15, 15, 15)) == 7, "chunk fill")
	# set AIR->AIR is a no-op
	chunk.fill(0)
	_check(not chunk.set_block(Vector3i(0, 0, 0), 0), "chunk air->air noop")


# --- VoxelChunk: dirty/modified flags ---

func _check_chunk_flags() -> void:
	var chunk := VoxelChunk.new()
	chunk.is_dirty = false
	chunk.is_modified = false
	_check(chunk.set_block(Vector3i(1, 1, 1), 2), "flag test: edit accepted")
	_check(chunk.is_dirty and chunk.is_modified, "flag test: edit sets dirty+modified")
	chunk.is_dirty = false
	_check(not chunk.set_block(Vector3i(1, 1, 1), 2), "flag test: same value rejected")
	# noop must not re-set the (manually cleared) dirty flag, and must not
	# touch is_modified — the earlier real edit is still unsaved.
	_check(not chunk.is_dirty and chunk.is_modified, "flag test: no flag churn on noop")
	# fill() (generation path) dirties but must NOT mark modified
	chunk.is_modified = false
	chunk.fill(5)
	_check(chunk.is_dirty, "flag test: fill sets dirty")
	_check(not chunk.is_modified, "flag test: fill does not mark modified")


# --- VoxelChunk: serialization ---

func _check_serialization() -> void:
	var a := VoxelChunk.new(Vector3i(-3, 4, 0))
	a.fill(1)
	a.set_block(Vector3i(0, 0, 0), 4)
	a.set_block(Vector3i(15, 15, 15), 6)
	a.set_block(Vector3i(7, 8, 9), 2)
	var bytes := a.serialize()
	var b := VoxelChunk.new()
	_check(b.deserialize(bytes), "serialize roundtrip accepts")
	_check(b.chunk_coord == Vector3i(-3, 4, 0), "serialize roundtrip coord")
	_check(b.get_block(Vector3i(0, 0, 0)) == 4, "serialize roundtrip block a")
	_check(b.get_block(Vector3i(15, 15, 15)) == 6, "serialize roundtrip block b")
	_check(b.get_block(Vector3i(7, 8, 9)) == 2, "serialize roundtrip block c")
	_check(b.get_block(Vector3i(1, 1, 1)) == 1, "serialize roundtrip fill base")
	_check(not b.is_modified, "serialize roundtrip clean (not modified)")
	_check(b.is_dirty, "serialize roundtrip dirty (needs meshing)")
	# corrupt input is rejected without mutation
	var corrupt := bytes.duplicate()
	corrupt[0] = 99
	_check(not b.deserialize(corrupt), "serialize rejects bad version")
	_check(not b.deserialize(PackedByteArray([1, 2, 3])), "serialize rejects short input")


# --- VoxelWorld: coordinate mapping ---

func _check_world_mapping() -> void:
	_check(VoxelWorld.world_to_chunk(Vector3i(0, 0, 0)) == Vector3i.ZERO, "map origin chunk")
	_check(VoxelWorld.world_to_chunk(Vector3i(15, 15, 15)) == Vector3i.ZERO, "map inside chunk")
	_check(VoxelWorld.world_to_chunk(Vector3i(16, 0, 0)) == Vector3i(1, 0, 0), "map x boundary")
	_check(VoxelWorld.world_to_chunk(Vector3i(-1, 0, 0)) == Vector3i(-1, 0, 0), "map negative x floor", "got %s" % VoxelWorld.world_to_chunk(Vector3i(-1, 0, 0)))
	_check(VoxelWorld.world_to_chunk(Vector3i(-16, -16, -16)) == Vector3i(-1, -1, -1), "map negative boundary")
	_check(VoxelWorld.world_to_local(Vector3i(-1, 0, 0)) == Vector3i(15, 0, 0), "map negative local")
	_check(VoxelWorld.world_to_local(Vector3i(16, 0, 0)) == Vector3i(0, 0, 0), "map positive local wrap")


# --- VoxelWorld: world-space get/set ---

func _check_world_get_set() -> void:
	var world := VoxelWorld.new()
	_check(world.get_block(Vector3i(0, 0, 0)) == 0, "world missing chunk reads air")
	_check(not world.has_chunk(Vector3i.ZERO), "world no chunk yet")
	_check(world.set_block(Vector3i(0, 1, 0), 3), "world set creates chunk")
	_check(world.has_chunk(Vector3i.ZERO), "world chunk created")
	_check(world.get_block(Vector3i(0, 1, 0)) == 3, "world get roundtrip")
	_check(world.get_block(Vector3i(0, 0, 0)) == 0, "world untouched neighbour air")
	# cross-chunk boundary write
	_check(world.set_block(Vector3i(16, 0, 0), 5), "world cross-chunk set")
	_check(world.has_chunk(Vector3i(1, 0, 0)), "world second chunk exists")
	_check(world.get_block(Vector3i(16, 0, 0)) == 5, "world cross-chunk get")
	# negative world coords: both cells live in chunk (-1,0,0) at opposite
	# ends of the x axis (local 15 and local 0) — no crash, distinct cells
	_check(world.set_block(Vector3i(-1, 0, 0), 9), "world negative set")
	_check(world.set_block(Vector3i(-16, 0, 0), 10), "world negative set 2")
	_check(world.get_block(Vector3i(-1, 0, 0)) == 9, "world negative get")
	_check(world.get_block(Vector3i(-16, 0, 0)) == 10, "world negative get 2")
	_check(world.get_chunk(Vector3i(-1, 0, 0)) != null, "world negative chunk exists")
	# unchanged write is rejected world-wide
	_check(not world.set_block(Vector3i(0, 1, 0), 3), "world same value rejected")
	# remove path
	var removed := world.remove_chunk(Vector3i(1, 0, 0))
	_check(removed != null and not world.has_chunk(Vector3i(1, 0, 0)), "world remove chunk")
	_check(world.get_block(Vector3i(16, 0, 0)) == 0, "world removed chunk reads air")
	_check(world.remove_chunk(Vector3i(999, 999, 999)) == null, "world remove missing -> null")
	world.free()


# --- VoxelWorld: block_changed signal ---

func _check_world_signal() -> void:
	var world := VoxelWorld.new()
	var seen := []
	var old_ids := []
	world.block_changed.connect(func(pos: Vector3i, old: int, new_id: int) -> void:
		seen.append(pos)
		old_ids.append(old)
	)
	world.set_block(Vector3i(5, 2, 5), 8)
	world.set_block(Vector3i(5, 2, 5), 4)
	world.set_block(Vector3i(5, 2, 5), 4)  # no-op, must not emit
	_check(seen.size() == 2, "signal emitted once per real change", "got %d" % seen.size())
	_check(seen[0] == Vector3i(5, 2, 5) and seen[1] == Vector3i(5, 2, 5), "signal positions")
	_check(old_ids[0] == 0 and old_ids[1] == 8, "signal old ids", "got %s" % str(old_ids))
	_check(world.get_block(Vector3i(5, 2, 5)) == 4, "signal world reflects latest")
	var chunk := world.get_chunk(Vector3i.ZERO)
	_check(chunk != null and chunk.is_modified, "signal chunk marked modified")
	world.free()
