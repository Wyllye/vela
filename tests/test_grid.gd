extends "res://tests/test_base.gd"
## Colisão da LevelGrid.

const BOX := [
	"##########",
	"#........#",
	"#........#",
	"#..====..#",
	"#........#",
	"#........#",
	"##########",
]


func _body(x: float, y: float) -> GridBody:
	var b := GridBody.new()
	b.pos = Vector2(x, y)
	b.size = Vector2(22, 44)
	return b


func test_stops_at_wall_without_tunneling() -> void:
	var g := LevelGrid.from_rows(PackedStringArray(BOX))
	var b := _body(100, 140)
	var hit := g.move_x(b, 5000.0)
	check(hit, "deveria bater na parede da direita")
	check(is_equal_approx(b.pos.x, 9 * 32 - 22), "encostado na parede (x=%.2f)" % b.pos.x)
	hit = g.move_x(b, -5000.0)
	check(hit and is_equal_approx(b.pos.x, 32.0), "encostado na parede da esquerda (x=%.2f)" % b.pos.x)


func test_lands_on_floor_and_ceiling() -> void:
	var g := LevelGrid.from_rows(PackedStringArray(BOX))
	var b := _body(40, 140)
	check(g.move_y(b, 300.0), "deveria bater no chão")
	check(is_equal_approx(b.pos.y + 44.0, 192.0), "pés no chão (y=%.2f)" % (b.pos.y + 44.0))
	check(g.is_grounded(b), "is_grounded no chão")
	check(g.move_y(b, -500.0), "deveria bater no teto")
	check(is_equal_approx(b.pos.y, 32.0), "cabeça no teto (y=%.2f)" % b.pos.y)


func test_one_way_platform() -> void:
	var g := LevelGrid.from_rows(PackedStringArray(BOX))
	# de baixo para cima: atravessa
	var b := _body(110, 120)
	check(not g.move_y(b, -60.0), "mão única não bloqueia subindo")
	# de cima para baixo: apoia
	b.pos.y = 40.0
	check(g.move_y(b, 100.0), "mão única segura quem cai de cima")
	check(is_equal_approx(b.pos.y + 44.0, 96.0), "pés na plataforma (y=%.2f)" % (b.pos.y + 44.0))
	check(g.is_grounded(b) and g.standing_only_on_one_way(b), "em pé só na plataforma")
	check(not g.move_y(b, 10.0, true), "drop_through atravessa")


func test_doors_open_outside_bounds() -> void:
	var g := LevelGrid.from_rows(PackedStringArray([
		"#####",
		"1....",
		"1...2",
		"#####",
	]))
	check(g.get_cell(-1, 1) == LevelGrid.Tile.EMPTY, "fora da sala na frente da porta é vazio")
	check(g.get_cell(-1, 3) == LevelGrid.Tile.SOLID, "fora da sala longe da porta é sólido")
	check(g.door_side("1") == "left" and g.door_side("2") == "right", "lados das portas")
	check(g.door_touching(Rect2(-10, 40, 22, 44)) == "1", "retângulo saindo pela porta 1")


func test_spikes_hazard_rect() -> void:
	var g := LevelGrid.from_rows(PackedStringArray([
		"#####",
		"#...#",
		"#.^.#",
		"#####",
	]))
	check(g.spike_hit(Rect2(64 + 4, 64 + 20, 10, 10)), "encostar na ponta machuca")
	check(not g.spike_hit(Rect2(64 + 4, 64 - 12, 10, 10)), "acima do espinho não machuca")
	check(g.spike_in(Rect2(60, 60, 40, 20)), "golpe para baixo enxerga o espinho")


func test_hidden_platform_and_needles_work_like_the_visible_ones() -> void:
	var g := LevelGrid.from_rows(PackedStringArray([
		"##########",
		"#........#",
		"#..----..#",
		"#........#",
		"#..!!!!..#",
		"##########",
	]))
	check(g.get_cell(3, 2) == LevelGrid.Tile.HIDDEN_ONE_WAY, "'-' é plataforma de aura escondida")
	var b := _body(100, 0)
	check(g.move_y(b, 200.0), "pousa na plataforma invisível")
	check(is_equal_approx(b.pos.y + 44.0, 64.0), "pés em cima dela (y=%.2f)" % (b.pos.y + 44.0))
	check(g.standing_only_on_one_way(b), "dá para descer dela como da de madeira")
	var up := _body(100, 120)
	check(not g.move_y(up, -60.0), "por baixo atravessa")
	check(g.spike_hit(Rect2(100, 150, 20, 10)), "'!' fere como espinho")
	check(g.spike_in(Rect2(96, 128, 30, 30)), "e aceita pogo")
	check(not g.is_rock(4, 4) and not g.is_solid(4, 4), "agulhas não são parede")


func test_loose_stone_falls_as_one_wall() -> void:
	var g := LevelGrid.from_rows(PackedStringArray([
		"##########",
		"#..%.....#",
		"#..%%..%.#",
		"#..%...%.#",
		"##########",
	]))
	check(g.is_solid(3, 2) and g.is_wall(3, 2), "pedra solta é parede")
	check(not g.is_rock(3, 2), "mas não é rocha (não vira chão seguro)")
	var broken := g.break_stone(Rect2(150, 70, 10, 10))
	check(broken.size() == 4, "o golpe derruba o muro inteiro, 4 pedras (veio %d)" % broken.size())
	check(g.get_cell(3, 1) == LevelGrid.Tile.EMPTY and g.get_cell(4, 2) == LevelGrid.Tile.EMPTY, "todas as pedras vizinhas")
	check(g.get_cell(7, 2) == LevelGrid.Tile.STONE, "outro muro fica de pé")
	check(g.break_stone(Rect2(40, 40, 10, 10)).is_empty(), "golpe no vazio não quebra nada")


func test_gates_block_until_opened() -> void:
	var g := LevelGrid.from_rows(PackedStringArray([
		"######",
		"#..|.#",
		"#..|.#",
		"######",
	]))
	var b := _body(40, 50)
	b.size = Vector2(22, 30)
	check(g.move_x(b, 200.0), "o portão segura")
	check(g.open_gates().size() == 2, "o sino abre as duas grades")
	check(not g.move_x(b, 40.0), "aberto, passa")
