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

## Sala do último altar em que a Vela descansou (onde ela renasce) e qual
## altar dela (ordem de leitura do mapa).
var respawn_room := "poco_fundo"
var respawn_altar := 0
## Eco póstumo da Vela: {"room": id, "pos": Vector2}; vazio se não há nenhum.
var shade: Dictionary = {}
## Células abertas para sempre (cascas rachadas, muros de pedra derrubados):
## id da sala -> Array[Vector2i].
var opened_cells: Dictionary = {}
## Marcas do mundo: "sino_<sala>" (o sino tocou e os portões abriram)...
var flags: Dictionary = {}
## Escritas em aura já lidas (chave do texto -> true) e salas mapeadas pelo En.
var aura_read: Dictionary = {}
var mapped_rooms: Dictionary = {}
var _aura_total := -1


func reset_world() -> void:
	respawn_room = "poco_fundo"
	respawn_altar = 0
	shade = {}
	opened_cells = {}
	flags = {}
	aura_read = {}
	mapped_rooms = {}


func add_opened(room_id: String, cells: Array) -> void:
	var list: Array = opened_cells.get(room_id, [])
	list.append_array(cells)
	opened_cells[room_id] = list


## Quantas escritas em aura existem no jogo todo (marcadores `g` das salas).
func aura_total() -> int:
	if _aura_total >= 0:
		return _aura_total
	_aura_total = 0
	var dir := DirAccess.open("res://levels")
	if dir == null:
		return 0
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var rd := RoomData.load_room(f.get_basename())
		if rd:
			_aura_total += rd.markers_of("g").size()
	return _aura_total


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
