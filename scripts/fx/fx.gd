class_name FX
extends RefCounted
## Ajudantes de efeitos: texturas de luz, explosões de partículas, anéis e a chama.

static var _light_tex: Texture2D
static var _dot_tex: Texture2D
static var _glow_tex: Texture2D
static var _add_mat: CanvasItemMaterial
static var _unshaded_mat: CanvasItemMaterial


## Gradiente radial suave para PointLight2D.
static func light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = _radial(512, PackedFloat32Array([0.0, 0.18, 0.45, 0.75, 1.0]),
			PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.78), Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)]))
	return _light_tex


## Ponto macio para partículas.
static func dot_texture() -> Texture2D:
	if _dot_tex == null:
		_dot_tex = _radial(32, PackedFloat32Array([0.0, 0.35, 1.0]),
			PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)]))
	return _dot_tex


## Halo para brilhos aditivos (chamas, olhos, lanternas).
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		_glow_tex = _radial(128, PackedFloat32Array([0.0, 0.2, 0.55, 1.0]),
			PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)]))
	return _glow_tex


## Solta as texturas guardadas em variáveis estáticas (chamado ao fechar o jogo).
static func cleanup() -> void:
	_light_tex = null
	_dot_tex = null
	_glow_tex = null
	_add_mat = null
	_unshaded_mat = null


static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _add_mat


## Mistura normal, mas sem receber luz: brilha igual no claro e no escuro (Ecos).
static func unshaded() -> CanvasItemMaterial:
	if _unshaded_mat == null:
		_unshaded_mat = CanvasItemMaterial.new()
		_unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_mat


static func _radial(size: int, offsets: PackedFloat32Array, colors: PackedColorArray) -> Texture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Brilho aditivo (Sprite2D) pronto para pendurar num nó.
static func make_glow(color: Color, size_px: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.material = additive()
	s.modulate = color
	s.scale = Vector2.ONE * (size_px / 128.0)
	return s


static func make_light(color: Color, radius_px: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius_px / 256.0
	l.color = color
	l.energy = energy
	return l


## Explosão única de partículas que se apaga sozinha.
static func burst(parent: Node, pos: Vector2, opts: Dictionary) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = int(opts.get("z", 5))
	p.amount = int(opts.get("amount", 10))
	p.lifetime = float(opts.get("life", 0.5))
	p.one_shot = true
	p.explosiveness = float(opts.get("explosive", 0.95))
	p.randomness = 0.4
	p.local_coords = false
	p.texture = dot_texture()
	p.direction = opts.get("dir", Vector2.UP)
	p.spread = float(opts.get("spread", 60.0))
	p.initial_velocity_min = float(opts.get("speed_min", 40.0))
	p.initial_velocity_max = float(opts.get("speed_max", 120.0))
	p.gravity = opts.get("gravity", Vector2(0, 200))
	p.damping_min = float(opts.get("damping", 60.0))
	p.damping_max = float(opts.get("damping", 60.0)) * 1.5
	p.scale_amount_min = float(opts.get("scale_min", 0.12))
	p.scale_amount_max = float(opts.get("scale_max", 0.28))
	var col: Color = opts.get("color", Color.WHITE)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([col, Color(col, col.a * 0.6), Color(col, 0.0)])
	p.color_ramp = ramp
	if opts.get("additive", false):
		p.material = additive()
	if opts.has("rect"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = opts["rect"]
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Anel que se expande e some (impacto do pogo, golpe na pedra).
static func ring(parent: Node, pos: Vector2, color: Color, radius: float, life: float = 0.28) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var r := RingFX.new()
	r.position = pos
	r.color = color
	r.max_radius = radius
	r.life = life
	parent.add_child(r)


## Desenha uma chama em forma de gota. `tilt` inclina a ponta (radianos aprox.).
static func draw_flame(ci: CanvasItem, base: Vector2, height: float, width: float, tilt: float, outer: Color, inner: Color, core: Color) -> void:
	# Camadas aditivas: o alfa de cada uma é baixo para não saturar em branco.
	ci.draw_colored_polygon(_flame_poly(base, height, width, tilt), Color(outer, outer.a * 0.62))
	ci.draw_colored_polygon(_flame_poly(base + Vector2(0, -height * 0.03), height * 0.62, width * 0.6, tilt * 0.8), Color(inner, inner.a * 0.5))
	ci.draw_colored_polygon(_flame_poly(base + Vector2(0, -height * 0.01), height * 0.3, width * 0.32, tilt * 0.6), Color(core, core.a * 0.55))


static func _flame_poly(base: Vector2, h: float, w: float, tilt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := w * 0.5
	var tip := base + Vector2(tilt * h, -h)
	var steps := 7
	# lado direito: base -> ponta (bezier quadrática)
	var c_r := base + Vector2(hw * 1.25 + tilt * h * 0.3, -h * 0.32)
	for i in range(steps + 1):
		var t := float(i) / steps
		pts.append(_bez(base + Vector2(hw, 0), c_r, tip, t))
	var c_l := base + Vector2(-hw * 1.25 + tilt * h * 0.3, -h * 0.32)
	for i in range(1, steps + 1):
		var t := float(i) / steps
		pts.append(_bez(tip, c_l, base + Vector2(-hw, 0), t))
	# fundo arredondado
	for i in range(1, 6):
		var a := PI + PI * float(i) / 6.0
		pts.append(base + Vector2(cos(a) * hw, -sin(a) * hw * 0.85))
	return pts


static func _bez(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t
