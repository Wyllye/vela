class_name StoneView
extends Node2D
## Muros de pedra solta: passagens que alguém emparedou às pressas, pedra sobre
## pedra, com argamassa grossa. O golpe comum só tilinta; com a aura no cajado
## (Shu) ou com o Ko, o muro inteiro cai.

const STONE := Color("6b6359")
const STONE_HI := Color("b0a28b")
const STONE_DEEP := Color("2a2622")
const MORTAR := Color("17140f")
const BRICK := 16.0

var grid: LevelGrid
var _cells: Array[Vector2i] = []
var _seed := 0


func setup(g: LevelGrid, seed_value: int) -> void:
	grid = g
	_seed = seed_value
	refresh()


func _ready() -> void:
	z_index = 1


## Relê a grade (depois que um muro caiu).
func refresh() -> void:
	if grid == null:
		return
	_cells = grid.cells_of(LevelGrid.Tile.STONE)
	queue_redraw()


func _brick_rng(bx: int, course: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + bx * 131 + course * 977 + 17
	return rng


func _draw() -> void:
	var ts := float(grid.tile_size)
	for k in _cells:
		var o := Vector2(k) * ts
		draw_rect(Rect2(o, Vector2(ts, ts)), MORTAR)
		for row in int(ts / BRICK):
			var course := int(k.y * ts / BRICK) + row
			var y0 := o.y + row * BRICK
			var off := BRICK * 0.5 if course % 2 == 1 else 0.0
			# tijolos (em coordenadas do mundo, para emendar com a célula vizinha)
			var bx := floori((o.x - off) / BRICK)
			while bx * BRICK + off < o.x + ts:
				var x0 := bx * BRICK + off
				var x1 := x0 + BRICK
				var rng := _brick_rng(bx, course)
				var shade := rng.randf_range(-0.12, 0.1)
				var col := STONE.lightened(shade) if shade > 0.0 else STONE.darkened(-shade)
				var cx0 := maxf(x0 + 1.0, o.x)
				var cx1 := minf(x1 - 1.0, o.x + ts)
				if cx1 > cx0:
					var br := Rect2(cx0, y0 + 1.0, cx1 - cx0, BRICK - 2.0)
					draw_rect(br, col)
					# luz de cima, sombra embaixo
					draw_line(Vector2(cx0, y0 + 1.6), Vector2(cx1, y0 + 1.6), Color(STONE_HI, 0.45), 1.0)
					draw_line(Vector2(cx0, y0 + BRICK - 1.6), Vector2(cx1, y0 + BRICK - 1.6), Color(STONE_DEEP, 0.55), 1.0)
					# lascas e rachaduras
					if rng.randf() < 0.3:
						var cx := x0 + rng.randf_range(3.0, BRICK - 3.0)
						if cx > cx0 and cx < cx1:
							draw_line(Vector2(cx, y0 + 2.0), Vector2(cx + rng.randf_range(-3.0, 3.0), y0 + BRICK - 3.0), Color(STONE_DEEP, 0.7), 1.0, true)
					if rng.randf() < 0.25:
						var corner := Vector2(cx1 - 1.0, y0 + 1.0) if rng.randf() < 0.5 else Vector2(cx0 + 1.0, y0 + BRICK - 1.0)
						draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(-3.0 if corner.x > cx0 + 2.0 else 3.0, 0), corner + Vector2(0, 3.0 if corner.y < y0 + 4.0 else -3.0)]), MORTAR)
				bx += 1
		# sombra ao pé do muro e borda escura onde ele encosta no vazio
		if grid.get_cell(k.x, k.y + 1) != LevelGrid.Tile.STONE and not grid.is_rock(k.x, k.y + 1):
			draw_rect(Rect2(o.x, o.y + ts - 3.0, ts, 3.0), Color(0, 0, 0, 0.35))
		for side in [-1, 1]:
			var n := grid.get_cell(k.x + side, k.y)
			if n != LevelGrid.Tile.STONE and not grid.is_rock(k.x + side, k.y):
				var x := o.x + (ts - 1.0 if side > 0 else 1.0)
				draw_line(Vector2(x, o.y), Vector2(x, o.y + ts), Color(STONE_DEEP, 0.8), 2.0)
