extends RefCounted
class_name BiomeRegistry
## Data-driven surface biomes. Canonical: ARCHITECTURE.md §5.2 / GAME_DESIGN.md.
##
## Biome selection is a Voronoi partition of (temperature, humidity) noise:
## each column's (temp, humid) picks the nearest biome center — deterministic
## and naturally clustered. Blending between biomes at borders is deferred to
## a later optimization pass (noted in TECHNICAL_NOTES).

const MEADOW: int = 0
const PINEWILD: int = 1
const REDSTONE_DESERT: int = 2
const FROSTLANDS: int = 3
const CRYSTAL_HIGHLANDS: int = 4
const BIOME_COUNT: int = 5

## Def keys: name, temp/humid (Voronoi centers 0..1), base/amp (height),
## surface/subsurface (block names), tree ("" | "broadleaf" | "pine"),
## tree_density (0..1 per column), crystals (surface crystal clusters).
const BIOMES: Array[Dictionary] = [
	{"name": "Meadow", "temp": 0.55, "humid": 0.55, "base": 32.0, "amp": 8.0,
		"surface": "GRASS", "subsurface": "DIRT", "tree": "broadleaf",
		"tree_density": 0.018, "crystals": false},
	{"name": "Pinewild", "temp": 0.35, "humid": 0.65, "base": 38.0, "amp": 12.0,
		"surface": "GRASS", "subsurface": "DIRT", "tree": "pine",
		"tree_density": 0.055, "crystals": false},
	{"name": "Redstone Desert", "temp": 0.85, "humid": 0.15, "base": 30.0, "amp": 10.0,
		"surface": "SAND", "subsurface": "SAND", "tree": "",
		"tree_density": 0.0, "crystals": false},
	{"name": "Frostlands", "temp": 0.10, "humid": 0.50, "base": 34.0, "amp": 4.0,
		"surface": "SNOW", "subsurface": "DIRT", "tree": "",
		"tree_density": 0.0, "crystals": false},
	{"name": "Crystal Highlands", "temp": 0.30, "humid": 0.25, "base": 48.0, "amp": 6.0,
		"surface": "STONE", "subsurface": "STONE", "tree": "",
		"tree_density": 0.0, "crystals": true},
]


## Nearest-center Voronoi in (temp, humid) space.
static func biome_by_temp_humid(temp: float, humid: float) -> int:
	var best := 0
	var best_dist := INF
	for i in BIOMES.size():
		var dt := temp - float(BIOMES[i].temp)
		var dh := humid - float(BIOMES[i].humid)
		var d := dt * dt + dh * dh
		if d < best_dist:
			best_dist = d
			best = i
	return best


static func display_name(biome: int) -> String:
	if biome < 0 or biome >= BIOMES.size():
		return "Unknown"
	return str(BIOMES[biome].name)
