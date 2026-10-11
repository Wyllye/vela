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
