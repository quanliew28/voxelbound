# VOXELBOUND — Roadmap

Status legend: [ ] not started · [~] in progress · [x] done (tested)

## Phase 0 — Repository & architecture [x]
- Repo initialized at ~/dev/voxelbound, Godot 4.7.1 confirmed
- Canonical architecture written (docs/ARCHITECTURE.md)

## Phase 1 — Godot foundation + first-person controller [x]
Deliverables: Godot project, first-person controller (WASD, mouse look,
gravity, jump, crouch, sprint, collision), procedural test terrain,
procedural lighting + sky, headless smoke test passing.
DONE 2026-08-08: 11/11 smoke assertions pass; game boots 120 frames clean.
Review fixes: coroutine awaits in test runner, crouch capsule recentering,
Project.godot -> project.godot case fix.

## Phase 2 — Voxel data model [x]
BlockRegistry, VoxelChunk (16^3, PackedByteArray), VoxelWorld world-space
get/set, dirty/modified flags, serialization hooks, unit tests.
DONE 2026-08-08: 85 voxel assertions + 11 smoke = 96/96; game boots clean.
BlockRegistry is a static singleton (BlockRegistry.shared()) — deviation from
the autoload plan, documented in TECHNICAL_NOTES. VoxelWorld.set_block is the
gameplay mutation API (marks modified); generation fills chunks directly.

## Phase 3 — Chunk meshing [x]
VoxelMesher visible-face culling, opaque/transparent/emissive surfaces,
per-chunk MeshInstance3D + collision, rebuild-on-dirty. Delete test_terrain.
DONE 2026-08-08: 142/142 assertions (44 mesher), game boots clean, player
walks on and collides with real voxel terrain. Mesher: face-planes + clockwise
winding regression tests. Chunk node ownership stays in VoxelWorld until
ChunkManager (Phase 6).

## Phase 4 — Block breaking/placement [x]
VoxelRaycaster (voxel DDA), LMB mine, RMB place, no placement inside player.
DONE 2026-08-08: 157/157 assertions (15 raycaster), boots clean. DDA skips
the origin cell; hit normals point back along the ray; placement guarded by
capsule-vs-cell overlap test.

## Phase 5 — Procedural terrain [x]
VoxelGenerator: seeded height, surface layers, underground strata.
DONE 2026-08-08: 178/178 assertions (21 generator). Seed-deterministic
FastNoiseLite terrain (base 32, hills ±14), GRASS/SAND-DIRT-STONE layering,
flattened spawn radius, chunk-boundary continuity. VoxelTestTerrain deleted;
main.gd now generates the world from a seed.

## Phase 6 — Chunk streaming [x]
ChunkManager: load/unload radii, generation + mesh queues, distance
priority, WorkerThreadPool, per-frame budget.
DONE 2026-08-08: 190/190 assertions (12 streaming), boots clean. ChunkManager
owns streaming (Chebyshev xz radii, vertical columns, budgeted threaded
generation with per-task generators, call_deferred results, periodic unload);
meshing stays in VoxelWorld. Spawn area pre-filled synchronously.

## Phase 7 — Inventory / hotbar [x]
36 inventory slots + 9 hotbar, stacking, item IDs, selection, pickup/drop,
hotbar UI + inventory UI (Control nodes only).
DONE 2026-08-08: 210/210 assertions (20 inventory), boots clean. ItemStack +
Inventory (64 stacks, overflow semantics), mining drops into inventory,
placement consumes selected hotbar item, Q drops to PickupEntity (Area3D,
primitive mesh, walk-over collection), HUD (crosshair, hotbar, E inventory
screen) built from Control nodes, hotbar keys 1-9.

## Phase 8 — Crafting / tools [x]
Data-driven recipes (original, not Minecraft copies), tool definitions:
durability, mining speed, damage, block affinities. Crafting UI.
DONE 2026-08-08: 256/256 assertions (46 crafting), boots clean. ToolRegistry
(6 original tools: 3 picks + 3 axes with speed/durability/affinity),
CraftingRegistry (6 original recipes, consume/refund semantics), hold-to-mine
with affinity speed + durability drain + tool break, HUD crafting panel.
Static singleton data via static var initializers; `is_tool` renamed
`check_tool` (GDScript `is`-keyword parse collision — TECHNICAL_NOTES).

## Phase 9 — Biomes / trees [x]
Meadow, Pinewild, Redstone Desert, Frostlands, Crystal Highlands,
Deep Caverns; biome-blended terrain; multiple procedural tree generators.
DONE 2026-08-08: 286/286 assertions (33 biomes), boots clean. BiomeRegistry
(5 surface biomes, Voronoi over widened temp/humid noise), per-biome
height/surface/subsurface, TreeGenerator (broadleaf + pine, deterministic
column hash, 5x5 lone-tree spacing for border-safe idempotency), surface
crystal clusters in highlands, spawn protected (meadow plateau, no trees).
(Deep Caverns underground biome arrives with Phase 10 caves.)

## Phase 10 — Caves / ores [x]
3D-noise caves: tunnels, chambers, shafts, rare crystal caves, ore blobs.
DONE 2026-08-08: 293/293 assertions (7 caves), boots clean. _carve_and_ore:
fractal tunnels (abs>0.30), chambers (>0.25), y-stretched shafts (>0.30),
deep crystal-cave pockets with sparse CRYSTAL, COAL (>0.22, below h-4) and
COPPER (>0.27, below h-14) blobs; surface 4 layers never carved; thresholds
calibrated to measured FBM ranges (see TECHNICAL_NOTES). World-coord noise
=> border-safe by construction.

## Phase 11 — Day/night / weather [x]
Sun/moon/stars cycle on the Phase 1 sky rig; rain, snow, fog (procedural).
DONE 2026-08-08: 306/306 assertions (13 daynight), boots clean. DayNight:
10-min cycle, sun+moon opposite directional lights, sky top-color +
energy_multiplier + ambient lerp, shader-drawn star sphere (zero assets).
Weather: seeded clear/rain/snow schedule, snow in cold biomes, fog density
per state, GPUParticles3D rain/snow with generated 1px texture.

## Phase 12 — Creatures / AI [x]
Original creatures (Burrower, Stoneback, Glow Moth, Nightcrawler, Forest
Stalker), primitive-built visuals; AI states: idle/wander/detect/chase/
attack/flee/return.
DONE 2026-08-08: 322/322 assertions (16 creatures), boots clean. Creature
(data-driven types, kinematic Node3D, terrain-snapped, seeded wander),
CreatureSpawner (biome pools, capped, despawn far).

## Phase 13 — Combat [x]
Melee, health, damage, knockback, death, drops; player fall damage + head bob.
DONE 2026-08-08: 359/359 assertions (16 combat), boots clean. Player
melee (tool damage or barehand, 0.5s cooldown, creature-in-front targeting),
take_damage + knockback + respawn, fall damage (>14 m/s), head bob.
Creature: hp/damage/drops data, take_damage + died signal, contact attacks
(1s cooldown), spawner drops. NOTE: recovered 24 silently-dropped async
assertions in daynight/creatures suites (missing `await` on coroutine checks
— TECHNICAL_NOTES).

## Phase 14 — Save/load [ ]
Seed + time + player + inventory + modified-chunk diffs only (ARCHITECTURE.md §10).

## Phase 15 — Procedural audio [ ]
AudioStreamGenerator synthesis: footsteps, break/place, jump, damage, combat,
creatures, UI, ambience. No audio files.

## Phase 16 — Particles / effects [ ]
GPUParticles3D with procedural materials: block debris, dust, rain, snow,
sparks, crystal, damage.

## Phase 17 — Optimization [ ]
Greedy meshing, allocation audit, profile-guided fixes only.

## Phase 18 — Polish [ ]
Menus, settings, debug overlay, juice, final pass.
