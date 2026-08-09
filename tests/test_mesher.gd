extends RefCounted
## Phase 3 suite: VoxelMesher / MeshData + VoxelWorld mesh integration.
## Runs headless via tests/run_tests.gd.

var tree: SceneTree
var last_passed: int = 0
var _failed: int = 0

func run() -> int:
	_check_air_only()
	_check_single_block()
	_check_face_culling()
	_check_cross_chunk_culling()
	_check_transparent_and_emissive_surfaces()
	_check_face_brightness_colors()
	_check_face_positions()
	_check_winding()
	_check_set_block_generated_flags()
	_check_world_rebuild_integration()
	_check_world_neighbor_dirtying()
	_check_world_remove_frees_node()
	print("SUITE mesher: %d passed, %d failed" % [last_passed, _failed])
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


## A world helper: one chunk at origin containing exactly the given blocks.
func _chunk_world(blocks: Dictionary) -> VoxelWorld:
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	for local in blocks:
		chunk.set_block_generated(local, blocks[local])
	world.add_chunk(chunk)
	return world


# --- Mesher: pure geometry counts ---

func _check_air_only() -> void:
	var world := _chunk_world({})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	_check(data.surface_empty(MeshData.SURFACE_OPAQUE), "mesher air-only opaque empty")
	_check(data.surface_empty(MeshData.SURFACE_TRANSPARENT), "mesher air-only transparent empty")
	_check(data.surface_empty(MeshData.SURFACE_EMISSIVE), "mesher air-only emissive empty")
	world.free()


func _check_single_block() -> void:
	var reg := BlockRegistry.shared()
	var world := _chunk_world({Vector3i(0, 0, 0): reg.get_id(&"STONE")})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	# one isolated block: 6 faces * 4 verts = 24 verts, 6 faces * 6 idx = 36
	_check(data.surface_vertex_count(MeshData.SURFACE_OPAQUE) == 24, "mesher single block 24 verts", "got %d" % data.surface_vertex_count(MeshData.SURFACE_OPAQUE))
	_check(data.surface_triangle_count(MeshData.SURFACE_OPAQUE) == 12, "mesher single block 12 tris", "got %d" % data.surface_triangle_count(MeshData.SURFACE_OPAQUE))
	_check(data.surface_empty(MeshData.SURFACE_TRANSPARENT), "mesher stone no transparent")
	_check(data.surface_empty(MeshData.SURFACE_EMISSIVE), "mesher stone no emissive")
	world.free()


func _check_face_culling() -> void:
	var reg := BlockRegistry.shared()
	# two adjacent stone blocks -> shared face culled: 10 faces -> 40 verts
	var world := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"STONE"),
		Vector3i(1, 0, 0): reg.get_id(&"STONE"),
	})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	# Phase 17 greedy: two adjacent blocks merge into ONE rectangle (24 verts),
	# vs 40 verts with per-face meshing — shared face culled, fewer triangles.
	var verts := data.surface_vertex_count(MeshData.SURFACE_OPAQUE)
	_check(verts < 40 and verts > 0, "mesher adjacent culling merges", "got %d" % verts)
	# stacked column of 3 -> greedy merges each side into one rectangle
	var world2 := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"STONE"),
		Vector3i(0, 1, 0): reg.get_id(&"STONE"),
		Vector3i(0, 2, 0): reg.get_id(&"STONE"),
	})
	var data2 := VoxelMesher.build_mesh(world2.get_chunk(Vector3i.ZERO), world2)
	_check(data2.surface_vertex_count(MeshData.SURFACE_OPAQUE) == 24, "mesher column merges to 6 quads", "got %d" % data2.surface_vertex_count(MeshData.SURFACE_OPAQUE))
	# solid 2x2x2 cube -> greedy merges each exposed side into ONE quad = 24 verts
	var world3 := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"STONE"), Vector3i(1, 0, 0): reg.get_id(&"STONE"),
		Vector3i(0, 1, 0): reg.get_id(&"STONE"), Vector3i(1, 1, 0): reg.get_id(&"STONE"),
		Vector3i(0, 0, 1): reg.get_id(&"STONE"), Vector3i(1, 0, 1): reg.get_id(&"STONE"),
		Vector3i(0, 1, 1): reg.get_id(&"STONE"), Vector3i(1, 1, 1): reg.get_id(&"STONE"),
	})
	var data3 := VoxelMesher.build_mesh(world3.get_chunk(Vector3i.ZERO), world3)
	var cube_verts := data3.surface_vertex_count(MeshData.SURFACE_OPAQUE)
	_check(cube_verts == 24, "mesher 2x2x2 cube merges to 6 quads", "got %d" % cube_verts)
	world.free()
	world2.free()
	world3.free()


func _check_cross_chunk_culling() -> void:
	var reg := BlockRegistry.shared()
	# block at the +x border of chunk (0,0,0) and a block in chunk (1,0,0):
	# the shared face must be culled by reading ACROSS the chunk border.
	var world := VoxelWorld.new()
	var c0 := VoxelChunk.new(Vector3i.ZERO)
	var c1 := VoxelChunk.new(Vector3i(1, 0, 0))
	c0.set_block_generated(Vector3i(15, 0, 0), reg.get_id(&"STONE"))
	c1.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(c0)
	world.add_chunk(c1)
	var data := VoxelMesher.build_mesh(c0, world)
	_check(data.surface_vertex_count(MeshData.SURFACE_OPAQUE) == 20, "mesher cross-chunk culling 5 faces", "got %d" % data.surface_vertex_count(MeshData.SURFACE_OPAQUE))
	# and the face IS visible when the neighbour chunk is missing (reads AIR)
	var world2 := VoxelWorld.new()
	world2.add_chunk(c0)
	var data2 := VoxelMesher.build_mesh(c0, world2)
	_check(data2.surface_vertex_count(MeshData.SURFACE_OPAQUE) == 24, "mesher missing neighbour -> 6 faces", "got %d" % data2.surface_vertex_count(MeshData.SURFACE_OPAQUE))
	world.free()
	world2.free()


func _check_transparent_and_emissive_surfaces() -> void:
	var reg := BlockRegistry.shared()
	var world := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"LEAF"),
		Vector3i(2, 0, 0): reg.get_id(&"CRYSTAL"),
	})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	_check(data.surface_empty(MeshData.SURFACE_OPAQUE), "mesher leaf+crystal no opaque")
	_check(data.surface_vertex_count(MeshData.SURFACE_TRANSPARENT) == 24, "mesher leaf on transparent", "got %d" % data.surface_vertex_count(MeshData.SURFACE_TRANSPARENT))
	_check(data.surface_vertex_count(MeshData.SURFACE_EMISSIVE) == 24, "mesher crystal on emissive", "got %d" % data.surface_vertex_count(MeshData.SURFACE_EMISSIVE))
	# same-type transparent seam is skipped; coplanar tops/bottoms/sides merge
	# -> 6 rectangles (24 verts) instead of 10 per-face faces (40)
	var world2 := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"LEAF"),
		Vector3i(1, 0, 0): reg.get_id(&"LEAF"),
	})
	var data2 := VoxelMesher.build_mesh(world2.get_chunk(Vector3i.ZERO), world2)
	_check(data2.surface_vertex_count(MeshData.SURFACE_TRANSPARENT) == 24, "mesher leaf-leaf seam culled + merged", "got %d" % data2.surface_vertex_count(MeshData.SURFACE_TRANSPARENT))
	# transparent against solid IS drawn: leaf next to stone
	var world3 := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"LEAF"),
		Vector3i(1, 0, 0): reg.get_id(&"STONE"),
	})
	var data3 := VoxelMesher.build_mesh(world3.get_chunk(Vector3i.ZERO), world3)
	# leaf: 5 faces (its +x face vs opaque stone is hidden); stone: all 6 faces
	# (its -x face vs non-opaque leaf is drawn)
	_check(data3.surface_vertex_count(MeshData.SURFACE_TRANSPARENT) == 20, "mesher leaf face vs stone culled", "got %d" % data3.surface_vertex_count(MeshData.SURFACE_TRANSPARENT))
	_check(data3.surface_vertex_count(MeshData.SURFACE_OPAQUE) == 24, "mesher stone face vs leaf drawn", "got %d" % data3.surface_vertex_count(MeshData.SURFACE_OPAQUE))
	world.free()
	world2.free()
	world3.free()


func _check_face_brightness_colors() -> void:
	var reg := BlockRegistry.shared()
	var stone := reg.get_id(&"STONE")
	var world := _chunk_world({Vector3i(0, 0, 0): stone})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	var base := reg.get_color(stone)
	var saw_top := false
	var saw_side := false
	var saw_bottom := false
	# brightness modulates RGB only; alpha stays as defined (1.0 for stone)
	var side_col := Color(base.r * 0.8, base.g * 0.8, base.b * 0.8, base.a)
	var bottom_col := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55, base.a)
	for i in data.colors[MeshData.SURFACE_OPAQUE].size():
		var n: Vector3 = data.normals[MeshData.SURFACE_OPAQUE][i]
		var c: Color = data.colors[MeshData.SURFACE_OPAQUE][i]
		if n.is_equal_approx(Vector3.UP):
			saw_top = saw_top or c.is_equal_approx(base)
		elif n.y < -0.9:
			saw_bottom = saw_bottom or c.is_equal_approx(bottom_col)
		else:
			saw_side = saw_side or c.is_equal_approx(side_col)
	_check(saw_top, "mesher top face full brightness")
	_check(saw_side, "mesher side face 0.8 brightness")
	_check(saw_bottom, "mesher bottom face 0.55 brightness")
	world.free()


## Regression: faces must sit on their correct PLANES (a single block at the
## origin spans 0..1: top at y=1, bottom at y=0, +x at x=1, -x at x=0, etc).
## Vertex-count tests cannot catch faces collapsed onto the wrong plane.
func _check_face_positions() -> void:
	var reg := BlockRegistry.shared()
	var world := _chunk_world({Vector3i(0, 0, 0): reg.get_id(&"STONE")})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	var verts: PackedVector3Array = data.vertices[MeshData.SURFACE_OPAQUE]
	var norms: PackedVector3Array = data.normals[MeshData.SURFACE_OPAQUE]
	var seen := {}
	for i in verts.size():
		var key := ""
		if norms[i].is_equal_approx(Vector3.UP):
			key = "top"
		elif norms[i].is_equal_approx(Vector3.DOWN):
			key = "bottom"
		elif norms[i].is_equal_approx(Vector3.RIGHT):
			key = "px"
		elif norms[i].is_equal_approx(Vector3.LEFT):
			key = "nx"
		elif norms[i].is_equal_approx(Vector3.BACK):  # (0,0,1) in Godot
			key = "pz"
		elif norms[i].is_equal_approx(Vector3.FORWARD):  # (0,0,-1) in Godot
			key = "nz"
		if key.is_empty():
			continue
		var pos: Vector3 = verts[i]
		var ok := false
		match key:
			"top": ok = absf(pos.y - 1.0) < 0.001
			"bottom": ok = absf(pos.y) < 0.001
			"px": ok = absf(pos.x - 1.0) < 0.001
			"nx": ok = absf(pos.x) < 0.001
			"pz": ok = absf(pos.z - 1.0) < 0.001
			"nz": ok = absf(pos.z) < 0.001
		if ok:
			seen[key] = true
	_check(seen.size() == 6, "mesher face planes", "seen %s" % str(seen.keys()))
	world.free()


## Regression: Godot front faces are CLOCKWISE. Every triangle's geometric
## normal (cross of its first two edges) must point OPPOSITE to the stored
## vertex normal, or the renderer culls the face and ConcavePolygonShape3D
## collides only from the back (player falls through terrain).
func _check_winding() -> void:
	var reg := BlockRegistry.shared()
	var world := _chunk_world({
		Vector3i(0, 0, 0): reg.get_id(&"STONE"),
		Vector3i(1, 0, 0): reg.get_id(&"LEAF"),
		Vector3i(2, 0, 0): reg.get_id(&"CRYSTAL"),
	})
	var data := VoxelMesher.build_mesh(world.get_chunk(Vector3i.ZERO), world)
	var bad := 0
	var total := 0
	for s in MeshData.SURFACE_COUNT:
		if data.surface_empty(s):
			continue
		var verts := data.vertices[s]
		var norms := data.normals[s]
		var idx := data.indices[s]
		for i in range(0, idx.size(), 3):
			var a: Vector3 = verts[idx[i]]
			var b: Vector3 = verts[idx[i + 1]]
			var c: Vector3 = verts[idx[i + 2]]
			var geo := (b - a).cross(c - a)
			if geo.length_squared() > 0.0 and geo.normalized().dot(norms[idx[i]]) >= 0.0:
				bad += 1
			total += 1
	_check(bad == 0 and total > 0, "mesher winding clockwise", "bad %d/%d" % [bad, total])
	world.free()


# --- VoxelChunk: generation-path write ---

func _check_set_block_generated_flags() -> void:
	var chunk := VoxelChunk.new()
	chunk.is_modified = false
	_check(chunk.set_block_generated(Vector3i(1, 2, 3), 5), "generated write accepted")
	_check(chunk.get_block(Vector3i(1, 2, 3)) == 5, "generated write roundtrip")
	_check(chunk.is_dirty, "generated write sets dirty")
	_check(not chunk.is_modified, "generated write does NOT mark modified")
	chunk.is_dirty = false
	_check(not chunk.set_block_generated(Vector3i(1, 2, 3), 5), "generated same value -> false")
	_check(not chunk.is_dirty, "generated noop no dirty churn")
	_check(not chunk.set_block_generated(Vector3i(99, 0, 0), 1), "generated out of bounds -> false")


# --- VoxelWorld: mesh node integration ---

func _check_world_rebuild_integration() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	_check(chunk.is_dirty, "world add_chunk leaves dirty")
	world.rebuild_all_dirty()
	_check(not chunk.is_dirty, "world rebuild clears dirty")
	_check(world.get_node_or_null("ChunkNode_0_0_0") != null, "world chunk node created")
	var node := world.get_node("ChunkNode_0_0_0")
	var mi := node.get_node("Mesh") as MeshInstance3D
	_check(mi.mesh != null and mi.mesh.get_surface_count() >= 1, "world mesh instance has surface")
	var cs := node.get_node("Collision/Shape") as CollisionShape3D
	_check(cs.shape is ConcavePolygonShape3D, "world collision is concave")
	# gameplay edit -> re-dirties, rebuild updates
	world.set_block(Vector3i(1, 0, 0), reg.get_id(&"STONE"))
	_check(chunk.is_dirty, "world set_block re-dirties chunk")
	world.rebuild_all_dirty()
	_check(not chunk.is_dirty, "world rebuild after edit clears dirty")
	var shape2 := (node.get_node("Collision/Shape") as CollisionShape3D).shape as ConcavePolygonShape3D
	_check(shape2 != null and shape2.get_faces().size() > 0, "world collision updated after edit")
	world.free()


func _check_world_neighbor_dirtying() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	var c0 := VoxelChunk.new(Vector3i.ZERO)
	var c1 := VoxelChunk.new(Vector3i(1, 0, 0))
	world.add_chunk(c0)
	world.add_chunk(c1)
	world.rebuild_all_dirty()
	c0.is_dirty = false
	c1.is_dirty = false
	# interior edit: only owning chunk dirties
	world.set_block(Vector3i(5, 0, 5), reg.get_id(&"STONE"))
	_check(c0.is_dirty and not c1.is_dirty, "world interior edit dirties only owner")
	c0.is_dirty = false
	# border edit: owner AND +x neighbour dirty
	world.set_block(Vector3i(15, 0, 5), reg.get_id(&"STONE"))
	_check(c0.is_dirty and c1.is_dirty, "world border edit dirties owner + neighbour")
	# negative border
	c0.is_dirty = false
	c1.is_dirty = false
	var cm1 := VoxelChunk.new(Vector3i(-1, 0, 0))
	world.add_chunk(cm1)
	world.rebuild_all_dirty()
	cm1.is_dirty = false
	c0.is_dirty = false
	world.set_block(Vector3i(0, 0, 5), reg.get_id(&"STONE"))
	_check(c0.is_dirty and cm1.is_dirty, "world -x border dirties neighbour")
	world.free()


func _check_world_remove_frees_node() -> void:
	var reg := BlockRegistry.shared()
	var world := VoxelWorld.new()
	var chunk := VoxelChunk.new(Vector3i.ZERO)
	chunk.set_block_generated(Vector3i(0, 0, 0), reg.get_id(&"STONE"))
	world.add_chunk(chunk)
	world.rebuild_all_dirty()
	var node := world.get_node_or_null("ChunkNode_0_0_0")
	_check(node != null, "remove test: node exists")
	world.remove_chunk(Vector3i.ZERO)
	_check(world.get_chunk(Vector3i.ZERO) == null, "remove test: chunk gone")
	_check(world.chunk_count() == 0, "remove test: chunk count 0")
	await tree.physics_frame
	_check(not is_instance_valid(node), "remove test: mesh node freed")
	world.free()
