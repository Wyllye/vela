class_name RoomData
extends RefCounted
## Dados de uma sala carregados de levels/<id>.json.

var id := ""
var display_name := ""
var area := ""
var area_title := ""
var music := ""
var ambience := ""
var palette := "poco"
var rng_seed := 0
## O que o altar da sala ensina ao meditar: uma lição do Nen ("ten", "zetsu",
## "ren", "gyo", "shu", "ken", "ko", "en"), "end" (fim da etapa) ou "".
var altar_lesson := ""
## Uma lição por altar, na ordem de leitura do mapa (quando a sala tem mais de um).
var altar_lessons: Array[String] = []
## "1" -> {"to": "galeria", "door": "1"}
var doors: Dictionary = {}
## Chaves de tradução das estelas, na ordem de leitura do mapa.
var texts: Array[String] = []
## Escritas em aura (marcadores `g`, na ordem de leitura): {"text": chave,
## "author": "monge"|"abadessa", "w": tiles, "h": tiles}.
var aura: Array[Dictionary] = []
## Murais no fundo: {"id": "juramento", "x", "y" (tiles), "anchor_x", "anchor_y"}.
var murals: Array = []
var rows := PackedStringArray()
var light_shafts: Array = []
var grid: LevelGrid


static func path_for(room_id: String) -> String:
	return "res://levels/%s.json" % room_id


static func load_room(room_id: String) -> RoomData:
	var txt := FileAccess.get_file_as_string(path_for(room_id))
	if txt.is_empty():
		push_error("Sala não encontrada: %s" % room_id)
		return null
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON inválido na sala %s" % room_id)
		return null
	return from_dict(data)


static func from_dict(d: Dictionary) -> RoomData:
	var rd := RoomData.new()
	rd.id = str(d.get("id", ""))
	rd.display_name = str(d.get("name", ""))
	rd.area = str(d.get("area", ""))
	rd.area_title = str(d.get("area_title", ""))
	rd.music = str(d.get("music", ""))
	rd.ambience = str(d.get("ambience", ""))
	rd.palette = str(d.get("palette", "poco"))
	rd.rng_seed = int(d.get("seed", 0))
	rd.altar_lesson = str(d.get("altar_lesson", ""))
	for l in d.get("altar_lessons", []):
		rd.altar_lessons.append(str(l))
	rd.doors = d.get("doors", {})
	for t in d.get("texts", []):
		rd.texts.append(str(t))
	for a in d.get("aura", []):
		if typeof(a) == TYPE_DICTIONARY:
			var e: Dictionary = a.duplicate()
			e["text"] = str(e.get("text", ""))
			rd.aura.append(e)
		else:
			rd.aura.append({"text": str(a)})
	rd.murals = d.get("murals", [])
	rd.light_shafts = d.get("light_shafts", [])
	for line in d.get("map", []):
		rd.rows.append(str(line))
	rd.grid = LevelGrid.from_rows(rd.rows)
	return rd


## Lição do altar `i` (ordem de leitura do mapa).
func lesson_for_altar(i: int) -> String:
	if i < altar_lessons.size():
		return altar_lessons[i]
	return altar_lesson


## Escrita em aura do marcador `g` número `i` (vazio se faltar no JSON).
func aura_entry(i: int) -> Dictionary:
	if i < aura.size():
		return aura[i]
	return {"text": ""}


## Marcadores de um tipo, em ordem de leitura (linha, depois coluna).
func markers_of(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in grid.markers:
		if m["ch"] == ch:
			out.append(m["cell"])
	return out
