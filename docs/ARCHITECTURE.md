# VOXELBOUND — Architecture

Status: CANONICAL. All agents (Hermes, Kimi K3, DeepSeek) must conform to this
document. Changes to architecture are made by editing THIS FILE FIRST, then code.

## 1. Vision & Hard Constraints

VOXELBOUND is an original voxel sandbox game (broad genre: Minecraft-like) built
in Godot 4.7 + GDScript for desktop.

**ZERO-ASSET RULE (absolute):** the repository contains NO binary or external
assets — no PNG/JPG/SVG, no FBX/OBJ/GLTF, no textures, no audio files, no fonts,
no asset packs. Everything is generated at runtime from code: meshes via
ArrayMesh/SurfaceTool and primitives, materials via code-built StandardMaterial3D/
ShaderMaterial, sky via ProceduralSkyMaterial, audio via AudioStreamGenerator,
UI via Control nodes. `.gd`, `.tscn`, `.tres` (text), `.cfg`, `.md` files are
allowed. The repo must stay asset-free — verify with:

    find . -type f ! -name "*.gd" ! -name "*.tscn" ! -name "*.tres" \
      ! -name "*.md" ! -name "*.cfg" ! -name "project.godot" \
      ! -name "*.json" ! -name ".git*" ! -path "./.git/*" ! -name "*.import"

(`.godot/` is engine cache and gitignored.)

## 2. Technology

- Engine: Godot 4.7.1 (mono build present, but project is PURE GDScript — no C#)
- Renderer: Forward+ (desktop)
- Language: GDScript, static typing everywhere (`var x: int`, `-> void`)
- Target: 60 FPS on a mid-range desktop

## 3. Repository Layout

```
voxelbound/
  project.godot
  CHANGELOG.md
  docs/
    ARCHITECTURE.md      <- this file (canonical)
    ROADMAP.md           <- phase plan + current status
    GAME_DESIGN.md       <- blocks, biomes, creatures, recipes, tools
    TECHNICAL_NOTES.md   <- pitfalls, decisions, measurements
    TESTING.md           <- how to run tests
  scenes/
    main.tscn            <- boot scene (Node3D + src/main.gd)
    player.tscn          <- CharacterBody3D rig
  src/
    main.gd              <- composition root: builds world, env, spawns player
    player/
      player_controller.gd
    world/
      block_registry.gd      (Phase 2)
      voxel_chunk.gd         (Phase 2)
      voxel_world.gd         (Phase 2)
      voxel_generator.gd     (Phase 5)
      voxel_mesher.gd        (Phase 3)
      chunk_manager.gd       (Phase 6)
      voxel_raycaster.gd     (Phase 4)
      test_terrain.gd        (Phase 1 ONLY - deleted after Phase 3)
    ui/     (Phase 7+)
    audio/  (Phase 15)
    fx/     (Phase 16)
  tests/
    run_tests.gd         <- headless test runner entry
    test_*.gd            <- one file per suite
```

## 4. Composition Root & Scene Tree

`main.tscn` is the ONLY entry scene. It contains a bare `Node3D` with
`src/main.gd`. main.gd is the composition root: it constructs the environment
(sky, sun, fog), the terrain/world, and instantiates `player.tscn`. No
autoloads in Phase 1. Planned autoloads (added only when their phase lands):

- `BlockRegistry` (Phase 2) — pure data, no node dependencies
- `SaveManager` (Phase 14)
- `AudioSynth` (Phase 15)

Keep autoload count minimal; prefer explicit references passed down from main.gd.

## 5. Voxel Engine Design (canonical, built Phases 2–6)

One canonical design. No agent may substitute its own.

### 5.1 Coordinate system & storage

- Chunk size: `CHUNK_SIZE = 16` (x,y,z). Constant lives in `VoxelChunk`.
- Y is up. World is chunked on all three axes (not column-based), enabling
  caves/overhangs without special cases. Streaming (Phase 6) loads a 3D
  neighbourhood around the player.
- Block storage per chunk: `PackedByteArray` of length 16^3 = 4096.
  Block id 0 = AIR, always. Max 255 block types; if we ever exceed that we
  migrate to PackedInt32Array behind the same get/set API (noted, not built).
- Index math (the ONLY valid mapping):
  `index = x + z * 16 + y * 256`
  (x varies fastest, then z, then y — the per-chunk block buffer is ordered by
  this formula and NOTHING else may index it.)
- Chunk coordinate of world position p: `floor(p / 16)` per axis, using
  floor division (GDScript `floori(p / 16.0)`) so negatives behave.
- Local coordinate: `p - chunk_coord * 16` (always 0..15).

### 5.2 Core classes

- **BlockRegistry** (RefCounted data, reached via `BlockRegistry.shared()` —
  NOT an autoload; see TECHNICAL_NOTES §2026-08-08): maps `StringName -> int` and
  back; holds per-block definition dictionaries: display name, opaque/transparent,
  emissive, hardness, tool affinity, color(s) for procedural materials,
  drops. All block IDs come from here — numeric IDs NEVER appear scattered in
  gameplay code.
- **VoxelChunk** (RefCounted): pure data. `get_block(local)`, `set_block(local,
  id)`, bounds-checked; `is_dirty` flag for mesh rebuild; `is_modified` flag for
  save system (touched-by-player chunks only); serialization hooks
  (`serialize() -> PackedByteArray`, `deserialize(bytes)`). Holds NO nodes.
- **VoxelWorld** (Node3D): owns `Dictionary[Vector3i, VoxelChunk]`, block
  get/set in WORLD coordinates (translates to chunk+local), emits
  `block_changed(world_pos)`; routes mesh rebuild requests to ChunkManager.
- **VoxelGenerator** (RefCounted): seed-deterministic; pure function
  `generate(chunk_coord) -> VoxelChunk`. FastNoiseLite only. No engine state,
  no RNG globals — all noise instances derive from the world seed. Pipeline
  (Phase 5+): continentalness -> height -> biome blend -> surface layers ->
  caves (3D noise) -> ores (blob noise) -> trees/structures (deterministic
  per-chunk hash, border-safe via chunk-neighbour margin).
- **VoxelMesher** (RefCounted): pure function `build_mesh(chunk, world) ->
  MeshData`. Phase 3: visible-face culling (skip faces adjacent to opaque
  blocks). Later: greedy meshing behind the same API. Always produces up to
  three surfaces: opaque, transparent, emissive — separate materials.
- **ChunkManager** (Node3D, child of VoxelWorld): owns one
  `MeshInstance3D + StaticBody3D + ConcavePolygonShape3D` per ACTIVE chunk
  (nodes per chunk, NEVER per block). Load radius / unload radius in chunks,
  generation queue + mesh queue, priority = distance to player, N chunks
  processed per frame; heavy generation dispatched to a WorkerThreadPool.
- **VoxelRaycaster** (RefCounted): Amanatides & Woo voxel DDA over world data.
  Returns `{hit, chunk_coord, block_pos, prev_pos, normal, distance}`.
  `prev_pos` is the placement cell.

### 5.3 Mesh rebuild rule

A chunk mesh is rebuilt only when: it finishes generating, or a block inside it
changes, or a block on its border changes in a neighbour (rebuild the owning
chunk AND the bordering neighbour). Rebuilds go through ChunkManager's queue —
never immediate, never more than one queued rebuild per chunk per frame.

## 6. Player (Phase 1, canonical)

`player.tscn`: CharacterBody3D ("Player")
- CollisionShape3D: CapsuleShape3D, height 1.8, radius 0.35 (standing)
- Head (Node3D) at y=1.62, crouches to y=0.9
  - Camera3D (fov 75)

`player_controller.gd`:
- Mouse look: yaw on body, pitch on Head, clamped ±89°. Mouse captured on
  click, ESC releases (Phase 1; a pause menu owns this later).
- WASD relative to yaw. Walk 4.5 m/s, sprint 7.0, crouch 2.0.
- Gravity 22.0, jump velocity 7.5. `move_and_slide()`, floor snap.
- Crouch shrinks capsule height to 1.0 (with headroom check on stand).
- Input actions (defined in project.godot, no defaults reliance):
  `move_forward/back/left/right` (WASD), `jump` (Space), `sprint` (Shift),
  `crouch` (C or Ctrl), `interact_primary` (LMB), `interact_secondary` (RMB).

Fall damage, head bob: Phase 13/polish, NOT Phase 1.

## 7. Procedural Test Terrain (Phase 1 ONLY)

`src/world/test_terrain.gd`: builds ONE 128×128 m heightmap plane (64×64 quads)
from FastNoiseLite as an ArrayMesh with per-vertex colors via code-built
material, plus a `HeightMapShape3D`-equivalent collision (a
ConcavePolygonShape3D from the same mesh is acceptable at this size). This is a
THROWAWAY stand-in so the controller can be tuned; it is deleted when Phase 3
voxel meshing lands. It is not the voxel engine and must not grow features.

## 8. Environment (Phase 1)

- Sky: `Sky` + `ProceduralSkyMaterial` (built-in, procedural — allowed).
- Sun: one `DirectionalLight3D`, shadow-enabled.
- `WorldEnvironment` with the sky + ambient light from sky, tonemap ACES.
- Day/night cycle (Phase 11) will animate these same nodes — main.gd should
  expose them as named children (`%Sun`, `%WorldEnvironment`).

## 9. Data-Driven Rules

Blocks, recipes, tools, creatures, biomes are DATA (dictionaries/typed resources
in registry scripts), never hardcoded in gameplay logic. GAME_DESIGN.md is the
content authority; the registries must match it.

## 10. Save System (Phase 14, design-fixed now)

Save = world seed + world time + player state + inventory + DIFFS of
player-modified chunks only (VoxelChunk.is_modified). Untouched procedural
terrain is never serialized. Format: binary via FileAccess.store_var or a
versioned header + compressed chunk diffs; version byte first, always.

## 11. Performance Rules

- Never one node per block. Nodes only per chunk mesh, per creature, per UI.
- No per-frame allocations in hot loops (reuse arrays/SurfaceTool).
- Mesh/generation work bounded per frame; heavy work on WorkerThreadPool.
- Optimize only with measurements (record in TECHNICAL_NOTES.md).

## 12. Testing

Headless runner: `godot --headless --path . -s tests/run_tests.gd`.
Each suite is `tests/test_*.gd` with `run() -> int` returning failure count.
Phase 1 smoke test: boot main scene headless for N frames, assert player node
exists, no script errors, controller moves player origin when input is
simulated. CI-style gate: tests must pass before a phase is called done.

## 13. Agent Workflow (binding)

1. Kimi designs / updates THIS FILE for the phase.
2. Hermes decomposes into small DeepSeek tasks (one file/system each).
3. DeepSeek implements ONLY what the task says, nothing more.
4. Hermes runs the game + tests, fixes or bounces back failures.
5. Kimi reviews cross-system/voxel/perf/save changes.
6. Hermes updates ROADMAP + CHANGELOG, commits.
