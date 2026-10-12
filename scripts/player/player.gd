class_name Player
extends Node2D
## A Vela: movimento com física própria em grade (LevelGrid), Vitalidade
## (gotas de cera), Aura (a chama), os fundamentos do Nen (Ten, Zetsu, Ren) e
## as técnicas avançadas: Gyo (segurar), En (Gyo + ↓ no chão), Shu (golpe com
## o Ren aceso), Ko (segurar o golpe) e Ken (abrir o Ren na hora do impacto).
##
## Toda a lógica roda em `step(dt)`, sem depender da árvore de cenas — os testes
## chamam `step()` direto com um ScriptedInput. Efeitos (som, partículas,
## câmera) saem pelo sinal `fx`; quem desenha é o PlayerView.

signal fx(event: StringName, data: Dictionary)

enum State { NORMAL, DASH, HURT, RESPAWN, INTRO_FALL, WAKE, REST, LOCKED, ENTER, KNOCKBACK, DEAD }

const SIZE := Vector2(22, 44)
const DASH_BUFFER := 0.08
const ATTACK_BUFFER := 0.10
const DROP_TIME := 0.18
const HURT_TIME := 0.38
const RESPAWN_BLACK := 0.30
const RESPAWN_TIME := 0.62
const WAKE_TIME := 1.8
const REVIVE_WAKE_TIME := 1.25
const LOOK_DELAY := 0.45
const RECOIL_TIME := 0.08

@export var tuning: MovementTuning
@export var nen: NenTuning

var grid: LevelGrid
var input: PlayerInput = PlayerInput.new()
var body := GridBody.new()
var vel := Vector2.ZERO
var facing := 1
var state: State = State.NORMAL
var state_time := 0.0

## Habilidades de movimento liberadas (todas ligadas até a Etapa 5).
var abilities := {"dash": true, "wall": true, "air_jump": true, "pogo": true}

# --- Nen e vida ---
## Técnicas aprendidas. O padrão (tudo) serve aos testes e ao --room; um jogo
## novo começa sem nenhuma (main.gd).
var learned := {"ten": true, "zetsu": true, "ren": true, "gyo": true, "shu": true, "ken": true, "ko": true, "en": true}
var vitality := 5
var vitality_max := 5
var aura := 100.0
## Aura máxima atual: cai quando o Eco póstumo guarda parte dela.
var aura_max := 100.0
var zetsu := false
var ren := false
## Gyo: aura nos olhos (revela a escrita em aura e o que o In esconde).
var gyo := false
## O Gyo apagou por falta de aura: só reacende soltando e apertando de novo.
var gyo_spent := false
## En: tempo ajoelhada concentrando (> 0 enquanto ajoelha) e se já espalhou.
var en_t := 0.0
var en_fired := false
## Ko: tempo segurando o golpe depois do golpe normal, carga, pronto, golpe ativo.
var ko_hold_t := 0.0
var ko_charge := 0.0
var ko_ready := false
var ko_strike := false
var ko_damage := 0
## Janela do Ken: logo depois de abrir o Ren, o golpe que chegar é aparado.
var ken_t := 0.0
var invuln_t := 0.0
var regen_delay_t := 0.0
var recoil_t := 0.0
var recoil_vx := 0.0
var wake_len := WAKE_TIME
var deaths := 0
var hits_taken := 0
## Como a Vela joga (a Adivinhação da Água, na Etapa 4, lê isto).
var style := {"ren": 0, "zetsu_time": 0.0, "strikes": 0, "sneak": 0, "melts": 0,
	"gyo_time": 0.0, "en": 0, "ko": 0, "ken": 0, "shu": 0}

# --- chão e pulo ---
var grounded := false
var coyote_t := 0.0
var jump_buffer_t := 0.0
var jump_cuttable := false
var air_jumps_left := 1
var drop_t := 0.0
var air_time := 0.0

# --- passo de Ren (dash) ---
var dash_ready := true
var dash_t := 0.0
var dash_cd_t := 0.0
var dash_buffer_t := 0.0
var dash_dir := 1

# --- aderência (parede) ---
var wall_dir := 0
var wall_sliding := false
var wall_coyote_t := 0.0
var last_wall_dir := 0
var wall_lock_t := 0.0

# --- golpe ---
var attack_t := 0.0
var attack_cd_t := 0.0
var attack_buffer_t := 0.0
## 0 = frente, -1 = cima, 1 = baixo
var attack_dir := 0
var attack_resolved := false

# --- outros ---
var safe_pos := Vector2.ZERO
var hurt_count := 0
## -1 olhando para cima, 1 para baixo (a câmera usa)
var look := 0
var look_t := 0.0
var step_dist := 0.0
var enter_vel := Vector2.ZERO
var enter_time := 0.0
## Objetos que reagem ao golpe: precisam de hit_rect() -> Rect2 e on_struck(player, dir, is_pogo) -> bool
var strikeables: Array = []


func _init() -> void:
	body.size = SIZE
	if tuning == null:
		tuning = MovementTuning.new()
	if nen == null:
		nen = NenTuning.new()
	vitality_max = nen.vitality_max
	vitality = vitality_max
	aura_max = nen.aura_max
	aura = aura_max


func setup(level: LevelGrid, top_left: Vector2) -> void:
	grid = level
	body.pos = top_left
	vel = Vector2.ZERO
	safe_pos = top_left
	air_jumps_left = tuning.air_jumps
	_sync_node()
	if is_inside_tree():
		reset_physics_interpolation()


func _input(event: InputEvent) -> void:
	input.feed(event)


func _physics_process(delta: float) -> void:
	if grid != null:
		step(delta)


# ===========================================================================
# Tick principal
# ===========================================================================

func step(dt: float) -> void:
	input.poll()
	state_time += dt
	_tick_timers(dt)
	if (ko_charge > 0.0 or ko_hold_t > 0.0) and state != State.NORMAL:
		_cancel_ko()
	if en_t > 0.0 and state != State.NORMAL:
		en_t = 0.0
		en_fired = false
	if state != State.DEAD:
		_update_nen(dt)
	# véus só se abrem para a Vela, e só durante o Zetsu
	grid.veil_open = zetsu
	match state:
		State.NORMAL:
			_update_normal(dt)
		State.DASH:
			_update_dash(dt)
		State.HURT:
			_update_hurt(dt)
		State.RESPAWN:
			_update_respawn(dt)
		State.INTRO_FALL:
			_update_intro_fall(dt)
		State.WAKE:
			_update_wake(dt)
		State.ENTER:
			_update_enter(dt)
		State.KNOCKBACK:
			_update_knockback(dt)
		State.DEAD:
			_update_dead(dt)
		_:
			_update_locked(dt)
	grid.veil_open = false
	_sync_node()


func _tick_timers(dt: float) -> void:
	jump_buffer_t = maxf(jump_buffer_t - dt, 0.0)
	dash_buffer_t = maxf(dash_buffer_t - dt, 0.0)
	attack_buffer_t = maxf(attack_buffer_t - dt, 0.0)
	dash_cd_t = maxf(dash_cd_t - dt, 0.0)
	wall_coyote_t = maxf(wall_coyote_t - dt, 0.0)
	wall_lock_t = maxf(wall_lock_t - dt, 0.0)
	attack_t = maxf(attack_t - dt, 0.0)
	attack_cd_t = maxf(attack_cd_t - dt, 0.0)
	drop_t = maxf(drop_t - dt, 0.0)
	invuln_t = maxf(invuln_t - dt, 0.0)
	recoil_t = maxf(recoil_t - dt, 0.0)
	ken_t = maxf(ken_t - dt, 0.0)
	if attack_t <= 0.0:
		ko_strike = false
	if not grounded:
		coyote_t = maxf(coyote_t - dt, 0.0)
		air_time += dt
	else:
		air_time = 0.0


func _read_buffers() -> void:
	if input.pressed(&"jump"):
		jump_buffer_t = tuning.jump_buffer
	if input.pressed(&"dash"):
		dash_buffer_t = DASH_BUFFER
	if input.pressed(&"attack"):
		attack_buffer_t = ATTACK_BUFFER


# ===========================================================================
# Estado NORMAL: correr, pular, parede, golpe
# ===========================================================================

func _update_normal(dt: float) -> void:
	var t := tuning
	var mx := int(input.move.x)
	var my := int(input.move.y)
	_read_buffers()
	_update_ground()
	_update_wall(mx)
	_update_en(mx, my, dt)
	_update_look(mx, my, dt)

	# --- horizontal ---
	var top := t.run_speed * _speed_mult()
	var target := mx * top
	var accel: float
	if grounded:
		if mx == 0:
			accel = t.ground_decel
		elif absf(vel.x) > 1.0 and signf(vel.x) != float(mx):
			accel = t.turn_accel
		else:
			accel = t.ground_accel
	else:
		accel = t.air_accel if mx != 0 else t.air_decel
	if mx != 0 and signf(vel.x) == float(mx) and absf(vel.x) > top:
		accel = t.overspeed_decel
	if wall_lock_t > 0.0:
		accel *= 0.25
	if recoil_t > 0.0:
		vel.x = recoil_vx
	else:
		vel.x = move_toward(vel.x, target, accel * dt)

	# --- pulo (chão > parede > aéreo) ---
	if jump_buffer_t > 0.0:
		if grounded or coyote_t > 0.0:
			if my > 0 and grounded and grid.standing_only_on_one_way(body):
				_drop_through()
			else:
				_jump()
		elif abilities["wall"] and (wall_dir != 0 or wall_coyote_t > 0.0):
			_wall_jump(wall_dir if wall_dir != 0 else last_wall_dir)
		elif abilities["air_jump"] and air_jumps_left > 0:
			if not zetsu and _can_afford():
				_spend(nen.air_jump_cost)
				_air_jump()
			elif input.pressed(&"jump"):
				fx.emit(&"fizzle", {"pos": body.center()})
	if input.released(&"jump") and jump_cuttable and vel.y < 0.0:
		vel.y *= t.jump_cut_mult
		jump_cuttable = false
	if vel.y >= 0.0:
		jump_cuttable = false

	# --- gravidade ---
	var g := t.gravity
	if vel.y > 0.0:
		g *= t.fall_gravity_mult
	elif input.held(&"jump") and absf(vel.y) < t.apex_threshold:
		g *= t.apex_gravity_mult
	vel.y += g * dt
	if wall_sliding:
		vel.y = minf(vel.y, t.wall_slide_max)
	else:
		vel.y = minf(vel.y, t.fast_fall if (my > 0 and not grounded) else t.max_fall)

	# --- golpe (e o Ko, segurando o golpe) ---
	if attack_buffer_t > 0.0 and attack_cd_t <= 0.0 and ko_charge <= 0.0:
		_start_attack(my)
	_update_ko(dt)

	# --- direção ---
	if wall_sliding:
		facing = -wall_dir
	elif mx != 0 and attack_t <= tuning.attack_time - tuning.attack_active:
		facing = mx

	# --- passo de Ren ---
	if dash_buffer_t > 0.0 and abilities["dash"] and dash_ready and dash_cd_t <= 0.0:
		if zetsu or not _can_afford():
			dash_buffer_t = 0.0
			fx.emit(&"fizzle", {"pos": body.center()})
		else:
			_spend(nen.dash_cost)
			_start_dash(mx)
			_update_dash(dt)
			return

	_move(dt)
	_resolve_attack()
	_post_move(dt)


func _update_ground() -> void:
	grounded = vel.y >= 0.0 and grid.is_grounded(body, drop_t > 0.0)
	if grounded:
		coyote_t = tuning.coyote_time
		air_jumps_left = tuning.air_jumps
		dash_ready = true
		wall_lock_t = 0.0


func _update_wall(mx: int) -> void:
	var was := wall_sliding
	wall_dir = 0
	if abilities["wall"] and not grounded:
		if grid.touches_wall(body, 1):
			wall_dir = 1
		elif grid.touches_wall(body, -1):
			wall_dir = -1
	wall_sliding = wall_dir != 0 and mx == wall_dir and vel.y > 0.0
	if wall_sliding:
		wall_coyote_t = tuning.wall_coyote
		last_wall_dir = wall_dir
		air_jumps_left = tuning.air_jumps
		dash_ready = true
	if wall_sliding != was:
		fx.emit(&"wall_slide", {"on": wall_sliding, "dir": wall_dir})


func _update_look(mx: int, my: int, dt: float) -> void:
	if en_t > 0.0:
		look_t = 0.0
		look = 0
		return
	if grounded and mx == 0 and my != 0 and absf(vel.x) < 5.0:
		look_t += dt
		if look_t > LOOK_DELAY:
			look = my
	else:
		look_t = 0.0
		look = 0


func _jump() -> void:
	vel.y = -tuning.jump_velocity
	jump_cuttable = true
	jump_buffer_t = 0.0
	coyote_t = 0.0
	grounded = false
	fx.emit(&"jump", {"pos": body.feet()})


func _air_jump() -> void:
	vel.y = -tuning.air_jump_velocity
	air_jumps_left -= 1
	jump_cuttable = true
	jump_buffer_t = 0.0
	fx.emit(&"air_jump", {"pos": body.feet()})


func _wall_jump(dir: int) -> void:
	vel.x = -dir * tuning.wall_jump_vx
	vel.y = -tuning.wall_jump_vy
	wall_lock_t = tuning.wall_jump_lock
	facing = -dir
	jump_cuttable = true
	jump_buffer_t = 0.0
	wall_coyote_t = 0.0
	if wall_sliding:
		wall_sliding = false
		fx.emit(&"wall_slide", {"on": false, "dir": dir})
	var side_x := body.pos.x + (body.size.x if dir > 0 else 0.0)
	fx.emit(&"wall_jump", {"pos": Vector2(side_x, body.pos.y + body.size.y * 0.5), "dir": dir})


func _drop_through() -> void:
	drop_t = DROP_TIME
	jump_buffer_t = 0.0
	grounded = false
	vel.y = 60.0
	fx.emit(&"drop", {"pos": body.feet()})


# ===========================================================================
# Passo de Ren (dash)
# ===========================================================================

func _start_dash(mx: int) -> void:
	_cancel_ko()
	dash_dir = mx if mx != 0 else facing
	if wall_sliding:
		dash_dir = -wall_dir
		wall_sliding = false
		fx.emit(&"wall_slide", {"on": false, "dir": wall_dir})
	facing = dash_dir
	state = State.DASH
	state_time = 0.0
	dash_t = tuning.dash_time
	dash_cd_t = tuning.dash_cooldown
	dash_buffer_t = 0.0
	if not grounded:
		dash_ready = false
	vel = Vector2(dash_dir * tuning.dash_speed, 0.0)
	jump_cuttable = false
	attack_t = 0.0
	fx.emit(&"dash", {"pos": body.center(), "dir": dash_dir})


func _update_dash(dt: float) -> void:
	_read_buffers()
	_update_ground()
	dash_t -= dt
	vel = Vector2(dash_dir * tuning.dash_speed, 0.0)

	# Pulo cancela o dash conservando parte do impulso.
	if jump_buffer_t > 0.0:
		var keep := dash_dir * tuning.dash_speed * tuning.dash_jump_keep
		if grounded or coyote_t > 0.0:
			_end_dash(keep)
			_jump()
			_move(dt)
			_post_move(dt)
			return
		var wd := 0
		if abilities["wall"]:
			wd = 1 if grid.touches_wall(body, 1) else (-1 if grid.touches_wall(body, -1) else 0)
		if wd != 0:
			_end_dash(0.0)
			_wall_jump(wd)
			_move(dt)
			_post_move(dt)
			return
		if abilities["air_jump"] and air_jumps_left > 0 and not zetsu and _can_afford():
			_spend(nen.air_jump_cost)
			_end_dash(keep)
			_air_jump()
			_move(dt)
			_post_move(dt)
			return

	var hit_wall := _move(dt)
	if hit_wall:
		_end_dash(0.0)
		fx.emit(&"dash_bonk", {"pos": body.center(), "dir": dash_dir})
	elif dash_t <= 0.0:
		_end_dash(dash_dir * maxf(tuning.run_speed, tuning.dash_speed * tuning.dash_end_mult))
	_post_move(dt)


func _end_dash(keep_vx: float) -> void:
	state = State.NORMAL
	state_time = 0.0
	dash_t = 0.0
	vel.x = keep_vx
	vel.y = 0.0


# ===========================================================================
# Golpe do cajado e pogo
# ===========================================================================

func _start_attack(my: int) -> void:
	attack_buffer_t = 0.0
	attack_cd_t = tuning.attack_cooldown
	attack_t = tuning.attack_time
	attack_resolved = false
	if my < 0:
		attack_dir = -1
	elif my > 0 and not grounded:
		attack_dir = 1
	else:
		attack_dir = 0
	fx.emit(&"attack", {"dir": attack_dir, "facing": facing})


func attack_active() -> bool:
	return attack_t > 0.0 and (tuning.attack_time - attack_t) <= tuning.attack_active


func attack_rect() -> Rect2:
	var c := body.center()
	if ko_strike:
		# Ko: toda a aura num ponto — um golpe largo para a frente
		var kw := 104.0
		var kx := c.x + 2.0 if facing > 0 else c.x - 2.0 - kw
		return Rect2(kx, body.pos.y - 14.0, kw, 64.0)
	var reach := nen.shu_reach if shu_active() else 1.0
	match attack_dir:
		-1:
			var hu := 50.0 * reach
			return Rect2(c.x - 24.0, body.pos.y + 6.0 - hu, 48.0, hu)
		1:
			return Rect2(c.x - 22.0, body.pos.y + body.size.y - 6.0, 44.0, 50.0 * reach)
	var w := 50.0 * reach
	var x := c.x + 4.0 if facing > 0 else c.x - 4.0 - w
	return Rect2(x, body.pos.y + 2.0, w, 34.0)


## Shu: com o Ren aceso, a aura corre pelo cajado (alcança mais e parte pedra).
func shu_active() -> bool:
	return ren and learned.get("shu", false)


func _resolve_attack() -> void:
	if attack_resolved or not attack_active():
		return
	var hb := attack_rect()
	# Ecos e objetos (lanternas, sino...): o golpe normal acerta um; o Ko, todos
	var hit_any := false
	for obj in strikeables:
		if not is_instance_valid(obj) or not obj.hit_rect().intersects(hb):
			continue
		var pogo: bool = attack_dir == 1 and abilities["pogo"]
		if not obj.on_struck(self, attack_dir, pogo):
			continue
		hit_any = true
		var is_eco := obj is Eco
		if is_eco:
			style["strikes"] += 1
			if shu_active():
				style["shu"] += 1
			if not ko_strike:
				_gain_aura(nen.strike_gain)
		elif pogo:
			_gain_aura(nen.pogo_gain)
		if pogo:
			_pogo(Vector2(body.center().x, obj.hit_rect().position.y))
		elif is_eco:
			if attack_dir == 0:
				_recoil(-facing * nen.strike_recoil * (1.6 if ko_strike else 1.0))
		else:
			fx.emit(&"strike", {"pos": hb.get_center(), "dir": attack_dir})
		if not ko_strike:
			break
	if hit_any and not ko_strike:
		attack_resolved = true
		return
	# pedra solta: o Shu e o Ko derrubam o muro inteiro
	if shu_active() or ko_strike:
		var broken := grid.break_stone(hb)
		if not broken.is_empty():
			attack_resolved = true
			fx.emit(&"stone_break", {"cells": broken, "pos": hb.get_center(), "dir": attack_dir})
			return
	if hit_any:
		attack_resolved = true
		return
	# espinhos: pogo
	if attack_dir == 1 and abilities["pogo"] and grid.spike_in(hb):
		attack_resolved = true
		_gain_aura(nen.pogo_gain)
		_pogo(Vector2(body.center().x, body.pos.y + body.size.y + 16.0))
		return
	# pedra (ou casca de aura): faísca e recuo
	if attack_dir != 1 and grid.overlaps_wall(hb.position, hb.size):
		attack_resolved = true
		if attack_dir == 0:
			vel.x -= facing * tuning.wall_hit_recoil
		var tip := Vector2(hb.end.x - 4.0 if facing > 0 else hb.position.x + 4.0, hb.get_center().y)
		if attack_dir == -1:
			tip = Vector2(hb.get_center().x, hb.position.y + 6.0)
		var ev := &"wall_hit"
		if grid.overlaps_tile(hb.position, hb.size, LevelGrid.Tile.SHELL):
			ev = &"shell_ting"
		elif grid.overlaps_tile(hb.position, hb.size, LevelGrid.Tile.STONE):
			ev = &"stone_ting"
		fx.emit(ev, {"pos": tip, "dir": attack_dir})


func _recoil(vx: float) -> void:
	recoil_t = RECOIL_TIME
	recoil_vx = vx
	vel.x = vx


func _pogo(at: Vector2) -> void:
	vel.y = -tuning.pogo_velocity
	jump_cuttable = false
	air_jumps_left = tuning.air_jumps
	dash_ready = true
	fx.emit(&"pogo", {"pos": at})


# ===========================================================================
# Movimento e colisão
# ===========================================================================

## Move nos dois eixos. Devolve true se bateu na horizontal.
func _move(dt: float) -> bool:
	var dx := vel.x * dt
	var dy := vel.y * dt
	var hit_x := false
	if dx != 0.0:
		if state == State.DASH and grid.overlaps_solid(body.pos + Vector2(dx, 0.0), body.size):
			_ledge_assist(dx)
		hit_x = grid.move_x(body, dx)
		if hit_x:
			vel.x = 0.0
	if dy < 0.0 and grid.overlaps_solid(body.pos + Vector2(0.0, dy), body.size):
		_corner_correct(dy)
	var was_grounded := grounded
	var falling_speed := vel.y
	if grid.move_y(body, dy, drop_t > 0.0):
		if dy > 0.0:
			if not was_grounded:
				_on_land(falling_speed)
		else:
			jump_cuttable = false
		vel.y = 0.0
	return hit_x


## Dash raspando numa quina: sobe alguns pixels em vez de parar.
func _ledge_assist(dx: float) -> void:
	for up in range(1, int(tuning.ledge_assist) + 1):
		var lifted := body.pos + Vector2(0.0, -up)
		if not grid.overlaps_solid(lifted, body.size) and not grid.overlaps_solid(lifted + Vector2(dx, 0.0), body.size):
			body.pos.y -= up
			return


## Cabeça raspando numa quina ao subir: desliza para o lado e segue subindo.
func _corner_correct(dy: float) -> void:
	for d in range(1, int(tuning.corner_correction) + 1):
		for s in [1, -1]:
			var shifted := body.pos + Vector2(d * s, 0.0)
			if not grid.overlaps_solid(shifted, body.size) and not grid.overlaps_solid(shifted + Vector2(0.0, dy), body.size):
				body.pos.x = shifted.x
				return


func _on_land(speed: float) -> void:
	grounded = true
	fx.emit(&"land", {"pos": body.feet(), "speed": speed})
	if state == State.INTRO_FALL:
		state = State.WAKE
		state_time = 0.0
		fx.emit(&"intro_land", {"pos": body.feet()})


func _post_move(dt: float) -> void:
	if grid.spike_hit(hurtbox()):
		_hurt()
		return
	var on_ground := vel.y >= 0.0 and grid.is_grounded(body, drop_t > 0.0)
	if on_ground and grid.fully_on_solid(body) and not grid.spike_near(body, 40.0):
		safe_pos = body.pos
	if on_ground and absf(vel.x) > 40.0:
		step_dist += absf(vel.x) * dt
		if step_dist > 40.0:
			step_dist = 0.0
			fx.emit(&"step", {"pos": body.feet()})


func hurtbox() -> Rect2:
	return Rect2(body.pos + Vector2(3, 6), body.size - Vector2(6, 9))


# ===========================================================================
# Dano de ambiente, respawn, intro, entrada de sala, descanso
# ===========================================================================

## Espinho: perde gota(s) e volta para o último chão seguro.
func _hurt() -> void:
	# empurrada para o espinho por um Eco: a gota já foi
	var dmg := 0 if state == State.KNOCKBACK else damage_mult()
	vitality = maxi(vitality - dmg, 0)
	hurt_count += 1
	_cancel_ko()
	_end_ren()
	if zetsu:
		_set_zetsu(false)
	attack_t = 0.0
	dash_t = 0.0
	_stop_wall_slide()
	if vitality <= 0:
		fx.emit(&"hurt", {"pos": body.center(), "dmg": dmg, "fatal": true})
		_die()
		return
	state = State.HURT
	state_time = 0.0
	vel = Vector2(-facing * 110.0, -330.0)
	fx.emit(&"hurt", {"pos": body.center(), "dmg": dmg, "fatal": false})


func _update_hurt(dt: float) -> void:
	vel.y = minf(vel.y + tuning.gravity * dt, tuning.max_fall)
	vel.x = move_toward(vel.x, 0.0, 300.0 * dt)
	_move(dt)
	if state_time >= HURT_TIME:
		state = State.RESPAWN
		state_time = 0.0
		fx.emit(&"respawn_start", {"black_at": RESPAWN_BLACK})


func _update_respawn(_dt: float) -> void:
	if state_time >= RESPAWN_BLACK and body.pos != safe_pos:
		body.pos = safe_pos
		vel = Vector2.ZERO
		grounded = true
		_sync_node()
		if is_inside_tree():
			reset_physics_interpolation()
		invuln_t = 0.6
		fx.emit(&"respawn_teleport", {"pos": body.center()})
	if state_time >= RESPAWN_TIME:
		state = State.NORMAL
		state_time = 0.0
		fx.emit(&"respawn_end", {"pos": body.center()})


func start_intro_fall() -> void:
	state = State.INTRO_FALL
	state_time = 0.0
	vel = Vector2.ZERO
	wake_len = WAKE_TIME


func _update_intro_fall(dt: float) -> void:
	grounded = false
	vel.y = minf(vel.y + tuning.gravity * tuning.fall_gravity_mult * dt, tuning.max_fall)
	vel.x = 0.0
	_move(dt)


func _update_wake(dt: float) -> void:
	vel = Vector2.ZERO
	_update_ground()
	# Depois de um tempo, qualquer botão adianta o despertar.
	var early := minf(0.9, wake_len * 0.6)
	if state_time >= wake_len or (state_time > early and (input.any_pressed() or input.move.x != 0.0)):
		state = State.NORMAL
		state_time = 0.0
		fx.emit(&"wake_done", {"revive": wake_len != WAKE_TIME})
	_move(dt)


## Chamado pela sala ao entrar por uma porta: anda sozinho por um instante.
func enter_room(top_left: Vector2, velocity: Vector2, duration: float) -> void:
	body.pos = top_left
	vel = velocity
	enter_vel = velocity
	enter_time = duration
	state = State.ENTER
	state_time = 0.0
	safe_pos = top_left
	dash_t = 0.0
	attack_t = 0.0
	wall_sliding = false
	_sync_node()
	if is_inside_tree():
		reset_physics_interpolation()


func _update_enter(dt: float) -> void:
	_read_buffers()
	_update_ground()
	if enter_vel.x != 0.0:
		vel.x = enter_vel.x
		facing = int(signf(enter_vel.x))
	var g := tuning.gravity * (tuning.fall_gravity_mult if vel.y > 0.0 else 1.0)
	vel.y = minf(vel.y + g * dt, tuning.max_fall)
	_move(dt)
	_post_move(dt)
	if state_time >= enter_time and state == State.ENTER:
		state = State.NORMAL
		state_time = 0.0
		if not grounded and enter_vel.y < 0.0:
			# chegou pulando de baixo: deixa o ápice natural
			jump_cuttable = false


func rest() -> void:
	state = State.REST
	state_time = 0.0
	vel = Vector2.ZERO
	_end_ren()
	if zetsu:
		_set_zetsu(false)
	_stop_wall_slide()


func stand_up() -> void:
	if state == State.REST:
		state = State.NORMAL
		state_time = 0.0


func lock(locked: bool) -> void:
	if locked:
		state = State.LOCKED
		state_time = 0.0
	elif state == State.LOCKED:
		state = State.NORMAL
		state_time = 0.0


func _update_locked(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, tuning.ground_decel * dt)
	_update_ground()
	if not grounded:
		vel.y = minf(vel.y + tuning.gravity * tuning.fall_gravity_mult * dt, tuning.max_fall)
	_move(dt)


# ===========================================================================
# Nen: aura, Ten, Zetsu e Ren
# ===========================================================================

func _update_nen(dt: float) -> void:
	var free := state == State.NORMAL or state == State.DASH or state == State.KNOCKBACK or state == State.ENTER
	# Zetsu: segurar fecha os nós de aura (dentro de um véu a chama não reacende)
	var want_zetsu: bool = free and learned["zetsu"] and input.held(&"zetsu")
	if zetsu and not want_zetsu and grid.overlaps_veil(body.pos, body.size):
		want_zetsu = true
	if want_zetsu != zetsu:
		_set_zetsu(want_zetsu)
	if zetsu:
		style["zetsu_time"] += dt
	# Gyo: aura nos olhos (nunca junto do Zetsu: com os nós fechados não há o que ver)
	if not input.held(&"gyo"):
		gyo_spent = false
	var want_gyo: bool = free and learned.get("gyo", false) and input.held(&"gyo") and not zetsu \
		and not gyo_spent and (aura > 0.0 if gyo else aura >= 4.0)
	if want_gyo != gyo:
		if gyo and aura <= 0.0:
			gyo_spent = true
		_set_gyo(want_gyo)
	if gyo:
		style["gyo_time"] += dt
	# Ren: apertar explode a aura, segurar mantém aberto
	if ren and (not input.held(&"ren") or not free or zetsu or aura <= 0.0):
		_end_ren()
	elif not ren and free and not zetsu and learned["ren"] and input.pressed(&"ren"):
		_cancel_ko()
		_start_ren()
	# aura: o Ren e o Gyo gastam; concentrando o Ko ou o En, ela não volta
	var cap := aura_cap()
	var regen := true
	if ren:
		aura -= nen.ren_drain * dt
		regen = false
	if gyo:
		aura -= nen.gyo_drain * dt
		regen = false
	if ko_charge > 0.0 or en_t > 0.0:
		regen = false
	if regen:
		if regen_delay_t > 0.0:
			regen_delay_t = maxf(regen_delay_t - dt, 0.0)
		elif zetsu:
			aura += nen.zetsu_regen * dt
		elif state == State.NORMAL or state == State.DASH or state == State.ENTER:
			var rate := nen.regen_air
			if grounded:
				rate = nen.regen_still if absf(vel.x) < 25.0 else nen.regen_moving
			aura += rate * dt
	if not learned["ten"]:
		aura -= nen.leak_rate * dt
	aura = clampf(aura, 0.0, cap)


## Quanto de aura a chama segura agora (antes do Ten ela vaza e segura pouco).
func aura_cap() -> float:
	return aura_max * (1.0 if learned["ten"] else nen.leak_cap)


## Aura relativa à chama cheia de verdade (o desenho da chama usa isto).
func aura_frac() -> float:
	return aura / maxf(nen.aura_max, 1.0)


func is_leaking() -> bool:
	return not learned["ten"]


func _speed_mult() -> float:
	if zetsu:
		return nen.zetsu_speed_mult
	if ren:
		return nen.ren_speed_mult
	return 1.0


## Dá para pagar uma habilidade: tem aura, ou dá para derreter uma gota sem apagar.
func _can_afford() -> bool:
	return aura > 0.5 or vitality > 1


## Paga com aura; com a chama zerada, derrete uma gota de cera.
func _spend(cost: float) -> void:
	regen_delay_t = nen.regen_delay
	if aura > 0.5:
		aura = maxf(aura - cost, 0.0)
		return
	vitality -= 1
	style["melts"] += 1
	fx.emit(&"melt", {"pos": body.center()})


func _gain_aura(amount: float) -> void:
	aura = minf(aura + amount, aura_cap())


func _set_zetsu(on: bool) -> void:
	zetsu = on
	if on:
		_end_ren()
		_cancel_ko()
		if gyo:
			_set_gyo(false)
	fx.emit(&"zetsu", {"on": on, "pos": body.center()})


func _set_gyo(on: bool) -> void:
	gyo = on
	fx.emit(&"gyo", {"on": on, "pos": body.center(), "empty": aura <= 0.0})


func _start_ren() -> void:
	if aura < nen.ren_min_aura:
		fx.emit(&"fizzle", {"pos": body.center()})
		return
	aura -= nen.ren_burst_cost
	regen_delay_t = nen.regen_delay
	ren = true
	style["ren"] += 1
	if learned.get("ken", false):
		ken_t = nen.ken_window
	var c := body.center()
	var broken := grid.break_shells(c, nen.ren_burst_radius)
	for obj in strikeables:
		if is_instance_valid(obj) and obj.has_method("on_ren_burst"):
			obj.on_ren_burst(self, c, nen.ren_burst_radius)
	fx.emit(&"ren_burst", {"pos": c, "radius": nen.ren_burst_radius, "broken": broken})


func _end_ren() -> void:
	if ren:
		ren = false
		fx.emit(&"ren_end", {"pos": body.center()})


## Dano recebido: dobra sem Ten (a aura vaza), no Zetsu (a aura fica fechada)
## e concentrando o Ko (a aura toda está no cajado).
func damage_mult() -> int:
	return 2 if (zetsu or not learned["ten"] or ko_charge > 0.0) else 1


## Dano do golpe do cajado: o Ren dobra, o Ko depende da aura gasta; acertar um
## Eco desatento soma um.
func strike_damage(target_aware: bool) -> int:
	var d := ko_damage if ko_strike else (2 if ren else 1)
	if not target_aware:
		d += 1
		style["sneak"] += 1
	return d


# ===========================================================================
# En: ajoelhar com o Gyo aceso e espalhar a aura pela sala
# ===========================================================================

func _update_en(mx: int, my: int, dt: float) -> void:
	var kneel: bool = gyo and learned.get("en", false) and grounded and my > 0 and mx == 0 \
		and attack_t <= 0.0 and ko_charge <= 0.0 and not wall_sliding
	if not kneel:
		en_t = 0.0
		en_fired = false
		return
	if en_t <= 0.0:
		fx.emit(&"en_kneel", {"pos": body.feet()})
	en_t += dt
	if en_t >= nen.en_kneel_time and not en_fired:
		en_fired = true
		if aura >= nen.en_cost:
			_fire_en()
		else:
			fx.emit(&"fizzle", {"pos": body.center()})


func _fire_en() -> void:
	_spend(nen.en_cost)
	style["en"] += 1
	var c := body.center()
	for obj in strikeables:
		if is_instance_valid(obj) and obj.has_method("on_en"):
			obj.on_en(self, c, nen.en_alert_radius)
	fx.emit(&"en", {"pos": c, "speed": nen.en_speed})


func kneeling() -> bool:
	return en_t > 0.0


# ===========================================================================
# Ko: segurar o golpe concentra toda a aura num ponto
# ===========================================================================

func _update_ko(dt: float) -> void:
	if ko_charge > 0.0:
		if not input.held(&"attack"):
			if ko_ready:
				_ko_release()
			else:
				_cancel_ko()
			return
		ko_charge += dt
		if not ko_ready and ko_charge >= nen.ko_charge_time:
			ko_ready = true
			fx.emit(&"ko_ready", {"pos": body.center()})
		return
	if not (learned.get("ko", false) and input.held(&"attack") and attack_t <= 0.0 and not ren and not zetsu):
		ko_hold_t = 0.0
		return
	var before := ko_hold_t
	ko_hold_t += dt
	if before < nen.ko_hold_delay and ko_hold_t >= nen.ko_hold_delay:
		if aura >= nen.ko_min_aura:
			ko_charge = 0.0001
			ko_ready = false
			fx.emit(&"ko_charge", {"pos": body.center()})
		else:
			fx.emit(&"fizzle", {"pos": body.center()})


func _ko_release() -> void:
	var spent := aura
	aura = 0.0
	regen_delay_t = nen.regen_delay * 2.0
	ko_damage = nen.ko_base_damage + int(spent / nen.ko_aura_per_damage)
	ko_charge = 0.0
	ko_ready = false
	ko_hold_t = 0.0
	ko_strike = true
	attack_dir = 0
	attack_t = tuning.attack_time
	attack_cd_t = tuning.attack_cooldown
	attack_resolved = false
	style["ko"] += 1
	fx.emit(&"ko", {"pos": body.center(), "dir": facing, "spent": spent, "damage": ko_damage})


func _cancel_ko() -> void:
	var was := ko_charge > 0.0
	ko_charge = 0.0
	ko_ready = false
	ko_hold_t = 0.0
	if was:
		fx.emit(&"ko_cancel", {"pos": body.center()})


func ko_charging() -> bool:
	return ko_charge > 0.0


# ===========================================================================
# Ken: o Ren aberto na hora do golpe vira defesa total por um instante
# ===========================================================================

func ken_active() -> bool:
	return ken_t > 0.0 and (state == State.NORMAL or state == State.DASH or state == State.ENTER or state == State.KNOCKBACK)


## Um golpe de Eco chegou na janela do Ken: aparado. Devolve true se aparou
## (quem chama cuida do Eco: on_parried).
func try_parry(from: Vector2) -> bool:
	if not ken_active():
		return false
	_gain_aura(nen.ken_refund)
	invuln_t = maxf(invuln_t, 0.35)
	style["ken"] += 1
	var c := body.center()
	var dir := signf(from.x - c.x)
	if dir == 0.0:
		dir = float(facing)
	fx.emit(&"ken_parry", {"pos": c.lerp(from, 0.45), "dir": dir})
	return true


## Os Ecos enxergam a Vela? (no Zetsu, apagada, não; morta ou descansando, também não)
func perceivable() -> bool:
	if zetsu:
		return false
	return state == State.NORMAL or state == State.DASH or state == State.KNOCKBACK or state == State.ENTER or state == State.HURT


func can_be_hit() -> bool:
	if invuln_t > 0.0:
		return false
	return state == State.NORMAL or state == State.DASH or state == State.ENTER or state == State.KNOCKBACK


# ===========================================================================
# Golpes dos Ecos, morte e renascimento
# ===========================================================================

## Golpe de um Eco. Devolve true se pegou (fora da invencibilidade).
func take_hit(amount: int, from: Vector2) -> bool:
	if not can_be_hit():
		return false
	var dmg := amount * damage_mult()
	vitality = maxi(vitality - dmg, 0)
	hits_taken += 1
	_cancel_ko()
	_end_ren()
	if zetsu and not grid.overlaps_veil(body.pos, body.size):
		_set_zetsu(false)
	attack_t = 0.0
	dash_t = 0.0
	recoil_t = 0.0
	_stop_wall_slide()
	var dir := signf(body.center().x - from.x)
	if dir == 0.0:
		dir = -float(facing)
	var fatal := vitality <= 0
	fx.emit(&"hit", {"pos": body.center(), "dmg": dmg, "dir": dir, "fatal": fatal})
	if fatal:
		_die()
		return true
	state = State.KNOCKBACK
	state_time = 0.0
	vel = Vector2(dir * nen.knockback.x, nen.knockback.y)
	facing = -int(dir)
	invuln_t = nen.invuln_time
	return true


func _update_knockback(dt: float) -> void:
	_update_ground()
	vel.y = minf(vel.y + tuning.gravity * dt, tuning.max_fall)
	vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
	_move(dt)
	_post_move(dt)
	if state == State.KNOCKBACK and state_time >= nen.knockback_time:
		state = State.NORMAL
		state_time = 0.0


func _die() -> void:
	state = State.DEAD
	state_time = 0.0
	deaths += 1
	vel.x *= 0.3
	vel.y = maxf(vel.y, 0.0)
	_end_ren()
	_cancel_ko()
	if gyo:
		_set_gyo(false)
	ken_t = 0.0
	en_t = 0.0
	zetsu = false
	_stop_wall_slide()
	attack_t = 0.0
	dash_t = 0.0
	fx.emit(&"die", {"pos": body.center()})


func _update_dead(dt: float) -> void:
	_update_ground()
	if not grounded:
		vel.y = minf(vel.y + tuning.gravity * tuning.fall_gravity_mult * dt, tuning.max_fall)
	vel.x = move_toward(vel.x, 0.0, 1200.0 * dt)
	_move(dt)


func is_dead() -> bool:
	return state == State.DEAD


## Onde o Eco póstumo fica: onde a Vela apagou, ou no último chão seguro se ela
## caiu em espinhos (para dar para alcançar).
func shade_spot() -> Vector2:
	if grid.spike_near(body, 30.0) or grid.spike_hit(hurtbox()):
		return safe_pos + body.size * 0.5
	return body.center()


## Renasce de pé num altar, com todas as gotas e a chama cheia.
func revive(top_left: Vector2) -> void:
	body.pos = top_left
	safe_pos = top_left
	vel = Vector2.ZERO
	vitality = vitality_max
	aura = aura_cap()
	invuln_t = 0.0
	zetsu = false
	ren = false
	gyo = false
	ken_t = 0.0
	en_t = 0.0
	ko_strike = false
	recoil_t = 0.0
	attack_t = 0.0
	dash_t = 0.0
	grounded = true
	wake_len = REVIVE_WAKE_TIME
	state = State.WAKE
	state_time = 0.0
	_sync_node()
	if is_inside_tree():
		reset_physics_interpolation()
	fx.emit(&"revive", {"pos": body.center()})


## Descanso no altar: gotas e chama cheias.
func refill() -> void:
	vitality = vitality_max
	aura = aura_cap()


func _stop_wall_slide() -> void:
	if wall_sliding:
		wall_sliding = false
		fx.emit(&"wall_slide", {"on": false, "dir": wall_dir})


# ===========================================================================
# Utilidades
# ===========================================================================

func center() -> Vector2:
	return body.center()


## Lado pelo qual o centro saiu da sala ("" se ainda está dentro).
func exit_side() -> String:
	var c := body.center()
	var s := grid.pixel_size()
	if c.x < 0.0:
		return "left"
	if c.x > s.x:
		return "right"
	if c.y > s.y:
		return "bottom"
	if c.y < 0.0:
		return "top"
	return ""


func is_controllable() -> bool:
	return state == State.NORMAL or state == State.DASH


func _sync_node() -> void:
	position = body.feet()
