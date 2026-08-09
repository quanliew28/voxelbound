# VOXELBOUND

An original voxel sandbox game built in **Godot 4.7 + GDScript** — procedurally
generated terrain, mining, building, crafting, biomes, creatures, and more.

**The twist: the repository contains zero assets.** No textures, no models, no
audio files, no fonts. Every mesh, material, sound, and UI element is generated
at runtime from code.

```
No .png · No .jpg · No .svg · No .fbx · No .obj · No .gltf · No .wav · No .ogg
```

## Status

**VOXELBOUND 1.0 — all 18 phases complete (2026-08-08).** Fully playable
procedural voxel sandbox: seeded biomes + trees, 3D-noise caves and ores,
day/night + weather, creatures with AI, combat, inventory/crafting/tools,
save/load (F5/F9), procedural audio, particles, greedy meshing, main menu,
pause menu (ESC), debug overlay (F3). **410/410 headless assertions pass;
zero external assets.** See [docs/ROADMAP.md](docs/ROADMAP.md) for the phase
log and [docs/TECHNICAL_NOTES.md](docs/TECHNICAL_NOTES.md) for pitfalls.

What works today:

- First-person controller: mouse look, WASD, sprint, crouch (with headroom
  check), jump, gravity, smooth acceleration
- Procedural test terrain (FastNoiseLite heightmap, vertex-colored, full
  collision)
- Procedural sky, sun, and lighting — built entirely in code
- Headless test harness (11 assertions, zero-asset guard included)

Planned: chunk-based voxel engine (16³ chunks, visible-face culling, greedy
meshing), block breaking/placement, seeded world generation, biomes, caves,
ores, crafting, tools, creatures with AI, combat, day/night + weather,
procedural audio, save/load, and chunk streaming.

## Requirements

- [Godot 4.7+](https://godotengine.org/download) (standard or .NET build —
  the project is pure GDScript, no C#)

## Run

1. Clone this repository
2. Open `project.godot` in Godot
3. Press **F5**

## Controls

| Input | Action |
|-------|--------|
| Mouse | Look |
| `W A S D` | Move |
| `Shift` | Sprint |
| `Space` | Jump |
| `C` / `Ctrl` | Crouch |
| `Esc` | Release mouse (click to re-capture) |

## Tests

Headless test suite (no window required):

```bash
godot --headless --path . -s tests/run_tests.gd
```

Exit code 0 = all assertions pass. The suite boots the real game scene,
verifies player physics (gravity, movement), terrain, collision, environment,
and enforces the zero-asset rule.

## Architecture

Canonical design lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) —
chunk storage format, block registry, mesher, streaming, save format, and
performance rules are all specified there before any code is written.

| Doc | Contents |
|-----|----------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Canonical technical design |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 18-phase development plan + status |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | Blocks, biomes, creatures, tools |
| [docs/TECHNICAL_NOTES.md](docs/TECHNICAL_NOTES.md) | Decisions, pitfalls, measurements |
| [docs/TESTING.md](docs/TESTING.md) | Test harness conventions |
| [CHANGELOG.md](CHANGELOG.md) | Per-phase changelog |

## Development

Built with a multi-agent workflow: a lead architect model designs each system
(canonical architecture doc first), an implementation model writes the code in
small scoped tasks, and an orchestrator verifies everything by actually running
the game and the test suite before each phase is called done.

## License

[MIT](LICENSE)
