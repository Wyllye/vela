extends Node
## Orquestra o jogo: título, salas, transições, respawn, descanso, efeitos e UI.
##
## A física da Vela roda aqui (player.step) para garantir a ordem:
## controles → Vela → salas/objetos → câmera.
##
## Argumentos de linha de comando (depois de `--`), úteis para testes e capturas:
##   --room=<id>        começa direto numa sala (pula título e intro)
##   --at=<col>,<lin>   posição inicial na sala (célula)
##   --demo=<rota>      a Vela anda sozinha seguindo uma rota de tools/demo_routes.gd
##   --shot=<arquivo>   salva um print depois de --frames=<n> frames e fecha
##   --autostart        sai da tela de título sozinho (para gravar a intro)
##   --clean            sem granulação de filme (capturas e GIFs menores)

enum Mode { TITLE, PLAY, TRANSITION, REST }

const FIRST_ROOM := "poco_fundo"
const VIEW := Vector2(1280, 720)
const TS := 32.0

@onready var background: CanvasLayer = $Background
@onready var world: Node2D = $World
@onready var room_root: Node2D = $World/RoomRoot
@onready var fx_root: Node2D = $World/FX
@onready var player: Player = $World/Player
@onready var camera: GameCamera = $World/Camera
@onready var ui: GameUI = $UI

var room: Room
var mode: Mode = Mode.TITLE
var _active_tablet: Tablet
var _near_altar: Altar
var _title_t := 0.0
var _rest_t := 0.0
var _args: Dictionary = {}
var _frames := 0
var _debug_draw: DebugDraw


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	background.process_mode = Node.PROCESS_MODE_PAUSABLE
	TranslationServer.set_locale("pt_BR")
	_args = _parse_args()
	player.set_physics_process(false)
	player.fx.connect(_on_player_fx)
	camera.target = player
	_debug_draw = DebugDraw.new()
	_debug_draw.main = self
	_debug_draw.visible = false
	world.add_child(_debug_draw)

	if _args.has("clean"):
		var post := $Post/Vignette as ColorRect
		(post.material as ShaderMaterial).set_shader_parameter("grain", 0.0)
	if _args.has("room"):
		_start_direct(str(_args["room"]))
		return

	_load_room(FIRST_ROOM)
	_place_at_cell(room.spawn_cell if room.spawn_cell.x >= 0 else Vector2i(9, 2))
	player.visible = false
	player.lock(true)
	camera.position = Vector2(player.body.center().x, VIEW.y * 0.5)
	camera.reset_physics_interpolation()
	ui.show_title()
	AudioManager.play_music("titulo", 1.5)
	AudioManager.play_ambience("amb_poco")


func _start_direct(room_id: String) -> void:
	mode = Mode.PLAY
	_load_room(room_id)
	var cell := room.spawn_cell if room.spawn_cell.x >= 0 else Vector2i(3, 3)
	if _args.has("at"):
		var parts := str(_args["at"]).split(",")
		cell = Vector2i(int(parts[0]), int(parts[1]))
	_place_at_cell(cell)
	if _args.has("demo"):
		player.input = DemoRoutes.make_input(str(_args["demo"]), player, room)
	AudioManager.play_music(room.data.music, 0.5)


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
		elif a.begins_with("--"):
			out[a.substr(2)] = true
	return out


# ---------------------------------------------------------------------------
# Salas
# ---------------------------------------------------------------------------

func _load_room(id: String) -> void:
	if room:
		room.free_room()
		room = null
	var rd := RoomData.load_room(id)
	room = Room.new()
	room_root.add_child(room)
	room.build(rd, background)
	player.grid = rd.grid
	player.strikeables = room.strikeables
	camera.setup_room(rd.grid.pixel_size())
	_active_tablet = null
	_near_altar = null
	ui.hide_inscription()
	if mode != Mode.TITLE and rd.music != "":
		AudioManager.play_music(rd.music)
	if rd.ambience != "":
		AudioManager.play_ambience(rd.ambience)


func _place_at_cell(cell: Vector2i) -> void:
	var pos := Vector2(cell.x * TS + (TS - Player.SIZE.x) * 0.5, (cell.y + 1) * TS - Player.SIZE.y)
	player.setup(room.data.grid, pos)
	camera.snap()
	room.update_parallax(camera.view_top_left())


func _check_exit() -> void:
	if player.exit_side() == "":
		return
	var door := room.data.grid.door_touching(player.body.rect())
	if door == "" or not room.data.doors.has(door):
		return
	var link: Dictionary = room.data.doors[door]
	_transition(str(link["to"]), str(link["door"]), player.vel)


func _transition(to_id: String, door_id: String, vel: Vector2) -> void:
	mode = Mode.TRANSITION
	AudioManager.loop_sfx("wall_slide", false)
	AudioManager.play_sfx("transition", -10.0, 0.02)
	await ui.fade_to(1.0, 0.14)
	_load_room(to_id)
	_enter_door(door_id, vel)
	camera.snap()
	room.update_parallax(camera.view_top_left())
	await ui.fade_to(0.0, 0.24)
	if mode == Mode.TRANSITION:
		mode = Mode.PLAY


func _enter_door(door_id: String, vel: Vector2) -> void:
	var g := room.data.grid
	var cells := g.door_cells_of(door_id)
	if cells.is_empty():
		push_error("Porta %s não existe em %s" % [door_id, room.data.id])
		_place_at_cell(Vector2i(2, 2))
		return
	var min_c := cells[0].x
	var max_c := cells[0].x
	var max_r := cells[0].y
	for k in cells:
		min_c = mini(min_c, k.x)
		max_c = maxi(max_c, k.x)
		max_r = maxi(max_r, k.y)
	var size := Player.SIZE
	var run := player.tuning.run_speed
	match g.door_side(door_id):
		"left":
			player.enter_room(Vector2(4.0, (max_r + 1) * TS - size.y), Vector2(run, 0), 0.22)
		"right":
			player.enter_room(Vector2(g.width * TS - size.x - 4.0, (max_r + 1) * TS - size.y), Vector2(-run, 0), 0.22)
		"top":
			player.enter_room(Vector2((min_c + max_c + 1) * TS * 0.5 - size.x * 0.5, 4.0), Vector2(vel.x * 0.3, maxf(vel.y, 200.0)), 0.06)
		_:
			player.enter_room(Vector2((min_c + max_c + 1) * TS * 0.5 - size.x * 0.5, g.height * TS - size.y - 4.0), Vector2(vel.x * 0.5, -900.0), 0.06)
	player.strikeables = room.strikeables


# ---------------------------------------------------------------------------
# Laço principal
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_music"):
		AudioManager.toggle_music()
		ui.refresh_pause()
		return
	if event.is_action_pressed("debug"):
		Game.debug = not Game.debug
		ui.set_debug_visible(Game.debug)
		_debug_draw.visible = Game.debug
		return
	match mode:
		Mode.TITLE:
			if _is_press(event):
				_start_game()
			return
		Mode.REST:
			if ui.end_card_visible and _rest_t > 2.0 and _is_press(event) and not event.is_action("pause"):
				_leave_rest()
				return
	if event.is_action_pressed("pause") and (mode == Mode.PLAY or mode == Mode.REST):
		var paused := not get_tree().paused
		get_tree().paused = paused
		ui.set_paused(paused)
		if paused:
			AudioManager.loop_sfx("wall_slide", false)


func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _start_game() -> void:
	mode = Mode.PLAY
	ui.hide_title()
	AudioManager.stop_music(2.5)
	AudioManager.play_sfx("ui_start", -2.0, 0.0)
	player.visible = true
	player.start_intro_fall()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_frames += 1
	if _args.has("shot") and _frames == int(_args.get("frames", 90)):
		_take_shot(str(_args["shot"]))
	match mode:
		Mode.TITLE:
			_title_t += delta
			camera.position.y = VIEW.y * 0.5 + sin(_title_t * 0.35) * 8.0
			if _args.has("autostart") and _title_t > 2.0:
				_start_game()
			return
		Mode.TRANSITION:
			return
	player.step(delta)
	if mode == Mode.PLAY:
		_update_tablets()
		_update_altar()
		if player.is_controllable() or player.state == Player.State.ENTER:
			_check_exit()
	elif mode == Mode.REST:
		_rest_t += delta
	camera.follow(delta)


func _process(_delta: float) -> void:
	if room:
		room.update_parallax(camera.view_top_left())
	if Game.debug:
		ui.update_debug(player, Engine.get_frames_per_second(), room.data.id if room else "")
		_debug_draw.queue_redraw()


func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("print salvo: ", path)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Estelas e altar
# ---------------------------------------------------------------------------

func _update_tablets() -> void:
	var t := room.tablet_near(player.body.center())
	if t == _active_tablet:
		return
	if _active_tablet:
		_active_tablet.set_active(false)
	_active_tablet = t
	if t:
		t.set_active(true)
		ui.show_inscription(tr(t.text_key))
		AudioManager.play_sfx("tablet", -7.0, 0.0)
	else:
		ui.hide_inscription()


func _update_altar() -> void:
	var a := room.altar_near(player.body.center())
	if a != _near_altar:
		if _near_altar:
			_near_altar.set_near(false)
		_near_altar = a
		if a:
			a.set_near(true)
	var can_rest := a != null and player.grounded and player.state == Player.State.NORMAL
	ui.show_rest_prompt(can_rest)
	if can_rest and player.input.pressed(&"move_up"):
		_rest(a)


func _rest(a: Altar) -> void:
	mode = Mode.REST
	_rest_t = 0.0
	player.rest()
	ui.show_rest_prompt(false)
	ui.hide_inscription()
	AudioManager.play_sfx("altar", -3.0, 0.0)
	FX.burst(fx_root, a.position + Vector2(0, -30), {"amount": 26, "life": 2.2, "color": Color(1.0, 0.82, 0.55, 0.8),
		"dir": Vector2.UP, "spread": 50.0, "speed_min": 15.0, "speed_max": 45.0, "gravity": Vector2(0, -12), "additive": true,
		"rect": Vector2(50, 6), "explosive": 0.3, "damping": 4.0, "scale_min": 0.08, "scale_max": 0.16})
	await get_tree().create_timer(1.8).timeout
	if mode == Mode.REST:
		ui.show_end_card()


func _leave_rest() -> void:
	ui.hide_end_card()
	player.stand_up()
	mode = Mode.PLAY


# ---------------------------------------------------------------------------
# Efeitos da Vela → som, partículas, câmera
# ---------------------------------------------------------------------------

func _on_player_fx(ev: StringName, d: Dictionary) -> void:
	var aura := Color("ffc56a")
	var dust := Color(0.78, 0.8, 0.84, 0.7)
	match ev:
		&"jump":
			AudioManager.play_sfx("jump", -6.0, 0.06)
			_dust(d["pos"], 7, 70.0)
		&"air_jump":
			AudioManager.play_sfx("air_jump", -4.0, 0.04)
			FX.burst(fx_root, d["pos"], {"amount": 16, "life": 0.45, "color": Color(aura, 0.9), "dir": Vector2.DOWN, "spread": 70.0,
				"speed_min": 60.0, "speed_max": 160.0, "gravity": Vector2.ZERO, "additive": true, "damping": 180.0})
			FX.ring(fx_root, d["pos"], Color(aura, 0.8), 26.0, 0.3)
		&"wall_jump":
			AudioManager.play_sfx("wall_jump", -5.0, 0.06)
			_dust(d["pos"], 6, 60.0)
		&"land":
			var speed: float = d.get("speed", 0.0)
			if speed > 700.0:
				AudioManager.play_sfx("land_hard", -3.0, 0.05)
				camera.add_trauma(0.22)
				_dust(d["pos"], 14, 140.0)
			elif speed > 220.0:
				AudioManager.play_sfx("land", -6.0, 0.08)
				_dust(d["pos"], 8, 90.0)
		&"step":
			AudioManager.play_sfx("step", -15.0, 0.1, 3)
		&"dash":
			AudioManager.play_sfx("dash", -3.0, 0.04)
			camera.add_trauma(0.08)
			FX.burst(fx_root, d["pos"], {"amount": 14, "life": 0.35, "color": Color(aura, 0.8), "dir": Vector2(-float(d["dir"]), 0),
				"spread": 25.0, "speed_min": 80.0, "speed_max": 220.0, "gravity": Vector2.ZERO, "additive": true, "damping": 300.0})
		&"dash_bonk":
			AudioManager.play_sfx("wall_hit", -6.0, 0.05)
			camera.add_trauma(0.18)
		&"attack":
			AudioManager.play_sfx("swing", -6.0, 0.08, 2)
		&"pogo":
			AudioManager.play_sfx("ring", -2.0, 0.05)
			Game.hitstop(0.05)
			camera.add_trauma(0.14)
			FX.ring(fx_root, d["pos"], Color(1, 0.95, 0.85, 0.9), 34.0, 0.3)
			FX.burst(fx_root, d["pos"], {"amount": 14, "life": 0.4, "color": Color(1, 0.9, 0.7, 0.95), "dir": Vector2.UP, "spread": 80.0,
				"speed_min": 90.0, "speed_max": 240.0, "gravity": Vector2(0, 500), "additive": true})
		&"strike":
			AudioManager.play_sfx("ring", -6.0, 0.08)
			FX.burst(fx_root, d["pos"], {"amount": 8, "life": 0.3, "color": Color(1, 0.9, 0.7, 0.9), "spread": 180.0, "additive": true})
		&"wall_hit":
			AudioManager.play_sfx("wall_hit", -4.0, 0.08)
			Game.hitstop(0.025)
			camera.add_trauma(0.08)
			FX.burst(fx_root, d["pos"], {"amount": 10, "life": 0.28, "color": Color(1, 0.96, 0.85, 1.0), "spread": 180.0,
				"speed_min": 80.0, "speed_max": 200.0, "gravity": Vector2(0, 600), "additive": true, "scale_min": 0.06, "scale_max": 0.12})
		&"wall_slide":
			AudioManager.loop_sfx("wall_slide", bool(d.get("on", false)), -12.0)
		&"hurt":
			AudioManager.loop_sfx("wall_slide", false)
			AudioManager.play_sfx("hurt", -2.0, 0.03)
			Game.hitstop(0.11)
			camera.add_trauma(0.55)
			FX.burst(fx_root, d["pos"], {"amount": 22, "life": 0.6, "color": Color("ebe0ca"), "spread": 180.0,
				"speed_min": 80.0, "speed_max": 260.0, "gravity": Vector2(0, 700)})
			FX.burst(fx_root, d["pos"], {"amount": 14, "life": 0.6, "color": Color(aura, 0.9), "spread": 180.0, "additive": true})
		&"respawn_start":
			ui.fade_to(1.0, 0.24)
		&"respawn_teleport":
			camera.snap()
			ui.fade_to(0.0, 0.3)
			AudioManager.play_sfx("respawn", -5.0, 0.0)
			FX.burst(fx_root, d["pos"], {"amount": 18, "life": 0.7, "color": Color(aura, 0.8), "dir": Vector2.UP, "spread": 180.0,
				"speed_min": 20.0, "speed_max": 70.0, "gravity": Vector2(0, -40), "additive": true, "damping": 20.0})
		&"intro_land":
			AudioManager.play_sfx("land_hard", 0.0, 0.0)
			camera.add_trauma(0.45)
			_dust(d["pos"], 18, 170.0)
		&"wake_done":
			if room.data.area_title != "":
				ui.show_area_title(tr(room.data.area_title), tr(room.data.area_title + "_SUB"))
			AudioManager.play_music(room.data.music, 5.0)


func _dust(pos: Vector2, amount: int, speed: float) -> void:
	FX.burst(fx_root, pos + Vector2(0, -2), {"amount": amount, "life": 0.45, "color": Color(0.78, 0.8, 0.84, 0.55),
		"dir": Vector2.UP, "spread": 85.0, "speed_min": speed * 0.3, "speed_max": speed, "gravity": Vector2(0, 160),
		"damping": 120.0, "scale_min": 0.1, "scale_max": 0.24})


## Caixas de colisão e alvos (F3).
class DebugDraw extends Node2D:
	var main

	func _ready() -> void:
		z_index = 50
		light_mask = 0

	func _draw() -> void:
		var p: Player = main.player
		draw_rect(p.body.rect(), Color(0.3, 1.0, 0.5, 0.9), false, 1.5)
		draw_rect(p.hurtbox(), Color(1.0, 0.4, 0.3, 0.7), false, 1.0)
		if p.attack_active():
			draw_rect(p.attack_rect(), Color(1.0, 0.9, 0.3, 0.8), false, 1.5)
		draw_circle(p.safe_pos + p.body.size * Vector2(0.5, 1.0), 3.0, Color(0.4, 0.7, 1.0))
		for s in p.strikeables:
			if is_instance_valid(s):
				draw_rect(s.hit_rect(), Color(0.5, 0.8, 1.0, 0.7), false, 1.0)
