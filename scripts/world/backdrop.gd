class_name Backdrop
extends Node2D
## Uma camada de fundo desenhada em código, com fator de parallax.
##
## Camadas de tela (na CanvasLayer de fundo) não são afetadas pela luz;
## camadas de mundo (parede do fundo, primeiro plano) são.
## Posição na tela = ponto - câmera * fator.

enum Kind { SKY, FAR, ARCH, PILLARS, BACKWALL, FOREGROUND }

const VIEW := Vector2(1280, 720)

var kind: Kind = Kind.SKY
var factor := 0.0
## true = vive na CanvasLayer de fundo (coordenadas de tela)
var screen_space := true
var room_size := Vector2(1280, 720)
var palette: Dictionary = {}
var content := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var base_seed := 0
var _flames: Array = []
var _t := 0.0


func setup(k: Kind, f: float, in_screen: bool, room_px: Vector2, pal: Dictionary, seed_value: int) -> void:
	kind = k
	factor = f
	screen_space = in_screen
	room_size = room_px
	palette = pal
	base_seed = seed_value * 7919 + int(k) * 131
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	content = VIEW + (room_size - VIEW).max(Vector2.ZERO) * f + Vector2(240, 160)
	if kind == Kind.FOREGROUND:
		light_mask = 0
		z_index = 10
	elif kind == Kind.BACKWALL:
		z_index = -5
	set_process(kind == Kind.FAR)
	queue_redraw()


func update_camera(cam_tl: Vector2) -> void:
	if kind == Kind.SKY:
		position = Vector2.ZERO
		return
	var margin := Vector2(120, 80)
	if screen_space:
		position = -cam_tl * factor - margin
	else:
		position = cam_tl * (1.0 - factor) - margin


func _process(delta: float) -> void:
	_t += delta
	if not _flames.is_empty():
		queue_redraw()


func _draw() -> void:
	# mesma semente a cada redesenho: a geometria não muda entre frames
	rng.seed = base_seed
	match kind:
		Kind.SKY:
			_draw_sky()
		Kind.FAR:
			_draw_far()
		Kind.ARCH:
			_draw_arches()
		Kind.PILLARS:
			_draw_pillars()
		Kind.BACKWALL:
			_draw_backwall()
		Kind.FOREGROUND:
			_draw_foreground()


# ---------------------------------------------------------------------------

func _draw_sky() -> void:
	var top: Color = palette["sky_top"]
	var bottom: Color = palette["sky_bottom"]
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(VIEW.x, 0), Vector2(VIEW.x, VIEW.y), Vector2(0, VIEW.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# claridade vinda da superfície, bem lá em cima
	draw_texture_rect(FX.glow_texture(), Rect2(VIEW.x * 0.15, -VIEW.y * 0.9, VIEW.x * 0.7, VIEW.y * 1.4), false, Color(top.lightened(0.25), 0.35))


func _draw_far() -> void:
	var col: Color = palette["far"]
	var rim: Color = palette["far_rim"]
	# teto e chão distantes da caverna
	_jagged_band(0.0, 90.0, 60.0, col.darkened(0.15), true)
	_jagged_band(content.y, 70.0, 50.0, col.darkened(0.1), false)
	# colossos: estátuas de Velas encapuzadas
	var n := 3 + int(content.x / 900.0)
	_flames.clear()
	for i in n:
		var x := (i + 0.5) / n * content.x + rng.randf_range(-80, 80)
		var h := rng.randf_range(380, 560)
		var base_y := content.y + rng.randf_range(20, 120)
		var lit := rng.randf() < 0.4
		_statue(Vector2(x, base_y), h, col, rim, lit)
	# correntes longas com sinos
	for i in int(content.x / 420.0):
		var x := rng.randf_range(0, content.x)
		var chain_len := rng.randf_range(120, 300)
		draw_line(Vector2(x, 0), Vector2(x, chain_len), col.lightened(0.04), 2.0)
		_bell(Vector2(x, chain_len), rng.randf_range(10, 16), col.lightened(0.06))
	_draw_far_flames()


func _statue(base: Vector2, h: float, col: Color, rim: Color, lit: bool) -> void:
	var w := h * 0.42
	var shoulder := base.y - h * 0.62
	var robe := PackedVector2Array([
		Vector2(base.x - w * 0.5, base.y),
		Vector2(base.x - w * 0.3, shoulder + h * 0.08),
		Vector2(base.x - w * 0.18, shoulder),
		Vector2(base.x + w * 0.18, shoulder),
		Vector2(base.x + w * 0.3, shoulder + h * 0.08),
		Vector2(base.x + w * 0.5, base.y),
	])
	draw_colored_polygon(robe, col)
	# luz de borda num lado
	draw_polyline(PackedVector2Array([robe[3], robe[4], robe[5]]), Color(rim, 0.8), 2.5, true)
	# capuz
	var hc := Vector2(base.x, shoulder - h * 0.1)
	var hr := h * 0.13
	draw_circle(hc, hr, col)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 0.9, -hr * 0.3), hc + Vector2(-hr * 1.5, -hr * 1.3), hc + Vector2(hr * 0.2, -hr * 0.95)]), col)
	draw_arc(hc, hr, -PI * 0.45, PI * 0.3, 16, Color(rim, 0.7), 2.0, true)
	# rosto escuro (elipse virada para a frente)
	var face := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		face.append(hc + Vector2(hr * 0.34, hr * 0.14) + Vector2(cos(a) * hr * 0.4, sin(a) * hr * 0.56))
	draw_colored_polygon(face, col.darkened(0.3))
	# mãos segurando uma tigela
	var bowl := Vector2(base.x, shoulder + h * 0.2)
	draw_colored_polygon(PackedVector2Array([bowl + Vector2(-w * 0.16, 0), bowl + Vector2(w * 0.16, 0), bowl + Vector2(w * 0.1, h * 0.04), bowl + Vector2(-w * 0.1, h * 0.04)]), col.lightened(0.03))
	# pavio
	var wick_top := hc + Vector2(0, -hr - h * 0.035)
	draw_line(hc + Vector2(0, -hr * 0.95), wick_top, col.darkened(0.3), 3.0)
	if lit:
		_flames.append({"pos": wick_top, "h": h * 0.06})


func _bell(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3, 0), p + Vector2(s * 0.3, 0), p + Vector2(s * 0.6, s), p + Vector2(-s * 0.6, s)]), col)
	draw_circle(p + Vector2(0, s * 1.1), s * 0.18, col)


func _jagged_band(y: float, depth: float, step: float, col: Color, from_top: bool) -> void:
	var pts := PackedVector2Array()
	var x := -20.0
	pts.append(Vector2(-20, y))
	while x < content.x + 40:
		var d := rng.randf_range(depth * 0.3, depth)
		if rng.randf() < 0.18:
			d *= 2.2
		pts.append(Vector2(x, y + (d if from_top else -d)))
		x += rng.randf_range(step * 0.5, step * 1.4)
	pts.append(Vector2(content.x + 40, y))
	draw_colored_polygon(pts, col)


func _draw_arches() -> void:
	var col: Color = palette["arch"]
	var rim: Color = palette["arch_rim"]
	var x := rng.randf_range(-60, 40)
	var floor_y := content.y * rng.randf_range(0.78, 0.9)
	while x < content.x:
		var w := rng.randf_range(170, 260)
		var h := rng.randf_range(330, 470)
		var pw := w * 0.16
		var top := floor_y - h
		# pilares
		draw_rect(Rect2(x, top + w * 0.5, pw, h - w * 0.5 + 400), col)
		draw_rect(Rect2(x + w - pw, top + w * 0.5, pw, h - w * 0.5 + 400), col)
		# arco
		draw_arc(Vector2(x + w * 0.5, top + w * 0.5), w * 0.5 - pw * 0.5, PI, TAU, 28, col, pw, true)
		draw_arc(Vector2(x + w * 0.5, top + w * 0.5), w * 0.5 - pw * 0.05, PI * 1.05, PI * 1.6, 16, Color(rim, 0.6), 2.0, true)
		# parede acima do arco
		draw_rect(Rect2(x - 2, top - 80 - rng.randf_range(0, 120), w + 4, 80 + w * 0.12), col)
		# janelinha
		if rng.randf() < 0.5:
			var wx := x + w * 0.5
			var wy := top - 40
			draw_rect(Rect2(wx - 8, wy - 16, 16, 26), col.darkened(0.5))
		# telhado em beiral (às vezes)
		if rng.randf() < 0.35:
			var ry := top - 150
			draw_colored_polygon(PackedVector2Array([Vector2(x - 40, ry + 40), Vector2(x + w * 0.5, ry - 30), Vector2(x + w + 40, ry + 40), Vector2(x + w + 20, ry + 50), Vector2(x - 20, ry + 50)]), col)
			draw_rect(Rect2(x + w * 0.2, ry + 45, w * 0.6, 120), col)
		x += w + rng.randf_range(-10, 60)
	# chão / escadaria
	draw_rect(Rect2(-40, floor_y, content.x + 80, content.y), col.darkened(0.08))
	var sx := rng.randf_range(content.x * 0.2, content.x * 0.7)
	for i in 8:
		draw_rect(Rect2(sx + i * 26, floor_y - i * 14, 300, 14), col.darkened(0.04))


func _draw_pillars() -> void:
	var col: Color = palette["pillar"]
	var cloth: Color = palette["cloth"].darkened(0.55)
	var x := rng.randf_range(80, 300)
	while x < content.x:
		var w := rng.randf_range(54, 96)
		draw_rect(Rect2(x, -40, w, content.y + 80), col)
		# capitel e base
		draw_rect(Rect2(x - w * 0.25, content.y * rng.randf_range(0.08, 0.2), w * 1.5, 22), col.lightened(0.02))
		draw_rect(Rect2(x - w * 0.2, content.y * 0.86, w * 1.4, 28), col.lightened(0.02))
		# estandarte entre pilares
		if rng.randf() < 0.55:
			var bx := x + w + rng.randf_range(40, 140)
			var bw := rng.randf_range(26, 40)
			var bl := rng.randf_range(160, 320)
			var by := content.y * rng.randf_range(0.05, 0.2)
			var pts := PackedVector2Array([Vector2(bx, by), Vector2(bx + bw, by), Vector2(bx + bw, by + bl)])
			var teeth := 4
			for i in range(1, teeth):
				var tx := bx + bw - bw * float(i) / teeth
				pts.append(Vector2(tx, by + bl + (10.0 if i % 2 == 1 else 2.0) + rng.randf_range(0, 4)))
			pts.append(Vector2(bx, by + bl))
			draw_colored_polygon(pts, cloth)
			draw_line(Vector2(bx - 6, by), Vector2(bx + bw + 6, by), col.lightened(0.05), 3.0)
		x += w + rng.randf_range(380, 700)


func _draw_backwall() -> void:
	# Painéis de alvenaria e pilares com vãos entre eles: pelos vãos aparece
	# o fundo distante (estátuas, arcos), o que dá profundidade.
	var base: Color = palette["backwall"]
	var x := rng.randf_range(-160.0, 60.0)
	while x < content.x:
		var roll := rng.randf()
		if roll < 0.3:
			x += rng.randf_range(240.0, 520.0)
			continue
		var tint := rng.randf_range(-0.07, 0.05)
		var col := base.lightened(tint) if tint > 0.0 else base.darkened(-tint)
		if roll < 0.62:
			var w := rng.randf_range(340.0, 720.0)
			_wall_panel(Rect2(x, rng.randf_range(-40.0, content.y * 0.3), w, content.y + 80.0), col)
			x += w + rng.randf_range(0.0, 60.0)
		else:
			var pw := rng.randf_range(70.0, 110.0)
			var gap := rng.randf_range(130.0, 230.0)
			_pillar(Rect2(x, -40.0, pw, content.y + 80.0), col)
			_pillar(Rect2(x + pw + gap, -40.0, pw, content.y + 80.0), col)
			if rng.randf() < 0.6:
				# arco ligando os pilares
				var c := Vector2(x + pw + gap * 0.5, content.y * rng.randf_range(0.18, 0.35))
				draw_arc(c, gap * 0.5 + pw * 0.25, PI, TAU, 24, col, pw * 0.5, true)
			x += pw * 2.0 + gap + rng.randf_range(40.0, 120.0)


func _wall_panel(r: Rect2, col: Color) -> void:
	var line: Color = palette["backwall_line"]
	var relief: Color = palette["backwall_relief"]
	var bw := 72.0
	var bh := 44.0
	var rows := int(r.size.y / bh) + 1
	var cols := int(r.size.x / bw) + 2
	for row in rows:
		var off := (bw * 0.5) if row % 2 == 1 else 0.0
		var y := r.position.y + row * bh
		for c in cols:
			var bx := r.position.x + c * bw - off
			var x0 := maxf(bx, r.position.x)
			var x1 := minf(bx + bw, r.end.x)
			if x1 - x0 < 8.0:
				continue
			# topo quebrado: falta pedra nas primeiras fileiras
			if row < 2 and rng.randf() < 0.35:
				continue
			var k := rng.randf_range(-0.035, 0.035)
			var bc := col.lightened(k) if k > 0.0 else col.darkened(-k)
			draw_rect(Rect2(x0, y, x1 - x0, bh), bc)
			draw_rect(Rect2(x0, y, x1 - x0, bh), line, false, 1.5)
	# nicho ou relevo do hexágono
	var cx := r.position.x + r.size.x * rng.randf_range(0.3, 0.7)
	var cy := r.position.y + rng.randf_range(160.0, maxf(170.0, r.size.y * 0.5))
	if rng.randf() < 0.5:
		_hexagon_relief(Vector2(cx, cy), rng.randf_range(34.0, 50.0), relief)
	else:
		_niche(Vector2(cx, cy), relief)
	# rachaduras
	for i in 2:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), r.position.y + rng.randf_range(60.0, 300.0))
		var pts := PackedVector2Array([p])
		for s in 6:
			p += Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(8.0, 26.0))
			pts.append(p)
		draw_polyline(pts, line.darkened(0.3), 1.5, true)


func _pillar(r: Rect2, col: Color) -> void:
	var line: Color = palette["backwall_line"]
	draw_rect(r, col)
	var y := r.position.y
	while y < r.end.y:
		var h := rng.randf_range(50.0, 90.0)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 1.5)
		y += h
	draw_line(Vector2(r.end.x - 3.0, r.position.y), Vector2(r.end.x - 3.0, r.end.y), col.darkened(0.25), 4.0)
	var cap_y := r.position.y + content.y * rng.randf_range(0.12, 0.3)
	draw_rect(Rect2(r.position.x - 12.0, cap_y, r.size.x + 24.0, 18.0), col.lightened(0.04))
	draw_rect(Rect2(r.position.x - 6.0, cap_y + 18.0, r.size.x + 12.0, 8.0), col.darkened(0.1))


func _hexagon_relief(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, 3.0, true)
	for i in 6:
		var a := -PI / 2.0 + i * TAU / 6.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r, 5.0, col)
	draw_circle(c, r * 0.28, col, false, 2.0, true)


func _niche(c: Vector2, col: Color) -> void:
	var w := 40.0
	var h := 64.0
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5 + w * 0.5, w, h - w * 0.5), col.darkened(0.55))
	draw_circle(Vector2(c.x, c.y - h * 0.5 + w * 0.5), w * 0.5, col.darkened(0.55))
	draw_arc(Vector2(c.x, c.y - h * 0.5 + w * 0.5), w * 0.5, PI, TAU, 20, col, 3.0, true)
	draw_rect(Rect2(c.x - w * 0.5 - 4, c.y + h * 0.5, w + 8, 6), col)
	# vela apagada dentro
	draw_rect(Rect2(c.x - 4, c.y + h * 0.5 - 18, 8, 18), col.lightened(0.15))


func _draw_foreground() -> void:
	var col: Color = palette["fg"]
	var x := rng.randf_range(200, 500)
	while x < content.x:
		var choice := rng.randi() % 3
		if choice == 0:
			# raízes/estalactites penduradas no alto
			var w := rng.randf_range(60, 140)
			var pts := PackedVector2Array([Vector2(x - w, -20)])
			var steps := 6
			for i in range(steps + 1):
				var tx := x - w + 2.0 * w * float(i) / steps
				var depth := rng.randf_range(30, 90) * (1.0 - absf(float(i) / steps - 0.5) * 1.4)
				pts.append(Vector2(tx, depth + 40))
			pts.append(Vector2(x + w, -20))
			draw_colored_polygon(pts, Color(col, 0.94))
		elif choice == 1:
			# corrente grossa atravessando o quadro
			var top := Vector2(x, -10)
			var bottom := Vector2(x + rng.randf_range(-60, 60), rng.randf_range(160, 300))
			var links := 12
			for i in links:
				var p := top.lerp(bottom, float(i) / links)
				draw_circle(p, 7.0, Color(col, 0.94), false, 4.0, true)
		else:
			# pedra/base de pilar embaixo
			var w := rng.randf_range(90, 180)
			var y := content.y
			draw_colored_polygon(PackedVector2Array([Vector2(x - w, y + 10), Vector2(x - w * 0.6, y - rng.randf_range(40, 90)), Vector2(x + w * 0.4, y - rng.randf_range(60, 120)), Vector2(x + w, y + 10)]), Color(col, 0.94))
		x += rng.randf_range(700, 1100)


func _draw_far_flames() -> void:
	for f in _flames:
		var p: Vector2 = f["pos"]
		var h: float = f["h"]
		var flick := 0.9 + 0.1 * sin(_t * 7.0 + p.x)
		var c: Color = palette["far_flame"]
		draw_texture_rect(FX.glow_texture(), Rect2(p - Vector2(h * 2.6, h * 3.2), Vector2(h * 5.2, h * 5.2)), false, Color(c, 0.35))
		FX.draw_flame(self, p, h * flick, h * 0.45, 0.0, Color(c, 0.75), Color(1, 0.93, 0.8, 0.85), Color(1, 1, 1, 0.9))
