extends "res://tests/test_base.gd"
## Salas: dados válidos, portas que se conectam e desafios vencíveis.

const ROOMS := ["poco_fundo", "dormitorio", "galeria", "lanternas", "votos", "limiar"]
const OPPOSITE := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}


func test_rooms_load_and_are_rectangular() -> void:
	for id in ROOMS:
		var rd := RoomData.load_room(id)
		check(rd != null, "sala %s carrega" % id)
		if rd == null:
			continue
		var w := rd.rows[0].length()
		for i in rd.rows.size():
			check(rd.rows[i].length() == w, "%s: linha %d tem %d colunas (esperado %d)" % [id, i, rd.rows[i].length(), w])
		check(rd.grid.width * 32 >= 1280 and rd.grid.height * 32 >= 720, "%s: sala cobre a tela inteira" % id)
		var tablets := rd.markers_of("T").size()
		check(tablets == rd.texts.size(), "%s: %d estelas e %d textos" % [id, tablets, rd.texts.size()])


func test_doors_connect_both_ways() -> void:
	for id in ROOMS:
		var rd := RoomData.load_room(id)
		for door_id: String in rd.doors:
			var link: Dictionary = rd.doors[door_id]
			check(not rd.grid.door_cells_of(door_id).is_empty(), "%s: porta %s existe no mapa" % [id, door_id])
			var other := RoomData.load_room(str(link["to"]))
			check(other != null, "%s: destino %s existe" % [id, link["to"]])
			if other == null:
				continue
			var back_id := str(link["door"])
			check(other.doors.has(back_id) and str(other.doors[back_id]["to"]) == id, "%s ↔ %s: volta pela porta %s" % [id, link["to"], back_id])
			var side := rd.grid.door_side(door_id)
			var other_side := other.grid.door_side(back_id)
			check(OPPOSITE.get(side, "") == other_side, "%s:%s (%s) encaixa em %s:%s (%s)" % [id, door_id, side, link["to"], back_id, other_side])


func test_texts_exist_in_translation_file() -> void:
	var csv := FileAccess.get_file_as_string("res://locale/textos.csv")
	for id in ROOMS:
		var rd := RoomData.load_room(id)
		for key in rd.texts:
			check(csv.contains("\n" + key + ","), "%s: texto %s existe em textos.csv" % [id, key])


func test_intro_fall_lands_on_cavern_floor() -> void:
	var rd := RoomData.load_room("poco_fundo")
	var spawn: Vector2i = rd.markers_of("P")[0]
	var p := Player.new()
	p.input = ScriptedInput.new()
	_nodes.append(p)
	p.setup(rd.grid, Vector2(spawn.x * 32.0 + 5.0, (spawn.y + 1) * 32.0 - 44.0))
	p.start_intro_fall()
	var woke := false
	for i in 600:
		p.step(DT)
		if p.state == Player.State.NORMAL:
			woke = true
			break
	check(woke, "a queda do começo termina com a Vela acordando")
	check(is_equal_approx(p.body.pos.y + p.body.size.y, 36 * 32.0), "pousa no chão da caverna (pés em %.1f)" % (p.body.pos.y + p.body.size.y))


## Vão de 8 tiles da Galeria: só passa com pulo + Passo de Ren.
func test_gallery_dash_gap_is_crossable() -> void:
	var rd := RoomData.load_room("galeria")
	var p := Player.new()
	p.input = ScriptedInput.new()
	_nodes.append(p)
	p.setup(rd.grid, Vector2(14 * 32.0 + 5.0, 30 * 32.0 - 44.0))
	var si := inp(p)
	si.set_held(&"move_right", true)
	var jumped := false
	var dashed := false
	var jump_frame := 0
	for i in 240:
		if not jumped and p.body.pos.x + p.body.size.x >= 18 * 32.0 - 2.0:
			si.set_held(&"jump", true)
			jumped = true
			jump_frame = i
		if jumped and not dashed and i == jump_frame + 14:
			si.set_held(&"dash", true)
			dashed = true
		elif dashed:
			si.set_held(&"dash", false)
		p.step(DT)
		if p.hurt_count > 0:
			break
		if dashed and p.grounded and p.body.pos.x > 26 * 32.0:
			break
	check(p.hurt_count == 0, "atravessa o vão sem cair nos espinhos")
	check(p.body.pos.x > 26 * 32.0, "chega do outro lado (x=%.1f)" % p.body.pos.x)


## Câmara das Lanternas: quicar numa lanterna e alcançar a próxima com Passo de Ren.
func test_lantern_pogo_reach() -> void:
	var p := make_player(_open_room(40, 30), Vector2i(5, 28))
	var lantern := Lantern.new()
	lantern.setup(0.0, Color.WHITE, 0.0)
	lantern.position = Vector2(8 * 32.0, 14 * 32.0)
	_nodes.append(lantern)
	p.strikeables = [lantern]
	p.body.pos = Vector2(lantern.position.x - 11.0, lantern.position.y - 140.0)
	p.grounded = false
	var si := inp(p)
	si.set_held(&"move_down", true)
	var bounced := false
	for i in 120:
		var feet := p.body.pos.y + p.body.size.y
		si.set_held(&"attack", not bounced and p.attack_cd_t <= 0.0 and feet > lantern.position.y - 70.0)
		p.step(DT)
		if p.vel.y < -400.0:
			bounced = true
			break
	check(bounced, "quica na lanterna")
	si.set_held(&"move_down", false)
	si.set_held(&"attack", false)
	si.set_held(&"move_right", true)
	var x0 := p.body.pos.x
	run(p, 12)
	tap(p, &"dash")
	var best := 0.0
	for i in 60:
		p.step(DT)
		if p.body.pos.y > lantern.position.y - 40.0:
			break
		best = p.body.pos.x - x0
	check(best > 7 * 32.0 - 30.0, "alcança a próxima lanterna, 7 tiles adiante (andou %.1f px)" % best)


func _open_room(w: int, h: int) -> Array:
	var rows := ["#".repeat(w)]
	for i in h - 2:
		rows.append("#" + ".".repeat(w - 2) + "#")
	rows.append("#".repeat(w))
	return rows


func _room_player(id: String, cell: Vector2i) -> Player:
	var rd := RoomData.load_room(id)
	var p := Player.new()
	p.input = ScriptedInput.new()
	_nodes.append(p)
	p.setup(rd.grid, Vector2(cell.x * 32.0 + 5.0, (cell.y + 1) * 32.0 - 44.0))
	return p


func test_lesson_altars_in_order() -> void:
	var want := {"poco_fundo": "ten", "dormitorio": "zetsu", "votos": "ren", "limiar": "end"}
	for id: String in want:
		var rd := RoomData.load_room(id)
		check(rd.altar_lesson == want[id], "%s ensina %s (veio %s)" % [id, want[id], rd.altar_lesson])
		check(rd.markers_of("A").size() == 1, "%s tem um altar" % id)


func test_dormitory_door_needs_zetsu() -> void:
	var p := _room_player("dormitorio", Vector2i(52, 21))
	inp(p).set_held(&"move_right", true)
	run(p, 120)
	check(p.exit_side() == "", "sem Zetsu o véu segura a Vela")
	inp(p).set_held(&"zetsu", true)
	var out := false
	for i in 180:
		p.step(DT)
		if p.exit_side() == "right":
			out = true
			break
	check(out, "no Zetsu ela atravessa o véu e chega na porta")


func test_vows_exit_needs_ren() -> void:
	var p := _room_player("votos", Vector2i(58, 13))
	run(p, 10)
	check(p.grounded, "de pé na saída alta")
	inp(p).set_held(&"move_right", true)
	run(p, 90)
	check(p.exit_side() == "", "a casca de aura lacra a saída")
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	p.step(DT)
	inp(p).set_held(&"ren", false)
	var out := false
	for i in 180:
		p.step(DT)
		if p.exit_side() == "right":
			out = true
			break
	check(out, "o Ren racha a casca e a porta abre")
