extends Node
## Orquestra o jogo: título, salas, transições, Ecos, morte e Eco póstumo,
## altares (descanso e lições de Nen), escrita em aura, En e mapa da sala,
## sino e portões, efeitos e UI.
##
## A física da Vela e dos Ecos roda aqui para garantir a ordem:
## controles → Vela → Ecos (e dano de contato) → salas/objetos → câmera.
##
## Argumentos de linha de comando (depois de `--`), úteis para testes e capturas:
##   --room=<id>        começa direto numa sala (pula título e intro)
##   --at=<col>,<lin>   posição inicial na sala (célula)
##   --nen=<nível>      técnicas já aprendidas até essa lição: none, ten, zetsu, ren,
##                      gyo, shu, ken, ko ou all (padrão)
##   --shade=<col>,<lin> põe o Eco póstumo da Vela nessa célula da sala inicial
##   --vit=<n>          começa com n gotas de cera
##   --hold=<ações>     segura ações: ren@1-3,move_right@0-2,zetsu (capturas)
##   --smoke=<s>        fecha depois de s segundos de jogo (teste de fumaça do CI: se o
##                      jogo congelar, o tempo de jogo para de correr e o CI estoura)
##   --demo=<rota>      a Vela anda sozinha seguindo uma rota de tools/demo_routes.gd
##   --shot=<arquivo>   salva um print depois de --frames=<n> frames e fecha
##   --autostart        sai da tela de título sozinho (para gravar a intro)
##   --clean            sem granulação de filme (capturas e GIFs menores)

signal _button_pressed

enum Mode { TITLE, PLAY, TRANSITION, REST, DEATH }

const FIRST_ROOM := "poco_fundo"
const VIEW := Vector2(1280, 720)
const TS := 32.0
## Ordem das lições: um altar ensina a dele e as que ficaram para trás.
const LESSONS := ["ten", "zetsu", "ren", "gyo", "shu", "ken", "ko", "en"]
const AURA_COLOR := Color("ffc56a")

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
var _active_glyph: AuraGlyph
var _near_altar: Altar
var _title_t := 0.0
var _rest_t := 0.0
var _rest_ready := false
var _button_wait := false
var _args: Dictionary = {}
var _frames := 0
## Tempo de jogo de verdade (soma dos deltas; para durante o hit-stop).
var _game_time := 0.0
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
	ui.hud.player = player
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
	Game.reset_world()
	_set_nen_level(str(_args.get("nen", "all")))
	if _args.has("shade"):
		var parts := str(_args["shade"]).split(",")
		Game.shade = {"room": room_id, "pos": Vector2((int(parts[0]) + 0.5) * TS, (int(parts[1]) + 0.5) * TS)}
		player.aura_max = player.nen.aura_max * (1.0 - player.nen.shade_share)
		player.aura = player.aura_cap()
	if _args.has("vit"):
		player.vitality = clampi(int(_args["vit"]), 1, player.vitality_max)
	Game.respawn_room = room_id
	Game.respawn_altar = 0
	_load_room(room_id)
	var cell := room.spawn_cell if room.spawn_cell.x >= 0 else Vector2i(3, 3)
	if _args.has("at"):
		var parts := str(_args["at"]).split(",")
		cell = Vector2i(int(parts[0]), int(parts[1]))
	_place_at_cell(cell)
	if _args.has("demo"):
		player.input = DemoRoutes.make_input(str(_args["demo"]), player, room)
	elif _args.has("hold"):
		player.input = _hold_input(str(_args["hold"]))
	AudioManager.play_music(room.data.music, 0.5)
	ui.show_hud(true, 0.0)


## --hold=ren@1-3,move_right@0-2,zetsu : segura ações (para capturas e testes visuais).
func _hold_input(spec: String) -> ScriptedInput:
	var si := ScriptedInput.new()
	for item in spec.split(","):
		var parts := item.split("@")
		var from := 0.0
		var to := 99999.0
		if parts.size() > 1:
			var span := parts[1].split("-")
			from = float(span[0])
			if span.size() > 1:
				to = float(span[1])
		si.timeline.append({"from": from, "to": to, "action": parts[0]})
	return si


## Quantas lições a Vela já tem: none, uma lição (ela e as anteriores) ou all.
func _set_nen_level(level: String) -> void:
	var n := LESSONS.size()
	if level == "none":
		n = 0
	elif level in LESSONS:
		n = LESSONS.find(level) + 1
	for i in LESSONS.size():
		player.learned[LESSONS[i]] = i < n
	player.aura = player.aura_cap()


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
	for cell: Vector2i in Game.opened_cells.get(id, []):
		rd.grid.set_cell(cell.x, cell.y, LevelGrid.Tile.EMPTY)
	if Game.flags.has("sino_" + id):
		rd.grid.open_gates()
	room = Room.new()
	room_root.add_child(room)
	room.build(rd, background)
	room.veils.player = player
	room.aura_layer.player = player
	for e in room.ecos:
		e.fx.connect(_on_eco_fx)
	for b in room.bells:
		b.rung.connect(_on_bell_rung.bind(b))
	if str(Game.shade.get("room", "")) == id:
		var sh := room.spawn_shade(Game.shade["pos"])
		sh.fx.connect(_on_eco_fx)
	player.grid = rd.grid
	player.strikeables = room.strikeables
	camera.setup_room(rd.grid.pixel_size())
	_active_tablet = null
	_active_glyph = null
	_near_altar = null
	ui.hide_inscription()
	if ui.room_map.visible:
		ui.room_map.hide_map(0.1)
	room.update_tint(player.zetsu, player.gyo)
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
	if _button_wait and not get_tree().paused and _is_press(event) and not event.is_action("pause"):
		_button_wait = false
		_button_pressed.emit()
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
		ui.set_paused(paused, room, player)
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
	Game.reset_world()
	_set_nen_level("none")
	player.aura_max = player.nen.aura_max
	player.vitality = player.vitality_max
	player.aura = player.aura_cap()
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
	_game_time += delta
	if _args.has("smoke") and _game_time >= float(_args["smoke"]):
		print("teste de fumaça: %.1f s de jogo, %d quadros, vitalidade %d, mortes %d, golpes em Ecos %d" % [
			_game_time, _frames, player.vitality, player.deaths, player.style["strikes"]])
		get_tree().quit()
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
	room.step_ecos(delta, player)
	# botões também chegam pela entrada da Vela (inclusive a roteirizada)
	if _button_wait and player.input.any_pressed():
		_button_wait = false
		_button_pressed.emit()
	elif mode == Mode.REST and ui.end_card_visible and _rest_t > 2.0 and player.input.any_pressed():
		_leave_rest()
	if mode == Mode.PLAY:
		_update_reading()
		_update_altar()
		if player.is_controllable() or player.state == Player.State.ENTER:
			_check_exit()
	elif mode == Mode.REST:
		_rest_t += delta
		if _rest_ready and _wants_to_stand(player.input):
			_leave_rest()
	camera.follow(delta)


func _process(_delta: float) -> void:
	if room:
		room.update_parallax(camera.view_top_left())
		var post := ($Post/Vignette as ColorRect).material as ShaderMaterial
		post.set_shader_parameter("gyo", room.aura_layer.gyo_k)
	if Game.debug:
		ui.update_debug(player, Engine.get_frames_per_second(), room.data.id if room else "")
		_debug_draw.queue_redraw()


func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("print salvo: ", path)
	get_tree().quit()


func _wait_button() -> void:
	_button_wait = true
	await _button_pressed


# ---------------------------------------------------------------------------
# Estelas e altares
# ---------------------------------------------------------------------------

## Estelas acendem quando a Vela chega perto; a escrita em aura só se lê com os
## olhos de aura (Gyo) ou logo depois da onda do En.
func _update_reading() -> void:
	var c := player.body.center()
	var t := room.tablet_near(c)
	var gl: AuraGlyph = null if t else room.glyph_near(c)
	if t == _active_tablet and gl == _active_glyph:
		return
	if _active_tablet and _active_tablet != t:
		_active_tablet.set_active(false)
	_active_tablet = t
	_active_glyph = gl
	if t:
		t.set_active(true)
		ui.show_inscription(tr(t.text_key))
		AudioManager.play_sfx("tablet", -7.0, 0.0)
	elif gl:
		ui.show_inscription(tr(gl.text_key), gl.color)
		if not Game.aura_read.has(gl.text_key):
			Game.aura_read[gl.text_key] = true
			gl.read = true
			AudioManager.play_sfx("aura_read", -4.0, 0.0)
			ui.hud.flash()
		else:
			AudioManager.play_sfx("aura_read", -12.0, 0.0)
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
	var can_rest := a != null and player.grounded and player.state == Player.State.NORMAL and not player.kneeling()
	ui.show_rest_prompt(can_rest, can_rest and not _pending_lessons(a.lesson).is_empty())
	if can_rest and player.input.pressed(&"move_up"):
		_rest(a)


## Lições que este altar ainda tem para dar: a dele e as anteriores que faltam.
func _pending_lessons(lesson: String) -> Array:
	var out := []
	var idx := LESSONS.find(lesson)
	for i in range(0, idx + 1):
		if not player.learned.get(LESSONS[i], false):
			out.append(LESSONS[i])
	return out


func _rest(a: Altar) -> void:
	mode = Mode.REST
	_rest_t = 0.0
	_rest_ready = false
	player.rest()
	player.refill()
	Game.respawn_room = room.data.id
	Game.respawn_altar = a.index
	ui.show_rest_prompt(false)
	ui.hide_inscription()
	AudioManager.play_sfx("altar", -3.0, 0.0)
	FX.burst(fx_root, a.position + Vector2(0, -30), {"amount": 26, "life": 2.2, "color": Color(1.0, 0.82, 0.55, 0.8),
		"dir": Vector2.UP, "spread": 50.0, "speed_min": 15.0, "speed_max": 45.0, "gravity": Vector2(0, -12), "additive": true,
		"rect": Vector2(50, 6), "explosive": 0.3, "damping": 4.0, "scale_min": 0.08, "scale_max": 0.16})
	var lessons := _pending_lessons(a.lesson)
	await get_tree().create_timer(1.8 if not lessons.is_empty() else 1.2).timeout
	for lesson: String in lessons:
		if mode != Mode.REST:
			return
		await _teach(lesson)
	if mode != Mode.REST:
		return
	if a.lesson == "end":
		ui.show_hud(false)
		ui.show_end_card()
	else:
		_rest_ready = true


func _teach(lesson: String) -> void:
	player.learned[lesson] = true
	player.refill()
	ui.hud.flash()
	AudioManager.play_sfx("lesson", -1.0, 0.0)
	camera.add_trauma(0.22)
	var c := player.body.center()
	FX.ring(fx_root, c, Color(1.0, 0.86, 0.6, 0.9), 170.0, 0.9)
	FX.ring(fx_root, c, Color(1.0, 0.86, 0.6, 0.5), 260.0, 1.4)
	FX.burst(fx_root, c, {"amount": 40, "life": 1.6, "color": Color(AURA_COLOR, 0.9), "spread": 180.0,
		"speed_min": 60.0, "speed_max": 200.0, "gravity": Vector2(0, -40), "additive": true, "damping": 60.0})
	ui.show_lesson(lesson)
	await get_tree().create_timer(1.6).timeout
	ui.show_lesson_continue()
	await _wait_button()
	ui.hide_lesson()
	await get_tree().create_timer(0.5).timeout


func _wants_to_stand(inp: PlayerInput) -> bool:
	return inp.move.x != 0.0 or inp.pressed(&"jump") or inp.pressed(&"attack") or inp.pressed(&"dash")


func _leave_rest() -> void:
	if ui.end_card_visible:
		ui.hide_end_card()
		ui.show_hud(true)
	_rest_ready = false
	player.stand_up()
	mode = Mode.PLAY


# ---------------------------------------------------------------------------
# Morte, Eco póstumo e renascimento
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	mode = Mode.DEATH
	AudioManager.stop_music(1.6)
	AudioManager.loop_sfx("ren_hum", false)
	AudioManager.set_muffled(false)
	ui.hide_inscription()
	ui.show_rest_prompt(false)
	await get_tree().create_timer(1.9).timeout
	await ui.fade_to(1.0, 0.9)
	# a aura que escorreu fica onde a Vela apagou, presa ao Eco dela
	Game.shade = {"room": room.data.id, "pos": player.shade_spot()}
	player.aura_max = player.nen.aura_max * (1.0 - player.nen.shade_share)
	_load_room(Game.respawn_room)
	_revive_at_altar()
	camera.snap()
	room.update_parallax(camera.view_top_left())
	await get_tree().create_timer(0.4).timeout
	mode = Mode.PLAY
	await ui.fade_to(0.0, 1.1)


## Renasce de pé diante do altar (ou na entrada, se a sala não tiver altar).
func _revive_at_altar() -> void:
	var altars := room.data.markers_of("A")
	var pos: Vector2
	if altars.is_empty():
		var cell := room.spawn_cell if room.spawn_cell.x >= 0 else Vector2i(3, 3)
		pos = Vector2(cell.x * TS + (TS - Player.SIZE.x) * 0.5, (cell.y + 1) * TS - Player.SIZE.y)
	else:
		var a: Vector2i = altars[clampi(Game.respawn_altar, 0, altars.size() - 1)]
		pos = Vector2((a.x + 0.5) * TS + 46.0 - Player.SIZE.x * 0.5, (a.y + 1) * TS - Player.SIZE.y)
	player.revive(pos)
	player.facing = -1


func _free_shade(pos: Vector2) -> void:
	Game.shade = {}
	player.aura_max = player.nen.aura_max
	player.aura = player.aura_cap()
	ui.hud.flash()
	AudioManager.play_sfx("shade_free", -2.0, 0.0)
	camera.add_trauma(0.3)
	FX.ring(fx_root, pos, Color(1.0, 0.86, 0.6, 0.9), 120.0, 0.7)
	FX.burst(fx_root, pos, {"amount": 34, "life": 1.4, "color": Color(AURA_COLOR, 0.9), "spread": 180.0,
		"speed_min": 50.0, "speed_max": 180.0, "gravity": Vector2(0, -30), "additive": true, "damping": 50.0})


# ---------------------------------------------------------------------------
# Efeitos da Vela → som, partículas, câmera
# ---------------------------------------------------------------------------

func _on_player_fx(ev: StringName, d: Dictionary) -> void:
	var aura := AURA_COLOR
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
		&"shell_ting":
			AudioManager.play_sfx("shell_ting", -5.0, 0.05)
			Game.hitstop(0.02)
			FX.burst(fx_root, d["pos"], {"amount": 8, "life": 0.35, "color": Color(ShellView.AMBER, 0.9), "spread": 180.0,
				"speed_min": 60.0, "speed_max": 170.0, "gravity": Vector2(0, 500), "additive": true, "scale_min": 0.05, "scale_max": 0.1})
		&"wall_slide":
			AudioManager.loop_sfx("wall_slide", bool(d.get("on", false)), -12.0)
		&"hurt":
			AudioManager.loop_sfx("wall_slide", false)
			AudioManager.play_sfx("hurt", -2.0, 0.03)
			if room:
				room.aura_layer.flash_near(d["pos"], 90.0)
			Game.hitstop(0.11)
			camera.add_trauma(0.55)
			FX.burst(fx_root, d["pos"], {"amount": 22, "life": 0.6, "color": Color("ebe0ca"), "spread": 180.0,
				"speed_min": 80.0, "speed_max": 260.0, "gravity": Vector2(0, 700)})
			FX.burst(fx_root, d["pos"], {"amount": 14, "life": 0.6, "color": Color(aura, 0.9), "spread": 180.0, "additive": true})
		&"hit":
			AudioManager.loop_sfx("wall_slide", false)
			AudioManager.play_sfx("hurt", -3.0, 0.04)
			AudioManager.play_sfx("eco_strike", -4.0, 0.05)
			Game.hitstop(0.25 if d.get("fatal", false) else 0.12)
			camera.add_trauma(0.5)
			var away := Vector2(float(d.get("dir", 1.0)), -0.4)
			FX.burst(fx_root, d["pos"], {"amount": 18, "life": 0.55, "color": Color("ebe0ca"), "dir": away, "spread": 70.0,
				"speed_min": 90.0, "speed_max": 260.0, "gravity": Vector2(0, 700)})
			FX.burst(fx_root, d["pos"], {"amount": 12, "life": 0.5, "color": Color(aura, 0.9), "spread": 180.0, "additive": true})
		&"die":
			AudioManager.play_sfx("death", -1.0, 0.0)
			camera.add_trauma(0.6)
			FX.burst(fx_root, d["pos"] + Vector2(0, -20), {"amount": 24, "life": 2.0, "color": Color(0.55, 0.58, 0.64, 0.5), "dir": Vector2.UP,
				"spread": 30.0, "speed_min": 15.0, "speed_max": 50.0, "gravity": Vector2(0, -20), "damping": 6.0, "explosive": 0.4,
				"scale_min": 0.2, "scale_max": 0.4})
			_on_player_died()
		&"melt":
			AudioManager.play_sfx("melt", -4.0, 0.06)
			FX.burst(fx_root, d["pos"] + Vector2(0, 10), {"amount": 14, "life": 0.8, "color": Color("ebe0ca"), "dir": Vector2.DOWN,
				"spread": 50.0, "speed_min": 20.0, "speed_max": 90.0, "gravity": Vector2(0, 600), "scale_min": 0.08, "scale_max": 0.16})
		&"fizzle":
			AudioManager.play_sfx("fizzle", -9.0, 0.08)
			FX.burst(fx_root, d["pos"] + Vector2(0, -30), {"amount": 6, "life": 0.6, "color": Color(0.7, 0.72, 0.78, 0.45), "dir": Vector2.UP,
				"spread": 40.0, "speed_min": 10.0, "speed_max": 40.0, "gravity": Vector2(0, -20), "scale_min": 0.12, "scale_max": 0.22})
		&"zetsu":
			var on := bool(d.get("on", false))
			AudioManager.play_sfx("zetsu_on" if on else "zetsu_off", -6.0 if on else -9.0, 0.02)
			AudioManager.set_muffled(on)
			if room:
				room.update_tint(on, player.gyo)
			if on:
				FX.burst(fx_root, d["pos"] + Vector2(0, -28), {"amount": 8, "life": 0.9, "color": Color(0.7, 0.72, 0.78, 0.4), "dir": Vector2.UP,
					"spread": 25.0, "speed_min": 10.0, "speed_max": 35.0, "gravity": Vector2(0, -25), "scale_min": 0.12, "scale_max": 0.22})
		&"ren_burst":
			AudioManager.play_sfx("ren_burst", -1.0, 0.03)
			AudioManager.loop_sfx("ren_hum", true, -15.0)
			Game.hitstop(0.05)
			camera.add_trauma(0.38)
			var r: float = d.get("radius", 120.0)
			FX.ring(fx_root, d["pos"], Color(aura, 0.95), r, 0.32)
			FX.ring(fx_root, d["pos"], Color(1.0, 0.95, 0.85, 0.6), r * 0.6, 0.22)
			FX.burst(fx_root, d["pos"], {"amount": 30, "life": 0.6, "color": Color(aura, 0.9), "spread": 180.0,
				"speed_min": 200.0, "speed_max": 420.0, "gravity": Vector2.ZERO, "additive": true, "damping": 420.0})
			_shatter_shells(d.get("broken", []))
		&"ren_end":
			AudioManager.loop_sfx("ren_hum", false)
		&"gyo":
			var on_g := bool(d.get("on", false))
			AudioManager.play_sfx("gyo_on" if on_g else "gyo_off", -8.0 if on_g else -11.0, 0.02)
			if room:
				room.update_tint(player.zetsu, on_g)
			if not on_g and bool(d.get("empty", false)):
				_on_player_fx(&"fizzle", d)
		&"en_kneel":
			AudioManager.play_sfx("en_kneel", -8.0, 0.03)
			_dust(d["pos"], 5, 40.0)
		&"en":
			_spread_en(d["pos"], float(d.get("speed", 1100.0)))
		&"ko_charge":
			AudioManager.loop_sfx("ko_charge", true, -9.0)
		&"ko_ready":
			AudioManager.play_sfx("ko_ready", -4.0, 0.0)
			camera.add_trauma(0.08)
			FX.ring(fx_root, d["pos"] + Vector2(player.facing * 20.0, -8.0), Color(aura, 0.9), 22.0, 0.25)
		&"ko_cancel":
			AudioManager.loop_sfx("ko_charge", false)
		&"ko":
			AudioManager.loop_sfx("ko_charge", false)
			AudioManager.play_sfx("ko_release", 0.0, 0.0)
			Game.hitstop(0.09)
			camera.add_trauma(0.55)
			var kp: Vector2 = d["pos"] + Vector2(float(d["dir"]) * 56.0, -6.0)
			FX.ring(fx_root, kp, Color(1.0, 0.95, 0.85, 0.95), 70.0, 0.3)
			FX.ring(fx_root, kp, Color(aura, 0.8), 120.0, 0.45)
			FX.burst(fx_root, kp, {"amount": 34, "life": 0.55, "color": Color(aura, 0.95), "dir": Vector2(float(d["dir"]), 0), "spread": 40.0,
				"speed_min": 220.0, "speed_max": 520.0, "gravity": Vector2.ZERO, "additive": true, "damping": 520.0})
		&"ken_parry":
			AudioManager.play_sfx("ken_parry", -1.0, 0.03)
			Game.hitstop(0.12)
			camera.add_trauma(0.35)
			FX.ring(fx_root, d["pos"], Color(1.0, 0.97, 0.9, 0.95), 46.0, 0.25)
			FX.ring(fx_root, player.body.center(), Color(aura, 0.8), 64.0, 0.35)
			FX.burst(fx_root, d["pos"], {"amount": 18, "life": 0.45, "color": Color(1.0, 0.92, 0.7, 1.0), "dir": Vector2(float(d.get("dir", 1.0)), -0.3),
				"spread": 70.0, "speed_min": 160.0, "speed_max": 380.0, "gravity": Vector2(0, 500), "additive": true, "scale_min": 0.05, "scale_max": 0.11})
		&"stone_ting":
			AudioManager.play_sfx("stone_ting", -5.0, 0.06)
			Game.hitstop(0.02)
			FX.burst(fx_root, d["pos"], {"amount": 8, "life": 0.35, "color": Color(0.85, 0.8, 0.7, 0.9), "spread": 180.0,
				"speed_min": 60.0, "speed_max": 170.0, "gravity": Vector2(0, 700), "scale_min": 0.05, "scale_max": 0.1})
		&"stone_break":
			_break_stones(d.get("cells", []))
		&"respawn_start":
			ui.fade_to(1.0, 0.24)
		&"respawn_teleport":
			camera.snap()
			ui.fade_to(0.0, 0.3)
			AudioManager.play_sfx("respawn", -5.0, 0.0)
			FX.burst(fx_root, d["pos"], {"amount": 18, "life": 0.7, "color": Color(aura, 0.8), "dir": Vector2.UP, "spread": 180.0,
				"speed_min": 20.0, "speed_max": 70.0, "gravity": Vector2(0, -40), "additive": true, "damping": 20.0})
		&"revive":
			AudioManager.play_sfx("respawn", -3.0, 0.0)
			FX.burst(fx_root, d["pos"], {"amount": 24, "life": 1.2, "color": Color(aura, 0.85), "dir": Vector2.UP, "spread": 120.0,
				"speed_min": 20.0, "speed_max": 80.0, "gravity": Vector2(0, -50), "additive": true, "damping": 20.0})
		&"intro_land":
			AudioManager.play_sfx("land_hard", 0.0, 0.0)
			camera.add_trauma(0.45)
			_dust(d["pos"], 18, 170.0)
		&"wake_done":
			ui.show_hud(true)
			if d.get("revive", false):
				return
			if room.data.area_title != "":
				ui.show_area_title(tr(room.data.area_title), tr(room.data.area_title + "_SUB"))
			AudioManager.play_music(room.data.music, 5.0)


## Shu ou Ko derrubou um muro de pedra solta: pedras rolando e poeira.
func _break_stones(cells: Array) -> void:
	if cells.is_empty() or room == null:
		return
	Game.add_opened(room.data.id, cells)
	room.stones.refresh()
	AudioManager.play_sfx("stone_break", -1.0, 0.04)
	Game.hitstop(0.05)
	camera.add_trauma(0.4)
	for k: Vector2i in cells:
		var c := (Vector2(k) + Vector2(0.5, 0.5)) * TS
		FX.burst(fx_root, c, {"amount": 7, "life": 1.1, "color": Color("7d7366"), "spread": 180.0,
			"speed_min": 60.0, "speed_max": 240.0, "gravity": Vector2(0, 1100), "explosive": 1.0, "scale_min": 0.12, "scale_max": 0.26})
		FX.burst(fx_root, c, {"amount": 5, "life": 1.4, "color": Color(0.72, 0.7, 0.66, 0.4), "dir": Vector2.UP, "spread": 120.0,
			"speed_min": 10.0, "speed_max": 50.0, "gravity": Vector2(0, -10), "damping": 20.0, "explosive": 0.8, "scale_min": 0.25, "scale_max": 0.45})


## En: a onda sai da Vela, revela o que o In escondia e desenha o mapa da sala.
func _spread_en(pos: Vector2, speed: float) -> void:
	AudioManager.play_sfx("en_pulse", -2.0, 0.0)
	camera.add_trauma(0.12)
	room.aura_layer.add_pulse(pos, speed)
	Game.mapped_rooms[room.data.id] = true
	ui.room_map.show_room(room, player, pos, speed, 5.5)
	ui.hud.flash()


## O sino: um gemido com o golpe comum; com o Ko ele canta e os portões sobem.
func _on_bell_rung(strong: bool, bell: Bell) -> void:
	var bp := bell.position + bell.body_pos()
	if not strong:
		_sfx_at("bell_soft", bp, -6.0)
		return
	AudioManager.play_sfx("bell_toll", 0.0, 0.0)
	Game.hitstop(0.06)
	camera.add_trauma(0.5)
	FX.ring(fx_root, bp, Color(1.0, 0.86, 0.6, 0.8), 180.0, 0.9)
	FX.ring(fx_root, bp, Color(1.0, 0.86, 0.6, 0.5), 320.0, 1.4)
	# o som atordoa os Ecos perto
	for e in room.ecos:
		if is_instance_valid(e) and e.alive() and e.body.center().distance_to(bp) < 420.0:
			e.stun_t = maxf(e.stun_t, 1.2)
			e.flash = 0.7
	var key := "sino_" + room.data.id
	if Game.flags.has(key):
		return
	Game.flags[key] = true
	var cells := room.open_gates(true)
	if not cells.is_empty():
		await get_tree().create_timer(0.5).timeout
		AudioManager.play_sfx("gate_open", -2.0, 0.0)
		camera.add_trauma(0.18)


## A explosão do Ren rachou cascas de aura: estilhaços e o caminho fica aberto.
func _shatter_shells(cells: Array) -> void:
	if cells.is_empty() or room == null:
		return
	Game.add_opened(room.data.id, cells)
	room.shells.refresh()
	AudioManager.play_sfx("shell_break", -1.0, 0.03)
	camera.add_trauma(0.3)
	for k: Vector2i in cells:
		var c := (Vector2(k) + Vector2(0.5, 0.5)) * TS
		FX.burst(fx_root, c, {"amount": 9, "life": 0.9, "color": Color(ShellView.AMBER, 0.95), "spread": 180.0,
			"speed_min": 80.0, "speed_max": 260.0, "gravity": Vector2(0, 900), "explosive": 1.0, "scale_min": 0.08, "scale_max": 0.2})
		FX.burst(fx_root, c, {"amount": 5, "life": 0.7, "color": Color(ShellView.AMBER_HI, 0.8), "spread": 180.0,
			"speed_min": 30.0, "speed_max": 120.0, "gravity": Vector2(0, -20), "additive": true, "damping": 80.0})


# ---------------------------------------------------------------------------
# Efeitos dos Ecos
# ---------------------------------------------------------------------------

func _on_eco_fx(ev: StringName, d: Dictionary) -> void:
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	var cold := Eco.COLD
	match ev:
		&"eco_hit":
			var crit := int(d.get("dmg", 1)) > 1
			AudioManager.play_sfx("eco_hit", -3.0 if crit else -5.0, 0.06)
			if bool(d.get("sneak", false)):
				AudioManager.play_sfx("sneak", -3.0, 0.02)
			Game.hitstop(0.08 if crit else 0.05)
			camera.add_trauma(0.18 if crit else 0.11)
			var dir := Vector2(float(d.get("facing", 1)), -0.2)
			match int(d.get("dir", 0)):
				1:
					dir = Vector2(0, 1)
				-1:
					dir = Vector2(0, -1)
			FX.burst(fx_root, pos, {"amount": 16 if crit else 10, "life": 0.45, "color": Color(cold, 0.9), "dir": dir, "spread": 55.0,
				"speed_min": 120.0, "speed_max": 320.0, "gravity": Vector2(0, 300), "additive": true, "damping": 160.0,
				"scale_min": 0.06, "scale_max": 0.14})
			FX.ring(fx_root, pos, Color(1.0, 0.95, 0.85, 0.8) if crit else Color(cold, 0.8), 46.0 if crit else 30.0, 0.25)
		&"eco_die":
			AudioManager.play_sfx("eco_die", -3.0, 0.04)
			camera.add_trauma(0.22)
			FX.ring(fx_root, pos, Color(cold, 0.7), 60.0, 0.5)
			FX.burst(fx_root, pos, {"amount": 30, "life": 1.3, "color": Color(cold, 0.85), "dir": Vector2.UP, "spread": 70.0,
				"speed_min": 30.0, "speed_max": 120.0, "gravity": Vector2(0, -60), "additive": true, "damping": 30.0,
				"explosive": 0.7, "rect": Vector2(10, 18)})
			if str(d.get("kind", "")) == "eco_vela":
				_free_shade(pos)
		&"eco_notice":
			_sfx_at("eco_notice", pos, -5.0)
		&"vigia_charge":
			_sfx_at("vigia_charge", pos, -4.0)
		&"vigia_stop":
			_dust(pos, 8, 100.0)
		&"saltador_jump":
			if d.get("big", false):
				_sfx_at("saltador_jump", pos, -8.0)
		&"saltador_land":
			_dust(pos, 4, 50.0)
		&"mariposa_windup":
			_sfx_at("mariposa_windup", pos, -6.0)
		&"mariposa_dive":
			_sfx_at("mariposa_dive", pos, -5.0)
		&"mariposa_bonk":
			_dust(pos, 5, 60.0)
		&"shade_wake":
			_sfx_at("shade_wake", pos, -7.0)
		&"shade_windup":
			_sfx_at("mariposa_windup", pos, -6.0)
		&"shade_lunge":
			_sfx_at("dash", pos, -7.0)
		&"penitente_raise":
			_sfx_at("penitente_raise", pos, -4.0)
		&"penitente_slam":
			_sfx_at("penitente_slam", pos, -1.0)
			var near := clampf(1.0 - pos.distance_to(player.body.center()) / 700.0, 0.0, 1.0)
			camera.add_trauma(0.15 + 0.35 * near)
			_dust(pos, 16, 170.0)
		&"penitente_block":
			_sfx_at("stone_ting", pos, -3.0)
			Game.hitstop(0.04)
			FX.burst(fx_root, pos, {"amount": 10, "life": 0.35, "color": Color(1.0, 0.95, 0.85, 0.95), "spread": 160.0,
				"dir": Vector2(-float(d.get("dir", 1)), -0.3), "speed_min": 90.0, "speed_max": 220.0, "gravity": Vector2(0, 600),
				"additive": true, "scale_min": 0.05, "scale_max": 0.1})
		&"slab_crack":
			_sfx_at("stone_crack", pos, -2.0)
			Game.hitstop(0.06)
			camera.add_trauma(0.18)
			FX.burst(fx_root, pos, {"amount": 10, "life": 0.8, "color": Color("7d7366"), "spread": 180.0,
				"speed_min": 60.0, "speed_max": 200.0, "gravity": Vector2(0, 1000), "scale_min": 0.08, "scale_max": 0.16})
		&"slab_break":
			_sfx_at("stone_break", pos, 0.0)
			Game.hitstop(0.08)
			camera.add_trauma(0.4)
			FX.burst(fx_root, pos, {"amount": 26, "life": 1.1, "color": Color("7d7366"), "spread": 180.0,
				"speed_min": 80.0, "speed_max": 300.0, "gravity": Vector2(0, 1100), "explosive": 1.0, "scale_min": 0.1, "scale_max": 0.24})


## Toca um efeito de algo no mundo, mais baixo quanto mais longe da câmera.
func _sfx_at(sfx: String, pos: Vector2, base_db: float) -> void:
	var d := pos.distance_to(camera.get_screen_center_position())
	if d > 1100.0:
		return
	AudioManager.play_sfx(sfx, base_db - clampf((d - 380.0) / 700.0, 0.0, 1.0) * 14.0, 0.05)


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
		if p.ren:
			draw_arc(p.body.center(), p.nen.ren_burst_radius, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.4), 1.0)
		for s in p.strikeables:
			if is_instance_valid(s):
				draw_rect(s.hit_rect(), Color(0.5, 0.8, 1.0, 0.7), false, 1.0)
				if s is Eco and s.alive():
					draw_rect(s.contact_rect(), Color(1.0, 0.3, 0.3, 0.6), false, 1.0)
					var eye: Vector2 = s.eye()
					draw_circle(eye, 2.5, Color(1, 0.4, 0.4) if s.aware else Color(0.6, 0.9, 1.0))
