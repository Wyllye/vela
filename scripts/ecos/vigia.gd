class_name Vigia
extends Eco
## Patrulheiro. O Vigia jurou que ninguém passaria pela porta do dormitório
## dos noviços: anda diante dela de um lado para o outro, com a lanterna
## erguida, e investe contra a chama que enxerga. Só vê para a frente, na faixa
## da lanterna — pelas costas, ou apagada no Zetsu, dá para passar.

enum S { PATROL, TURN, NOTICE, CHARGE, RECOVER }

const SIZE := Vector2(26, 52)
const WALK := 58.0
const CHARGE_SPEED := 410.0
const NOTICE_TIME := 0.5
const CHARGE_TIME := 1.2
const RECOVER_TIME := 0.85
const TURN_TIME := 0.75
const CLOSE_SENSE := 60.0
const BAND := 100.0
const CONE_LEN := 260.0
const CONE_HALF := 0.34

var s := S.PATROL
var s_t := 0.0
var walk_phase := 0.0
var swing := 0.0
var swing_v := 0.0


func _init() -> void:
	body.size = SIZE
	hp = 3
	max_hp = 3
	kind = "vigia"
	sight = 300.0
	leash = 7.0 * 32.0


## Enxerga só para a frente, na faixa da lanterna; de muito perto sente pelas costas.
func _sees(player: Player) -> bool:
	if not player.perceivable():
		return false
	var target := player.body.center()
	var to := target - eye()
	var d := to.length()
	if d > sight:
		return false
	if d > CLOSE_SENSE:
		if signf(to.x) != float(facing) or absf(to.y) > BAND:
			return false
	return grid.line_clear(eye(), target)


func _think(dt: float, player: Player) -> void:
	s_t += dt
	_fall(dt)
	match s:
		S.PATROL:
			var off := body.center().x - home.x
			if absf(off) > leash and signf(off) == float(facing):
				facing = -facing
			vel.x = facing * WALK
			if _wall_ahead(facing) or not _floor_ahead(facing) or (absf(off) >= leash and signf(off) == float(facing)):
				vel.x = 0.0
				_go(S.TURN)
			if aware:
				_notice(player)
		S.TURN:
			vel.x = 0.0
			if aware:
				_notice(player)
			elif s_t >= TURN_TIME:
				facing = -facing
				_go(S.PATROL)
		S.NOTICE:
			vel.x = 0.0
			if s_t >= NOTICE_TIME:
				_go(S.CHARGE)
				fx.emit(&"vigia_charge", {"pos": body.center(), "dir": facing})
		S.CHARGE:
			vel.x = facing * CHARGE_SPEED
			if _wall_ahead(facing) or not _floor_ahead(facing) or s_t >= CHARGE_TIME:
				vel.x = 0.0
				_go(S.RECOVER)
				fx.emit(&"vigia_stop", {"pos": body.center() + Vector2(facing * 12.0, 20.0), "dir": facing})
		S.RECOVER:
			vel.x = move_toward(vel.x, 0.0, 2000.0 * dt)
			if s_t >= RECOVER_TIME:
				if aware:
					_notice(player)
				else:
					_go(S.PATROL)
	_move_body(dt)
	walk_phase += absf(vel.x) * dt * 0.09
	swing_v += (-swing * 60.0 - swing_v * 5.0 - vel.x * 0.004) * dt
	swing = clampf(swing + swing_v * dt, -0.7, 0.7)


func _notice(player: Player) -> void:
	facing = 1 if player.body.center().x >= body.center().x else -1
	_go(S.NOTICE)
	fx.emit(&"eco_notice", {"pos": eye(), "kind": kind})


func _go(ns: S) -> void:
	s = ns
	s_t = 0.0


## Investindo, o Vigia não para com o golpe (só pisca); fora disso, cambaleia.
func _on_hit(player: Player, dir: int) -> void:
	if s == S.CHARGE:
		return
	stun_t = 0.25
	if dir == 0:
		vel.x = player.facing * 150.0
	s = S.RECOVER
	s_t = RECOVER_TIME - 0.3


func _rage() -> float:
	if s == S.NOTICE or s == S.CHARGE:
		return 1.0
	return 0.55 if aware else 0.0


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _bob() -> float:
	if s == S.PATROL:
		return -absf(sin(walk_phase * PI)) * 1.6
	return sin(anim_t * 2.0) * 0.8


func _lean() -> float:
	match s:
		S.CHARGE:
			return 7.0
		S.NOTICE:
			return -2.0 - 2.0 * minf(s_t / NOTICE_TIME, 1.0)
		S.RECOVER:
			return 3.0 * (1.0 - minf(s_t / RECOVER_TIME, 1.0))
	return 0.0


func _lantern_pos() -> Vector2:
	var b := _bob()
	return Vector2(21.0 + _lean() * 0.6, -26.0 + b) + Vector2(0, 9).rotated(swing)


func _draw_body() -> void:
	var b := _bob()
	var lean := _lean()
	var col := _body_color(1.0)
	# manto: capuz alto, ombros, barra que vira fiapos de aura
	var pts := PackedVector2Array([
		Vector2(4 + lean, -35 + b), Vector2(9 + lean, -30 + b), Vector2(11.5 + lean * 0.8, -19 + b),
		Vector2(12 + lean * 0.5, -6 + b), Vector2(14 + lean * 0.3, 6 + b * 0.5)])
	pts.append_array(_wisp_tail(6.0 + b * 0.5, 14.0, 22.0, 3, 3.0))
	pts.append_array(PackedVector2Array([
		Vector2(-14 + lean * 0.2, 6 + b * 0.5), Vector2(-12 + lean * 0.4, -7 + b),
		Vector2(-11 + lean * 0.7, -21 + b), Vector2(-8 + lean, -31 + b), Vector2(-4 + lean, -39 + b)]))
	_ghost_poly(pts, -38.0, 28.0, 0.62, col)
	draw_polyline(pts, Color(COLD_CORE, 0.22 * _alpha()), 1.0, true)
	# rosto oco
	var face := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		face.append(Vector2(5.0 + lean, -24.0 + b) + Vector2(cos(a) * 5.4, sin(a) * 6.6))
	draw_colored_polygon(face, Color(HOLLOW, 0.9 * _alpha()))
	# braço e vara da lanterna
	var hand := Vector2(12.0 + lean * 0.7, -6.0 + b)
	var tip := Vector2(21.0 + lean * 0.6, -26.0 + b)
	draw_line(Vector2(6 + lean, -14 + b), hand, Color(col, 0.6 * _alpha()), 3.0, true)
	draw_line(hand + Vector2(-3, 9), tip, Color(COLD_DEEP.lerp(COLD, 0.5), 0.85 * _alpha()), 2.0, true)
	# gaiola da lanterna
	var lp := _lantern_pos()
	draw_line(tip, lp + Vector2(0, -5), Color(COLD_DEEP, 0.8 * _alpha()), 1.0, true)
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(lp + Vector2(cos(a) * 5.0, sin(a) * 6.0))
	draw_polyline(hex, Color(COLD_DEEP.lerp(COLD, 0.6), 0.9 * _alpha()), 1.4, true)


func _draw_glow(ci: CanvasItem) -> void:
	var a := _alpha()
	var b := _bob()
	var rage := _rage()
	var lp := _lantern_pos()
	var cone_col := COLD.lerp(RAGE, rage)
	# feixe da lanterna: mostra para onde o Vigia olha
	var cone_a := 0.085
	if s == S.CHARGE or s == S.RECOVER:
		cone_a = 0.025
	elif s == S.TURN:
		cone_a = 0.085 * (1.0 - minf(s_t / TURN_TIME, 1.0) * 0.7)
	elif s == S.NOTICE:
		cone_a = 0.16
	var steps := 10
	var pts := PackedVector2Array([lp])
	var cols := PackedColorArray([Color(cone_col, cone_a * 1.6 * a)])
	for i in range(steps + 1):
		var ang := lerpf(-CONE_HALF, CONE_HALF, float(i) / steps) + swing * 0.15
		pts.append(lp + Vector2(cos(ang), sin(ang)) * CONE_LEN)
		cols.append(Color(cone_col, 0.0))
	ci.draw_polygon(pts, cols)
	# núcleo da lanterna
	var pulse := 0.85 + 0.15 * sin(anim_t * 5.0) + (0.5 if s == S.NOTICE else 0.0)
	ci.draw_circle(lp, 7.0 * pulse, Color(cone_col, 0.3 * a))
	ci.draw_circle(lp, 3.0, Color(COLD_CORE.lerp(RAGE, rage * 0.6), 0.95 * a))
	_draw_eyes(ci, Vector2(5.5 + _lean(), -24.5 + b), 4.6, 1.3)
