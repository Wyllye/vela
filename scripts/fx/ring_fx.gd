class_name RingFX
extends Node2D
## Anel de choque que cresce e desaparece.

var color := Color.WHITE
var max_radius := 40.0
var life := 0.28
var _t := 0.0


func _ready() -> void:
	z_index = 6
	material = FX.additive()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var r := max_radius * (0.25 + 0.75 * (1.0 - pow(1.0 - k, 3.0)))
	var a := (1.0 - k) * color.a
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, a), 3.0 * (1.0 - k) + 1.0, true)
