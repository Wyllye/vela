class_name RoomMap
extends Node2D
## Mapa da sala revelado pelo En: a aura escorre pelo espaço vazio e desenha a
## sala inteira — paredes, portas, altares, escritas em aura (lidas ou não),
## o que o In escondia e onde os Ecos estavam no instante do En.
## Aparece no canto depois do En e na pausa, se a sala já foi mapeada.

const MAX := Vector2(300, 190)
const AURA := Color("d6ccff")
const WALL := Color("1a1f29")
const VELA := Color("ffc56a")
const COLD := Color("a9cfdc")
const PEARL := Color("ffd6f0")
const BELL := Color("d9c9a3")

var font: Font
var room: Room
var player: Player
## Centro e tempo da onda (o mapa se enche junto com ela); -1 = já cheio.
var _wave_c := Vector2.ZERO
var _wave_t := -1.0
var _wave_speed := 1100.0
var _ecos: Array = []
var _eco_t := 0.0
var _t := 0.0
var _scale := 0.1
var _tween: Tween
## Versão menor, no canto de baixo (pausa).
var compact := false


func _ready() -> void:
	modulate.a = 0.0
	visible = false


## Mostra o mapa da sala atual. `wave_from` (px na sala) faz o mapa se encher
## junto com a onda do En; sem ele aparece inteiro (pausa, sala já mapeada).
func show_room(r: Room, p: Player, wave_from := Vector2(-1, -1), speed := 1100.0, hold := 5.0, small := false) -> void:
	room = r
	player = p
	compact = small
	var px := r.data.grid.pixel_size()
	var box := MAX * (0.74 if small else 1.0)
	_scale = minf(box.x / px.x, box.y / px.y)
	position = Vector2(1280.0 - 34.0 - px.x * _scale, 46.0)
	if small:
		position = Vector2(34.0, 720.0 - 30.0 - px.y * _scale)
	_wave_speed = speed
	if wave_from.x >= 0.0:
		_wave_c = wave_from
		_wave_t = 0.0
		_ecos.clear()
		for e in r.ecos:
			if is_instance_valid(e) and e.alive():
				_ecos.append(e.body.center())
		_eco_t = hold
	else:
		_wave_t = -1.0
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	if hold > 0.0:
		_tween.tween_interval(hold)
		_tween.tween_property(self, "modulate:a", 0.0, 1.0)
		_tween.tween_callback(func(): visible = false)


func hide_map(time := 0.3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, time)
	_tween.tween_callback(func(): visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _wave_t >= 0.0:
		_wave_t += delta
	_eco_t = maxf(_eco_t - delta, 0.0)
	queue_redraw()


func _revealed(cell_center: Vector2) -> bool:
	if _wave_t < 0.0:
		return true
	return cell_center.distance_to(_wave_c) <= _wave_t * _wave_speed


func _draw() -> void:
	if room == null or not is_instance_valid(room):
		return
	var g := room.data.grid
	var ts := float(g.tile_size)
	var s := _scale
	var size := g.pixel_size() * s
	# moldura
	draw_rect(Rect2(Vector2(-10, -10), size + Vector2(20, 20)), Color(0.0, 0.01, 0.03, 0.62))
	draw_rect(Rect2(Vector2(-10, -10), size + Vector2(20, 20)), Color(AURA, 0.25), false, 1.0)
	if font:
		draw_string(font, Vector2(-8, -16), (room.data.display_name if room.data.display_name != "" else room.data.id).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(AURA, 0.8))
	var cs := ts * s
	for r in g.height:
		for c in g.width:
			var center := Vector2(c + 0.5, r + 0.5) * ts
			if not _revealed(center):
				continue
			var t := g.get_cell(c, r)
			var o := Vector2(c, r) * cs
			match t:
				LevelGrid.Tile.SOLID:
					# borda da rocha que encosta no vazio
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var n := g.get_cell(c + d.x, r + d.y)
						if n != LevelGrid.Tile.SOLID and c + d.x >= 0 and r + d.y >= 0 and c + d.x < g.width and r + d.y < g.height:
							var a := o + Vector2(maxf(d.x, 0), maxf(d.y, 0)) * cs
							var b := a + (Vector2(0, cs) if d.x != 0 else Vector2(cs, 0))
							draw_line(a, b, Color(AURA, 0.7), 1.0)
				LevelGrid.Tile.STONE:
					draw_rect(Rect2(o, Vector2(cs, cs)), Color("b08a52", 0.75))
				LevelGrid.Tile.SHELL:
					draw_rect(Rect2(o, Vector2(cs, cs)), Color("e9c27e", 0.7))
				LevelGrid.Tile.GATE:
					draw_rect(Rect2(o + Vector2(cs * 0.3, 0), Vector2(cs * 0.4, cs)), Color(0.75, 0.78, 0.84, 0.8))
				LevelGrid.Tile.VEIL:
					draw_rect(Rect2(o, Vector2(cs, cs)), Color(AURA, 0.35))
				LevelGrid.Tile.ONE_WAY, LevelGrid.Tile.HIDDEN_ONE_WAY:
					var hidden := t == LevelGrid.Tile.HIDDEN_ONE_WAY
					draw_rect(Rect2(o, Vector2(cs, maxf(cs * 0.25, 1.2))), Color(PEARL if hidden else AURA, 0.9 if hidden else 0.6))
				LevelGrid.Tile.SPIKE, LevelGrid.Tile.HIDDEN_SPIKE:
					var hid := t == LevelGrid.Tile.HIDDEN_SPIKE
					draw_colored_polygon(PackedVector2Array([o + Vector2(0, cs), o + Vector2(cs, cs), o + Vector2(cs * 0.5, cs * 0.35)]),
						Color(PEARL if hid else Color(0.85, 0.5, 0.45), 0.85))
				_:
					draw_rect(Rect2(o, Vector2(cs, cs)), Color(AURA, 0.07))
	# portas
	for k: Vector2i in g.door_cells:
		if _revealed((Vector2(k) + Vector2(0.5, 0.5)) * ts):
			draw_rect(Rect2(Vector2(k) * cs, Vector2(cs, cs)), Color(VELA, 0.5))
	# altares, sinos, escritas em aura
	for a in room.altars:
		if _revealed(a.position):
			var p: Vector2 = a.position * s + Vector2(0, -3)
			draw_circle(p, 4.5, Color(VELA, 0.25))
			draw_circle(p, 2.2, Color(VELA, 0.95))
	for b in room.bells:
		if _revealed(b.position + b.body_pos()):
			draw_arc((b.position + b.body_pos()) * s, 3.2, PI, TAU, 10, Color(BELL, 0.9), 1.4)
	for gl in room.glyphs:
		if _revealed(gl.position):
			var gp: Vector2 = gl.position * s
			var col := PEARL if gl.author == "abadessa" else AURA
			if Game.aura_read.has(gl.text_key):
				draw_circle(gp, 2.4, Color(col, 0.95))
			else:
				draw_arc(gp, 2.6, 0.0, TAU, 12, Color(col, 0.9), 1.1)
	# onde os Ecos estavam no instante do En
	if _eco_t > 0.0:
		var ea := clampf(_eco_t / 1.5, 0.0, 1.0)
		for e in _ecos:
			if _revealed(e):
				draw_circle(e * s, 2.0, Color(COLD, 0.85 * ea))
	# a Vela
	if player != null and is_instance_valid(player):
		var vp := player.body.center() * s
		var pulse := 0.6 + 0.4 * sin(_t * 5.0)
		draw_circle(vp, 4.5, Color(VELA, 0.22 * pulse))
		draw_circle(vp, 2.2, VELA)
