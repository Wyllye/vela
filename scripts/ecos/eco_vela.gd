class_name EcoVela
extends Eco
## O Eco póstumo da própria Vela. Quando ela apaga, a aura que escorreu fica
## onde ela caiu, presa ao último desejo dela — continuar. Guarda parte da aura
## máxima; vencê-lo devolve tudo. Sente a Vela mesmo no Zetsu (é a aura dela).

enum S { WAIT, HUNT, WINDUP, LUNGE, RECOVER }

const SIZE := Vector2(24, 44)
const LUNGE_SPEED := 370.0
const WINDUP_TIME := 0.42
const LUNGE_TIME := 0.36
const RECOVER_TIME := 0.6

var s := S.WAIT
var s_t := 0.0
var lunge_dir := Vector2.RIGHT
var hunt_t := 0.0


func _init() -> void:
	body.size = SIZE
	hp = 4
	max_hp = 4
	kind = "eco_vela"
	sight = 380.0
	memory_time = 3.0


## O Eco aparece onde a Vela apagou (centro do corpo dela).
func setup_at(level: LevelGrid, center: Vector2) -> void:
	grid = level
	body.pos = center - SIZE * 0.5
	_keep_inside()
	home = body.center()
	rng.seed = int(center.x) * 31 + int(center.y)
	_sync()


func _sees(player: Player) -> bool:
	var st := player.state
	if st != Player.State.NORMAL and st != Player.State.DASH and st != Player.State.KNOCKBACK and st != Player.State.ENTER:
		return false
	var target := player.body.center()
	return target.distance_to(eye()) <= sight and grid.line_clear(eye(), target)


func _on_spotted(_player: Player) -> void:
	fx.emit(&"shade_wake", {"pos": body.center()})


func _think(dt: float, player: Player) -> void:
	s_t += dt
	var pc := player.body.center()
	match s:
		S.WAIT:
			_steer(home + Vector2(0, sin(anim_t * 1.3) * 6.0), 40.0, 200.0, dt)
			if aware:
				_go(S.HUNT)
		S.HUNT:
			hunt_t += dt
			var side := 1.0 if pc.x >= body.center().x else -1.0
			facing = int(side)
			_steer(pc + Vector2(-side * 84.0, -12.0), 120.0, 520.0, dt)
			if not aware:
				_go(S.WAIT)
			elif hunt_t > 1.2 and body.center().distance_to(pc) < 180.0:
				hunt_t = 0.0
				_go(S.WINDUP)
				fx.emit(&"shade_windup", {"pos": body.center()})
		S.WINDUP:
			vel = vel.move_toward(Vector2.ZERO, 900.0 * dt)
			lunge_dir = (pc - body.center()).normalized()
			facing = 1 if lunge_dir.x >= 0.0 else -1
			if s_t >= WINDUP_TIME:
				_go(S.LUNGE)
				fx.emit(&"shade_lunge", {"pos": body.center(), "dir": lunge_dir})
		S.LUNGE:
			vel = lunge_dir * LUNGE_SPEED
			if s_t >= LUNGE_TIME:
				_go(S.RECOVER)
		S.RECOVER:
			vel = vel.move_toward(Vector2.ZERO, 900.0 * dt)
			if s_t >= RECOVER_TIME:
				_go(S.HUNT)
	_move_body(dt)


func _go(ns: S) -> void:
	s = ns
	s_t = 0.0


func _on_hit(player: Player, dir: int) -> void:
	stun_t = 0.22
	match dir:
		1:
			vel = Vector2(vel.x * 0.3, 220.0)
		-1:
			vel = Vector2(vel.x * 0.3, -220.0)
		_:
			vel = Vector2(player.facing * 220.0, -30.0)
	_go(S.RECOVER)
	s_t = RECOVER_TIME * 0.5


func _update_stunned(dt: float) -> void:
	vel = vel.move_toward(Vector2.ZERO, 800.0 * dt)
	_move_body(dt)


func _rage() -> float:
	return 1.0 if s == S.WINDUP or s == S.LUNGE else 0.0


# ---------------------------------------------------------------------------
# Desenho: a Vela em negativo — cera escura, chama fria
# ---------------------------------------------------------------------------

const INK := Color("1a2130")
const INK_HI := Color("3a4a62")


func _bob() -> float:
	return sin(anim_t * 1.9) * 2.0


func _draw_body() -> void:
	var b := _bob()
	var a := _alpha()
	var ink := INK.lerp(Color(0.8, 0.9, 1.0), flash * 0.6)
	var hi := INK_HI.lerp(Color.WHITE, flash * 0.5)
	# batina que se desfaz em fiapos
	var robe := PackedVector2Array([Vector2(8, -8 + b), Vector2(11, 2 + b), Vector2(12, 12 + b)])
	robe.append_array(_wisp_tail(12.0 + b, 12.0, 16.0, 3, 2.6))
	robe.append_array(PackedVector2Array([Vector2(-12, 12 + b), Vector2(-11, 1 + b), Vector2(-8, -9 + b)]))
	var cols := PackedColorArray()
	for q in robe:
		var k := clampf((q.y + 10.0) / 36.0, 0.0, 1.0)
		cols.append(Color(ink.lerp(hi, 0.25 * (1.0 - k)), (0.92 - 0.8 * k * k) * a))
	draw_polygon(robe, cols)
	draw_polyline(robe, Color(hi, 0.5 * a), 1.0, true)
	# capuz
	var hood := PackedVector2Array()
	var tip := Vector2(-10, -27 + b)
	var added := false
	for i in 24:
		var ang := TAU * i / 24.0
		var deg := rad_to_deg(ang)
		if deg > 186.0 and deg < 264.0:
			if not added:
				hood.append(tip)
				added = true
			continue
		hood.append(Vector2(2, -15 + b) + Vector2(cos(ang), sin(ang)) * 10.0)
	draw_colored_polygon(hood, Color(ink, 0.95 * a))
	draw_polyline(hood, Color(hi, 0.55 * a), 1.0, true)
	var face := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0
		face.append(Vector2(5.4, -14.5 + b) + Vector2(cos(ang) * 5.6, sin(ang) * 6.8))
	draw_colored_polygon(face, Color(0, 0, 0, 0.95 * a))
	# cajado
	var ang_s := deg_to_rad(-84.0)
	if s == S.WINDUP:
		ang_s = deg_to_rad(lerpf(-84.0, -150.0, minf(s_t / WINDUP_TIME, 1.0)))
	elif s == S.LUNGE:
		ang_s = deg_to_rad(35.0)
	var hand := Vector2(9, 1 + b)
	var u := Vector2(cos(ang_s), sin(ang_s))
	draw_line(hand - u * 18.0, hand + u * 34.0, Color(hi, 0.8 * a), 2.2, true)
	draw_arc(hand + u * 37.0, 3.4, 0.0, TAU, 14, Color(hi, 0.8 * a), 1.2, true)


func _draw_glow(ci: CanvasItem) -> void:
	var b := _bob()
	var a := _alpha()
	var flick := 0.88 + 0.08 * sin(anim_t * 9.0) + 0.04 * sin(anim_t * 23.0)
	FX.draw_flame(ci, Vector2(2.6, -32.0 + b), 15.0 * flick, 6.4, sin(anim_t * 2.3) * 0.08,
		Color(0.62, 0.8, 1.0, 0.8 * a), Color(0.85, 0.94, 1.0, 0.85 * a), Color(1, 1, 1, 0.9 * a))
	_draw_eyes(ci, Vector2(5.6, -15.0 + b), 4.0, 1.2)
	if s == S.WINDUP:
		var k := clampf(s_t / WINDUP_TIME, 0.0, 1.0)
		ci.draw_circle(Vector2(0, -6), 16.0 + 10.0 * k, Color(0.7, 0.85, 1.0, 0.07 * k * a))
