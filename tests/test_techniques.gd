extends "res://tests/test_base.gd"
## Técnicas avançadas: Gyo, En, Shu, Ko e Ken.

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

## Muro de pedra solta logo à frente da Vela (coluna 12) e outro mais longe.
const WALLED := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...........%..................%.......#",
	"#...........%..................%.......#",
	"#...........%..................%.......#",
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


func _events(p: Player) -> Array:
	var got := []
	p.fx.connect(func(ev, _d): got.append(ev))
	return got


# ---------------------------------------------------------------- Gyo

func test_gyo_costs_aura_and_stops_regen() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.aura = 60.0
	inp(p).set_held(&"gyo", true)
	run(p, 60)
	check(p.gyo, "segurando o Gyo, a aura vai para os olhos")
	check_range(p.aura, 53.0, 56.0, "Gyo gasta ~5 de aura por segundo e a aura não volta")
	inp(p).set_held(&"gyo", false)
	run(p, 30)
	check(not p.gyo, "soltou, apagou")
	check(p.aura > 70.0, "sem o Gyo a aura volta a encher (%.1f)" % p.aura)


func test_gyo_never_with_zetsu_and_needs_the_lesson() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	inp(p).set_held(&"gyo", true)
	run(p, 5)
	check(p.gyo, "Gyo aceso")
	inp(p).set_held(&"zetsu", true)
	run(p, 3)
	check(p.zetsu and not p.gyo, "no Zetsu os nós fecham e o Gyo apaga")
	inp(p).set_held(&"zetsu", false)
	run(p, 3)
	check(p.gyo, "saiu do Zetsu segurando Gyo: acende de novo")
	p.learned["gyo"] = false
	run(p, 2)
	check(not p.gyo, "sem a lição não tem Gyo")


func test_gyo_goes_out_when_the_flame_is_empty() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.aura = 2.0
	inp(p).set_held(&"gyo", true)
	run(p, 3)
	check(not p.gyo, "com quase nada de aura o Gyo não acende")
	p.aura = 5.0
	run(p, 2)
	check(p.gyo, "com um pouco de aura, acende")
	run(p, 90)
	check(not p.gyo, "a aura acabou e o Gyo apagou")
	run(p, 30)
	check(not p.gyo, "e não reacende sozinho enquanto o botão segue apertado")
	inp(p).set_held(&"gyo", false)
	run(p, 2)
	inp(p).set_held(&"gyo", true)
	run(p, 2)
	check(p.gyo, "soltou e apertou de novo: acende")


# ---------------------------------------------------------------- En

func test_en_kneel_spreads_the_aura() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var got := _events(p)
	p.aura = 80.0
	inp(p).set_held(&"move_down", true)
	run(p, 40)
	check(not got.has(&"en"), "só ↓ não é En (é olhar para baixo)")
	p.aura = 80.0
	inp(p).set_held(&"gyo", true)
	run(p, 10)
	check(p.kneeling(), "Gyo + ↓ no chão: ajoelha")
	run(p, 25)
	check(got.has(&"en"), "ajoelhada um instante, a aura se espalha (En)")
	check_range(p.aura, 45.0, 51.0, "o En custa 30 de aura")
	run(p, 60)
	check(got.count(&"en") == 1, "segurando, não repete")
	check(p.look == 0, "ajoelhada a câmera não desce")


func test_en_without_aura_fizzles() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var got := _events(p)
	p.aura = 20.0
	inp(p).set_held(&"gyo", true)
	inp(p).set_held(&"move_down", true)
	run(p, 40)
	check(not got.has(&"en"), "com pouca aura não sai En")
	check(got.has(&"fizzle"), "a chama falha")


func test_en_wakes_the_ecos_around() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var near := _eco(Vigia.new(), p, Vector2i(16, 10)) as Vigia
	var far := _eco(Vigia.new(), p, Vector2i(35, 10)) as Vigia
	near.facing = 1
	far.facing = 1
	_tick(p, [near, far], 2)
	check(not near.aware, "o Vigia olha para o outro lado")
	p.aura = 100.0
	inp(p).set_held(&"gyo", true)
	inp(p).set_held(&"move_down", true)
	_tick(p, [near, far], 32)
	check(near.aware, "o En é sentido por quem está perto")
	check(not far.aware, "longe demais, nada")


# ---------------------------------------------------------------- Shu

func test_shu_breaks_loose_stone_and_reaches_further() -> void:
	var p := make_player(WALLED, Vector2i(10, 10))
	p.facing = 1
	var got := _events(p)
	tap(p, &"attack")
	run(p, 20)
	check(p.grid.get_cell(12, 9) == LevelGrid.Tile.STONE, "golpe comum só faísca na pedra")
	check(got.has(&"stone_ting"), "e tilinta diferente (dá para quebrar)")
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	run(p, 3)
	check(p.shu_active(), "com o Ren aceso, a aura corre pelo cajado (Shu)")
	tap(p, &"attack")
	run(p, 4)
	check(got.has(&"stone_break"), "o golpe com Shu parte a pedra")
	for r in [8, 9, 10]:
		check(p.grid.get_cell(12, r) == LevelGrid.Tile.EMPTY, "o muro inteiro cai (linha %d)" % r)
	check(p.grid.get_cell(31, 9) == LevelGrid.Tile.STONE, "outro muro, longe, fica")
	inp(p).set_held(&"ren", false)
	run(p, 30)
	var plain := p.attack_rect().size.x
	inp(p).set_held(&"ren", true)
	run(p, 2)
	check(p.attack_rect().size.x > plain * 1.4, "o golpe com Shu alcança mais (%.0f → %.0f px)" % [plain, p.attack_rect().size.x])


func test_shu_pogo_drops_through_a_stone_floor() -> void:
	var rows := HALL.duplicate()
	rows[7] = "#........%%%%..........................#"
	var p := make_player(rows, Vector2i(10, 6))
	run(p, 5)
	check(p.grounded, "de pé no chão de pedra")
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	run(p, 2)
	inp(p).set_held(&"jump", true)
	run(p, 8)
	inp(p).set_held(&"jump", false)
	inp(p).set_held(&"move_down", true)
	for i in 40:
		inp(p).set_held(&"attack", p.vel.y > 0.0 and p.attack_cd_t <= 0.0)
		p.step(DT)
		if p.grid.get_cell(10, 7) == LevelGrid.Tile.EMPTY:
			break
	check(p.grid.get_cell(10, 7) == LevelGrid.Tile.EMPTY, "golpe para baixo com Shu abre o chão de pedra")
	inp(p).set_held(&"attack", false)
	run(p, 40)
	check(p.body.pos.y > 8 * 32.0, "e a Vela cai pelo buraco")


# ---------------------------------------------------------------- Ko

func test_ko_charges_on_hold_and_spends_all_the_aura() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var got := _events(p)
	var v := _eco(Vigia.new(), p, Vector2i(13, 10)) as Vigia
	v.hp = 10
	v.max_hp = 10
	v.aware = true
	v.memory = 99.0
	p.facing = 1
	p.aura = 100.0
	inp(p).set_held(&"attack", true)
	p.step(DT)
	_tick(p, [], 30)
	check(p.ko_charging(), "segurando o golpe, a aura se concentra (Ko)")
	check(not p.ko_ready, "ainda não está pronto")
	_tick(p, [], 40)
	check(p.ko_ready, "pronto depois de concentrar")
	check(got.has(&"ko_ready"), "avisa que ficou pronto")
	check(p.aura > 95.0, "concentrando, a aura não se gasta nem volta (%.1f)" % p.aura)
	var hp0 := v.hp
	inp(p).set_held(&"attack", false)
	_tick(p, [v], 4)
	check(got.has(&"ko"), "soltou: Ko")
	check(p.aura < 1.0, "o Ko gasta a chama inteira")
	check(hp0 - v.hp == 3 + 4, "100 de aura: 3 + 4 de dano (tirou %d)" % (hp0 - v.hp))


func test_ko_released_early_does_nothing() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var got := _events(p)
	p.aura = 100.0
	inp(p).set_held(&"attack", true)
	run(p, 30)
	check(p.ko_charging(), "concentrando")
	inp(p).set_held(&"attack", false)
	run(p, 3)
	check(not got.has(&"ko") and not p.ko_charging(), "soltar antes da hora desfaz o Ko")
	check(p.aura > 95.0, "e não gasta aura")


func test_ko_charge_leaves_the_body_open() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.aura = 100.0
	inp(p).set_held(&"attack", true)
	run(p, 30)
	check(p.damage_mult() == 2, "concentrando o Ko, o resto do corpo fica sem defesa")
	p.take_hit(1, p.body.center() + Vector2(20, 0))
	check(p.vitality == 3, "um golpe tira duas gotas (ficou %d)" % p.vitality)
	check(not p.ko_charging(), "e desfaz a concentração")


func test_ko_needs_aura_and_not_ren() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.aura = 30.0
	p.regen_delay_t = 99.0
	inp(p).set_held(&"attack", true)
	run(p, 40)
	check(not p.ko_charging(), "com menos de 40 de aura não dá para concentrar")
	inp(p).set_held(&"attack", false)
	run(p, 2)
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	run(p, 2)
	inp(p).set_held(&"attack", true)
	run(p, 40)
	check(not p.ko_charging(), "com o Ren aberto a aura não se concentra num ponto")


func test_ko_breaks_stone() -> void:
	var p := make_player(WALLED, Vector2i(10, 10))
	p.facing = 1
	p.aura = 100.0
	inp(p).set_held(&"attack", true)
	run(p, 75)
	check(p.ko_ready, "Ko pronto")
	inp(p).set_held(&"attack", false)
	run(p, 4)
	check(p.grid.get_cell(12, 10) == LevelGrid.Tile.EMPTY, "o Ko derruba o muro de pedra")


# ---------------------------------------------------------------- Ken

func test_ken_parries_a_hit_right_after_ren() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var got := _events(p)
	var m := _eco(Mariposa.new(), p, Vector2i(20, 8)) as Mariposa
	p.aura = 60.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	inp(p).set_held(&"ren", false)
	check(p.ken_active(), "abriu o Ren: janela do Ken")
	m.body.pos = p.body.pos + Vector2(4, 0)
	m.hp = 5
	var aura0 := p.aura
	Eco.update_all([m], DT, p)
	check(got.has(&"ken_parry"), "o golpe chegou na janela: aparado")
	check(p.vitality == 5, "nenhuma gota perdida")
	check(m.hp == 4, "a pancada volta contra o Eco")
	check(m.stun_t > 0.5, "e ele fica atordoado")
	check(p.aura > aura0 + 10.0, "aparar devolve aura")


func test_ken_window_closes() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	var s := _eco(Saltador.new(), p, Vector2i(20, 10))
	p.aura = 60.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	inp(p).set_held(&"ren", false)
	run(p, 30)
	check(not p.ken_active(), "a janela do Ken dura um instante")
	s.body.pos = p.body.pos + Vector2(4, 0)
	Eco.update_all([s], DT, p)
	check(p.vitality == 4, "fora da janela o golpe pega (ficou %d)" % p.vitality)


func test_ken_needs_the_lesson() -> void:
	var p := make_player(HALL, Vector2i(10, 10))
	p.learned["ken"] = false
	p.aura = 60.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	check(not p.ken_active(), "sem a lição, o Ren é só Ren")
