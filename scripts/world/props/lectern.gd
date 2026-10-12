class_name Lectern
extends Node2D
## Atril de leitura com um livro aberto (e as linhas que ninguém mais lê).
## Origem = base, em cima do chão.

const WOOD := Color("43332a")
const WOOD_HI := Color("8a6b4c")
const WOOD_DARK := Color("1d1611")
const PAGE := Color("d4c6a4")
const INK := Color("4a3f33")

var _flip := 1.0


func setup(seed_value: int) -> void:
	_flip = 1.0 if seed_value % 2 == 0 else -1.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_flip, 1.0))
	# pé e base
	draw_rect(Rect2(-12, -4, 24, 4), WOOD_DARK)
	draw_rect(Rect2(-3, -40, 6, 37), WOOD)
	draw_line(Vector2(-3, -40), Vector2(-3, -4), WOOD_HI, 1.0)
	# tampo inclinado
	var top := PackedVector2Array([Vector2(-17, -40), Vector2(17, -48), Vector2(18, -44), Vector2(-16, -36)])
	draw_colored_polygon(top, WOOD)
	draw_line(Vector2(-17, -40), Vector2(17, -48), WOOD_HI, 1.2)
	# livro aberto
	var l := PackedVector2Array([Vector2(-15, -42), Vector2(0, -46), Vector2(0, -55), Vector2(-14, -51)])
	var r := PackedVector2Array([Vector2(0, -46), Vector2(16, -50), Vector2(15, -59), Vector2(0, -55)])
	draw_colored_polygon(l, PAGE.darkened(0.08))
	draw_colored_polygon(r, PAGE)
	for i in 3:
		var t := 0.3 + i * 0.2
		draw_line(Vector2(-12, -44 - 9 * t), Vector2(-3, -46.5 - 9 * t), Color(INK, 0.6), 0.8)
		draw_line(Vector2(3, -47.5 - 9 * t), Vector2(13, -50 - 9 * t), Color(INK, 0.6), 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
