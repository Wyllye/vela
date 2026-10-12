class_name Eco
extends Node2D
## Eco: o Nen póstumo de um monge de Vesperal, preso ao último voto que fez.
## Cada tipo repete o voto como comportamento (vigia.gd, saltador.gd,
## mariposa.gd) — o comportamento é um pedaço da história.
##
## A lógica roda em `step(dt, player)` sem depender da árvore de cenas (os
## testes chamam direto); o desenho fica no `_draw` de cada tipo. Os Ecos
## enxergam a chama da Vela: no Zetsu ela some para eles.
## Origem do nó = centro do corpo.

signal fx(event: StringName, data: Dictionary)

## Aura fria dos Ecos (a cor viva da tela continua sendo a da Vela).
const COLD := Color("a9cfdc")
const COLD_DEEP := Color("40606f")
const COLD_CORE := Color("e8f7fc")
const HOLLOW := Color("070a0e")
const RAGE := Color("ff8a6e")
const GRAVITY := 2100.0
const MAX_FALL := 820.0
const DIE_TIME := 0.75

var grid: LevelGrid
var body := GridBody.new()
var vel := Vector2.ZERO
var facing := 1
var hp := 2
var max_hp := 2
var contact_damage := 1
## Centro de origem e quanto o Eco se afasta dele quando não está caçando.
var home := Vector2.ZERO
var leash := 6.0 * 32.0
## Percebe a Vela agora (ou ainda lembra dela).
var aware := false
var memory := 0.0
## Até onde enxerga a chama, e por quanto tempo lembra depois de perdê-la.
var sight := 280.0
var memory_time := 1.6
var flash := 0.0
var stun_t := 0.0
var dying_t := -1.0
var dead := false
var anim_t := 0.0
var kind := "eco"
var rng := RandomNumberGenerator.new()
var _light: PointLight2D
var _glow: Sprite2D
var _overlay: Overlay
## Silhueta do último desenho (a camada aditiva contorna com brilho).
var _sil := PackedVector2Array()


## Coloca o Eco em pé (ou pairando, nos voadores) na célula do marcador.
func setup(level: LevelGrid, cell: Vector2i) -> void:
	grid = level
	var ts := float(level.tile_size)
	body.pos = Vector2(cell.x * ts + (ts - body.size.x) * 0.5, (cell.y + 1) * ts - body.size.y)
	home = body.center()
	rng.seed = cell.x * 7919 + cell.y * 104729 + 17
	anim_t = rng.randf() * 10.0
	_sync()


func _ready() -> void:
	material = FX.unshaded()
	_glow = FX.make_glow(Color(COLD, 0.3), maxf(body.size.x, body.size.y) * 3.2)
	add_child(_glow)
	_light = FX.make_light(COLD, 150.0, 0.55)
	add_child(_light)
	_overlay = Overlay.new()
	_overlay.eco = self
	add_child(_overlay)
	reset_physics_interpolation()


# ---------------------------------------------------------------------------
# Passo
# ---------------------------------------------------------------------------

func step(dt: float, player: Player) -> void:
	anim_t += dt
	flash = move_toward(flash, 0.0, dt * 5.0)
	if dead:
		return
	if dying_t >= 0.0:
		dying_t += dt
		vel = vel.move_toward(Vector2(0, -30), 400.0 * dt)
		body.pos += vel * dt
		if dying_t >= DIE_TIME:
			dead = true
		_sync()
		return
	_update_awareness(dt, player)
	if stun_t > 0.0:
		stun_t -= dt
		_update_stunned(dt)
	else:
		_think(dt, player)
	_sync()


## Comportamento de cada tipo (o voto).
func _think(_dt: float, _player: Player) -> void:
	pass


func _update_awareness(dt: float, player: Player) -> void:
	if _sees(player):
		if not aware:
			_on_spotted(player)
		aware = true
		memory = memory_time
		return
	memory -= dt
	# apagada no Zetsu, a Vela some depressa da memória dos Ecos
	if not player.perceivable():
		memory = minf(memory, 0.35)
	if memory <= 0.0:
		aware = false


func _on_spotted(_player: Player) -> void:
	pass


## Vê a chama da Vela: perto o bastante e sem rocha no caminho.
func _sees(player: Player) -> bool:
	if not player.perceivable():
		return false
	var target := player.body.center()
	if target.distance_to(eye()) > sight:
		return false
	return grid.line_clear(eye(), target)


func eye() -> Vector2:
	return body.center() + Vector2(0, -body.size.y * 0.22)


func _update_stunned(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
	_fall(dt)
	_move_body(dt)


# ---------------------------------------------------------------------------
# Golpes
# ---------------------------------------------------------------------------

func alive() -> bool:
	return not dead and dying_t < 0.0


func harmful() -> bool:
	return alive()


func hit_rect() -> Rect2:
	return body.rect().grow(4.0)


func contact_rect() -> Rect2:
	return body.rect().grow(-3.0)


## Golpe do cajado. Atacar um Eco desatento (pelas costas, no Zetsu) fere mais.
func on_struck(player: Player, dir: int, _is_pogo: bool) -> bool:
	if not alive():
		return false
	var was_aware := aware
	var dmg := player.strike_damage(was_aware)
	hp -= dmg
	flash = 1.0
	aware = true
	memory = memory_time
	_on_hit(player, dir)
	fx.emit(&"eco_hit", {"pos": body.center(), "dmg": dmg, "sneak": not was_aware, "kind": kind,
		"dir": dir, "facing": player.facing, "ren": player.ren})
	if hp <= 0:
		_start_dying(player)
	return true


## Reação ao golpe (cada tipo ajusta): recua e fica atordoado um instante.
func _on_hit(player: Player, dir: int) -> void:
	stun_t = 0.2
	match dir:
		1:
			vel.y = maxf(vel.y, 160.0)
		-1:
			vel.y = -260.0
		_:
			vel.x = player.facing * 190.0


## Explosão do Ren: empurra para longe e atordoa.
func on_ren_burst(player: Player, center: Vector2, radius: float) -> void:
	if not alive():
		return
	var to := body.center() - center
	if to.length() > radius + maxf(body.size.x, body.size.y) * 0.5:
		return
	aware = true
	memory = memory_time
	flash = 1.0
	hp -= 1
	var dir := to.normalized() if to.length() > 1.0 else Vector2(player.facing, 0)
	vel = dir * 430.0 + Vector2(0, -170.0)
	stun_t = 0.6
	fx.emit(&"eco_hit", {"pos": body.center(), "dmg": 1, "sneak": false, "kind": kind, "dir": 0, "facing": int(signf(dir.x)), "ren": true})
	if hp <= 0:
		_start_dying(player)


func _start_dying(player: Player) -> void:
	dying_t = 0.0
	stun_t = 0.0
	vel = Vector2(player.facing * 60.0, -40.0)
	fx.emit(&"eco_die", {"pos": body.center(), "kind": kind})


## A Vela levou o golpe de contato (alguns tipos reagem).
func on_hit_player(_player: Player) -> void:
	pass


# ---------------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------------

func _fall(dt: float) -> void:
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)


## Move pela grade (véus são paredes para os Ecos). Devolve se bateu em x e em y.
func _move_body(dt: float) -> Vector2i:
	var hx := false
	var hy := false
	if vel.x != 0.0:
		hx = grid.move_x(body, vel.x * dt)
		if hx:
			vel.x = 0.0
	if vel.y != 0.0:
		hy = grid.move_y(body, vel.y * dt)
		if hy:
			vel.y = 0.0
	_keep_inside()
	return Vector2i(int(hx), int(hy))


func _keep_inside() -> void:
	var s := grid.pixel_size()
	body.pos.x = clampf(body.pos.x, 2.0, s.x - body.size.x - 2.0)
	body.pos.y = clampf(body.pos.y, 2.0, s.y - body.size.y - 2.0)


func on_ground() -> bool:
	return vel.y >= 0.0 and grid.is_grounded(body)


## Chão firme logo à frente (não anda para o vazio nem para espinhos).
func _floor_ahead(dir: int) -> bool:
	var ts := float(grid.tile_size)
	var x := body.pos.x + (body.size.x + 3.0 if dir > 0 else -3.0)
	var c := floori(x / ts)
	var r := floori((body.pos.y + body.size.y + 2.0) / ts)
	return grid.is_solid(c, r) or grid.get_cell(c, r) == LevelGrid.Tile.ONE_WAY


func _wall_ahead(dir: int) -> bool:
	return grid.overlaps_solid(body.pos + Vector2(dir * 3.0, -1.0), body.size)


## Voa até um ponto com velocidade e aceleração limitadas.
func _steer(target: Vector2, max_speed: float, accel: float, dt: float) -> void:
	var d := target - body.center()
	var want := Vector2.ZERO
	if d.length() > 1.0:
		want = d.normalized() * minf(max_speed, d.length() * 2.6)
	vel = vel.move_toward(want, accel * dt)


func _sync() -> void:
	position = body.center()


# ---------------------------------------------------------------------------
# Sala inteira
# ---------------------------------------------------------------------------

## Passo de todos os Ecos de uma sala e dano por contato na Vela.
static func update_all(ecos: Array, dt: float, player: Player) -> void:
	for e in ecos:
		if is_instance_valid(e):
			e.step(dt, player)
	if not player.can_be_hit():
		return
	var hb := player.hurtbox()
	for e in ecos:
		if is_instance_valid(e) and e.harmful() and e.contact_rect().intersects(hb):
			if player.take_hit(e.contact_damage, e.body.center()):
				e.on_hit_player(player)
			return


# ---------------------------------------------------------------------------
# Desenho comum
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if dead:
		visible = false
		return
	var a := _alpha()
	if _glow:
		_glow.modulate = Color(COLD.lerp(Color.WHITE, flash), (0.22 + 0.25 * flash) * a)
	if _light:
		_light.energy = (0.5 + 0.9 * flash) * a
		_light.color = COLD.lerp(RAGE, 0.35 * _rage())
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Corpo do Eco (mistura normal), desenhado olhando para a direita.
func _draw_body() -> void:
	pass


## Brilhos aditivos (olhos, lanterna, rastros), também olhando para a direita.
func _draw_glow(_ci: CanvasItem) -> void:
	pass


## 0..1 sumindo ao morrer.
func _alpha() -> float:
	if dying_t < 0.0:
		return 1.0
	return clampf(1.0 - dying_t / DIE_TIME, 0.0, 1.0)


## 0..1: quão hostil o Eco está agora (olhos esquentam).
func _rage() -> float:
	return 1.0 if aware else 0.0


## Cor do corpo: aura fria, branca no golpe.
func _body_color(a: float) -> Color:
	var c := COLD.lerp(Color.WHITE, flash * 0.8)
	return Color(c, a * _alpha())


func _draw_eyes(ci: CanvasItem, at: Vector2, gap: float, size: float) -> void:
	var col := COLD_CORE.lerp(RAGE, _rage() * 0.85)
	var a := _alpha()
	for side in [-1.0, 1.0]:
		var p := at + Vector2(gap * 0.5 * side, 0)
		ci.draw_circle(p, size * 2.4, Color(col, 0.16 * a))
		ci.draw_circle(p, size, Color(col.lerp(Color.WHITE, 0.4), 0.95 * a))


## Polígono com degradê vertical: forte em cima, some embaixo (fantasma).
## Guarda a silhueta para a camada aditiva contornar com brilho.
func _ghost_poly(pts: PackedVector2Array, top_y: float, bottom_y: float, top_a: float, base: Color) -> void:
	var cols := PackedColorArray()
	for q in pts:
		var k := clampf((q.y - top_y) / maxf(bottom_y - top_y, 1.0), 0.0, 1.0)
		var c := base.lerp(COLD_DEEP, k * 0.6)
		cols.append(Color(c, top_a * (1.0 - k * k) * _alpha()))
	draw_polygon(pts, cols)
	_sil = pts


## Brilho aditivo da silhueta: o Eco é feito de aura, as bordas acendem.
func _draw_sil_glow(ci: CanvasItem) -> void:
	if _sil.size() < 3:
		return
	var a := _alpha() * (0.55 + 0.45 * flash)
	var c := COLD.lerp(Color.WHITE, flash * 0.6)
	var cols := PackedColorArray()
	var top := INF
	var bottom := -INF
	for q in _sil:
		top = minf(top, q.y)
		bottom = maxf(bottom, q.y)
	for q in _sil:
		var k := clampf((q.y - top) / maxf(bottom - top, 1.0), 0.0, 1.0)
		cols.append(Color(c, (0.13 + 0.12 * flash) * (1.0 - k) * a))
	ci.draw_polygon(_sil, cols)
	var edge := _sil.duplicate()
	edge.append(_sil[0])
	ci.draw_polyline(edge, Color(c, 0.16 * a), 1.6, true)


## Caudas ondulantes de aura na barra (o Eco não tem pés).
func _wisp_tail(top_y: float, half_w: float, length: float, count: int, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count * 2 + 1):
		var u := float(i) / float(count * 2)
		var x := lerpf(half_w, -half_w, u)
		var tip := i % 2 == 1
		var y := top_y + (length if tip else length * 0.45)
		x += sin(anim_t * 4.0 + u * 7.0) * sway * (1.0 if tip else 0.4)
		pts.append(Vector2(x, y))
	return pts


## Camada aditiva do Eco (olhos, lanterna, rastros): brilha no escuro.
class Overlay extends Node2D:
	var eco: Eco

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		if eco.dead:
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(eco.facing, 1))
		eco._draw_sil_glow(self)
		eco._draw_glow(self)
