# VOXELBOUND — Technical Notes

Decisions, pitfalls, and measurements. Append dated entries.

## 2026-08-08 — Phase 0/1 setup
- Godot 4.7.1 stable (mono build) at /Applications/Godot_mono.app; project is
  pure GDScript — the mono binary runs GDScript fine.
- Headless verification command:
  `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path ~/dev/voxelbound -s tests/run_tests.gd`
- Renderer: Forward+ (desktop). Chosen over Mobile for shadow/feature headroom;
  revisit if profiling says otherwise (Phase 17).
- Team pipeline: Kimi K3 = architecture/review (inline in Hermes session);
  DeepSeek V4 Flash = implementation via OpenCode CLI
  (`opencode run`, provider omniapi/opencode-go/deepseek-v4-flash);
  Hermes = orchestration + verification.

## 2026-08-08 — Phase 2 (voxel data model)
- **BlockRegistry = static singleton, NOT autoload** (deviation from the
  Phase-0 autoload plan, noted in ARCHITECTURE.md §5.2): autoloads in
  `-s script.gd` headless mode are ambiguous, and a lazy static singleton
  (`BlockRegistry.shared()`) is deterministic for both tests and the game.
  Revisit for Kimi review; migration to autoload is a 1-line change.
- Chunk serialization format frozen at
  `[u8 version][i32 cx][i32 cy][i32 cz][4096 raw bytes]` (version 1). Save
  system (Phase 14) consumes this; generation uses `fill()` which dirties but
  never marks `is_modified` — only `VoxelWorld.set_block()` (gameplay edits)
  marks modified. This is the entire save-diff contract.
- GDScript gotcha: `new` is a reserved keyword — cannot be a parameter name
  (parse error in a lambda here). Renamed to `new_id`.

## 2026-08-08 — Phase 3 (chunk meshing)
- **Godot front-face winding is CLOCKWISE (left-handed convention)** — the
  opposite of the OpenGL right-hand rule. Triangles built with CCW winding
  render inside-out (backface-culled) AND collide one-sided from the back,
  which made the player fall through the terrain. Fix: flip triangle order in
  the mesher. Regression test `mesher winding clockwise` asserts every
  triangle's geometric cross opposes its vertex normal. ALWAYS verify winding
  against physics when adding new procedural geometry.
- **StandardMaterial3D lost `emission_vertex_color` in Godot 4.x** (probe
  confirmed absent in 4.7.1). Emissive blocks now use a small procedural
  shader (`src/world/shaders/emissive.gdshader`) that maps vertex color to
  EMISSION. Shaders are code — zero-asset compliant.
- **ConcavePolygonShape3D.set_faces() requires triangle soup** (count % 3 ==
  0) — quad-indexed meshes crash it. Expand through the index buffer.
- Face quads must be placed at `cell + clamp(face_offset, 0, 1)`: top/+x/+z
  faces at cell+1, bottom/-x/-z at the cell boundary. Building all faces at
  cell_origin collapsed every block's geometry to its bottom corner (rendered
  wrong AND physics ~1 block off) — caught via debug raycast, not by
  vertex-count tests; added `mesher face planes` regression.
- Physics queries in `-s` mode: `intersect_ray` before any `physics_frame`
  await hangs headless; await a frame first.

## 2026-08-08 — Phase 8 (crafting/tools)
- **GDScript: never name a function `is_*` and call it as `Class.is_foo()`**
  — e.g. `ToolRegistry.is_tool()` failed from most call sites with
  "Invalid call ... Expected 0 argument(s)" (parser collision with the `is`
  keyword; even static→static and _initialize contexts broke while identical
  helper classes worked). Symptom was intermittent (nested-argument calls
  appeared to work). Fix: rename to `check_tool()`. Naming rule: avoid `is_`
  prefix on functions accessed via class names.
- Static singleton data: prefer STATIC VAR INITIALIZERS over lazy
  `_ensure()` for pure-data registries (deterministic at class load).

## 2026-08-08 — Phase 10 (caves/ores)
- **FastNoiseLite FBM output range is compressed**: 3-octave fractal noise
  returns roughly ±0.55 (not ±1), 2-octave ±0.5, and values cluster near 0
  (chamber noise p90 was 0.07!). Thresholds calibrated from measured
  percentiles, never guessed: cave abs 0.30 (~8%), chamber 0.25 (~2%),
  shaft 0.30 (~10%), crystal region 0.18, coal 0.22, copper 0.27. When
  tuning procedural noise, ALWAYS probe the distribution first.
- GDScript: `for cy in [1, 2]` yields an untyped loop var — a subsequent
  `var wy := cy * 16 + y` fails type inference; annotate `var wy: int`.

## 2026-08-08 — Phase 11 (day/night/weather)
- **ProceduralSkyMaterial has NO `sun_energy` in Godot 4.7** — the property
  is `energy_multiplier` (scales the whole sky). Assigning `sun_energy`
  throws every frame (silent in filtered logs, but it also aborted the rest
  of `_update`, leaving ambient stuck at its default).
- `Node3D.global_position` on a node NOT inside the tree returns
  Transform3D() identity with an error — not the local position. Add the
  node to the tree (or use `.position`) when testing transforms headless.

## 2026-08-08 — Phase 12 (creatures/AI)
- **`_ = delta` is invalid GDScript** — a bare `_` assignment at statement
  level is a parse error ("Expected statement"). Use an underscore-prefixed
  parameter (`_delta: float`) to silence unused-arg warnings.
- **Nodes added during a synchronous test body are NOT "inside the tree"**
  until a frame passes: `global_position` reads return Transform3D()
  identity with an error. Tests must `await tree.physics_frame` after
  add_child before relying on global transforms, and production code must
  add_child BEFORE setting global_position.

## 2026-08-08 — Phase 13 (combat)
- **Calling a coroutine function WITHOUT `await` silently drops it**: a
  function containing `await` called bare from a suite's run() runs only
  until its first await, then is abandoned — the remaining checks NEVER
  execute and the suite under-reports. ALWAYS `await` check calls in run().
  This hid 24 assertions across daynight/creatures suites.
- GDScript lambda captures are BY VALUE for locals — a lambda mutating an
  outer bool doesn't change it; use a mutable container (e.g. `[false]`).
- `Inventory` has no `set_slot` — use `add_item` (fills slot 0 of an empty
  inventory) and select the resulting slot explicitly.

## 2026-08-08 — Phase 14 (save/load)
- **Typed var assignment of null throws in GDScript**: `var slot: Dictionary =
  data[i]` errors when the value is null — use an untyped `var slot = ...`
  and null-check when serialized arrays may hold empties.
- `Vector3i(3.5, 40.0, 2.5)` truncates to (3, 40, 2) — comparing a float
  position against a Vector3i target fails by ~0.7 units. Keep float
  comparisons in Vector3.
- VoxelChunk.serialize() payload is 1 + 12 + 4096 = 4109 bytes (version +
  coord + blocks) — reading exactly 4096 bytes fails deserialize.

## 2026-08-08 — Phase 15 (procedural audio)
- **AudioStreamGeneratorPlayback.push_buffer takes PackedVector2Array**
  (interleaved STEREO frames), not PackedFloat32Array — mono streams must be
  converted to Vector2(v, v) per frame.
- Unpacking a value from an UNTYPED Dictionary (`var v := entry.samples[i]`)
  fails type inference ("Cannot infer the type") — annotate `var v: float`.
- Always check `get_frames_available()` before push_buffer — pushing more
  than the internal buffer holds silently drops frames.

## 2026-08-08 — Phase 16 (particles)
- **Ternary type inference**: `var x := A if cond else B` where A and B are
  DIFFERENT types infers Variant — this project's warning-as-error settings
  reject it at compile time. Annotate the target type
  (`var mesh: Mesh = QuadMesh.new() if not box else BoxMesh.new()`).
- (Reminder: every coroutine check in a suite's run() must be `await`ed —
  this suite initially shipped two un-awaited checks and silently ran 2 of 4.)

## 2026-08-08 — Phase 17 (greedy meshing)
- Greedy meshing: per direction, build a 16x16 visible-face mask per slice,
  then pack maximal same-id rectangles (extend width, then height while the
  whole row matches AND is uncovered) — one quad per rectangle. Keep the
  winding rule by choosing the index pattern from the sign of
  (u_vec x v_vec).n; a dynamically-chosen pattern passes the existing
  cross-opposes-normal regression test with no special-casing per axis.
- Mesh-data tests that assert per-face vertex counts MUST be updated when
  meshing changes (counts are an implementation detail; merge behavior and
  seam culling are the invariants).

## Pitfalls log

- **Godot 4 coroutine calls**: calling a GDScript function that contains
  `await` WITHOUT `await` at the call site runs it only to its first
  suspension — the remainder may never execute (or races the caller). This
  silently skipped the movement test and broke the runner. Rule: any call to
  a suite/helper that awaits internally MUST be awaited. "Trying to call an
  async function without await" in output = this bug.
- **CapsuleShape3D crouch**: shrinking capsule height without moving the
  CollisionShape3D lifts the bottom off the floor. Always set
  `collision_shape.position.y = height * 0.5` when changing height.
- **DeepSeek/OpenCode verification**: a subagent may report success without
  writing files. Every delegated task prompt must end with an on-disk
  verification step (`ls`), and Hermes must re-check the filesystem before
  accepting a task as done.
- **project.godot case**: Godot on macOS tolerates `Project.godot` but warns
  and breaks case-sensitive exports. Keep it lowercase.
