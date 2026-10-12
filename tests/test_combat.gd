extends "res://tests/test_base.gd"
## Combate: golpes nos Ecos, dano por contato, invencibilidade, os votos de cada
## Eco (Vigia, Saltador, Mariposa), morte e o Eco póstumo.

const HALL := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"########################################",
]


func _eco(e: Eco, p: Player, cell: Vector2i) -> Eco:
	e.setup(p.grid, cell)
	_nodes.append(e)
	p.strikeables.append(e)
	return e


func _tick(p: Player, ecos: Array, frames: int) -> void:
	for i in frames:
		p.step(DT)
		Eco.update_all(ecos, DT, p)


func test_strike_damages_and_kills_eco() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var s := _eco(Saltador.new(), p, Vector2i(11, 10))
	s.aware = true
	s.memory = 99.0
	p.aura = 50.0
	p.regen_delay_t = 10.0
	tap(p, &"attack")
	run(p, 3)
	check(s.hp == 1, "golpe tira 1 de vida (hp %d)" % s.hp)
	check(p.aura > 50.0, "acertar um Eco devolve aura (%.1f)" % p.aura)
	run(p, 20)
	tap(p, &"attack")
	run(p, 3)
	check(not s.alive(), "segundo golpe apaga o Saltador")
	for i in 60:
		s.step(DT, p)
	check(s.dead, "o Eco se desfaz")


func test_sneak_and_ren_strikes_hit_harder() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var v := _eco(Vigia.new(), p, Vector2i(11, 10))
	v.facing = 1
	check(not v.aware, "o Vigia olha para o outro lado")
	tap(p, &"attack")
	run(p, 3)
	check(v.hp == 1, "golpe pelas costas tira 2 (hp %d)" % v.hp)
	check(v.aware, "e agora ele sabe")
	run(p, 20)
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	check(v.hp <= 0 or not v.alive(), "a explosão do Ren acaba com ele")


func test_contact_hurts_with_knockback_and_invulnerability() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var s := _eco(Saltador.new(), p, Vector2i(11, 10))
	s.body.pos.x = p.body.pos.x + 10.0
	Eco.update_all([s], DT, p)
	check(p.vitality == 4, "encostar no Eco custa uma gota (ficou %d)" % p.vitality)
	check(p.state == Player.State.KNOCKBACK, "e empurra")
	check(p.vel.x < 0.0, "para longe do Eco")
	check(p.invuln_t > 0.9, "invencível por um tempo")
	Eco.update_all([s], DT, p)
	check(p.vitality == 4, "na invencibilidade não perde outra")
	run(p, 20)
	check(p.state == Player.State.NORMAL, "o controle volta")


func test_vigia_charges_the_flame_but_not_the_dark() -> void:
	var p := make_player(HALL, Vector2i(6, 10))
	var v := _eco(Vigia.new(), p, Vector2i(14, 10))
	v.facing = -1
	var start_x := v.body.pos.x
	var charged := false
	for i in 120:
		p.step(DT)
		Eco.update_all([v], DT, p)
		if v.s == Vigia.S.CHARGE:
			charged = true
	check(charged, "o Vigia viu a chama e investiu")
	check(p.vitality < 5, "e acertou a Vela")
	check(v.body.pos.x < start_x - 64.0, "investiu na direção dela")
	# no escuro
	var q := make_player(HALL, Vector2i(6, 10))
	var w := _eco(Vigia.new(), q, Vector2i(14, 10))
	w.facing = -1
	inp(q).set_held(&"zetsu", true)
	for i in 120:
		q.step(DT)
		Eco.update_all([w], DT, q)
	check(not w.aware and w.s != Vigia.S.CHARGE, "no Zetsu o Vigia não vê nada")


func test_vigia_only_sees_ahead() -> void:
	var p := make_player(HALL, Vector2i(5, 10))
	var v := _eco(Vigia.new(), p, Vector2i(12, 10))
	v.facing = 1
	_tick(p, [v], 10)
	check(not v.aware, "a Vela atrás dele, longe, não é vista")
	v.facing = -1
	_tick(p, [v], 2)
	check(v.aware, "virou de frente, viu")


func test_pogo_on_saltador() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var s := _eco(Saltador.new(), p, Vector2i(10, 10))
	s.stun_t = 99.0
	p.body.pos.y = s.body.pos.y - p.body.size.y - 30.0
	p.vel = Vector2(0, 200)
	inp(p).set_held(&"move_down", true)
	tap(p, &"attack")
	var bounced := false
	for i in 10:
		p.step(DT)
		if p.vel.y < -500.0:
			bounced = true
	check(bounced, "quicou no Saltador")
	check(s.hp < s.max_hp, "e machucou ele")


func test_mariposa_dives_at_the_flame_and_loses_it_in_zetsu() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var m := _eco(Mariposa.new(), p, Vector2i(16, 5))
	var dived := false
	for i in 300:
		p.step(DT)
		Eco.update_all([m], DT, p)
		if m.s == Mariposa.S.DIVE:
			dived = true
			break
	check(dived, "a Mariposa mergulhou na chama")
	var q := make_player(HALL, Vector2i(10, 10))
	var n := _eco(Mariposa.new(), q, Vector2i(16, 5))
	inp(q).set_held(&"zetsu", true)
	for i in 240:
		q.step(DT)
		Eco.update_all([n], DT, q)
	check(n.s == Mariposa.S.DRIFT, "com a chama apagada, continua pairando")


func test_ren_burst_pushes_ecos_away() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var s := _eco(Saltador.new(), p, Vector2i(12, 10))
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	check(s.hp == 1, "a explosão fere")
	check(s.vel.x > 200.0, "e empurra para longe (vx %.0f)" % s.vel.x)
	check(s.stun_t > 0.3, "e atordoa")


func test_death_leaves_a_shade_that_gives_aura_back() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.vitality = 1
	var died := [false]
	p.fx.connect(func(ev, _d): if ev == &"die": died[0] = true)
	check(p.take_hit(1, p.body.center() + Vector2(20, 0)), "golpe pegou")
	check(p.is_dead() and died[0], "a última gota apaga a Vela")
	check(not p.can_be_hit(), "apagada, nada mais fere")
	var spot := p.shade_spot()
	var q := make_player(HALL, Vector2i(5, 10))
	var sh := EcoVela.new()
	sh.setup_at(q.grid, spot)
	_nodes.append(sh)
	q.strikeables.append(sh)
	var freed := [false]
	sh.fx.connect(func(ev, d): if ev == &"eco_die" and d["kind"] == "eco_vela": freed[0] = true)
	_tick(q, [sh], 20)
	check(sh.aware, "o Eco póstumo sente a Vela")
	for k in 6:
		sh.stun_t = 0.0
		sh.body.pos = q.body.pos + Vector2(q.facing * 30.0, 0)
		q.attack_cd_t = 0.0
		q.invuln_t = 5.0
		tap(q, &"attack")
		run(q, 3)
		if not sh.alive():
			break
	check(freed[0], "vencido, o Eco póstumo devolve a aura")


func test_spikes_cost_a_drop_and_can_kill() -> void:
	var rows := [
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
		"#.........^^^^...............#",
		"##############################",
	]
	var p := make_player(rows, Vector2i(5, 10))
	inp(p).set_held(&"move_right", true)
	for i in 120:
		p.step(DT)
		if p.state == Player.State.HURT:
			break
	check(p.vitality == 4, "espinho custa uma gota (ficou %d)" % p.vitality)
	inp(p).set_held(&"move_right", false)
	run(p, 80)
	check(p.state == Player.State.NORMAL, "volta ao chão seguro")
	p.vitality = 1
	inp(p).set_held(&"move_right", true)
	for i in 120:
		p.step(DT)
		if p.is_dead():
			break
	check(p.is_dead(), "com uma gota, o espinho apaga a Vela")


# ---------------------------------------------------------------- Penitente

func _penitente_facing_vela(p: Player, cell: Vector2i) -> Penitente:
	var e := _eco(Penitente.new(), p, cell) as Penitente
	e.facing = -1 if p.body.center().x < e.body.center().x else 1
	return e


func test_penitente_blocks_from_the_front_but_not_from_behind() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var e := _penitente_facing_vela(p, Vector2i(12, 10))
	p.facing = 1
	e.aware = true
	e.memory = 99.0
	tap(p, &"attack")
	run(p, 3)
	check(e.hp == 5, "de frente, o cajado bate na laje (hp %d)" % e.hp)
	check(e.has_slab, "a laje aguenta o golpe comum")
	e.facing = 1
	run(p, 25)
	p.body.pos.x = 10 * 32.0 + 5.0
	tap(p, &"attack")
	run(p, 3)
	check(e.hp < 5, "pelas costas, o golpe passa (hp %d)" % e.hp)


func test_penitente_slam_hurts_and_ken_turns_it_back() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var e := _penitente_facing_vela(p, Vector2i(13, 10))
	p.facing = 1
	var raised := false
	for i in 120:
		_tick(p, [e], 1)
		if e.s == Penitente.S.RAISE:
			raised = true
		if p.vitality < 5:
			break
	check(raised, "ele vê a chama, chega perto e ergue a laje")
	check(p.vitality == 3, "a pancada da laje tira duas gotas (ficou %d)" % p.vitality)
	# de novo, agora abrindo o Ren no instante da pancada (Ken)
	var p2 := make_player(HALL, Vector2i(10, 10))
	var e2 := _penitente_facing_vela(p2, Vector2i(13, 10))
	p2.facing = 1
	p2.aura = 100.0
	var parried := false
	for i in 120:
		var slam_next := e2.s == Penitente.S.RAISE and e2.s_t >= e2._raise_time() - 2.0 * DT
		inp(p2).set_held(&"ren", slam_next or p2.ren)
		_tick(p2, [e2], 1)
		if e2.s == Penitente.S.STAGGER:
			parried = true
			break
	check(parried, "Ken: a pancada volta e ele cambaleia")
	check(p2.vitality == 5, "sem perder gota (ficou %d)" % p2.vitality)
	check(e2.hp == 3, "a explosão do Ren e a pancada devolvida ferem quem bateu (hp %d)" % e2.hp)
	inp(p2).set_held(&"ren", false)
	inp(p2).set_held(&"move_right", true)
	_tick(p2, [e2], 14)
	inp(p2).set_held(&"move_right", false)
	check(e2.s == Penitente.S.STAGGER, "ainda cambaleando")
	var hp_before := e2.hp
	tap(p2, &"attack")
	_tick(p2, [e2], 3)
	check(e2.hp < hp_before, "cambaleando, a laje caída não protege (hp %d)" % e2.hp)


func test_shu_cracks_the_slab_and_ko_breaks_it() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var e := _penitente_facing_vela(p, Vector2i(12, 10))
	e.aware = true
	e.memory = 99.0
	p.facing = 1
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	run(p, 2)
	tap(p, &"attack")
	run(p, 20)
	check(e.has_slab and e.slab_hp == 1, "com Shu, o golpe racha a laje")
	inp(p).set_held(&"ren", true)
	tap(p, &"attack")
	run(p, 3)
	check(not e.has_slab, "o segundo golpe com Shu quebra a laje")
	var p2 := make_player(HALL, Vector2i(10, 10))
	var e2 := _penitente_facing_vela(p2, Vector2i(12, 10))
	e2.aware = true
	e2.memory = 99.0
	p2.facing = 1
	p2.aura = 100.0
	inp(p2).set_held(&"attack", true)
	run(p2, 75)
	inp(p2).set_held(&"attack", false)
	run(p2, 3)
	check(not e2.has_slab, "o Ko parte a laje de uma vez")
	check(not e2.alive() or e2.hp < 0 or e2.hp <= 5 - 7, "e passa com tudo (hp %d)" % e2.hp)


func test_bell_only_sings_with_ko() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var b := Bell.new()
	b.setup(60.0, 0.0)
	b.position = Vector2(12.5 * 32.0, 10 * 32.0 - 70.0)
	_nodes.append(b)
	p.strikeables = [b]
	p.facing = 1
	var tolls := []
	b.rung.connect(func(strong): tolls.append(strong))
	tap(p, &"attack")
	run(p, 20)
	check(tolls == [false], "o golpe comum só arranca um gemido (%s)" % [tolls])
	p.aura = 100.0
	inp(p).set_held(&"attack", true)
	run(p, 75)
	inp(p).set_held(&"attack", false)
	run(p, 3)
	check(tolls.count(true) == 1 and tolls.back() == true, "com o Ko o sino canta (%s)" % [tolls])
