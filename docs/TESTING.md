# VOXELBOUND — Testing

## How to run

```
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless \
  --path ~/dev/voxelbound -s tests/run_tests.gd
```

Exit code 0 = all suites pass; non-zero = failures. The runner prints one
line per assertion (`PASS`/`FAIL name — detail`) and a summary.

## Conventions

- One suite per file: `tests/test_<area>.gd`
- Each suite extends `RefCounted` and implements `run() -> int`
  (returns number of failed assertions).
- `tests/run_tests.gd` extends `SceneTree`, discovers/instantiates suites,
  aggregates failures, prints summary, `quit(failures)`.
- No engine window required; suites must run headless.
- Never test by parsing stdout of the game; test real state.

## Current suites

- `test_smoke.gd` (Phase 1): boots main scene in the tree, steps frames,
  asserts the player exists, gravity acts (y decreases when airborne),
  simulated forward input increases displacement, terrain + collision body
  exist. Also asserts the repo has no binary assets (zero-asset guard).

## Gate

A phase is only "done" when: tests pass, game boots without errors, docs
updated, CHANGELOG entry written.
