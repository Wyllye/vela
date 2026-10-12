class_name AuraLayer
extends Node2D
## O que só os olhos de aura veem: plataformas e agulhas que alguém escondeu
## com In. Também diz quanto cada ponto da sala está revelado agora:
##   - o Gyo revela tudo à vista enquanto está aceso;
##   - o En revela a sala inteira por alguns segundos, numa onda que sai da Vela;
##   - pisar numa plataforma escondida ou se ferir nas agulhas acende um pouco
##     o que foi tocado (o In não esconde o que já se sentiu na pele).

const COLOR := Color("d6ccff")
const NEEDLE := Color("f0e8ff")
## Depois que a onda do En passa, quanto tempo o que ela tocou fica visível.
const EN_HOLD := 2.4
const EN_FADE := 1.4

var grid: LevelGrid
var player: Player
var gyo_k := 0.0
var pulses: Array = []
var _platforms: Array[Vector2i] = []
var _needles: Array[Vector2i] = []
var _touch: Dictionary = {}
var _t := 0.0
var _ring: Ring


func setup(g: LevelGrid) -> void:
	grid = g
	_platforms = g.cells_of(LevelGrid.Tile.HIDDEN_ONE_WAY)
	_needles = g.cells_of(LevelGrid.Tile.HIDDEN_SPIKE)


func _ready() -> void:
	material = FX.additive()
	light_mask = 0
	z_index = 2
	_ring = Ring.new()
	_ring.layer = self
	_ring.z_index = 6
	add_child(_ring)


## Onda do En saindo de `center`.
func add_pulse(center: Vector2, speed: float) -> void:
	pulses.append({"c": center, "t": 0.0, "speed": speed})


## Acende o que está escondido perto de um ponto (agulha que feriu a Vela).
func flash_near(pos: Vector2, radius: float) -> void:
	var ts := float(grid.tile_size)
	for k in _needles + _platforms:
		if ((Vector2(k) + Vector2(0.5, 0.5)) * ts).distance_to(pos) <= radius:
			_touch[k] = 1.0


## 0..1: quanto o ponto está revelado agora (Gyo, onda do En).
func reveal_at(pos: Vector2) -> float:
	var r := gyo_k
	for p in pulses:
		var front: float = p["t"] * p["speed"]
		var d := pos.distance_to(p["c"])
		if d <= front:
			var since: float = (front - d) / p["speed"]
			r = maxf(r, 1.0 - smoothstep(EN_HOLD, EN_HOLD + EN_FADE, since))
	return r


func en_active() -> bool:
	return not pulses.is_empty()


func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if (player != null and is_instance_valid(player) and player.gyo) else 0.0
	gyo_k = move_toward(gyo_k, want, delta * (5.0 if want > gyo_k else 3.0))
	var room_diag := grid.pixel_size().length() if grid else 2000.0
	for p in pulses:
		p["t"] += delta
	pulses = pulses.filter(func(p): return p["t"] * p["speed"] < room_diag + p["speed"] * (EN_HOLD + EN_FADE))
	# pisar numa plataforma escondida: ela aparece um pouco sob os pés
	if player != null and is_instance_valid(player) and player.grounded and grid:
		var ts := float(grid.tile_size)
		var r := floori((player.body.pos.y + player.body.size.y + 1.0) / ts)
		for c in range(floori(player.body.pos.x / ts), floori((player.body.pos.x + player.body.size.x - 0.01) / ts) + 1):
			if grid.get_cell(c, r) == LevelGrid.Tile.HIDDEN_ONE_WAY:
				var k := Vector2i(c, r)
				_touch[k] = maxf(float(_touch.get(k, 0.0)), 0.4)
	for k in _touch.keys():
		_touch[k] = move_toward(_touch[k], 0.0, delta * 0.6)
		if _touch[k] <= 0.0:
			_touch.erase(k)
	queue_redraw()
	_ring.queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var ts := float(grid.tile_size)
	for k in _platforms:
		var o := Vector2(k) * ts
		var a := maxf(reveal_at(o + Vector2(ts * 0.5, 4.0)), float(_touch.get(k, 0.0)))
		if a < 0.01:
			continue
		var flick := 0.85 + 0.15 * sin(_t * 3.0 + k.x * 1.7)
		draw_rect(Rect2(o.x + 1, o.y, ts - 2, 7), Color(COLOR, 0.16 * a * flick))
		draw_line(Vector2(o.x + 1, o.y + 1), Vector2(o.x + ts - 1, o.y + 1), Color(COLOR, 0.75 * a * flick), 1.6, true)
		# fios de aura pendendo da tábua
		for i in 3:
			var x := o.x + (i + 0.5) * ts / 3.0 + sin(_t * 1.4 + i + k.x) * 1.5
			var l := 7.0 + 4.0 * sin(_t * 2.0 + i * 2.1 + k.x)
			draw_line(Vector2(x, o.y + 2), Vector2(x, o.y + 2 + l), Color(COLOR, 0.3 * a), 1.0, true)
	for k in _needles:
		var o := Vector2(k) * ts
		var a := maxf(reveal_at(o + Vector2(ts * 0.5, ts * 0.7)), float(_touch.get(k, 0.0)))
		if a < 0.01:
			continue
		for i in 4:
			var x := o.x + (i + 0.5) * ts / 4.0
			var h := ts * (0.45 + 0.15 * sin(k.x * 3.1 + i * 1.7)) * (0.92 + 0.08 * sin(_t * 5.0 + i))
			var base := Vector2(x, o.y + ts)
			var tip := base + Vector2(sin(_t * 1.1 + i) * 0.6, -h)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-2.4, 0), base + Vector2(2.4, 0), tip]), Color(COLOR, 0.35 * a))
			draw_line(base, tip, Color(NEEDLE, 0.85 * a), 1.0, true)
			draw_circle(tip, 1.5, Color(NEEDLE, 0.7 * a))


## A onda do En (por cima de tudo na sala).
class Ring extends Node2D:
	var layer: AuraLayer

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		for p in layer.pulses:
			var front: float = p["t"] * p["speed"]
			var c: Vector2 = p["c"]
			var fade := clampf(1.0 - p["t"] / 2.2, 0.0, 1.0)
			if fade <= 0.0:
				continue
			for i in 4:
				var r := front - i * 14.0
				if r <= 4.0:
					continue
				draw_arc(c, r, 0.0, TAU, 96, Color(AuraLayer.COLOR, (0.32 - i * 0.07) * fade), 3.0 - i * 0.5, true)
			# brilho no chão onde a Vela pôs a mão
			draw_circle(c + Vector2(0, 18), 26.0 * fade, Color(AuraLayer.COLOR, 0.12 * fade))
