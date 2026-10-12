class_name GateView
extends Node2D
## Portões de ferro do Noviciado: grades que descem do teto e trancam a
## passagem. Quando o sino toca, sobem e somem no vão de cima.

const IRON := Color("2f3238")
const IRON_HI := Color("6f7680")
const IRON_DEEP := Color("121418")
const RUST := Color("5e3a26")

var grid: LevelGrid
## Um portão por grupo de células: {"rect": Rect2, "open": 0..1}
var gates: Array = []
var _opening := false


func setup(g: LevelGrid) -> void:
	grid = g
	var seen := {}
	var ts := float(g.tile_size)
	for k in g.cells_of(LevelGrid.Tile.GATE):
		if seen.has(k):
			continue
		# grupo de células vizinhas = um portão
		var stack: Array[Vector2i] = [k]
		var lo := k
		var hi := k
		while not stack.is_empty():
			var q: Vector2i = stack.pop_back()
			if seen.has(q) or g.get_cell(q.x, q.y) != LevelGrid.Tile.GATE:
				continue
			seen[q] = true
			lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
			hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				stack.append(q + o)
		gates.append({"rect": Rect2(Vector2(lo) * ts, Vector2(hi - lo + Vector2i.ONE) * ts), "open": 0.0})


func _ready() -> void:
	z_index = 1


## O sino tocou: as grades sobem (devagar, com peso).
func open(animated: bool) -> void:
	for gt in gates:
		gt["open"] = 0.0 if animated else 1.0
	_opening = animated
	queue_redraw()


func is_empty() -> bool:
	return gates.is_empty()


func _process(delta: float) -> void:
	if not _opening:
		return
	var done := true
	for gt in gates:
		var o: float = gt["open"]
		o = minf(o + delta / 1.6, 1.0)
		gt["open"] = o
		if o < 1.0:
			done = false
	_opening = not done
	queue_redraw()


func _draw() -> void:
	for gt in gates:
		var r: Rect2 = gt["rect"]
		var o: float = gt["open"]
		var e := o * o * (3.0 - 2.0 * o)
		var lift := e * (r.size.y + 6.0)
		var bottom := r.end.y - lift
		if bottom <= r.position.y + 1.0:
			continue
		# trilhos nas laterais (ficam)
		draw_rect(Rect2(r.position.x - 2, r.position.y, 4, r.size.y), IRON_DEEP)
		draw_rect(Rect2(r.end.x - 2, r.position.y, 4, r.size.y), IRON_DEEP)
		# barras verticais com pontas
		var bars := maxi(2, int(r.size.x / 9.0))
		for i in bars:
			var x := r.position.x + (i + 0.5) * r.size.x / bars
			draw_line(Vector2(x, r.position.y), Vector2(x, bottom - 6), IRON, 3.4, true)
			draw_line(Vector2(x - 0.8, r.position.y), Vector2(x - 0.8, bottom - 6), Color(IRON_HI, 0.45), 1.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, bottom - 7), Vector2(x + 3, bottom - 7), Vector2(x, bottom)]), IRON_HI.darkened(0.2))
		# travessas
		var y := r.position.y + 14.0
		while y < bottom - 12.0:
			draw_rect(Rect2(r.position.x, y, r.size.x, 4), IRON)
			draw_line(Vector2(r.position.x, y + 0.5), Vector2(r.end.x, y + 0.5), Color(IRON_HI, 0.35), 1.0)
			for i in 3:
				draw_circle(Vector2(r.position.x + (i + 0.5) * r.size.x / 3.0, y + 2), 1.4, Color(RUST, 0.8))
			y += 34.0
