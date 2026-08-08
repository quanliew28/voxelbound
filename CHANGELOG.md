# Changelog

All notable changes per phase. Newest first.

## [Phase 6] — 2026-08-08
- **ChunkManager** (`src/world/chunk_manager.gd`): streaming — load/unload
  radii (Chebyshev xz), vertical chunk columns [0, top_chunk_y], generation
  queue sorted by player distance, WorkerThreadPool dispatch (fresh
  VoxelGenerator per task, call_deferred results, in-flight dedupe, per-frame
  + concurrency budgets), periodic far-chunk unload, `generate_sync()` for
  the spawn area. VoxelWorld gains `get_loaded_chunk_coords()`.
- main.gd: spawn area pre-filled synchronously, streaming maintains the world
  around the player as they move.
- Tests: 12 new streaming assertions (load radius fill, meshing, unload on
  teleport, bounded world size, threaded determinism vs direct generation,
  mesh node freeing). Total: 190/190 passing; boots clean.
- **VoxelGenerator** (`src/world/voxel_generator.gd`): seed-deterministic
  terrain — 4-octave Perlin height (base 32, ±14), surface layers
  (GRASS/SAND on top, DIRT/SAND ×3, STONE below), flattened spawn radius 4,
  pure `generate(chunk_coord)` + `fill_area()`. VoxelWorld gains `world_seed`
  and `generator`. main.gd now seeds the world (424242).
- `VoxelTestTerrain` deleted (its job is done).
- Tests: 21 new generator assertions (determinism, seed variance, layering,
  boundary continuity, spawn flatness, fill volume, valid ids).
  Total: 178/178 passing; boots clean.
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
