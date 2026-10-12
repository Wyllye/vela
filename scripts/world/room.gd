class_name Room
extends Node2D
## Monta uma sala a partir de um RoomData: fundo em camadas, névoa, luz,
## terreno, véus e cascas de aura, objetos, Ecos e poeira no ar.

const TS := 32.0

var data: RoomData
var palette: Dictionary
var tablets: Array[Tablet] = []
var altars: Array[Altar] = []
var glyphs: Array[AuraGlyph] = []
var bells: Array[Bell] = []
var murals: Array[Mural] = []
var strikeables: Array = []
var ecos: Array = []
var spawn_cell := Vector2i(-1, -1)
var ambient: CanvasModulate
var veils: VeilView
var shells: ShellView
var stones: StoneView
var gates: GateView
var aura_layer: AuraLayer
var _layers: Array = []
var _bg_nodes: Array[Node] = []
var _eco_root: Node2D
var _tint_tween: Tween


func build(rd: RoomData, background: CanvasLayer) -> void:
	data = rd
	name = "Room_" + rd.id
	palette = Palettes.get_palette(rd.palette)
	var size := rd.grid.pixel_size()
	var s := rd.rng_seed

	# luz ambiente do mundo (a Vela e as velas iluminam por cima disto)
	ambient = CanvasModulate.new()
	ambient.color = palette["ambient"]
	add_child(ambient)

	# fundo distante: não recebe luz nem modulação
	_add_backdrop(background, Backdrop.Kind.SKY, 0.0, true, s)
	_add_backdrop(background, Backdrop.Kind.FAR, 0.12, true, s)
	_add_fog(background, 0.2, true, 0.18, s)
	_add_backdrop(background, Backdrop.Kind.ARCH, 0.3, true, s)
	_add_backdrop(background, Backdrop.Kind.PILLARS, 0.55, true, s)
	_add_fog(background, 0.62, true, 0.14, s + 1)

	# parede do fundo, iluminada (e os murais pintados nela)
	_add_backdrop(self, Backdrop.Kind.BACKWALL, 0.9, false, s)
	for m in rd.murals:
		var mu := Mural.new()
		mu.setup(m, s + murals.size(), Vector2(1280, 720))
		add_child(mu)
		_layers.append(mu)
		murals.append(mu)
	_add_fog(self, 0.93, false, 0.06, s + 2)

	for shaft_data in rd.light_shafts:
		var shaft := LightShaft.new()
		add_child(shaft)
		shaft.setup(shaft_data, TS, palette["shaft"], palette["shaft_light"], s)

	var terrain := TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(rd.grid, palette, s)

	shells = ShellView.new()
	shells.name = "Shells"
	shells.setup(rd.grid, s)
	add_child(shells)

	stones = StoneView.new()
	stones.name = "Stones"
	stones.setup(rd.grid, s)
	add_child(stones)

	gates = GateView.new()
	gates.name = "Gates"
	gates.setup(rd.grid)
	add_child(gates)

	_spawn_props()

	_eco_root = Node2D.new()
	_eco_root.name = "Ecos"
	_eco_root.z_index = 4
	add_child(_eco_root)
	_spawn_ecos()

	veils = VeilView.new()
	veils.name = "Veils"
	veils.setup(rd.grid, s)
	add_child(veils)

	aura_layer = AuraLayer.new()
	aura_layer.name = "AuraLayer"
	aura_layer.setup(rd.grid)
	add_child(aura_layer)
	for gl in glyphs:
		gl.layer = aura_layer
	for mu in murals:
		mu.layer = aura_layer
	_add_dust(size)

	_add_backdrop(self, Backdrop.Kind.FOREGROUND, 1.22, false, s)


func free_room() -> void:
	for n in _bg_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_bg_nodes.clear()
	queue_free()


func update_parallax(cam_tl: Vector2) -> void:
	for layer in _layers:
		if is_instance_valid(layer):
			layer.update_camera(cam_tl)


func _add_backdrop(parent: Node, kind: Backdrop.Kind, factor: float, in_screen: bool, s: int) -> void:
	var b := Backdrop.new()
	parent.add_child(b)
	b.setup(kind, factor, in_screen, data.grid.pixel_size(), palette, s)
	_layers.append(b)
	if parent != self:
		_bg_nodes.append(b)


func _add_fog(parent: Node, factor: float, in_screen: bool, density: float, s: int) -> void:
	var f := FogLayer.new()
	parent.add_child(f)
	f.setup(factor, in_screen, data.grid.pixel_size(), palette["fog"], density, s)
	_layers.append(f)
	if parent != self:
		_bg_nodes.append(f)


func _add_dust(size: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.name = "Dust"
	p.amount = clampi(int(size.x * size.y / 16000.0), 50, 180)
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.local_coords = false
	p.texture = FX.dot_texture()
	p.material = FX.additive()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size * 0.5
	p.position = size * 0.5
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector2(1.5, -2.5)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	var c := Color(0.86, 0.9, 1.0)
	ramp.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.32), Color(c, 0.32), Color(c, 0.0)])
	p.color_ramp = ramp
	p.z_index = 3
	add_child(p)


# ---------------------------------------------------------------------------
# Objetos a partir dos marcadores do mapa
# ---------------------------------------------------------------------------

func _spawn_props() -> void:
	var g := data.grid
	var rng := RandomNumberGenerator.new()
	rng.seed = data.rng_seed * 97 + 3
	var text_i := 0
	var glyph_i := 0
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	for m in g.markers:
		var ch: String = m["ch"]
		var cell: Vector2i = m["cell"]
		var base := Vector2((cell.x + 0.5) * TS, (cell.y + 1) * TS)
		match ch:
			"P":
				spawn_cell = cell
			"c":
				var cd := Candle.new()
				cd.setup(rng.randf_range(12, 24), rng.randf_range(5, 7), true, rng.randf() * 10.0)
				cd.position = base + Vector2(rng.randf_range(-6, 6), 0)
				props.add_child(cd)
			"C":
				for k in 3:
					var cd := Candle.new()
					cd.setup([22.0, 14.0, 30.0][k] * rng.randf_range(0.85, 1.15), [7.0, 6.0, 8.0][k], rng.randf() > 0.15, rng.randf() * 10.0)
					cd.position = base + Vector2([-9.0, 2.0, 11.0][k], 0)
					props.add_child(cd)
			"o":
				var ceil_row := g.ceiling_above(cell.x, cell.y, 12)
				var ln := Lantern.new()
				if ceil_row >= 0:
					ln.position = Vector2((cell.x + 0.5) * TS, (ceil_row + 1) * TS)
					ln.setup((cell.y - ceil_row - 0.5) * TS, palette["lantern"], rng.randf() * TAU)
				else:
					ln.position = Vector2((cell.x + 0.5) * TS, (cell.y + 0.5) * TS)
					ln.setup(0.0, palette["lantern"], rng.randf() * TAU)
				props.add_child(ln)
				strikeables.append(ln)
			"T":
				var tb := Tablet.new()
				var key := data.texts[text_i] if text_i < data.texts.size() else ""
				text_i += 1
				tb.setup(key, data.rng_seed + text_i * 13)
				tb.position = base
				props.add_child(tb)
				tablets.append(tb)
			"A":
				var al := Altar.new()
				al.position = base
				al.index = altars.size()
				al.lesson = data.lesson_for_altar(al.index)
				props.add_child(al)
				altars.append(al)
			"g":
				var gl := AuraGlyph.new()
				gl.setup(data.aura_entry(glyph_i), data.rng_seed + glyph_i * 7 + 1)
				glyph_i += 1
				gl.position = Vector2((cell.x + 0.5) * TS, (cell.y + 0.5) * TS)
				props.add_child(gl)
				glyphs.append(gl)
			"B":
				var ceil_s := g.ceiling_above(cell.x, cell.y, 16)
				var bl := Bell.new()
				if ceil_s >= 0:
					bl.position = Vector2((cell.x + 0.5) * TS, (ceil_s + 1) * TS)
					bl.setup((cell.y - ceil_s - 0.5) * TS, rng.randf() * TAU)
				else:
					bl.position = Vector2((cell.x + 0.5) * TS, cell.y * TS - 60.0)
					bl.setup(60.0 + TS * 0.5, 0.0)
				props.add_child(bl)
				bells.append(bl)
				strikeables.append(bl)
			"m", "x":
				var hk := Husk.new()
				hk.setup("sit" if ch == "m" else "fallen", 1 if cell.x < g.width * 0.5 else -1)
				hk.position = base
				props.add_child(hk)
			"b":
				var ceil_b := g.ceiling_above(cell.x, cell.y + 1, 10)
				var bn := Banner.new()
				bn.setup(rng.randf_range(80, 140), palette["cloth"], palette["cloth_mark"], rng.randf() * TAU)
				bn.position = Vector2((cell.x + 0.5) * TS, (ceil_b + 1) * TS if ceil_b >= 0 else cell.y * TS)
				props.add_child(bn)
			"h":
				var ceil_h := g.ceiling_above(cell.x, cell.y + 1, 10)
				var chn := HangingChain.new()
				chn.setup(rng.randf_range(70, 200), rng.randf() * TAU)
				chn.position = Vector2((cell.x + 0.5) * TS, (ceil_h + 1) * TS if ceil_h >= 0 else cell.y * TS)
				props.add_child(chn)
			"l":
				var sh := Shelf.new()
				sh.setup(data.rng_seed * 13 + cell.x * 7 + cell.y)
				sh.position = base + Vector2(rng.randf_range(-4, 4), 0)
				props.add_child(sh)
			"w":
				var lc := Lectern.new()
				lc.setup(cell.x + cell.y)
				lc.position = base
				props.add_child(lc)
			"r":
				var rb := Rubble.new()
				rb.setup(palette, data.rng_seed + cell.x * 7 + cell.y)
				rb.position = base
				props.add_child(rb)
			"V", "S", "M", "E":
				pass  # Ecos: _spawn_ecos()
			_:
				push_warning("Marcador desconhecido '%s' em %s (%s)" % [ch, cell, data.id])


# ---------------------------------------------------------------------------
# Ecos
# ---------------------------------------------------------------------------

func _spawn_ecos() -> void:
	for m in data.grid.markers:
		var e: Eco = null
		match m["ch"]:
			"V":
				e = Vigia.new()
			"S":
				e = Saltador.new()
			"M":
				e = Mariposa.new()
			"E":
				e = Penitente.new()
		if e == null:
			continue
		e.setup(data.grid, m["cell"])
		_add_eco(e)


func _add_eco(e: Eco) -> void:
	e.facing = 1 if e.home.x < data.grid.pixel_size().x * 0.5 else -1
	_eco_root.add_child(e)
	ecos.append(e)
	strikeables.append(e)


## O Eco póstumo da Vela aparece onde ela apagou.
func spawn_shade(center: Vector2) -> EcoVela:
	var sh := EcoVela.new()
	sh.setup_at(data.grid, center)
	_add_eco(sh)
	return sh


func step_ecos(dt: float, player: Player) -> void:
	Eco.update_all(ecos, dt, player)


## Zetsu: o mundo escurece um pouco junto com a chama da Vela. Gyo: escurece e
## esfria, para o que é feito de aura saltar aos olhos.
func update_tint(zetsu: bool, gyo: bool) -> void:
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	var target: Color = palette["ambient"]
	if zetsu:
		target = target.darkened(0.28).lerp(Color(0.32, 0.36, 0.5), 0.2)
	elif gyo:
		target = target.darkened(0.32).lerp(Color(0.36, 0.33, 0.52), 0.3)
	_tint_tween = create_tween()
	_tint_tween.tween_property(ambient, "color", target, 0.35)


## Estela mais próxima dentro do alcance (ou null).
func tablet_near(p: Vector2) -> Tablet:
	var best: Tablet = null
	var best_d := INF
	for t in tablets:
		var d := t.position - Vector2(0, 24) - p
		if absf(d.x) < 64.0 and absf(d.y) < 80.0 and d.length() < best_d:
			best = t
			best_d = d.length()
	return best


## O sino tocou: os portões sobem (o JSON da sala não muda; o Game guarda).
func open_gates(animated: bool) -> Array[Vector2i]:
	var cells := data.grid.open_gates()
	gates.open(animated)
	return cells


## Escrita em aura legível perto da Vela (revelada pelo Gyo ou pelo En), ou null.
func glyph_near(p: Vector2) -> AuraGlyph:
	var best: AuraGlyph = null
	var best_d := INF
	for gl in glyphs:
		if gl.reveal < 0.5 or gl.text_key == "":
			continue
		var r := Rect2(gl.position - gl.size * 0.5, gl.size).grow(64.0)
		if not r.has_point(p):
			continue
		var d := gl.position.distance_to(p)
		if d < best_d:
			best = gl
			best_d = d
	return best


func altar_near(p: Vector2) -> Altar:
	for a in altars:
		var d := a.position - Vector2(0, 20) - p
		if absf(d.x) < 56.0 and absf(d.y) < 60.0:
			return a
	return null
