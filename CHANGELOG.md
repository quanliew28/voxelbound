# Changelog

All notable changes per phase. Newest first.

## [Phase 2] — 2026-08-08
- **BlockRegistry** (`src/world/block_registry.gd`): data-driven block
  definitions (name, opacity, emissive, hardness, tool affinity, color,
  drops), StringName<->id mapping, AIR = 0, static singleton access.
  10 default blocks per GAME_DESIGN (GRASS, DIRT, STONE, SAND, WOOD, LEAF,
  COAL, COPPER, CRYSTAL). Duplicate/overflow registration refused.
- **VoxelChunk** (`src/world/voxel_chunk.gd`): pure-data 16^3 storage
  (PackedByteArray, 4096 bytes), canonical index mapping
  `x + z*16 + y*256`, bounds-checked get/set, `is_dirty` (mesh rebuild) and
  `is_modified` (save diff) flags with no-op semantics, `fill()` for
  generation, frozen serialize/deserialize format (version 1).
- **VoxelWorld** (`src/world/voxel_world.gd`): chunk map owned by a Node3D,
  world-space get/set with floor-division mapping (negatives correct),
  `block_changed(world_pos, old_id, new_id)` signal, get_or_create_chunk,
  add/remove chunk paths for the future streaming phase.
- Tests: 85 new voxel assertions (index math, bounds, flags, serialization
  roundtrip + corrupt input, coordinate mapping, cross-chunk/negative
  world ops, signal semantics). Total suite: 96/96 passing.
- Game boots headless with zero errors; no regression to Phase 1.
