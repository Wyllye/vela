class_name Banner
extends Node2D
## Estandarte rasgado pendurado no teto, balançando devagar.
## Origem = ponto de ancoragem no teto.

var length := 110.0
var width := 26.0
var cloth := Color("4d2b2a")
var mark := Color("b09a62")
var phase := 0.0
var _t := 0.0


func setup(l: float, c: Color, m: Color, p: float) -> void:
	length = l
	cloth = c
	mark = m
	phase = p


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _sway(y: float) -> float:
	var k := y / length
	return sin(_t * 0.9 + phase + k * 2.0) * 3.5 * k * k


func _draw() -> void:
	draw_line(Vector2(-width * 0.5 - 5, 2), Vector2(width * 0.5 + 5, 2), Color("3f3a33"), 3.0, true)
	var pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var y := length * float(i) / steps
		pts.append(Vector2(width * 0.5 + _sway(y), y))
	var teeth := 5
	for i in range(1, teeth):
		var x := width * 0.5 - width * float(i) / teeth
		var y := length + (12.0 if i % 2 == 1 else 2.0) + absf(sin(phase * 3.0 + i)) * 3.0
		pts.append(Vector2(x + _sway(y), y))
	for i in range(steps, -1, -1):
		var y := length * float(i) / steps
		pts.append(Vector2(-width * 0.5 + _sway(y), y))
	draw_colored_polygon(pts, cloth)
	# hexágono bordado
	var c := Vector2(_sway(length * 0.35), length * 0.35)
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(c + Vector2(cos(a), sin(a)) * 7.0)
	draw_polyline(hex, Color(mark, 0.75), 1.6, true)
	draw_circle(c, 2.0, Color(mark, 0.75))
