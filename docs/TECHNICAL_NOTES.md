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
