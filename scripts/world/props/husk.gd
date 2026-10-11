class_name Husk
extends Node2D
## Casca: um monge de cera que apagou no Grande Silêncio. A pose conta a história.
## Origem = base, em cima do chão.

const WAX := Color("8e877b")
const WAX_SHADE := Color("635d54")
const HOOD_IN := Color("15161a")
const WICK := Color("2a2622")

var pose := "sit"   # "sit" (meditando) ou "fallen" (caído)
var flip := 1


func setup(p: String, f: int) -> void:
	pose = p
	flip = f


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1))
	if pose == "fallen":
		_draw_fallen()
	else:
		_draw_sitting()


func _draw_sitting() -> void:
	# corpo largo, sentado
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(12, -14), Vector2(7, -24), Vector2(-7, -24), Vector2(-12, -14)]), WAX)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(-4, 0), Vector2(-5, -24), Vector2(-7, -24), Vector2(-12, -14)]), WAX_SHADE)
	# capuz inclinado (cabeça baixa)
	var hc := Vector2(3, -30)
	draw_circle(hc, 9.0, WAX)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-8, -3), hc + Vector2(-14, -9), hc + Vector2(-1, -9)]), WAX)
	draw_circle(hc + Vector2(4, 2), 5.0, HOOD_IN)
	# pavio frio
	draw_line(hc + Vector2(-1, -9), hc + Vector2(0, -13), WICK, 1.5, true)
	# cera escorrida no chão
	draw_rect(Rect2(-19, -2, 38, 2), WAX_SHADE)


func _draw_fallen() -> void:
	# deitado de lado, estendendo a mão para a saída
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(14, 0), Vector2(18, -6), Vector2(10, -13), Vector2(-16, -12), Vector2(-24, -6)]), WAX)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(14, 0), Vector2(12, -4), Vector2(-20, -4)]), WAX_SHADE)
	var hc := Vector2(22, -8)
	draw_circle(hc, 8.0, WAX)
	draw_circle(hc + Vector2(3, 1), 4.2, HOOD_IN)
	draw_line(hc + Vector2(6, -6), hc + Vector2(10, -9), WICK, 1.5, true)
	# braço estendido
	draw_line(Vector2(10, -4), Vector2(34, -2), WAX, 3.0, true)
	draw_rect(Rect2(-26, -2, 56, 2), WAX_SHADE)
