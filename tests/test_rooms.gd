extends "res://tests/test_base.gd"
## Salas: dados válidos, portas que se conectam e desafios vencíveis.

const ROOMS := ["poco_fundo", "dormitorio", "galeria", "lanternas", "votos", "limiar",
	"leitura", "arquivo", "exercicios", "campanario", "capela"]
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
	var want := {"poco_fundo": ["ten"], "dormitorio": ["zetsu"], "votos": ["ren"], "limiar": [""],
		"leitura": ["gyo"], "arquivo": ["shu"], "exercicios": ["ken"], "campanario": ["ko"], "capela": ["end", "en"]}
	for id: String in want:
		var rd := RoomData.load_room(id)
		var lessons: Array = want[id]
		check(rd.markers_of("A").size() == lessons.size(), "%s tem %d altar(es)" % [id, lessons.size()])
		for i in lessons.size():
			check(rd.lesson_for_altar(i) == lessons[i], "%s: altar %d ensina '%s' (veio '%s')" % [id, i, lessons[i], rd.lesson_for_altar(i)])


func test_aura_writings_come_from_the_room_data() -> void:
	var csv := FileAccess.get_file_as_string("res://locale/textos.csv")
	var total := 0
	for id in ROOMS:
		var rd := RoomData.load_room(id)
		var marks := rd.markers_of("g").size()
		total += marks
		check(marks == rd.aura.size(), "%s: %d escritas em aura no mapa e %d no JSON" % [id, marks, rd.aura.size()])
		for e: Dictionary in rd.aura:
			check(csv.contains("\n" + str(e["text"]) + ","), "%s: texto %s existe em textos.csv" % [id, e["text"]])
			check(str(e.get("author", "monge")) in ["monge", "abadessa"], "%s: autor conhecido" % id)
	check(total >= 15, "o Poço e o Noviciado guardam pelo menos 15 escritas em aura (%d)" % total)
	check(Game.aura_total() == total, "o Game conta as mesmas %d (contou %d)" % [total, Game.aura_total()])


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


## Pula de onde a Vela está, correndo para `dir`, e devolve a célula onde ela pousou.
func _jump_to(p: Player, dir: int, run_frames: int, hold_jump: int) -> Vector2i:
	var key := &"move_right" if dir > 0 else &"move_left"
	inp(p).set_held(key, true)
	run(p, run_frames)
	inp(p).set_held(&"jump", true)
	run(p, hold_jump)
	inp(p).set_held(&"jump", false)
	for i in 120:
		p.step(DT)
		if p.grounded and p.vel.y >= 0.0:
			break
	inp(p).set_held(key, false)
	run(p, 12)
	var f := p.body.feet()
	return Vector2i(floori(f.x / 32.0), floori((f.y - 1.0) / 32.0))


func test_vows_chamber_climb_reaches_the_sealed_exit() -> void:
	var p := _room_player("votos", Vector2i(21, 25))
	run(p, 5)
	var c := _jump_to(p, 1, 6, 20)
	check(c.y == 22 and c.x >= 25 and c.x <= 39, "chão → tablado (pousou em %s)" % c)
	p.body.pos.x = 37 * 32.0
	c = _jump_to(p, 1, 8, 24)
	check(c.y == 18 and c.x >= 42 and c.x <= 47, "tablado → plataforma da direita (pousou em %s)" % c)
	p.body.pos.x = 46 * 32.0
	c = _jump_to(p, 1, 2, 18)
	check(c.y == 16 and c.x >= 50 and c.x <= 55, "plataforma → plataforma alta (pousou em %s)" % c)
	p.body.pos.x = 54 * 32.0
	c = _jump_to(p, 1, 2, 18)
	check(c.y == 13 and c.x >= 57 and c.x <= 59, "plataforma alta → saída lacrada (pousou em %s)" % c)


func test_dormitory_bunks_are_reachable() -> void:
	var p := _room_player("dormitorio", Vector2i(10, 21))
	run(p, 5)
	var c := _jump_to(p, 1, 4, 22)
	check(c.y == 17 and c.x >= 13 and c.x <= 17, "chão → beliche de baixo (pousou em %s)" % c)
	p.body.pos.x = 16 * 32.0
	c = _jump_to(p, 1, 2, 22)
	check(c.y == 13 and c.x >= 17 and c.x <= 21, "beliche de baixo → de cima (pousou em %s)" % c)


# ---------------------------------------------------------------- Noviciado

## Procura um pulo que leve a Vela de `from` (de pé) até pousar dentro de
## `target` (células) sem se ferir: varia a corrida antes do pulo, quanto tempo
## segura o pulo, quando solta a direção e se usa o Sopro (pulo no ar).
## Devolve {"ok", "pos"} — prova que o pulo existe, sem coreografia frágil.
func _hop(grid: LevelGrid, from: Vector2, dir: int, target: Rect2i, allow_air := false) -> Dictionary:
	var key := &"move_right" if dir > 0 else &"move_left"
	var airs := [-1, 3, 8] if allow_air else [-1]
	for air in airs:
		for run_f in [0, 3, 6, 10, 14, 20, 30, 45]:
			for hold in [6, 10, 14, 18, 22]:
				for stop in [999, 6, 10, 14, 18, 24, 30]:
					var p := Player.new()
					p.input = ScriptedInput.new()
					p.setup(grid, from)
					var si := p.input as ScriptedInput
					for i in 6:
						p.step(DT)
					si.set_held(key, true)
					for i in run_f:
						p.step(DT)
					var f := 0
					var landed := false
					while f < 150:
						si.set_held(&"jump", f < hold or (air >= 0 and f >= hold + air and f < hold + air + 24))
						si.set_held(key, f < stop)
						p.step(DT)
						f += 1
						if p.hurt_count > 0:
							break
						if f > 4 and p.grounded and p.vel.y >= 0.0:
							landed = true
							break
					var feet := p.body.feet()
					var cell := Vector2i(floori(feet.x / 32.0), floori((feet.y - 1.0) / 32.0))
					var ok := landed and p.hurt_count == 0 and target.has_point(cell)
					var pos := p.body.pos
					p.free()
					if ok:
						return {"ok": true, "pos": pos, "cell": cell}
	return {"ok": false, "pos": from, "cell": Vector2i(-1, -1)}


## Encadeia pulos: [[dir, Rect2i alvo, sopro?], ...]. Devolve o último resultado.
func _route(room_id: String, start_cell: Vector2i, hops: Array, label: String) -> Dictionary:
	var rd := RoomData.load_room(room_id)
	var pos := Vector2(start_cell.x * 32.0 + 5.0, (start_cell.y + 1) * 32.0 - 44.0)
	var r := {"ok": true, "pos": pos}
	var i := 0
	for h in hops:
		r = _hop(rd.grid, pos, h[0], h[1], h.size() > 2 and h[2])
		check(r["ok"], "%s: pulo %d até %s" % [label, i + 1, h[1]])
		if not r["ok"]:
			return r
		pos = r["pos"]
		i += 1
	return r


func test_reading_room_hidden_floor_crosses_the_pit() -> void:
	_route("leitura", Vector2i(22, 25), [
		[1, Rect2i(25, 25, 3, 1)], [1, Rect2i(30, 25, 3, 1)], [1, Rect2i(35, 25, 4, 1)], [1, Rect2i(41, 25, 3, 1)]],
		"fosso da Sala de Leitura")


func test_reading_room_needles_hurt_unless_you_hop_between() -> void:
	var p := _room_player("leitura", Vector2i(43, 25))
	run(p, 5)
	inp(p).set_held(&"move_right", true)
	run(p, 40)
	inp(p).set_held(&"move_right", false)
	check(p.hurt_count == 1, "andar às cegas pelo corredor fere nas agulhas")
	_route("leitura", Vector2i(44, 25), [
		[1, Rect2i(47, 25, 2, 1)], [1, Rect2i(51, 25, 2, 1)], [1, Rect2i(55, 25, 4, 1)]],
		"corredor das agulhas")


func test_reading_room_exit_and_secret_balcony() -> void:
	_route("leitura", Vector2i(57, 25), [[1, Rect2i(58, 21, 4, 1)], [1, Rect2i(60, 17, 9, 1)]], "subida da saída")
	_route("leitura", Vector2i(61, 17), [[-1, Rect2i(57, 11, 4, 1), true]], "estante alta da escrita")
	_route("leitura", Vector2i(11, 25), [
		[1, Rect2i(12, 21, 3, 1)], [-1, Rect2i(6, 17, 3, 1)], [1, Rect2i(12, 13, 3, 1)], [-1, Rect2i(1, 9, 9, 1)]],
		"escada escondida da sacada")


func test_archive_needs_shu_for_the_wall_and_the_floor() -> void:
	var p := _room_player("arquivo", Vector2i(12, 25))
	p.learned["shu"] = false
	run(p, 5)
	inp(p).set_held(&"move_right", true)
	run(p, 60)
	check(p.body.pos.x < 15 * 32.0, "o muro segura a Vela")
	inp(p).set_held(&"move_right", false)
	p.learned["shu"] = true
	p.aura = 100.0
	inp(p).set_held(&"ren", true)
	run(p, 2)
	tap(p, &"attack")
	run(p, 4)
	inp(p).set_held(&"ren", false)
	check(p.grid.get_cell(15, 23) == LevelGrid.Tile.EMPTY, "com Shu, o muro cai")
	# o chão de pedra sobre o corredor de baixo
	var q := _room_player("arquivo", Vector2i(47, 25))
	run(q, 5)
	q.aura = 100.0
	inp(q).set_held(&"ren", true)
	run(q, 2)
	inp(q).set_held(&"jump", true)
	run(q, 8)
	inp(q).set_held(&"jump", false)
	inp(q).set_held(&"move_down", true)
	for i in 50:
		inp(q).set_held(&"attack", q.vel.y > 0.0 and q.attack_cd_t <= 0.0)
		q.step(DT)
	inp(q).set_held(&"attack", false)
	inp(q).set_held(&"move_down", false)
	inp(q).set_held(&"ren", false)
	run(q, 60)
	check(q.body.pos.y > 29 * 32.0 - 44.0, "o golpe para baixo com Shu abre o chão e ela cai no corredor (y=%.0f)" % q.body.pos.y)
	inp(q).set_held(&"move_right", true)
	var out := false
	for i in 300:
		q.step(DT)
		if q.exit_side() == "right":
			out = true
			break
	check(out, "o corredor de baixo leva à saída")
	# a alcova emparedada: a estante alta chega à pedra
	_route("arquivo", Vector2i(41, 25), [[1, Rect2i(43, 21, 4, 1)], [1, Rect2i(47, 17, 4, 1)], [-1, Rect2i(43, 13, 4, 1)],
		[1, Rect2i(47, 10, 5, 1)]], "estantes até a alcova emparedada")
	# de pé na estante alta, o golpe com Shu alcança a pedra da alcova
	var s := _room_player("arquivo", Vector2i(51, 10))
	run(s, 5)
	s.facing = 1
	s.aura = 100.0
	inp(s).set_held(&"ren", true)
	run(s, 2)
	tap(s, &"attack")
	run(s, 4)
	check(s.grid.get_cell(53, 8) == LevelGrid.Tile.EMPTY, "da estante alta o Shu derruba o muro da alcova")


func test_bell_tower_climb_reaches_the_bell() -> void:
	_route("campanario", Vector2i(14, 41), [
		[1, Rect2i(16, 37, 6, 1)], [1, Rect2i(24, 33, 6, 1)], [1, Rect2i(32, 29, 6, 1)],
		[-1, Rect2i(24, 25, 6, 1)], [-1, Rect2i(16, 21, 6, 1)], [-1, Rect2i(6, 18, 16, 1)]],
		"subida da torre")
	_route("campanario", Vector2i(26, 25), [[1, Rect2i(27, 18, 15, 1), true]], "degrau → galeria da saída")
	# da beirada da galeria, o Ko alcança o sino
	var rd := RoomData.load_room("campanario")
	var b: Vector2i = rd.markers_of("B")[0]
	var ceil_row := rd.grid.ceiling_above(b.x, b.y, 16)
	var bell_center := Vector2((b.x + 0.5) * 32.0, (ceil_row + 1) * 32.0 + (b.y - ceil_row - 0.5) * 32.0)
	var p := _room_player("campanario", Vector2i(21, 18))
	run(p, 5)
	p.facing = 1
	p.ko_strike = true
	var hit := Rect2(bell_center + Vector2(-36, -44), Vector2(72, 76))
	check(p.attack_rect().intersects(hit), "da beirada da galeria o Ko alcança o sino")
	p.ko_strike = false


func test_bell_tower_gate_opens_only_with_the_bell() -> void:
	var p := _room_player("campanario", Vector2i(38, 18))
	run(p, 5)
	inp(p).set_held(&"move_right", true)
	run(p, 90)
	check(p.exit_side() == "", "o portão tranca a saída")
	p.grid.open_gates()
	var out := false
	for i in 120:
		p.step(DT)
		if p.exit_side() == "right":
			out = true
			break
	check(out, "com o portão aberto, a Capela está logo ali")


func test_chapel_hidden_stair_reaches_the_balcony() -> void:
	_route("capela", Vector2i(48, 25), [
		[1, Rect2i(50, 21, 3, 1)], [1, Rect2i(54, 17, 3, 1)], [-1, Rect2i(50, 13, 3, 1)], [1, Rect2i(47, 10, 12, 1)]],
		"escada de aura da Capela")
	_route("capela", Vector2i(42, 28), [[1, Rect2i(47, 25, 12, 1)]], "degraus da abside")


func test_training_yard_crosses_the_dais() -> void:
	_route("exercicios", Vector2i(24, 24), [[1, Rect2i(27, 22, 10, 1)], [1, Rect2i(37, 24, 26, 1)]], "tablado do Pátio")
