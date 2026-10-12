extends "res://tests/test_base.gd"
## Nen: aura, derreter, Ten (vazamento), Zetsu (véus, esconder) e Ren (explosão).

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

## Corredor com um véu de aura no meio.
const VEIL := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#..............~.............#",
	"#..............~.............#",
	"#..............~.............#",
	"#..............~.............#",
	"#..............~.............#",
	"##############################",
]

## Casca de aura fechando o corredor.
const SHELL := [
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"#...........**...............#",
	"#...........**...............#",
	"#...........**...............#",
	"#...........**...............#",
	"#...........**...............#",
	"##############################",
]


func _settle(p: Player) -> void:
	run(p, 10)
	p.regen_delay_t = 0.0


func test_dash_and_air_jump_cost_aura() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	_settle(p)
	p.aura = 100.0
	tap(p, &"dash")
	check_range(p.aura, 81.0, 83.0, "aura depois do dash (100 - 18)")
	check(p.state == Player.State.DASH, "o dash saiu")
	run(p, 30)
	p.aura = 100.0
	tap(p, &"jump")
	run(p, 8)
	tap(p, &"jump")
	check_range(p.aura, 85.0, 87.5, "aura depois do Sopro (100 - 14)")


func test_aura_regenerates_on_ground() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	_settle(p)
	p.aura = 20.0
	run(p, 60)
	check_range(p.aura, 85.0, 92.0, "parada no chão, ~70/s de volta")


func test_melt_when_aura_is_empty() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	_settle(p)
	var melts := [0]
	p.fx.connect(func(ev, _d): if ev == &"melt": melts[0] += 1)
	p.aura = 0.0
	p.regen_delay_t = 10.0
	tap(p, &"dash")
	check(p.state == Player.State.DASH, "sem aura, o dash ainda sai (derretendo)")
	check(p.vitality == 4, "derreter custa uma gota (ficou %d)" % p.vitality)
	check(melts[0] == 1, "efeito de derreter")
	run(p, 30)
	p.aura = 0.0
	p.vitality = 1
	p.regen_delay_t = 10.0
	tap(p, &"dash")
	check(p.state != Player.State.DASH, "com uma gota só, a chama não responde")
	check(p.vitality == 1, "e não apaga a Vela")


func test_leaking_before_ten() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	p.learned["ten"] = false
	p.aura = 100.0
	run(p, 30)
	check(p.aura <= p.nen.aura_max * p.nen.leak_cap + 0.01, "vazando, a chama segura pouca aura (%.1f)" % p.aura)
	check(p.damage_mult() == 2, "sem Ten, golpe fere em dobro")
	p.learned["ten"] = true
	check(p.damage_mult() == 1, "com Ten, dano normal")
	run(p, 60)
	check(p.aura > 90.0, "com Ten a chama enche (%.1f)" % p.aura)


func test_zetsu_opens_veils_and_closes_dash() -> void:
	var p := make_player(VEIL, Vector2i(10, 10))
	inp(p).set_held(&"move_right", true)
	run(p, 90)
	var veil_x := 15 * 32.0
	check(p.body.pos.x + p.body.size.x <= veil_x + 0.01, "sem Zetsu o véu é parede (x=%.1f)" % p.body.pos.x)
	inp(p).set_held(&"zetsu", true)
	run(p, 4)
	check(p.zetsu, "segurando, Zetsu liga")
	tap(p, &"dash")
	check(p.state != Player.State.DASH, "no Zetsu não há Passo de Ren")
	run(p, 6)
	check(p.grid.overlaps_veil(p.body.pos, p.body.size), "entrou no véu")
	inp(p).set_held(&"zetsu", false)
	run(p, 2)
	check(p.zetsu, "dentro do véu a chama não reacende")
	run(p, 60)
	check(p.body.pos.x > veil_x + 32.0, "atravessou o véu (x=%.1f)" % p.body.pos.x)
	check(not p.zetsu, "fora do véu, Zetsu solta")
	check(p.damage_mult() == 1, "e o dano volta ao normal")


func test_zetsu_speed_and_regen() -> void:
	var p := make_player(FLAT, Vector2i(3, 10))
	_settle(p)
	inp(p).set_held(&"zetsu", true)
	inp(p).set_held(&"move_right", true)
	run(p, 30)
	check_range(p.vel.x, p.tuning.run_speed * p.nen.zetsu_speed_mult - 1.0, p.tuning.run_speed * p.nen.zetsu_speed_mult + 1.0, "andar escondida é mais lento")
	check(p.damage_mult() == 2, "no Zetsu o golpe fere em dobro")
	p.aura = 10.0
	p.regen_delay_t = 0.0
	inp(p).set_held(&"move_right", false)
	run(p, 30)
	check(p.aura > 25.0, "no Zetsu a aura volta (%.1f)" % p.aura)


func test_ren_burst_breaks_shells_and_drains() -> void:
	var p := make_player(SHELL, Vector2i(10, 10))
	inp(p).set_held(&"move_right", true)
	run(p, 40)
	check(p.body.pos.x + p.body.size.x <= 12 * 32.0 + 0.01, "a casca segura a Vela")
	inp(p).set_held(&"move_right", false)
	p.aura = 100.0
	var broken := [0]
	p.fx.connect(func(ev, d): if ev == &"ren_burst": broken[0] = d["broken"].size())
	inp(p).set_held(&"ren", true)
	p.step(DT)
	check(p.ren, "Ren abriu")
	check(broken[0] == 10, "a explosão rachou a casca inteira (%d células)" % broken[0])
	check(p.aura < 100.0 - p.nen.ren_burst_cost + 0.5, "a explosão custa aura")
	var before := p.aura
	run(p, 30)
	check(p.aura < before - p.nen.ren_drain * 0.4, "segurar o Ren esvai a aura")
	inp(p).set_held(&"ren", false)
	p.step(DT)
	check(not p.ren, "soltou, fechou")
	inp(p).set_held(&"move_right", true)
	run(p, 60)
	check(p.body.pos.x > 14 * 32.0, "caminho aberto (x=%.1f)" % p.body.pos.x)


func test_ren_needs_aura_and_doubles_damage() -> void:
	var p := make_player(FLAT, Vector2i(5, 10))
	p.aura = 4.0
	p.regen_delay_t = 10.0
	tap(p, &"ren")
	check(not p.ren, "sem aura o Ren não abre")
	check(p.strike_damage(true) == 1, "golpe normal")
	check(p.strike_damage(false) == 2, "golpe num Eco desatento")
	run(p, 1)
	p.aura = 100.0
	tap(p, &"ren")
	check(p.strike_damage(true) == 2, "no Ren o cajado fere em dobro")
