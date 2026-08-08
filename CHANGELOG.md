# Changelog

All notable changes per phase. Newest first.

## [Phase 4] — 2026-08-08
- **VoxelRaycaster** (`src/world/voxel_raycaster.gd`): Amanatides & Woo voxel
  DDA — pure static math over VoxelWorld. Returns hit/block_pos/prev_pos/
  normal/distance; origin cell skipped; distance = cell-boundary distance.
- **Block interaction** in PlayerController: LMB mines (hardness > 0), RMB
  places `selected_block_id` at the face-adjacent cell, guarded by a
  capsule-vs-cell AABB overlap test (never inside yourself). `interact_range`
  6 m. World wired by main.gd.
- Tests: 15 new raycaster assertions (axis hits + normals + placement cells,
  misses, range, inside-solid origin skip, overlap guard incl. crouch,
  end-to-end mine/place/reject). Total: 157/157 passing; boots clean.
- **VoxelMesher + MeshData** (`src/world/`): pure-function chunk mesher with
  visible-face culling across chunk borders, three surfaces (opaque /
  transparent / emissive), per-face brightness, Godot-clockwise winding.
- **VoxelWorld meshing integration**: per-chunk nodes
  (ChunkNode_* > MeshInstance3D multi-surface ArrayMesh + StaticBody3D >
  ConcavePolygonShape3D from opaque surface), deduplicated dirty queue with
  per-frame budget (4/frame), `rebuild_all_dirty()` for startup/tests,
  border edits dirty + rebuild bordering chunks, `set_block_generated()` on
  VoxelChunk (generation path, never marks modified).
- **Procedural materials**: opaque = vertex-color StandardMaterial3D;
  transparent (leaves) = alpha, double-sided; emissive (crystal) = custom
  procedural shader mapping vertex color to emission.
- **VoxelTestTerrain** (temporary, deleted at Phase 5): block-based plateau +
  hills + ore sprinkle + surface crystals; spawn-safe. Old `test_terrain.gd`
  (heightmap) removed.
- **main.gd** now builds a real VoxelWorld; player spawns on voxel surface.
- Tests: 44 new mesher assertions incl. face-plane and winding regressions.
  Total suite: 142/142 passing. Game boots headless clean, player walks on
  and collides with voxel terrain.
