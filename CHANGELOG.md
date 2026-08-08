# Changelog

All notable changes per phase. Newest first.

## [Phase 1] — 2026-08-08
- Repository initialized; canonical docs set (ARCHITECTURE / ROADMAP /
  GAME_DESIGN / TECHNICAL_NOTES / TESTING).
- Godot 4.7 project scaffold: Forward+, 1280x720, full input map
  (move/jump/sprint/crouch/interact actions).
- First-person controller (`src/player/player_controller.gd`): mouse look
  (yaw body / pitch head, ±89°), WASD, walk 4.5 / sprint 7.0 / crouch 2.0,
  gravity 22, jump 7.5, smooth acceleration, crouch with headroom check and
  grounded capsule recentering, ESC/click mouse capture toggle,
  `simulate_for_test()` hook for headless tests.
- Procedural test terrain (`src/world/test_terrain.gd`, TEMPORARY until
  Phase 3): 128x128m FastNoiseLite heightmap, analytic normals, vertex-color
  gradient material, concave collision, `get_height_at()` for spawning.
- Environment (`src/main.gd` composition root): ProceduralSkyMaterial sky,
  shadowed directional sun, ACES tonemap, sky ambient — all code-built.
- Headless test harness (`tests/run_tests.gd` + `tests/test_smoke.gd`):
  11 assertions (boot, player, gravity, movement, terrain, collision,
  environment, zero-asset guard) — all passing.
- Game boots headless 120 frames with zero errors.
