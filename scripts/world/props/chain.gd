class_name HangingChain
extends Node2D
## Corrente pendurada no teto. Origem = ponto de ancoragem.

const IRON := Color("3d434a")
const IRON_HI := Color("737b84")

var length := 120.0
var phase := 0.0
var hook := true
var _t := 0.0


func setup(l: float, p: float) -> void:
	length = l
	phase = p
	hook = int(p * 10.0) % 2 == 0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sway := sin(_t * 0.8 + phase) * 0.025
	var n := int(length / 10.0)
	var end := Vector2.ZERO
	for i in n:
		var p := Vector2(0, i * 10.0 + 5.0).rotated(sway)
		if i % 2 == 0:
			draw_set_transform(p, sway, Vector2(0.6, 1.0))
			draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 14, IRON, 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_line(p + Vector2(0, -4).rotated(sway), p + Vector2(0, 4).rotated(sway), IRON_HI, 1.5, true)
		end = p
	if hook:
		draw_arc(end + Vector2(3, 8).rotated(sway), 5.0, PI * 0.1, PI * 1.2, 10, IRON, 2.2, true)
