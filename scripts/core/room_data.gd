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
## "1" -> {"to": "galeria", "door": "1"}
var doors: Dictionary = {}
## Chaves de tradução das estelas, na ordem de leitura do mapa.
var texts: Array[String] = []
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
	rd.doors = d.get("doors", {})
	for t in d.get("texts", []):
		rd.texts.append(str(t))
	rd.light_shafts = d.get("light_shafts", [])
	for line in d.get("map", []):
		rd.rows.append(str(line))
	rd.grid = LevelGrid.from_rows(rd.rows)
	return rd


## Marcadores de um tipo, em ordem de leitura (linha, depois coluna).
func markers_of(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in grid.markers:
		if m["ch"] == ch:
			out.append(m["cell"])
	return out
