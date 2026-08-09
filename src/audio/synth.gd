extends RefCounted
class_name Synth
## Pure procedural sound synthesis (zero assets — no audio files). All
## recipes are pure functions returning PackedFloat32Array samples at
## SAMPLE_RATE, so they are unit-testable without any audio device.
## Canonical: ARCHITECTURE.md §9.2 / ROADMAP Phase 15.

const SAMPLE_RATE: int = 22050


## Deterministic noise (seeded locally so sounds are reproducible).
static func _noise(seed_value: int, count: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = rng.randf() * 2.0 - 1.0
	return out


## Sine tone with attack/decay envelope.
static func sine(freq: float, duration: float, volume: float = 0.5) -> PackedFloat32Array:
	return _tone(freq, duration, volume, 0, 0)


static func _tone(freq: float, duration: float, volume: float, wave: int, seed_value: int) -> PackedFloat32Array:
	var count := maxi(1, int(duration * SAMPLE_RATE))
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var t := float(i) / SAMPLE_RATE
		phase += freq / SAMPLE_RATE
		var v := 0.0
		match wave:
			0:
				v = sin(phase * TAU)
			1:
				v = 1.0 if sin(phase * TAU) >= 0.0 else -1.0  # square
			2:
				v = 2.0 * (phase - floor(0.5 + phase))  # saw
			3:
				v = rng.randf() * 2.0 - 1.0  # noise
		# attack 10ms, decay to 0 at the end
		var env := 1.0
		var attack := 0.01
		if t < attack:
			env = t / attack
		env *= 1.0 - float(i) / count
		out[i] = clampf(v * env * volume, -1.0, 1.0)
	return out


# --- recipes (original sounds, GAME_DESIGN.md) ---

static func footstep() -> PackedFloat32Array:
	return _tone(90.0, 0.06, 0.5, 3, 1)  # soft dirt thud

static func block_break() -> PackedFloat32Array:
	var crack := _tone(0.0, 0.12, 0.7, 3, 2)
	var thud := sine(150.0, 0.08, 0.4)
	var out := crack
	out.append_array(thud)
	return out

static func block_place() -> PackedFloat32Array:
	return sine(170.0, 0.08, 0.45)

static func jump() -> PackedFloat32Array:
	var count := int(0.12 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var f := lerpf(200.0, 320.0, t / 0.12)
		phase += f / SAMPLE_RATE
		out[i] = sin(phase * TAU) * (1.0 - float(i) / count) * 0.4
	return out

static func player_damage() -> PackedFloat32Array:
	return _tone(220.0, 0.15, 0.5, 1, 3)  # harsh square sting

static func melee_hit() -> PackedFloat32Array:
	var impact := _tone(0.0, 0.05, 0.6, 3, 4)
	impact.append_array(sine(140.0, 0.1, 0.35))
	return impact

static func creature_hurt() -> PackedFloat32Array:
	var count := int(0.2 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var f := lerpf(90.0, 55.0, t / 0.2)  # falling growl
		phase += f / SAMPLE_RATE
		out[i] = (2.0 * (phase - floor(0.5 + phase))) * (1.0 - float(i) / count) * 0.4
	return out

static func pickup() -> PackedFloat32Array:
	var count := int(0.1 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var f := lerpf(500.0, 800.0, t / 0.1)
		phase += f / SAMPLE_RATE
		out[i] = sin(phase * TAU) * (1.0 - float(i) / count) * 0.3
	return out

static func ui_click() -> PackedFloat32Array:
	return sine(600.0, 0.03, 0.25)

## Looping wind bed (~4 s of slow-envelope noise for ambient use).
static func ambient_wind() -> PackedFloat32Array:
	var count := int(4.0 * SAMPLE_RATE)
	var raw := _noise(5, count)
	var out := PackedFloat32Array()
	out.resize(count)
	var cycle := count / 8.0
	for i in count:
		var env := 0.4 + 0.3 * sin(float(i) / cycle * TAU * 2.0)
		out[i] = clampf(raw[i] * env, -1.0, 1.0)
	return out
