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

## Phase 2 — Voxel data model [ ]
BlockRegistry, VoxelChunk (16^3, PackedByteArray), VoxelWorld world-space
get/set, dirty/modified flags, serialization hooks, unit tests.

## Phase 3 — Chunk meshing [ ]
VoxelMesher visible-face culling, opaque/transparent/emissive surfaces,
per-chunk MeshInstance3D + collision, rebuild-on-dirty. Delete test_terrain.

## Phase 4 — Block breaking/placement [ ]
VoxelRaycaster (voxel DDA), LMB mine, RMB place, no placement inside player.

## Phase 5 — Procedural terrain [ ]
VoxelGenerator: seeded height, surface layers, underground strata.

## Phase 6 — Chunk streaming [ ]
ChunkManager: load/unload radii, generation + mesh queues, distance
priority, WorkerThreadPool, per-frame budget.

## Phase 7 — Inventory / hotbar [ ]
36 inventory slots + 9 hotbar, stacking, item IDs, selection, pickup/drop,
hotbar UI + inventory UI (Control nodes only).

## Phase 8 — Crafting / tools [ ]
Data-driven recipes (original, not Minecraft copies), tool definitions:
durability, mining speed, damage, block affinities. Crafting UI.

## Phase 9 — Biomes / trees [ ]
Meadow, Pinewild, Redstone Desert, Frostlands, Crystal Highlands,
Deep Caverns; biome-blended terrain; multiple procedural tree generators.

## Phase 10 — Caves / ores [ ]
3D-noise caves: tunnels, chambers, shafts, rare crystal caves, ore blobs.

## Phase 11 — Day/night / weather [ ]
Sun/moon/stars cycle on the Phase 1 sky rig; rain, snow, fog (procedural).

## Phase 12 — Creatures / AI [ ]
Original creatures (Burrower, Stoneback, Glow Moth, Nightcrawler, Forest
Stalker), primitive-built visuals; AI states: idle/wander/detect/chase/
attack/flee/return.

## Phase 13 — Combat [ ]
Melee, health, damage, knockback, death, drops; player fall damage + head bob.

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
