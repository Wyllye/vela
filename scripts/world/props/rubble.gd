class_name Rubble
extends Node2D
## Pedras soltas no chão. Origem = base.

var palette: Dictionary
var rng := RandomNumberGenerator.new()


func setup(pal: Dictionary, seed_value: int) -> void:
	palette = pal
	rng.seed = seed_value


func _draw() -> void:
	var col: Color = palette.get("stone_edge", Color("515e6e"))
	for i in 5:
		var cx := rng.randf_range(-22, 22)
		var r := rng.randf_range(4, 10)
		var pts := PackedVector2Array()
		for k in 7:
			var a := PI + PI * float(k) / 6.0
			pts.append(Vector2(cx + cos(a) * r * rng.randf_range(0.8, 1.2), sin(a) * r * rng.randf_range(0.6, 1.1)))
		draw_colored_polygon(pts, col.darkened(rng.randf_range(0.1, 0.45)))
