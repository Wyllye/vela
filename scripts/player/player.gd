class_name Player
extends Node2D
## A Vela: controle de movimento com física própria em grade (LevelGrid).
##
## Toda a lógica roda em `step(dt)`, sem depender da árvore de cenas — os testes
## chamam `step()` direto com um ScriptedInput. Efeitos (som, partículas,
## câmera) saem pelo sinal `fx`; quem desenha é o PlayerView.

signal fx(event: StringName, data: Dictionary)

enum State { NORMAL, DASH, HURT, RESPAWN, INTRO_FALL, WAKE, REST, LOCKED, ENTER }

const SIZE := Vector2(22, 44)
const DASH_BUFFER := 0.08
const ATTACK_BUFFER := 0.10
const DROP_TIME := 0.18
const HURT_TIME := 0.38
const RESPAWN_BLACK := 0.30
const RESPAWN_TIME := 0.62
const WAKE_TIME := 1.8
const LOOK_DELAY := 0.45

@export var tuning: MovementTuning

var grid: LevelGrid
var input: PlayerInput = PlayerInput.new()
var body := GridBody.new()
var vel := Vector2.ZERO
var facing := 1
var state: State = State.NORMAL
var state_time := 0.0

## Habilidades liberadas. Na Etapa 1 todas vêm ligadas para testar a sensação.
var abilities := {"dash": true, "wall": true, "air_jump": true, "pogo": true}

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
		_:
			_update_locked(dt)
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
	_update_look(mx, my, dt)

	# --- horizontal ---
	var target := mx * t.run_speed
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
	if mx != 0 and signf(vel.x) == float(mx) and absf(vel.x) > t.run_speed:
		accel = t.overspeed_decel
	if wall_lock_t > 0.0:
		accel *= 0.25
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
			_air_jump()
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

	# --- golpe ---
	if attack_buffer_t > 0.0 and attack_cd_t <= 0.0:
		_start_attack(my)

	# --- direção ---
	if wall_sliding:
		facing = -wall_dir
	elif mx != 0 and attack_t <= tuning.attack_time - tuning.attack_active:
		facing = mx

	# --- passo de Ren ---
	if dash_buffer_t > 0.0 and abilities["dash"] and dash_ready and dash_cd_t <= 0.0:
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
		if abilities["air_jump"] and air_jumps_left > 0:
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
	match attack_dir:
		-1:
			return Rect2(c.x - 24.0, body.pos.y - 44.0, 48.0, 50.0)
		1:
			return Rect2(c.x - 22.0, body.pos.y + body.size.y - 6.0, 44.0, 50.0)
	var w := 50.0
	var x := c.x + 4.0 if facing > 0 else c.x - 4.0 - w
	return Rect2(x, body.pos.y + 2.0, w, 34.0)


func _resolve_attack() -> void:
	if attack_resolved or not attack_active():
		return
	var hb := attack_rect()
	# objetos (lanternas etc.)
	for obj in strikeables:
		if is_instance_valid(obj) and obj.hit_rect().intersects(hb):
			var pogo: bool = attack_dir == 1 and abilities["pogo"]
			if obj.on_struck(self, attack_dir, pogo):
				attack_resolved = true
				if pogo:
					_pogo(Vector2(body.center().x, obj.hit_rect().position.y))
				else:
					fx.emit(&"strike", {"pos": hb.get_center(), "dir": attack_dir})
				return
	# espinhos: pogo
	if attack_dir == 1 and abilities["pogo"] and grid.spike_in(hb):
		attack_resolved = true
		_pogo(Vector2(body.center().x, body.pos.y + body.size.y + 16.0))
		return
	# pedra: faísca e recuo
	if attack_dir != 1 and grid.overlaps_solid(hb.position, hb.size):
		attack_resolved = true
		if attack_dir == 0:
			vel.x -= facing * tuning.wall_hit_recoil
		var tip := Vector2(hb.end.x - 4.0 if facing > 0 else hb.position.x + 4.0, hb.get_center().y)
		if attack_dir == -1:
			tip = Vector2(hb.get_center().x, hb.position.y + 6.0)
		fx.emit(&"wall_hit", {"pos": tip, "dir": attack_dir})


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

func _hurt() -> void:
	state = State.HURT
	state_time = 0.0
	hurt_count += 1
	vel = Vector2(-facing * 110.0, -330.0)
	attack_t = 0.0
	dash_t = 0.0
	if wall_sliding:
		wall_sliding = false
		fx.emit(&"wall_slide", {"on": false, "dir": wall_dir})
	fx.emit(&"hurt", {"pos": body.center()})


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
		fx.emit(&"respawn_teleport", {"pos": body.center()})
	if state_time >= RESPAWN_TIME:
		state = State.NORMAL
		state_time = 0.0
		fx.emit(&"respawn_end", {"pos": body.center()})


func start_intro_fall() -> void:
	state = State.INTRO_FALL
	state_time = 0.0
	vel = Vector2.ZERO


func _update_intro_fall(dt: float) -> void:
	grounded = false
	vel.y = minf(vel.y + tuning.gravity * tuning.fall_gravity_mult * dt, tuning.max_fall)
	vel.x = 0.0
	_move(dt)


func _update_wake(dt: float) -> void:
	vel = Vector2.ZERO
	_update_ground()
	# Depois de um tempo, qualquer botão adianta o despertar.
	if state_time >= WAKE_TIME or (state_time > 0.9 and (input.any_pressed() or input.move.x != 0.0)):
		state = State.NORMAL
		state_time = 0.0
		fx.emit(&"wake_done", {})
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
