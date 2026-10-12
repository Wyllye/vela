extends Node
## Estado global: configurações, depuração, hit-stop e o estado do mundo da
## partida atual (salvar em disco entra na Etapa 5).

const SETTINGS_PATH := "user://configuracoes.cfg"

var debug := false
var music_on := true
var _hitstop_until := 0

## Sala do último altar em que a Vela descansou (onde ela renasce).
var respawn_room := "poco_fundo"
## Eco póstumo da Vela: {"room": id, "pos": Vector2}; vazio se não há nenhum.
var shade: Dictionary = {}
## Cascas de aura já quebradas: id da sala -> Array[Vector2i].
var broken_shells: Dictionary = {}


func reset_world() -> void:
	respawn_room = "poco_fundo"
	shade = {}
	broken_shells = {}


func add_broken_shells(room_id: String, cells: Array) -> void:
	var list: Array = broken_shells.get(room_id, [])
	list.append_array(cells)
	broken_shells[room_id] = list


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = bool(cfg.get_value("audio", "musica", true))


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	FX.cleanup()


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
