extends Node
class_name AudioManager
## Plays procedural sounds (Synth recipes) through AudioStreamGenerator
## players — zero audio assets. One-shots are streamed into the generator
## in small chunks (get_frames_available) and freed when drained; the
## ambient wind loops forever until stopped.

var _oneshots: Array = []
var _ambient_player: AudioStreamPlayer
var _ambient_playback: AudioStreamGeneratorPlayback
var _wind: PackedFloat32Array
var _wind_pos: int = 0
var _ambient_active: bool = false


func _ready() -> void:
	_wind = Synth.ambient_wind()


func _process(_delta: float) -> void:
	for entry in _oneshots.duplicate():
		_push(entry)
		if entry.pos >= entry.samples.size():
			_oneshots.erase(entry)
			entry.player.queue_free()
	if _ambient_active and _ambient_playback != null:
		var avail: int = _ambient_playback.get_frames_available()
		var n := mini(avail, 2048)
		var chunk := PackedVector2Array()
		chunk.resize(n)
		for i in n:
			var v := _wind[_wind_pos]
			chunk[i] = Vector2(v, v)
			_wind_pos = (_wind_pos + 1) % _wind.size()
		if n > 0:
			_ambient_playback.push_buffer(chunk)


func _push(entry: Dictionary) -> void:
	var avail: int = entry.playback.get_frames_available()
	if avail <= 0:
		return
	var n := mini(avail, mini(2048, entry.samples.size() - entry.pos))
	var chunk := PackedVector2Array()
	chunk.resize(n)
	for i in n:
		var v: float = entry.samples[entry.pos]  # entry is untyped -> Variant
		chunk[i] = Vector2(v, v)
		entry.pos += 1
	entry.playback.push_buffer(chunk)


# --- gameplay API ---

func footstep() -> void:
	_play(Synth.footstep(), -8.0)

func block_break() -> void:
	_play(Synth.block_break(), -4.0)

func block_place() -> void:
	_play(Synth.block_place(), -6.0)

func jump() -> void:
	_play(Synth.jump(), -8.0)

func player_damage() -> void:
	_play(Synth.player_damage(), -4.0)

func melee_hit() -> void:
	_play(Synth.melee_hit(), -6.0)

func creature_hurt() -> void:
	_play(Synth.creature_hurt(), -6.0)

func pickup() -> void:
	_play(Synth.pickup(), -8.0)

func ui_click() -> void:
	_play(Synth.ui_click(), -10.0)

func start_ambient() -> void:
	if _ambient_active:
		return
	_ambient_active = true
	_make_ambient_player()

func stop_ambient() -> void:
	_ambient_active = false
	if _ambient_player != null:
		_ambient_player.queue_free()
		_ambient_player = null
		_ambient_playback = null


func _make_ambient_player() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = Synth.SAMPLE_RATE
	stream.buffer_length = 0.5
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = stream
	_ambient_player.volume_db = -14.0
	add_child(_ambient_player)
	_ambient_player.play()
	_ambient_playback = _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play(samples: PackedFloat32Array, volume_db: float) -> void:
	if samples.is_empty():
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = Synth.SAMPLE_RATE
	stream.buffer_length = 0.5
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	_oneshots.append({"player": player, "playback": playback, "samples": samples, "pos": 0})
