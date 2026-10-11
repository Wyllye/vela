class_name FogLayer
extends Node2D
## Camada de névoa animada (shader) com parallax.

const VIEW := Vector2(1280, 720)

var factor := 0.5
var screen_space := true
var content := Vector2.ZERO


func setup(f: float, in_screen: bool, room_px: Vector2, tint: Color, density: float, seed_value: int) -> void:
	factor = f
	screen_space = in_screen
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	content = VIEW + (room_px - VIEW).max(Vector2.ZERO) * f + Vector2(240, 160)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fog.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("drift", Vector2(0.008 + 0.004 * f, 0.002) * (1.0 if seed_value % 2 == 0 else -1.0))
	material = mat
	light_mask = 0
	queue_redraw()


func update_camera(cam_tl: Vector2) -> void:
	var margin := Vector2(120, 80)
	if screen_space:
		position = -cam_tl * factor - margin
	else:
		position = cam_tl * (1.0 - factor) - margin


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, content), Color.WHITE)
