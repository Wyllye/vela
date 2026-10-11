class_name Room
extends Node2D
## Monta uma sala a partir de um RoomData: fundo em camadas, névoa, luz,
## terreno, objetos e poeira no ar.

const TS := 32.0

var data: RoomData
var palette: Dictionary
var tablets: Array[Tablet] = []
var altars: Array[Altar] = []
var glyphs: Array[AuraGlyph] = []
var strikeables: Array = []
var spawn_cell := Vector2i(-1, -1)
var _layers: Array = []
var _bg_nodes: Array[Node] = []


func build(rd: RoomData, background: CanvasLayer) -> void:
	data = rd
	name = "Room_" + rd.id
	palette = Palettes.get_palette(rd.palette)
	var size := rd.grid.pixel_size()
	var s := rd.rng_seed

	# luz ambiente do mundo (a Vela e as velas iluminam por cima disto)
	var cm := CanvasModulate.new()
	cm.color = palette["ambient"]
	add_child(cm)

	# fundo distante: não recebe luz nem modulação
	_add_backdrop(background, Backdrop.Kind.SKY, 0.0, true, s)
	_add_backdrop(background, Backdrop.Kind.FAR, 0.12, true, s)
	_add_fog(background, 0.2, true, 0.18, s)
	_add_backdrop(background, Backdrop.Kind.ARCH, 0.3, true, s)
	_add_backdrop(background, Backdrop.Kind.PILLARS, 0.55, true, s)
	_add_fog(background, 0.62, true, 0.14, s + 1)

	# parede do fundo, iluminada
	_add_backdrop(self, Backdrop.Kind.BACKWALL, 0.9, false, s)
	_add_fog(self, 0.93, false, 0.06, s + 2)

	for shaft_data in rd.light_shafts:
		var shaft := LightShaft.new()
		add_child(shaft)
		shaft.setup(shaft_data, TS, palette["shaft"], palette["shaft_light"], s)

	var terrain := TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(rd.grid, palette, s)

	_spawn_props()
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
				props.add_child(al)
				altars.append(al)
			"g":
				var gl := AuraGlyph.new()
				glyph_i += 1
				gl.setup("GLYPH_%s_%d" % [data.id.to_upper(), glyph_i], data.rng_seed + glyph_i)
				gl.position = Vector2((cell.x + 0.5) * TS, (cell.y + 0.5) * TS)
				props.add_child(gl)
				glyphs.append(gl)
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
			"r":
				var rb := Rubble.new()
				rb.setup(palette, data.rng_seed + cell.x * 7 + cell.y)
				rb.position = base
				props.add_child(rb)
			_:
				push_warning("Marcador desconhecido '%s' em %s (%s)" % [ch, cell, data.id])


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


func altar_near(p: Vector2) -> Altar:
	for a in altars:
		var d := a.position - Vector2(0, 20) - p
		if absf(d.x) < 56.0 and absf(d.y) < 60.0:
			return a
	return null
