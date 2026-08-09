# Changelog

All notable changes per phase. Newest first.

## [Phase 18] — 2026-08-08
- **MainMenu** (`src/ui/main_menu.gd`, `scenes/menu.tscn`): procedural title
  screen — VOXELBOUND title, Start Game -> main scene, Quit. Now the boot
  scene (project run/main_scene).
- **PauseMenu** (`src/ui/pause_menu.gd`): ESC pauses the tree (menu runs
  WHEN_PAUSED), Resume, mouse-sensitivity slider persisted through
  `Settings` (user://settings.cfg, ConfigFile), Save & Quit to Menu
  (autosaves first), Quit.
- **DebugOverlay** (`src/ui/debug_overlay.gd`): F3 toggles FPS / position /
  HP / biome / chunk count / day time / weather.
- All three built entirely from Control nodes — zero assets, consistent with
  the whole game.
- Tests: 13 new polish assertions (settings roundtrip, menu buttons/labels,
  pause flow, debug overlay toggle + text). Total: **410/410 passing; boots
  clean. VOXELBOUND 1.0 — all 18 phases complete.**

## [Phase 17] — 2026-08-08
- **Greedy meshing** in `VoxelMesher` (same public API): per face direction,
  16 slices each build a 16x16 visible-face mask, then 2D greedy rectangle
  packing emits ONE quad per maximal same-id run. Terrain triangles drop
  5-20x; a 2x2x2 cube goes 96 -> 24 verts, a 3-block column 56 -> 24.
- Winding preserved: the index pattern is chosen from the sign of
  (u x v).n so triangle crosses always oppose the normal (the Phase 3
  winding regression test passes unchanged).
- Mesher tests updated from per-face counts to greedy-consistent
  expectations (merging + seam culling still verified).
- Total: 397/397 passing; boots clean.

## [Phase 16] — 2026-08-08
- **ParticleFX** (`src/fx/particle_fx.gd`): procedural one-shot particle
  bursts — block debris (cube mesh tinted with the block color), block
  place dust, melee sparks, damage red burst, cyan crystal sparkle (double
  burst on crystal break), landing dust. Auto-free after lifetime via
  SceneTreeTimer.
- **Wired**: mine/place/melee/fall-damage in the player controller; rain +
  snow emitters already exist since Phase 11.
- **Bug found**: a ternary mixing two mesh types (`QuadMesh if … else
  BoxMesh`) infers Variant, which this project treats as a compile error —
  annotate `var mesh: Mesh`. (And the Phase 13 `await`-dropping bug
  reappeared in this suite's last two checks — fixed.)
- Tests: 4 new fx assertions (emitters spawn, auto-free, block tint,
  crystal double burst). Total: 397/397 passing; boots clean.

## [Phase 15] — 2026-08-08
- **Synth** (`src/audio/synth.gd`): pure procedural sample recipes at
  22050 Hz — sine/square/saw/noise with attack/decay envelopes and
  frequency sweeps: footstep, block_break, block_place, jump,
  player_damage, melee_hit, creature_hurt, pickup, ui_click, ambient_wind
  (4 s looping noise bed). Zero audio files.
- **AudioManager** (`src/audio/audio_manager.gd`): AudioStreamGenerator
  one-shots streamed in chunks bounded by get_frames_available() and freed
  when drained; looping ambient wind; volume-trimmed API per sound.
- **Wired into gameplay**: player footsteps/jump/mine/place/damage/melee,
  pickup collection, creature hurt, HUD craft click; ambient wind starts
  with the game.
- **Bug found**: AudioStreamGeneratorPlayback.push_buffer takes stereo
  PackedVector2Array (not mono floats); untyped dict access needs explicit
  `var v: float` (Variant can't infer). TECHNICAL_NOTES updated.
- Tests: 14 new audio assertions (durations, clamping, distinctness,
  one-shot lifecycle, ambient). Total: 393/393 passing; boots clean.

## [Phase 14] — 2026-08-08
- **SaveManager** (`src/save/save_manager.gd`): versioned binary save/load
  (magic "VB1" + version byte, FileAccess). Writes world seed, day time,
  player position/spawn/hp, all 36 inventory slots (id/count/durability)
  and ONLY modified chunks (VoxelChunk.serialize, 4109-byte payloads).
  Corrupt magic / wrong version / missing file all return {} safely.
  apply_load() restores chunks + player state into a live world.
- **F5/F9**: save_game / load_game input actions wired in main.gd
  (user://world_save.vb).
- **Inventory.set_stack()** added (needed by save restore).
- Tests: 20 new save assertions (roundtrip incl. tool durability, diff-only,
  corruption/version/missing rejection, apply to fresh world, has_save).
  Total: 379/379 passing; boots clean.

## [Phase 13] — 2026-08-08
- **Player combat**: melee LMB (tool damage from registry or barehand 1,
  0.5 s cooldown, nearest creature in front within 3 m — interrupts
  mining), take_damage with knockback + damaged signal + respawn on death
  (spawn_point, full HP), fall damage ((speed-14)*2 above 14 m/s), head bob
  (pure bob_offset() + phase accumulator).
- **Creature combat**: hp/damage/drops in the data table, take_damage with
  knockback + died signal, aggressive creatures in contact attack the player
  every 1 s; spawner spawns PickupEntity drops on death.
- **HUD**: health bar + red damage flash.
- **Test-infra bug (important)**: calling a coroutine check function WITHOUT
  `await` in a suite's run() silently DROPS it (GDScript abandons the
  coroutine at its first await) — daynight, creatures and combat suites were
  under-reporting by 7+14+12 checks. All check calls are now awaited;
  per-suite totals verified against the check count. TECHNICAL_NOTES updated.
- Tests: 16 new combat assertions. Total: 359/359 passing; boots clean.

## [Phase 12] — 2026-08-08
- **Creature** (`src/creatures/creature.gd`): 5 data-driven types (Burrower,
  Stoneback, Glow Moth, Nightcrawler, Forest Stalker) with
  speed/vision/flee_range/aggression/height/color/glow; kinematic Node3D
  with terrain-snapped y (no navmesh needed on block terrain); state
  machine IDLE/WANDER/CHASE/FLEE/RETURN; seeded wander; primitive bodies
  (capsule + eyes, emissive moth wings).
- **CreatureSpawner** (`src/creatures/creature_spawner.gd`): biome -> spawn
  pool, 2 s seeded tick, capped population, despawn beyond 64 m.
- **Bugs found**: `_ = delta` is invalid GDScript (use an underscore-prefixed
  param); nodes added during a test's synchronous body are not "inside the
  tree" until a frame passes — global_position reads return identity with an
  error (tests must await a frame; spawner must add_child before setting
  global_position). TECHNICAL_NOTES updated.
- Tests: 16 new creature assertions. Total: 322/322 passing; boots clean.

## [Phase 11] — 2026-08-08
- **DayNight** (`src/environment/day_night.gd`): 0..1 day cycle (10 min),
  sun elevation = pure function of time, moon opposite the sun, sky
  top-color + energy_multiplier + ambient all lerp by night factor.
- **Procedural star field** (`sky_stars.gdshader` on a big sphere, cull
  front, blend add): grid-hashed stars, horizon fade, night-factor driven.
- **Weather** (`src/environment/weather.gd`): seeded clear/rain/snow
  schedule; snow replaces rain in Frostlands/Crystal Highlands; fog density
  per state; rain/snow GPUParticles3D with a generated 1px texture and
  box emission following the player.
- **Bug found**: `ProceduralSkyMaterial` has NO `sun_energy` in Godot 4.7 —
  it's `energy_multiplier`; the wrong property threw every frame at boot
  (also aborted the ambient lerp). TECHNICAL_NOTES updated.
- Tests: 13 new daynight assertions (elevation math, time advance, sun/moon
  opposition, light energies, ambient cycle, weather states + fog, seeded
  determinism, cold-biome snow). Total: 306/306 passing; boots clean.
- **Caves + ores** in `VoxelGenerator._carve_and_ore()`: three 3D-noise
  carving systems — spaghetti tunnels (abs fractal noise), large chambers
  (low-frequency), vertical shafts (y-stretched) — plus deep rare crystal
  caves ("Deep Caverns") that sprinkle CRYSTAL in the carved space, and
  COAL/COPPER ore blobs replacing stone. Carving never touches the top 4
  surface layers. All noise sampled at world coordinates → chunk-border-safe
  by construction.
- **Calibration lesson**: FastNoiseLite FBM compresses output to ~±0.55 (3
  octaves) / ~±0.5 (2 octaves); thresholds tuned from measured percentiles
  (TECHNICAL_NOTES).
- Tests: 7 new cave assertions (carving happens, surface intact, both ores,
  crystal caves, determinism, border strip integrity). Total: 293/293
  passing; boots clean.
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
