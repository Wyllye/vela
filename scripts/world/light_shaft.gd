class_name LightShaft
extends Node2D
## Feixe de luz entrando por cima (desenho aditivo + luz 2D suave no chão).

var top := Vector2.ZERO
var width := 200.0
var length := 900.0
var angle_deg := 0.0
var color := Color(0.7, 0.83, 1.0)


func setup(data: Dictionary, ts: float, tint: Color, light_tint: Color, seed_value: int) -> void:
	top = Vector2(float(data.get("x", 0)) * ts, float(data.get("y", 0)) * ts)
	width = float(data.get("w", 6)) * ts
	length = float(data.get("len", 20)) * ts
	angle_deg = float(data.get("angle", 0))
	color = tint
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/light_shaft.gdshader")
	mat.set_shader_parameter("color", tint)
	mat.set_shader_parameter("intensity", 0.55)
	mat.set_shader_parameter("seed", float(seed_value % 97))
	material = mat
	light_mask = 0
	z_index = 2
	# luz real, fraca e ampla, onde o feixe toca
	var dir := Vector2(sin(deg_to_rad(angle_deg)), cos(deg_to_rad(angle_deg)))
	var l := FX.make_light(light_tint, width * 1.6, 0.45)
	l.position = top + dir * length * 0.55
	l.texture_scale = maxf(width, length * 0.5) / 256.0
	add_child(l)
	queue_redraw()


func _draw() -> void:
	var dir := Vector2(sin(deg_to_rad(angle_deg)), cos(deg_to_rad(angle_deg)))
	var side := Vector2(dir.y, -dir.x)
	var spread := 1.35
	var a := top - side * width * 0.5
	var b := top + side * width * 0.5
	var c := top + dir * length + side * width * 0.5 * spread
	var d := top + dir * length - side * width * 0.5 * spread
	draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
