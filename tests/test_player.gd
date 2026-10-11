extends "res://tests/test_base.gd"
## Sensação da movimentação: os números do GDD viram asserções.

const FLAT := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"##############################",
]

const LEDGE := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"##########...................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"##############################",
]


func _jump_height(hold_frames: int) -> float:
	var p := make_player(FLAT, Vector2i(5, 10))
	var start := p.body.pos.y
	var top := start
	inp(p).set_held(&"jump", true)
	for i in 90:
		if i == hold_frames:
			inp(p).set_held(&"jump", false)
		p.step(DT)
		top = minf(top, p.body.pos.y)
	return start - top


func test_full_jump_height() -> void:
	# ~4,5 tiles (144 px) com o botão segurado
	check_range(_jump_height(90), 130.0, 165.0, "altura do pulo completo")


func test_short_hop_is_much_lower() -> void:
	var full := _jump_height(90)
	var hop := _jump_height(2)
	check(hop < full * 0.45, "pulo curto (%.1f) deveria ser bem menor que o completo (%.1f)" % [hop, full])
	check(hop > 10.0, "pulo curto ainda sai do chão (%.1f)" % hop)


func test_ground_acceleration_is_snappy() -> void:
	var p := make_player(FLAT, Vector2i(3, 10))
	inp(p).set_held(&"move_right", true)
	var frames := 0
	while p.vel.x < p.tuning.run_speed - 0.1 and frames < 60:
		p.step(DT)
		frames += 1
	check(frames <= 5, "chegar na velocidade máxima em até 5 frames (levou %d)" % frames)
	inp(p).set_held(&"move_right", false)
	inp(p).set_held(&"move_left", true)
	frames = 0
	while p.vel.x > 0.0 and frames < 60:
		p.step(DT)
		frames += 1
	check(frames <= 3, "virar em até 3 frames (levou %d)" % frames)


func test_coyote_time_allows_late_jump() -> void:
	var p := make_player(LEDGE, Vector2i(7, 3))
	p.abilities["air_jump"] = false
	inp(p).set_held(&"move_right", true)
	var left_ground_at := -1
	for i in 60:
		p.step(DT)
		if not p.grounded and left_ground_at < 0:
			left_ground_at = i
			break
	check(left_ground_at >= 0, "deveria cair da borda")
	run(p, 3)  # 0,05 s depois de sair do chão
	tap(p, &"jump")
	check(p.vel.y < -600.0, "pulo do coyote time (vy=%.1f)" % p.vel.y)


func test_no_jump_after_coyote_window() -> void:
	var p := make_player(LEDGE, Vector2i(7, 3))
	p.abilities["air_jump"] = false
	inp(p).set_held(&"move_right", true)
	for i in 60:
		p.step(DT)
		if not p.grounded:
			break
	run(p, 12)  # 0,2 s: passou da janela
	tap(p, &"jump")
	check(p.vel.y > 0.0, "sem pulo depois da janela (vy=%.1f)" % p.vel.y)


func test_jump_buffer_before_landing() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	p.abilities["air_jump"] = false
	p.body.pos.y -= 96.0  # 3 tiles acima do chão
	var floor_y := 11 * 32.0
	var pressed := false
	var jumped := false
	for i in 120:
		var dist := floor_y - (p.body.pos.y + p.body.size.y)
		if not pressed and p.vel.y > 0.0 and dist < p.vel.y * DT * 5.0:
			inp(p).set_held(&"jump", true)
			pressed = true
		elif pressed:
			inp(p).set_held(&"jump", false)
		p.step(DT)
		if pressed and p.vel.y < -500.0:
			jumped = true
			break
	check(pressed, "o teste deveria apertar pulo no ar")
	check(jumped, "o pulo apertado antes de pousar deveria sair ao pousar")


func test_dash_distance_and_refresh() -> void:
	var p := make_player(FLAT, Vector2i(4, 10))
	var x0 := p.body.pos.x
	tap(p, &"dash")
	check(p.state == Player.State.DASH, "entrou no dash")
	run(p, 30)
	var dist := p.body.pos.x - x0
	check_range(dist, 125.0, 180.0, "distância do dash no chão")
	check(p.grounded, "dash no chão termina no chão")


func test_air_dash_only_once() -> void:
	var p := make_player(FLAT, Vector2i(4, 10))
	p.body.pos.y = 40.0
	p.grounded = false
	tap(p, &"dash")
	check(p.state == Player.State.DASH, "primeiro dash no ar")
	run(p, 25)
	check(not p.grounded, "ainda no ar")
	tap(p, &"dash")
	check(p.state != Player.State.DASH, "segundo dash no ar não deveria sair")


func test_dash_jump_keeps_momentum() -> void:
	var p := make_player(FLAT, Vector2i(4, 10))
	tap(p, &"dash")
	run(p, 3)
	tap(p, &"jump")
	check(p.state == Player.State.NORMAL and p.vel.y < 0.0, "pulo cancela o dash")
	check(p.vel.x > p.tuning.run_speed * 1.5, "pulo do dash conserva impulso (vx=%.1f)" % p.vel.x)


func test_wall_slide_and_wall_jump() -> void:
	var rows := []
	rows.append("##########")
	for i in 14:
		rows.append("#.......##")
	rows.append("##########")
	var p := make_player(rows, Vector2i(6, 14))
	p.body.pos = Vector2(8 * 32.0 - p.body.size.x, 3 * 32.0)
	p.grounded = false
	inp(p).set_held(&"move_right", true)
	run(p, 30)
	check(p.wall_sliding, "deslizando na parede")
	check(p.vel.y <= p.tuning.wall_slide_max + 0.01, "queda limitada na parede (vy=%.1f)" % p.vel.y)
	check(p.facing == -1, "de costas para a parede")
	tap(p, &"jump")
	check(p.vel.x < 0.0 and p.vel.y < 0.0, "pulo de parede empurra para longe e para cima")


func test_wall_climb_with_repeated_jumps() -> void:
	var rows := []
	rows.append("##########")
	for i in 24:
		rows.append("#.......##")
	rows.append("##########")
	var p := make_player(rows, Vector2i(6, 24))
	p.body.pos = Vector2(8 * 32.0 - p.body.size.x, 18 * 32.0)
	p.grounded = false
	p.abilities["air_jump"] = false
	var y0 := p.body.pos.y
	inp(p).set_held(&"move_right", true)
	run(p, 6)
	for k in 6:
		inp(p).set_held(&"jump", true)
		run(p, 12)
		inp(p).set_held(&"jump", false)
		run(p, 12)
	check(y0 - p.body.pos.y > 96.0, "subir mais de 3 tiles só com pulos de parede (subiu %.1f)" % (y0 - p.body.pos.y))


func test_air_jump_once_and_refresh_on_land() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	tap(p, &"jump")
	run(p, 10)
	tap(p, &"jump")
	check(p.air_jumps_left == 0 and p.vel.y < -500.0, "pulo aéreo saiu")
	run(p, 10)
	var vy_before := p.vel.y
	tap(p, &"jump")
	check(p.vel.y > vy_before, "não existe terceiro pulo")
	run(p, 90)
	check(p.grounded and p.air_jumps_left == p.tuning.air_jumps, "pousar recarrega o pulo aéreo")


func test_pogo_on_spikes() -> void:
	var rows := ["##########"]
	for i in 7:
		rows.append("#........#")
	rows.append("#^^^^^^^^#")
	rows.append("##########")
	var p := make_player(rows, Vector2i(4, 6))
	p.body.pos.y = 64.0
	p.grounded = false
	p.dash_ready = false
	p.air_jumps_left = 0
	inp(p).set_held(&"move_down", true)
	var bounced := false
	for i in 90:
		var bottom := p.body.pos.y + p.body.size.y
		inp(p).set_held(&"attack", bottom > 190.0 and not bounced and p.attack_cd_t <= 0.0)
		p.step(DT)
		if p.vel.y <= -p.tuning.pogo_velocity + 50.0:
			bounced = true
			break
	check(bounced, "pogo nos espinhos")
	check(p.hurt_count == 0, "pogo não machuca")
	check(p.dash_ready and p.air_jumps_left == p.tuning.air_jumps, "pogo recarrega dash e pulo aéreo")


func test_spikes_hurt_and_respawn_on_safe_ground() -> void:
	var p := make_player([
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#....^^....#",
		"############",
	], Vector2i(2, 5))
	var safe := p.body.pos
	inp(p).set_held(&"move_right", true)
	var hurt := false
	for i in 120:
		p.step(DT)
		if p.state == Player.State.HURT:
			hurt = true
			break
	inp(p).set_held(&"move_right", false)
	check(hurt, "espinho machuca")
	run(p, 75)
	check(p.state == Player.State.NORMAL, "voltou ao normal depois do respawn")
	check(p.body.pos.x < 5 * 32.0 - 30.0, "renasceu longe dos espinhos (x=%.1f)" % p.body.pos.x)
	check(p.grounded or p.body.pos.distance_to(safe) < 200.0, "renasceu no chão seguro")


func test_corner_correction_slides_through_gap() -> void:
	var p := make_player([
		"##########",
		"#........#",
		"#........#",
		"####.#####",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	], Vector2i(4, 6))
	p.body.pos.x = 4 * 32.0 - 5.0  # 5 px raspando na quina esquerda do buraco
	var best := p.body.pos.y + p.body.size.y
	inp(p).set_held(&"jump", true)
	for i in 40:
		p.step(DT)
		best = minf(best, p.body.pos.y + p.body.size.y)
	check(best < 3 * 32.0, "atravessou o buraco do teto (pés em %.1f)" % best)


func test_one_way_jump_up_and_drop_down() -> void:
	var p := make_player([
		"##########",
		"#........#",
		"#........#",
		"#..====..#",
		"#........#",
		"#........#",
		"##########",
	], Vector2i(4, 5))
	inp(p).set_held(&"jump", true)
	run(p, 20)
	inp(p).set_held(&"jump", false)
	run(p, 60)
	check(p.grounded and is_equal_approx(p.body.pos.y + p.body.size.y, 96.0), "subiu e ficou em cima da plataforma (pés em %.1f)" % (p.body.pos.y + p.body.size.y))
	inp(p).set_held(&"move_down", true)
	tap(p, &"jump")
	inp(p).set_held(&"move_down", true)
	run(p, 60)
	check(is_equal_approx(p.body.pos.y + p.body.size.y, 192.0), "baixo + pulo atravessa para baixo (pés em %.1f)" % (p.body.pos.y + p.body.size.y))
