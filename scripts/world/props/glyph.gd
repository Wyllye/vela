class_name AuraGlyph
extends Node2D
## Escrita em aura: quase invisível sem Gyo (Etapa 3). Só cintila de leve,
## para quem presta atenção.

var text_key := ""
var color := Color("ffd6f0")
var _t := 0.0
var _strokes: Array = []


func setup(key: String, seed_value: int) -> void:
	text_key = key
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 7:
		var p := Vector2(rng.randf_range(-22, 22), rng.randf_range(-26, 20))
		var pts := PackedVector2Array([p])
		for k in rng.randi_range(2, 4):
			p += Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
			pts.append(p)
		_strokes.append(pts)


func _ready() -> void:
	material = FX.additive()
	light_mask = 0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var a := 0.05 + 0.05 * (0.5 + 0.5 * sin(_t * 1.3))
	for s in _strokes:
		draw_polyline(s, Color(color, a), 1.4, true)
	var hex := PackedVector2Array()
	for i in 7:
		var ang := -PI / 2.0 + i * TAU / 6.0
		hex.append(Vector2(cos(ang), sin(ang)) * 12.0)
	draw_polyline(hex, Color(color, a * 1.4), 1.2, true)
