class_name GameCamera
extends Camera2D
## Câmera que segue a Vela: antecipa para onde ela olha/corre, olha para
## cima/baixo quando ela segura a direção parada, desce junto em quedas
## rápidas e treme com impactos (trauma ao quadrado).

const VIEW := Vector2(1280, 720)

var target: Player
var room_size := VIEW
var look_ahead := 0.0
var look_y := 0.0
var trauma := 0.0
var _noise_t := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	make_current()


func setup_room(size: Vector2) -> void:
	room_size = size
	limit_left = 0
	limit_top = 0
	limit_right = int(size.x)
	limit_bottom = int(size.y)


func snap() -> void:
	look_ahead = target.facing * 60.0
	look_y = 0.0
	position = _clamp_goal(_goal())
	offset = Vector2.ZERO
	reset_smoothing()
	reset_physics_interpolation()


func _goal() -> Vector2:
	return target.body.center() + Vector2(look_ahead, -36.0 + look_y)


func _clamp_goal(g: Vector2) -> Vector2:
	var half := VIEW * 0.5
	return Vector2(
		clampf(g.x, half.x, maxf(half.x, room_size.x - half.x)),
		clampf(g.y, half.y, maxf(half.y, room_size.y - half.y)))


func follow(dt: float) -> void:
	if target == null:
		return
	var p := target
	var ahead := p.facing * 70.0 + clampf(p.vel.x * 0.16, -90.0, 90.0)
	if not p.is_controllable():
		ahead = p.facing * 40.0
	look_ahead = lerpf(look_ahead, ahead, 1.0 - exp(-2.6 * dt))
	var want_y := 0.0
	if p.look != 0:
		want_y = p.look * 190.0
	elif p.vel.y > 520.0:
		want_y = 130.0
	look_y = lerpf(look_y, want_y, 1.0 - exp(-3.2 * dt))
	var g := _clamp_goal(_goal())
	var kx := 1.0 - exp(-8.5 * dt)
	var ky := 1.0 - exp((-11.0 if absf(p.vel.y) > 420.0 else -6.5) * dt)
	position = Vector2(lerpf(position.x, g.x, kx), lerpf(position.y, g.y, ky))
	trauma = maxf(trauma - dt * 1.7, 0.0)
	var s := trauma * trauma
	_noise_t += dt * 34.0
	offset = Vector2(sin(_noise_t * 1.31) + 0.5 * sin(_noise_t * 2.73), cos(_noise_t * 1.67) + 0.5 * sin(_noise_t * 3.11)) * 11.0 * s


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Canto superior esquerdo da visão (já com interpolação), para o parallax.
func view_top_left() -> Vector2:
	return get_screen_center_position() - VIEW * 0.5
