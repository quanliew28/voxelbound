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
