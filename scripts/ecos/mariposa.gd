class_name Mariposa
extends Eco
## Voadora. Jurou velar toda chama acesa no Poço — e ainda vela: ronda a chama
## da Vela como mariposa e mergulha nela. Quando a chama apaga (Zetsu), perde o
## interesse e volta a pairar sobre as velas.

enum S { DRIFT, CIRCLE, WINDUP, DIVE, RISE }

const SIZE := Vector2(26, 24)
const ORBIT := 140.0
const CIRCLE_SPEED := 190.0
const DIVE_SPEED := 520.0
const WINDUP_TIME := 0.45
const DIVE_TIME := 0.5
const RISE_TIME := 0.55

var s := S.DRIFT
var s_t := 0.0
var cooldown := 1.2
var orbit_a := 0.0
var dive_dir := Vector2.RIGHT
var flap := 0.0


func _init() -> void:
	body.size = SIZE
	hp = 2
	max_hp = 2
	kind = "mariposa"
	sight = 340.0
	memory_time = 1.2


## Voadora: fica pairando no meio da célula do marcador.
func setup(level: LevelGrid, cell: Vector2i) -> void:
	super.setup(level, cell)
	var ts := float(level.tile_size)
	body.pos = Vector2((cell.x + 0.5) * ts, (cell.y + 0.5) * ts) - SIZE * 0.5
	home = body.center()
	orbit_a = rng.randf() * TAU
	_sync()


func _think(dt: float, player: Player) -> void:
	s_t += dt
	var pc := player.body.center()
	match s:
		S.DRIFT:
			var target := home + Vector2(sin(anim_t * 0.7) * 70.0, sin(anim_t * 1.4) * 26.0)
			_steer(target, 110.0, 380.0, dt)
			if aware:
				_go(S.CIRCLE)
				cooldown = 1.0
		S.CIRCLE:
			if not aware:
				_go(S.DRIFT)
			else:
				orbit_a += dt * 0.9
				var off := Vector2(cos(orbit_a) * ORBIT, -absf(sin(orbit_a)) * ORBIT * 0.55 - 40.0)
				_steer(pc + off, CIRCLE_SPEED, 700.0, dt)
				cooldown -= dt
				if cooldown <= 0.0 and grid.line_clear(body.center(), pc):
					_go(S.WINDUP)
					fx.emit(&"mariposa_windup", {"pos": body.center()})
		S.WINDUP:
			var away := (body.center() - pc).normalized()
			vel = vel.move_toward(away * 70.0, 900.0 * dt)
			dive_dir = (pc - body.center()).normalized()
			if s_t >= WINDUP_TIME:
				_go(S.DIVE)
				vel = dive_dir * DIVE_SPEED
				fx.emit(&"mariposa_dive", {"pos": body.center(), "dir": dive_dir})
		S.DIVE:
			vel = dive_dir * DIVE_SPEED
			if s_t >= DIVE_TIME:
				_go(S.RISE)
		S.RISE:
			vel = vel.move_toward(Vector2(0, -150.0), 1200.0 * dt)
			if s_t >= RISE_TIME:
				_go(S.CIRCLE if aware else S.DRIFT)
				cooldown = rng.randf_range(1.8, 2.6)
	var hit := _move_body(dt)
	if s == S.DIVE and (hit.x != 0 or hit.y != 0):
		_go(S.RISE)
		fx.emit(&"mariposa_bonk", {"pos": body.center()})
	if s == S.WINDUP or s == S.DIVE:
		facing = 1 if dive_dir.x >= 0.0 else -1
	elif aware:
		facing = 1 if pc.x >= body.center().x else -1
	elif absf(vel.x) > 10.0:
		facing = 1 if vel.x > 0.0 else -1


func _go(ns: S) -> void:
	s = ns
	s_t = 0.0


func _on_hit(player: Player, dir: int) -> void:
	stun_t = 0.3
	match dir:
		1:
			vel = Vector2(vel.x * 0.3, 260.0)
		-1:
			vel = Vector2(vel.x * 0.3, -260.0)
		_:
			vel = Vector2(player.facing * 260.0, -40.0)
	_go(S.RISE)


func _on_parried(_player: Player) -> void:
	_go(S.RISE)
	cooldown = 2.4


## Voadora atordoada: plana e freia, sem gravidade.
func _update_stunned(dt: float) -> void:
	vel = vel.move_toward(Vector2.ZERO, 700.0 * dt)
	_move_body(dt)


func _rage() -> float:
	if s == S.WINDUP or s == S.DIVE:
		return 1.0
	return 0.45 if aware else 0.0


func _process(delta: float) -> void:
	var speed := 14.0 if s == S.DRIFT else 20.0
	if s == S.WINDUP:
		speed = 34.0
	elif s == S.DIVE:
		speed = 4.0
	flap += delta * speed
	super._process(delta)


# ---------------------------------------------------------------------------
# Desenho (as asas não espelham: a mariposa é simétrica)
# ---------------------------------------------------------------------------

func _wing(side: float) -> PackedVector2Array:
	var open := 0.55 + 0.45 * sin(flap)
	if s == S.DIVE:
		open = 0.12
	var pts := PackedVector2Array()
	var root := Vector2(side * 3.0, -3.0)
	for i in range(13):
		var u := float(i) / 12.0
		var a := lerpf(-1.25, 1.05, u)
		var r := (20.0 + 7.0 * sin(u * PI)) * (0.35 + 0.65 * open)
		var q := Vector2(cos(a) * r * side, sin(a) * r * 0.75)
		pts.append(root + q)
	pts.append(root)
	return pts


func _draw() -> void:
	# sem espelhar: só o rosto olha para o lado
	var col := _body_color(1.0)
	var a := _alpha()
	for side in [-1.0, 1.0]:
		var w := _wing(side)
		var cols := PackedColorArray()
		for q in w:
			var k := clampf(q.length() / 26.0, 0.0, 1.0)
			cols.append(Color(col.lerp(COLD_DEEP, k * 0.5), (0.5 - 0.38 * k) * a))
		draw_polygon(w, cols)
		draw_polyline(w, Color(COLD_CORE, 0.18 * a), 1.0, true)
	# corpo: capuz pequeno e fiapos
	var bodyp := PackedVector2Array()
	for i in range(13):
		var ang := lerpf(PI * 0.85, PI * 2.15, float(i) / 12.0)
		bodyp.append(Vector2(cos(ang) * 8.0, sin(ang) * 8.5 - 3.0))
	bodyp.append_array(_wisp_tail(1.0, 7.0, 14.0, 2, 2.0))
	_ghost_poly(bodyp, -12.0, 14.0, 0.7, col)
	var fx_ := float(facing) * 2.5
	var face := PackedVector2Array()
	for i in 12:
		var t := TAU * i / 12.0
		face.append(Vector2(fx_ + cos(t) * 4.2, -3.0 + sin(t) * 4.2))
	draw_colored_polygon(face, Color(HOLLOW, 0.92 * a))


func _draw_glow(ci: CanvasItem) -> void:
	# a camada aditiva espelha pelo facing; desfaz para desenhar no lugar certo
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var a := _alpha()
	# manchas de "olho" nas asas, como nas mariposas de verdade
	for side in [-1.0, 1.0]:
		var w := _wing(side)
		var spot := w[7].lerp(Vector2(side * 3.0, -3.0), 0.45)
		ci.draw_circle(spot, 3.2, Color(COLD, 0.22 * a))
	_draw_eyes(ci, Vector2(float(facing) * 2.5, -3.2), 3.4, 1.15)
	if s == S.WINDUP:
		var k := clampf(s_t / WINDUP_TIME, 0.0, 1.0)
		ci.draw_circle(Vector2.ZERO, 14.0 + 10.0 * k, Color(RAGE, 0.08 * k * a))
