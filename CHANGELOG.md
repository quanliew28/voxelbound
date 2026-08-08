# Changelog

All notable changes per phase. Newest first.

## [Phase 9] — 2026-08-08
- **BiomeRegistry** (`src/world/biome_registry.gd`): 5 data-driven surface
  biomes (Meadow, Pinewild, Redstone Desert, Frostlands, Crystal Highlands)
  selected by Voronoi over widened temperature/humidity noise; per-biome
  height, surface + subsurface blocks, tree type/density, crystal flag.
- **VoxelGenerator biome pipeline**: biome height + layers replace the fixed
  height model; SNOW block added; spawn area stays a flat Meadow plateau.
- **TreeGenerator** (`src/world/tree_generator.gd`): broadleaf + pine shapes
  from column hashes; 5x5 lone-tree spacing rule makes chunk-border trees
  deterministic and order-independent (no trunk/canopy conflicts); trees
  root only in grass.
- **Crystal Highlands** surface crystal clusters (emissive).
- **ChunkManager fix**: generation workers now capture the world seed at
  dispatch (no world access on worker threads) and guard call_deferred
  against shutdown-time free — boot is warning-free.
- Tests: 33 new biome assertions (data validity, determinism, all 5 biomes
  reachable, per-biome layers, spawn safety, tree presence/structure, border
  consistency). Total: 286/286 passing; boots clean.
- **ToolRegistry** (`src/items/tool_registry.gd`): 6 original tools
  (Crude/Copper/Crystal Pick + Axe), data-driven speed/damage/durability/
  affinity, tool ids above the block space (100+), tools never stack.
  Static data built via static var initializers.
- **CraftingRegistry** (`src/items/crafting.gd`): 6 original recipes
  (ingredients: WOOD + STONE/COPPER/CRYSTAL), can_craft/craft with
  consume-and-refund semantics, crafted tools start at full durability.
- **Hold-to-mine** in PlayerController: LMB held accumulates progress
  (hardness seconds), tool affinity speeds mining (wrong tool = 0.5x),
  durability drains per block, tools break and leave the slot.
- **HUD crafting panel**: one button per recipe, disabled when ingredients
  are missing, crafts on click.
- **Bug found**: `ToolRegistry.is_tool()` failed with "Expected 0
  argument(s)" from most call sites — a GDScript parser collision with the
  `is` keyword (name starts with `is_`). Renamed to `check_tool()`; see
  TECHNICAL_NOTES.
- Tests: 26 new crafting assertions (registry data, recipe resolution,
  craft consume/refund, tool durability set, no tool stacking, mine speeds
  incl. wrong-affinity penalty, durability break + drops). Total: 256/256
  passing; boots clean.
- **ItemStack + Inventory** (`src/items/`): 36 slots (0..8 hotbar), stacking
  at 64, add/remove/remove_from_slot/count/find/has_item, overflow returns
  remainder, `changed` signal for UI.
- **Player integration**: mining adds registry drops to inventory (GRASS ->
  DIRT etc.), placement consumes the selected hotbar item, Q drops one unit
  as a **PickupEntity** (Area3D + primitive box + walk-over collection,
  despawns after 60s), hotbar keys 1-9 select, E toggles inventory screen.
- **HUD** (`src/ui/hud.gd`): crosshair, hotbar with selection highlight,
  full inventory grid — all from Control nodes, label updates only on
  change. New input actions: hotbar_1..9, drop (Q), inventory (E).
- Tests: 20 new inventory assertions (stacking/overflow, removal, counts,
  mine-drops, place-consumes, drop+pickup round trip). Total: 210/210
  passing; boots clean.
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
