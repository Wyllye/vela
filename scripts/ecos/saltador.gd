class_name Saltador
extends Eco
## O noviço que jurou nunca mais tocar o chão do Poço. Não para de saltar:
## pulinhos no lugar enquanto está sozinho, saltos longos em cima da chama da
## Vela quando a vê. Dá para quicar nele com o golpe para baixo (pogo).

enum S { CROUCH, AIR }

const SIZE := Vector2(24, 26)
const HOP_VY := -380.0
const LEAP_VY := -660.0
const LEAP_MAX_VX := 310.0
const AWARE_CROUCH := 0.34

var s := S.CROUCH
var s_t := 0.0
var crouch_len := 0.8
var squash := Vector2.ONE


func _init() -> void:
	body.size = SIZE
	hp = 2
	max_hp = 2
	kind = "saltador"
	sight = 300.0
	leash = 8.0 * 32.0


func setup(level: LevelGrid, cell: Vector2i) -> void:
	super.setup(level, cell)
	crouch_len = rng.randf_range(0.5, 1.0)


func _think(dt: float, player: Player) -> void:
	s_t += dt
	_fall(dt)
	match s:
		S.CROUCH:
			vel.x = move_toward(vel.x, 0.0, 1800.0 * dt)
			if aware:
				facing = 1 if player.body.center().x >= body.center().x else -1
				crouch_len = minf(crouch_len, AWARE_CROUCH)
			if s_t >= crouch_len and on_ground():
				_leap(player)
		S.AIR:
			if on_ground():
				s = S.CROUCH
				s_t = 0.0
				crouch_len = AWARE_CROUCH if aware else rng.randf_range(0.7, 1.05)
				fx.emit(&"saltador_land", {"pos": body.feet()})
	_move_body(dt)


func _leap(player: Player) -> void:
	if aware:
		var dx := player.body.center().x - body.center().x
		vel.x = clampf(dx * 1.5, -LEAP_MAX_VX, LEAP_MAX_VX)
		vel.y = LEAP_VY
		facing = 1 if dx >= 0.0 else -1
	else:
		# pulinhos no lugar, puxando de volta para casa
		vel.x = clampf((home.x - body.center().x) * 2.0, -90.0, 90.0)
		vel.y = HOP_VY
	s = S.AIR
	s_t = 0.0
	fx.emit(&"saltador_jump", {"pos": body.feet(), "big": aware})


func _on_parried(_player: Player) -> void:
	s = S.AIR
	s_t = 0.0


func _on_hit(player: Player, dir: int) -> void:
	stun_t = 0.18
	match dir:
		1:
			vel.y = maxf(vel.y, 260.0)
		-1:
			vel.y = -300.0
		_:
			vel.x = player.facing * 210.0
	s = S.AIR


func _update_stunned(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 700.0 * dt)
	_fall(dt)
	_move_body(dt)


func _process(delta: float) -> void:
	var want := Vector2.ONE
	if s == S.CROUCH and stun_t <= 0.0:
		var k := clampf(s_t / maxf(crouch_len, 0.01), 0.0, 1.0)
		want = Vector2(1.0 + 0.28 * k, 1.0 - 0.3 * k)
	elif s == S.AIR:
		var st := clampf(-vel.y / 700.0, -0.4, 1.0)
		want = Vector2(1.0 - 0.14 * st, 1.0 + 0.2 * st)
	squash = squash.lerp(want, 1.0 - exp(-18.0 * delta))
	super._process(delta)


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw_body() -> void:
	var sq := squash
	var base_y := 13.0
	var col := _body_color(1.0)
	# corpo encolhido: capuz redondo puxado para trás, da esquerda pelo topo até a direita
	var shape := PackedVector2Array()
	var n := 18
	for i in range(n + 1):
		var a := lerpf(PI * 0.9, PI * 2.1, float(i) / n)
		var q := Vector2(cos(a) * 12.0, sin(a) * 11.5 - 1.0)
		if q.y < -5.0 and q.x < -1.0:
			q += Vector2(-3.5, -3.0) * clampf((-q.y - 5.0) / 6.5, 0.0, 1.0)
		shape.append(q)
	shape.append_array(_wisp_tail(4.0, 11.0, 12.0, 2, 2.5))
	for k in shape.size():
		shape[k] = Vector2(shape[k].x * sq.x, base_y - (base_y - shape[k].y) * sq.y)
	_ghost_poly(shape, -16.0, 18.0, 0.66, col)
	draw_polyline(shape, Color(COLD_CORE, 0.2 * _alpha()), 1.0, true)
	var face := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		face.append(Vector2(4.5 * sq.x, base_y - (base_y + 3.0) * sq.y) + Vector2(cos(a) * 5.4, sin(a) * 5.0))
	draw_colored_polygon(face, Color(HOLLOW, 0.92 * _alpha()))


func _draw_glow(ci: CanvasItem) -> void:
	var sq := squash
	_draw_eyes(ci, Vector2(4.8 * sq.x, 13.0 - 16.0 * sq.y), 5.2, 1.6)
	if s == S.CROUCH and aware and stun_t <= 0.0:
		var k := clampf(s_t / maxf(crouch_len, 0.01), 0.0, 1.0)
		ci.draw_circle(Vector2(0, 10), 10.0 + 8.0 * k, Color(RAGE, 0.06 * k * _alpha()))
