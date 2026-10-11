class_name FlameNode
extends Node2D
## Chama desenhada em modo aditivo e sem sombreamento (brilha no escuro).

var height := 9.0
var width := 4.5
var tilt := 0.0
var outer := Color(1.0, 0.68, 0.32, 0.85)
var inner := Color(1.0, 0.9, 0.7, 0.9)
var core := Color(1, 1, 1, 0.95)
var flicker := 1.0
var phase := 0.0
var _t := 0.0


func _ready() -> void:
	material = FX.additive()
	light_mask = 0


func _process(delta: float) -> void:
	_t += delta
	flicker = 0.86 + 0.09 * sin(_t * 9.3 + phase) + 0.05 * sin(_t * 23.0 + phase * 1.7)
	queue_redraw()


func _draw() -> void:
	var sway := sin(_t * 3.1 + phase) * 0.08
	FX.draw_flame(self, Vector2.ZERO, height * flicker, width, tilt + sway, outer, inner, core)
