extends Node
## Estado global: configurações, depuração e hit-stop.

const SETTINGS_PATH := "user://configuracoes.cfg"

var debug := false
var music_on := true
var _hitstop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = bool(cfg.get_value("audio", "musica", true))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "musica", music_on)
	cfg.save(SETTINGS_PATH)


## Congela o jogo por alguns milissegundos para dar peso a um impacto.
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = 0.0
	await get_tree().create_timer(seconds, true, false, true).timeout
	if Time.get_ticks_msec() >= _hitstop_until - 2:
		Engine.time_scale = 1.0
