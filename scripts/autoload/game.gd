extends Node
## Estado global: configurações, depuração, hit-stop e o estado do mundo da
## partida atual (salvar em disco entra na Etapa 5).

const SETTINGS_PATH := "user://configuracoes.cfg"
## Nenhum hit-stop passa disto, aconteça o que acontecer.
const MAX_HITSTOP := 0.4

var debug := false
var music_on := true
## Fim do hit-stop atual, em microssegundos do relógio real.
var _hitstop_end_us := 0

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
## O fim é conferido a cada quadro contra o relógio real. (Antes era um timer:
## ele contava o quadro em que nasceu e disparava um quadro cedo; a checagem
## falhava e o jogo ficava parado para sempre.)
func hitstop(seconds: float, now_us: int = -1) -> void:
	if seconds <= 0.0:
		return
	if now_us < 0:
		now_us = Time.get_ticks_usec()
	var end := now_us + int(minf(seconds, MAX_HITSTOP) * 1000000.0)
	if end > _hitstop_end_us:
		_hitstop_end_us = end
	Engine.time_scale = 0.0


## Solta o hit-stop quando o prazo passa (roda todo quadro, mesmo congelado).
func update_hitstop(now_us: int = -1) -> void:
	if Engine.time_scale != 0.0:
		return
	if now_us < 0:
		now_us = Time.get_ticks_usec()
	if now_us >= _hitstop_end_us:
		Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	update_hitstop()
