class_name Penitente
extends Eco
## O monge que jurou que ninguém leria o que foi guardado no Arquivo. Ergueu o
## muro com as próprias mãos e nunca mais largou a última pedra: carrega a laje
## na frente do corpo, como escudo. De frente, o cajado só tilinta nela; quando
## a Vela chega perto, ele ergue a laje e a desce com tudo.
##
## Para passar por ele: pelas costas (o Zetsu ajuda), quebrando a laje (Shu ou
## Ko) ou aparando a pancada com o Ken — ele cambaleia e fica aberto.

enum S { GUARD, WALK, RAISE, SLAM, RECOVER, STAGGER }

const SIZE := Vector2(30, 50)
const WALK := 46.0
const WALK_BARE := 74.0
const RAISE_TIME := 0.62
const SLAM_TIME := 0.16
const RECOVER_TIME := 0.9
const STAGGER_TIME := 1.6
## Distância (à frente) em que ele decide bater.
const REACH := 86.0
const SLAB_HP := 2
const BAND := 90.0
const CLOSE_SENSE := 52.0

var s := S.GUARD
var s_t := 0.0
var has_slab := true
var slab_hp := SLAB_HP
## Dano da pancada (a laje desce com o peso todo).
var strike_damage := 2
var walk_phase := 0.0
## Brilho da laje quando o cajado bate nela (desenho).
var slab_flash := 0.0
var _slam_hit := false
var _slab: Slab


func _init() -> void:
	body.size = SIZE
	hp = 5
	max_hp = 5
	kind = "penitente"
	sight = 280.0
	leash = 6.0 * 32.0
	memory_time = 2.2


func _ready() -> void:
	super._ready()
	_slab = Slab.new()
	_slab.eco = self
	add_child(_slab)
	move_child(_slab, 0)


## Curvado sob a pedra, só enxerga para a frente; de muito perto sente pelas costas.
func _sees(player: Player) -> bool:
	if not player.perceivable():
		return false
	var target := player.body.center()
	var to := target - eye()
	var d := to.length()
	if d > sight:
		return false
	if d > CLOSE_SENSE and (signf(to.x) != float(facing) or absf(to.y) > BAND):
		return false
	return grid.line_clear(eye(), target)


func eye() -> Vector2:
	return body.center() + Vector2(facing * 9.0, -14.0)


func _think(dt: float, player: Player) -> void:
	s_t += dt
	_fall(dt)
	var pc := player.body.center()
	var dx := pc.x - body.center().x
	match s:
		S.GUARD:
			vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
			if aware:
				_go(S.WALK)
		S.WALK:
			if not aware:
				var off := home.x - body.center().x
				if absf(off) > 8.0:
					facing = int(signf(off))
					vel.x = facing * WALK * 0.7
					if _wall_ahead(facing) or not _floor_ahead(facing):
						vel.x = 0.0
						_go(S.GUARD)
				else:
					vel.x = 0.0
					_go(S.GUARD)
			else:
				facing = 1 if dx >= 0.0 else -1
				vel.x = facing * (WALK if has_slab else WALK_BARE)
				if _wall_ahead(facing) or not _floor_ahead(facing):
					vel.x = 0.0
				if absf(dx) < REACH and absf(pc.y - body.center().y) < 70.0:
					vel.x = 0.0
					_go(S.RAISE)
					fx.emit(&"penitente_raise", {"pos": body.center(), "slab": has_slab})
		S.RAISE:
			vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
			if s_t >= _raise_time():
				_go(S.SLAM)
				_slam_hit = false
		S.SLAM:
			if s_t >= SLAM_TIME:
				_go(S.RECOVER)
				fx.emit(&"penitente_slam", {"pos": slam_point(), "dir": facing, "slab": has_slab})
		S.RECOVER:
			if s_t >= RECOVER_TIME:
				_go(S.WALK if aware else S.GUARD)
		S.STAGGER:
			vel.x = move_toward(vel.x, 0.0, 700.0 * dt)
			if s_t >= STAGGER_TIME:
				_go(S.WALK if aware else S.GUARD)
	_move_body(dt)
	walk_phase += absf(vel.x) * dt * 0.08


func _raise_time() -> float:
	return RAISE_TIME if has_slab else RAISE_TIME * 0.75


func _go(ns: S) -> void:
	s = ns
	s_t = 0.0


## Onde a laje bate no chão.
func slam_point() -> Vector2:
	return Vector2(body.center().x + facing * 42.0, body.pos.y + body.size.y)


## Área da pancada (só enquanto a laje desce, uma vez por pancada).
func strike_rect() -> Rect2:
	if s != S.SLAM or _slam_hit or not alive():
		return Rect2()
	var w := 72.0 if has_slab else 52.0
	var x := body.pos.x + body.size.x - 6.0 if facing > 0 else body.pos.x + 6.0 - w
	return Rect2(x, body.pos.y - 12.0, w, body.size.y + 12.0)


func on_hit_player(_player: Player) -> void:
	_slam_hit = true


## De frente, com a laje erguida diante do corpo, o cajado só tilinta nela.
func _guarding(player: Player, dir: int) -> bool:
	if not has_slab or dir != 0:
		return false
	if s != S.GUARD and s != S.WALK and s != S.RAISE:
		return false
	# erguendo a laje, a frente fica aberta
	if s == S.RAISE and s_t > _raise_time() * 0.4:
		return false
	return signf(player.body.center().x - body.center().x) == float(facing)


func on_struck(player: Player, dir: int, is_pogo: bool) -> bool:
	if not alive():
		return false
	if _guarding(player, dir):
		aware = true
		memory = memory_time
		last_blocked = true
		if player.ko_strike:
			_break_slab(player)
			return super.on_struck(player, dir, is_pogo)
		if player.shu_active():
			slab_hp -= 1
			if slab_hp <= 0:
				_break_slab(player)
				_go(S.STAGGER)
				s_t = STAGGER_TIME * 0.4
				return true
			slab_flash = 1.0
			fx.emit(&"slab_crack", {"pos": slab_center(), "dir": player.facing})
			return true
		slab_flash = 0.6
		fx.emit(&"penitente_block", {"pos": slab_center(), "dir": player.facing})
		return true
	return super.on_struck(player, dir, is_pogo)


func _break_slab(player: Player) -> void:
	has_slab = false
	slab_hp = 0
	fx.emit(&"slab_break", {"pos": slab_center(), "dir": player.facing})


func slab_center() -> Vector2:
	return body.center() + Vector2(facing * 20.0, -2.0)


## Golpe que passou: pesado demais para recuar, só estremece (e não larga a
## pancada no meio).
func _on_hit(player: Player, _dir: int) -> void:
	if s == S.RAISE or s == S.SLAM:
		return
	stun_t = 0.15
	vel.x = player.facing * 60.0


## Ken: a pancada bate na aura da Vela e volta. Ele cambaleia com a laje caída.
func _on_parried(_player: Player) -> void:
	stun_t = 0.0
	vel = Vector2(-facing * 90.0, 0.0)
	_slam_hit = true
	_go(S.STAGGER)


## Pesado: a explosão do Ren fere, mas mal o move.
func on_ren_burst(player: Player, center: Vector2, radius: float) -> void:
	if not alive() or (body.center() - center).length() > radius + maxf(body.size.x, body.size.y) * 0.5:
		return
	super.on_ren_burst(player, center, radius)
	vel *= 0.2
	stun_t = minf(stun_t, 0.25)


func _process(delta: float) -> void:
	slab_flash = move_toward(slab_flash, 0.0, delta * 3.0)
	super._process(delta)


func _rage() -> float:
	if s == S.RAISE or s == S.SLAM:
		return 1.0
	return 0.6 if aware else 0.0


# ---------------------------------------------------------------------------
# Pose (só desenho)
# ---------------------------------------------------------------------------

## Laje: centro (olhando para a direita, origem no centro do corpo) e ângulo.
func slab_pose() -> Array:
	var guard := [Vector2(25, 4), 0.0]
	var raised := [Vector2(2, -44), -PI * 0.5]
	var down := [Vector2(46, 13), PI * 0.5]
	var dropped := [Vector2(28, 2), 0.35]
	match s:
		S.RAISE:
			var k := clampf(s_t / _raise_time(), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var tremble := Vector2(sin(anim_t * 70.0), 0) * 0.8 * k
			return [(guard[0] as Vector2).lerp(raised[0], k) + tremble, lerpf(guard[1], raised[1], k)]
		S.SLAM:
			var k2 := clampf(s_t / SLAM_TIME, 0.0, 1.0)
			k2 = k2 * k2
			var mid := (raised[0] as Vector2).lerp(down[0], k2) + Vector2(0, -sin(k2 * PI) * 16.0)
			return [mid, lerpf(raised[1], down[1], k2)]
		S.RECOVER:
			var k3 := clampf((s_t - (RECOVER_TIME - 0.28)) / 0.28, 0.0, 1.0)
			k3 = k3 * k3 * (3.0 - 2.0 * k3)
			return [(down[0] as Vector2).lerp(guard[0], k3), lerpf(down[1], guard[1], k3)]
		S.STAGGER:
			var k4 := clampf((s_t - (STAGGER_TIME - 0.3)) / 0.3, 0.0, 1.0)
			return [(dropped[0] as Vector2).lerp(guard[0], k4), lerpf(dropped[1], guard[1], k4)]
	return guard


func _hunch() -> float:
	match s:
		S.RAISE:
			return -4.0 * clampf(s_t / _raise_time(), 0.0, 1.0)
		S.SLAM:
			return 6.0
		S.RECOVER:
			return 6.0 * (1.0 - clampf(s_t / RECOVER_TIME, 0.0, 1.0))
		S.STAGGER:
			return -6.0
	return 0.0


func _bob() -> float:
	if s == S.WALK:
		return -absf(sin(walk_phase * PI)) * 1.4
	return sin(anim_t * 1.6) * 0.6


func _draw_body() -> void:
	var b := _bob()
	var h := _hunch()
	var col := _body_color(1.0)
	# manto curvado: capuz à frente, corcunda atrás, barra em fiapos de aura
	var pts := PackedVector2Array([
		Vector2(15 + h, -13 + b), Vector2(13 + h * 0.8, -5 + b), Vector2(13 + h * 0.4, 6 + b * 0.5)])
	pts.append_array(_wisp_tail(10.0 + b * 0.5, 14.0, 22.0, 3, 2.6))
	pts.append_array(PackedVector2Array([
		Vector2(-15, 8 + b * 0.5), Vector2(-16 + h * 0.2, -8 + b), Vector2(-12 + h * 0.5, -21 + b),
		Vector2(-3 + h * 0.8, -27 + b), Vector2(7 + h, -25 + b), Vector2(13 + h, -19 + b)]))
	_ghost_poly(pts, -27.0, 30.0, 0.6, col)
	draw_polyline(pts, Color(COLD_CORE, 0.2 * _alpha()), 1.0, true)
	# rosto oco sob o capuz
	var face := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		face.append(Vector2(9.5 + h, -15.0 + b) + Vector2(cos(a) * 4.6, sin(a) * 5.6))
	draw_colored_polygon(face, Color(HOLLOW, 0.9 * _alpha()))
	# braços até a laje
	var pose := slab_pose()
	var sc: Vector2 = pose[0]
	var sa: float = pose[1]
	var grip := sc + Vector2(-9, 0).rotated(sa) if has_slab else Vector2(16 + h, 2 + b)
	if not has_slab and (s == S.RAISE or s == S.SLAM):
		grip = sc
	var arm_col := Color(col, 0.55 * _alpha())
	draw_line(Vector2(4 + h * 0.6, -10 + b), grip + Vector2(0, -6), arm_col, 3.0, true)
	draw_line(Vector2(-2 + h * 0.5, -6 + b), grip + Vector2(0, 6), arm_col, 3.0, true)


func _draw_glow(ci: CanvasItem) -> void:
	_draw_eyes(ci, Vector2(10.0 + _hunch(), -15.5 + _bob()), 4.4, 1.25)
	if s == S.RAISE:
		var k := clampf(s_t / _raise_time(), 0.0, 1.0)
		var sc: Vector2 = slab_pose()[0]
		ci.draw_circle(sc, 18.0 + 10.0 * k, Color(RAGE, 0.06 + 0.08 * k))


## A laje de pedra: objeto de verdade, iluminado pela luz da sala (não é aura).
class Slab extends Node2D:
	const STONE := Color("6e6a64")
	const STONE_HI := Color("a29c90")
	const STONE_DEEP := Color("2c2a27")
	var eco: Penitente

	func _process(_delta: float) -> void:
		scale.x = float(eco.facing)
		modulate.a = eco._alpha()
		queue_redraw()

	func _draw() -> void:
		if not eco.has_slab or eco.dead:
			return
		var pose := eco.slab_pose()
		var c: Vector2 = pose[0]
		var a: float = pose[1]
		draw_set_transform(c, a, Vector2.ONE)
		var w := 24.0
		var h := 42.0
		var pts := PackedVector2Array([Vector2(-w * 0.5 + 2, -h * 0.5), Vector2(w * 0.5 - 3, -h * 0.5 + 1),
			Vector2(w * 0.5, -h * 0.5 + 5), Vector2(w * 0.5 - 1, h * 0.5 - 2), Vector2(w * 0.5 - 4, h * 0.5),
			Vector2(-w * 0.5 + 1, h * 0.5), Vector2(-w * 0.5, h * 0.5 - 6), Vector2(-w * 0.5, -h * 0.5 + 3)])
		var lit := STONE.lerp(Color.WHITE, eco.slab_flash * 0.35)
		var cols := PackedColorArray()
		for q in pts:
			cols.append(STONE_DEEP.lerp(lit, clampf(0.55 + q.x / w * 0.6 - q.y / h * 0.3, 0.0, 1.0)))
		draw_polygon(pts, cols)
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, STONE_DEEP, 1.4, true)
		draw_line(Vector2(-w * 0.5 + 3, -h * 0.5 + 2), Vector2(w * 0.5 - 4, -h * 0.5 + 2), Color(STONE_HI, 0.6), 1.2, true)
		# o selo do Arquivo gravado na pedra
		var hex := PackedVector2Array()
		for i in 7:
			var ang := -PI / 2.0 + i * TAU / 6.0
			hex.append(Vector2(0, -4) + Vector2(cos(ang), sin(ang)) * 6.5)
		draw_polyline(hex, STONE_DEEP, 1.6, true)
		draw_line(Vector2(-3, -4), Vector2(3, -4), STONE_DEEP, 1.2)
		# rachaduras (Shu)
		var cracks := Penitente.SLAB_HP - eco.slab_hp
		if cracks > 0:
			draw_polyline(PackedVector2Array([Vector2(-10, -12), Vector2(-3, -6), Vector2(-5, 3), Vector2(4, 10), Vector2(2, 19)]), STONE_DEEP, 1.6, true)
			draw_polyline(PackedVector2Array([Vector2(-3, -6), Vector2(6, -11), Vector2(11, -9)]), STONE_DEEP, 1.2, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
