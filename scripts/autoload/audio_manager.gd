extends Node
## Música com crossfade, ambiência em loop e efeitos sonoros com variação.
## Os arquivos são gerados por tools/audio (síntese em Python).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DB := -4.0
const AMBIENCE_DB := -8.0
const SILENT_DB := -60.0

var _music: Array[AudioStreamPlayer] = []
var _music_i := 0
var _current_music := ""
var _ambience: AudioStreamPlayer
var _current_ambience := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _loops: Dictionary = {}
var _cache: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	_ambience.volume_db = SILENT_DB
	add_child(_ambience)
	for i in 12:
		var s := AudioStreamPlayer.new()
		s.bus = &"SFX"
		add_child(s)
		_pool.append(s)
	_apply_music_mute()


func _exit_tree() -> void:
	# Para tudo e solta os streams, para o Godot não reclamar de recursos vivos ao fechar.
	for p in _music + _pool + [_ambience]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in _loops.values():
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_loops.clear()
	_cache.clear()
	_tweens.clear()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")
	var sfx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx, -2.0)
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.72
		rev.damping = 0.55
		rev.spread = 0.9
		rev.wet = 0.16
		rev.dry = 1.0
		AudioServer.add_bus_effect(sfx, rev)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.8
		AudioServer.add_bus_effect(master, lim)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	_cache[path] = stream
	return stream


# ---------------------------------------------------------------------------
# Música e ambiência
# ---------------------------------------------------------------------------

func play_music(track: String, fade := 2.0) -> void:
	if track == _current_music:
		return
	_current_music = track
	var stream := _load(MUSIC_DIR + track + ".ogg")
	var old := _music[_music_i]
	_music_i = 1 - _music_i
	var nxt := _music[_music_i]
	_fade(old, SILENT_DB, fade, true)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	nxt.stream = stream
	nxt.volume_db = SILENT_DB
	nxt.play()
	_fade(nxt, MUSIC_DB, fade, false)


func stop_music(fade := 2.0) -> void:
	_current_music = ""
	for m in _music:
		_fade(m, SILENT_DB, fade, true)


func current_music() -> String:
	return _current_music


func play_ambience(track: String, fade := 3.0) -> void:
	if track == _current_ambience:
		return
	_current_ambience = track
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience.stream = stream
	_ambience.volume_db = SILENT_DB
	_ambience.play()
	_fade(_ambience, AMBIENCE_DB, fade, false)


func toggle_music() -> bool:
	Game.music_on = not Game.music_on
	Game.save_settings()
	_apply_music_mute()
	return Game.music_on


func _apply_music_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Game.music_on)


func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	if _tweens.has(p) and _tweens[p] != null and (_tweens[p] as Tween).is_valid():
		(_tweens[p] as Tween).kill()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "volume_db", to_db, maxf(time, 0.01)).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[p] = tw


# ---------------------------------------------------------------------------
# Efeitos
# ---------------------------------------------------------------------------

## Toca um efeito. `variants` > 1 sorteia entre nome_1, nome_2...
func play_sfx(sfx: String, volume_db := 0.0, pitch_jitter := 0.04, variants := 1) -> void:
	var file := sfx
	if variants > 1:
		file = "%s_%d" % [sfx, randi_range(1, variants)]
	var stream := _load(SFX_DIR + file + ".wav")
	if stream == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Liga/desliga um efeito em loop (ex.: deslizar na parede).
func loop_sfx(sfx: String, on: bool, volume_db := -6.0) -> void:
	if on:
		if _loops.has(sfx):
			return
		var stream := _load(SFX_DIR + sfx + ".wav")
		if stream == null:
			return
		if stream is AudioStreamWAV:
			var w := stream as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.stream = stream
		p.volume_db = volume_db
		add_child(p)
		p.play()
		_loops[sfx] = p
	elif _loops.has(sfx):
		var p: AudioStreamPlayer = _loops[sfx]
		_loops.erase(sfx)
		var tw := create_tween()
		tw.tween_property(p, "volume_db", SILENT_DB, 0.12)
		tw.tween_callback(p.queue_free)
