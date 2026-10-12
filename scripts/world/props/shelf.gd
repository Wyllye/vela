class_name Shelf
extends Node2D
## Estante de livros e rolos do Noviciado: madeira escura, lombadas de cores
## gastas, um livro caído aqui e ali. Origem = base, em cima do chão.

const WOOD := Color("3d2f24")
const WOOD_HI := Color("7a5f45")
const WOOD_DARK := Color("1b140f")
const SPINES := [Color("6e3b30"), Color("5a4a2e"), Color("3f4a3a"), Color("7a6040"), Color("4a3a4f"), Color("8a7a5a"), Color("5c2f2a")]
const PAGE := Color("cbbd9c")

var _books: Array = []
var _fallen: Array = []
var _w := 46.0
var _h := 92.0


func setup(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_w = rng.randf_range(42.0, 52.0)
	_h = rng.randf_range(84.0, 104.0)
	var shelves := 4
	for s in shelves:
		var y_floor := -6.0 - s * ((_h - 10.0) / shelves)
		var x := -_w * 0.5 + 4.0
		while x < _w * 0.5 - 6.0:
			if rng.randf() < 0.12:
				x += rng.randf_range(4.0, 9.0)  # vão
				continue
			var bw := rng.randf_range(3.0, 6.5)
			var bh := rng.randf_range(12.0, (_h - 10.0) / shelves - 3.0)
			var lean := 0.0
			if rng.randf() < 0.12:
				lean = rng.randf_range(0.15, 0.35)
			var scroll := rng.randf() < 0.1
			_books.append({"x": x, "y": y_floor, "w": bw, "h": bh, "c": SPINES[rng.randi() % SPINES.size()], "lean": lean, "scroll": scroll})
			x += bw + rng.randf_range(0.2, 1.2)
	for i in rng.randi_range(0, 2):
		_fallen.append({"x": rng.randf_range(-_w * 0.6, _w * 0.6), "w": rng.randf_range(9.0, 14.0), "c": SPINES[rng.randi() % SPINES.size()], "open": rng.randf() < 0.5})


func _draw() -> void:
	# armação
	draw_rect(Rect2(-_w * 0.5 - 3, -_h, _w + 6, _h), WOOD_DARK)
	draw_rect(Rect2(-_w * 0.5, -_h + 3, _w, _h - 3), WOOD.darkened(0.35))
	draw_rect(Rect2(-_w * 0.5 - 4, -_h - 3, _w + 8, 5), WOOD)
	draw_line(Vector2(-_w * 0.5 - 4, -_h - 3), Vector2(_w * 0.5 + 4, -_h - 3), WOOD_HI, 1.2)
	for b in _books:
		var x: float = b["x"]
		var y: float = b["y"]
		var w: float = b["w"]
		var h: float = b["h"]
		var c: Color = b["c"]
		if b["scroll"]:
			draw_circle(Vector2(x + w * 0.5, y - 3.5), 3.5, PAGE.darkened(0.2))
			draw_circle(Vector2(x + w * 0.5, y - 3.5), 1.4, PAGE.darkened(0.5))
			continue
		var lean: float = b["lean"]
		var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w + h * lean, y - h), Vector2(x + h * lean, y - h)])
		draw_colored_polygon(pts, c)
		draw_line(Vector2(x + w * 0.5 + h * lean * 0.3, y - h * 0.3), Vector2(x + w * 0.5 + h * lean * 0.7, y - h * 0.7), Color(c.lightened(0.25), 0.6), 1.0)
	# prateleiras
	for s in 4:
		var y_floor := -6.0 - s * ((_h - 10.0) / 4.0)
		draw_rect(Rect2(-_w * 0.5, y_floor, _w, 3), WOOD)
		draw_line(Vector2(-_w * 0.5, y_floor), Vector2(_w * 0.5, y_floor), WOOD_HI, 1.0)
	# livros caídos no chão
	for f in _fallen:
		var fx: float = f["x"]
		var fw: float = f["w"]
		draw_rect(Rect2(fx - fw * 0.5, -4, fw, 4), f["c"])
		if f["open"]:
			draw_colored_polygon(PackedVector2Array([Vector2(fx - fw * 0.5, -4), Vector2(fx, -6), Vector2(fx + fw * 0.5, -4)]), PAGE)
