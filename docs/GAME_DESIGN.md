# VOXELBOUND — Game Design

Content authority. Registries in code must match this file. All names,
recipes, and creatures are ORIGINAL — do not copy Minecraft content.

## Blocks (initial set)

| ID name  | Properties |
|----------|-----------|
| AIR      | id 0, non-solid |
| GRASS    | surface, opaque |
| DIRT     | subsurface, opaque |
| STONE    | underground, opaque |
| SAND     | desert surface, opaque, falls (later) |
| WOOD     | tree trunks, opaque |
| LEAF     | transparent-ish, non-tool |
| COAL     | ore in stone, opaque |
| COPPER   | ore in stone, opaque |
| CRYSTAL  | rare, emissive, glows |

(Block IDs are assigned by BlockRegistry at runtime; AIR is always 0.)

## Biomes (original)

1. **Meadow** — gentle rolling green hills, scattered broadleaf trees.
2. **Pinewild** — cold conifer forest, taller terrain, dense pines.
3. **Redstone Desert** — red sand and rock mesas, sparse dry scrub.
4. **Frostlands** — snow-covered flats and ice spikes, low light warmth.
5. **Crystal Highlands** — high altitude, exposed crystal clusters, emissive.
6. **Deep Caverns** — underground biome: huge chambers, glow flora, crystal.

## Creatures (original)

- **Burrower** — small skittish digger, flees when approached, drops hide.
- **Stoneback** — slow armored grazer, neutral, charges if hurt.
- **Glow Moth** — flying ambient light source at night, harmless.
- **Nightcrawler** — nocturnal hostile, hunts in darkness, fears light.
- **Forest Stalker** — rare ambush predator in Pinewild.

Visuals: assembled from Godot primitives (boxes/spheres/capsules) with
procedural materials. No models.

## Tools (original)

- **Crude Pick / Flint Pick / Copper Pick / Crystal Pick** — mining tiers.
- **Crude Hatchet / ...** — wood tier line.
- Tools have: durability, mining speed multiplier, damage, block affinities.

## Crafting (data-driven, original recipes)

Exact recipe table defined in Phase 8 and recorded here before implementation.
No Minecraft recipe copies.

## Audio direction

All synthesized: filtered noise for impacts, sine/noise blips for UI,
pitched drone beds for ambience. (Phase 15.)
