class_name Mural
extends Node2D
## Mural pintado na parede do fundo (parallax, como a parede): a história do
## Juramento em cinco quadros, sem uma palavra.
##   1. Vesperal acesa — o mosteiro e as velas vivas.
##   2. A sombra — algo vem de fora; as chamas se encolhem.
##   3. O Juramento — a Abadessa ergue o selo; um fio sai de cada chama.
##   4. O Selo — o hexágono arde e a sombra se desfaz.
##   5. O Silêncio — as chamas apagadas; a Abadessa de joelhos.
## Por cima, pintado em aura (só o Gyo ou o En mostram), o que o pintor não
## podia pintar: os fios eram correntes, ela chorava, e uma chama ficou acesa.

const PW := 208.0
const PH := 176.0
const BAND := 14.0
const PANELS := 5
const SIZE := Vector2(PW * PANELS, PH + BAND * 2.0)

const PLASTER := Color("8a806f")
const PLASTER_DARK := Color("6a6152")
const STONE := Color("47423b")
const OCHRE := Color("b3863f")
const RED := Color("8e4a32")
const LAPIS := Color("3f5876")
const NIGHT := Color("1d2635")
const VERDIGRIS := Color("5e8a78")
const CARBON := Color("221f1d")
const GOLD := Color("e2b552")
const GOLD_HI := Color("f6dc93")
const BONE := Color("d5c9b0")
const ASH := Color("8c877e")
const HIDDEN := Color("ffd6f0")

var factor := 0.9
## Posição de projeto (px) e a câmera para a qual o mural fica exatamente nela.
var base_pos := Vector2.ZERO
var anchor_cam := Vector2.ZERO
var layer: AuraLayer
var _seed := 0
var _hidden: Hidden


func setup(entry: Dictionary, seed_value: int, view: Vector2) -> void:
	_seed = seed_value
	base_pos = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0))) * 32.0
	var center := base_pos + SIZE * 0.5
	anchor_cam = center - view * 0.5
	position = base_pos


func _ready() -> void:
	_hidden = Hidden.new()
	_hidden.mural = self
	add_child(_hidden)


func update_camera(cam_tl: Vector2) -> void:
	position = base_pos + (cam_tl - anchor_cam) * (1.0 - factor)


func _process(_delta: float) -> void:
	if _hidden:
		_hidden.queue_redraw()


## Quanto a camada de aura de um quadro está revelada (Gyo, onda do En).
func reveal(panel: int) -> float:
	if layer == null or not is_instance_valid(layer):
		return 0.0
	return layer.reveal_at(global_position + Vector2((panel + 0.5) * PW, SIZE.y * 0.5))


# ---------------------------------------------------------------------------
# Pintura (estática: desenha uma vez)
# ---------------------------------------------------------------------------

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 31 + 5
	# reboco
	draw_rect(Rect2(Vector2(-6, -6), SIZE + Vector2(12, 12)), STONE.darkened(0.2))
	draw_rect(Rect2(Vector2.ZERO, SIZE), PLASTER)
	_frieze(0.0)
	_frieze(SIZE.y - BAND)
	for i in PANELS:
		var o := Vector2(i * PW, BAND)
		match i:
			0:
				_panel_lit(o, rng)
			1:
				_panel_shadow(o, rng)
			2:
				_panel_oath(o, rng)
			3:
				_panel_seal(o, rng)
			_:
				_panel_silence(o, rng)
		# divisória pintada
		if i > 0:
			draw_rect(Rect2(o.x - 3, BAND, 6, PH), RED.darkened(0.15))
			draw_line(Vector2(o.x - 3, BAND), Vector2(o.x - 3, BAND + PH), Color(OCHRE, 0.6), 1.0)
			draw_line(Vector2(o.x + 3, BAND), Vector2(o.x + 3, BAND + PH), Color(OCHRE, 0.6), 1.0)
	_weather(rng)


func _frieze(y: float) -> void:
	draw_rect(Rect2(0, y, SIZE.x, BAND), RED.darkened(0.1))
	draw_line(Vector2(0, y + 2), Vector2(SIZE.x, y + 2), Color(OCHRE, 0.8), 1.2)
	draw_line(Vector2(0, y + BAND - 2), Vector2(SIZE.x, y + BAND - 2), Color(OCHRE, 0.8), 1.2)
	var x := 13.0
	while x < SIZE.x:
		_hexagon(Vector2(x, y + BAND * 0.5), 4.0, Color(OCHRE, 0.85), 1.1, 0.0)
		draw_circle(Vector2(x + 13.0, y + BAND * 0.5), 1.3, Color(BONE, 0.6))
		x += 26.0


func _sky(o: Vector2, top: Color, bottom: Color, h: float) -> void:
	var pts := PackedVector2Array([o, o + Vector2(PW, 0), o + Vector2(PW, h), o + Vector2(0, h)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _hexagon(c: Vector2, r: float, col: Color, width: float, fill_a: float) -> void:
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(c + Vector2(cos(a), sin(a)) * r)
	if fill_a > 0.0:
		draw_colored_polygon(hex.slice(0, 6), Color(col, fill_a))
	draw_polyline(hex, col, width, true)


func hex_vertex(c: Vector2, r: float, i: int) -> Vector2:
	var a := -PI / 2.0 + i * TAU / 6.0
	return c + Vector2(cos(a), sin(a)) * r


func _flame(base: Vector2, h: float, tilt: float, col := GOLD) -> void:
	var w := h * 0.42
	var tip := base + Vector2(sin(tilt) * h, -cos(tilt) * h)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(base + Vector2(cos(a) * w * 0.5, sin(a) * w * 0.35))
	pts.append(tip)
	draw_colored_polygon(pts, col)
	draw_line(base, base.lerp(tip, 0.55), Color(GOLD_HI, 0.8), maxf(1.0, w * 0.25), true)


## Monge-vela: batina, capuz, pavio; chama acesa (ou só um fio de fumaça).
func _monk(feet: Vector2, h: float, lit: bool, tilt: float, col: Color, fallen := false) -> Vector2:
	if fallen:
		var body := PackedVector2Array([feet + Vector2(-h * 0.5, 0), feet + Vector2(h * 0.45, 0),
			feet + Vector2(h * 0.4, -h * 0.28), feet + Vector2(-h * 0.35, -h * 0.3)])
		draw_colored_polygon(body, col)
		draw_circle(feet + Vector2(h * 0.55, -h * 0.16), h * 0.16, col)
		return feet + Vector2(h * 0.7, -h * 0.2)
	var bw := h * 0.3
	var pts := PackedVector2Array([feet + Vector2(-bw, 0), feet + Vector2(bw, 0),
		feet + Vector2(bw * 0.6, -h * 0.62), feet + Vector2(-bw * 0.6, -h * 0.62)])
	draw_colored_polygon(pts, col)
	var head := feet + Vector2(0, -h * 0.74)
	draw_circle(head, h * 0.17, col)
	draw_circle(head + Vector2(h * 0.03, h * 0.02), h * 0.08, CARBON)
	var wick := head + Vector2(0, -h * 0.17)
	draw_line(wick, wick + Vector2(0, -h * 0.07), CARBON, 1.0)
	var fb := wick + Vector2(0, -h * 0.06)
	if lit:
		_flame(fb, h * 0.32, tilt)
	else:
		draw_polyline(PackedVector2Array([fb, fb + Vector2(1.5, -h * 0.12), fb + Vector2(-1.0, -h * 0.24), fb + Vector2(1.0, -h * 0.34)]),
			Color(ASH, 0.6), 1.0, true)
	return fb


## A Abadessa: mais alta, auréola, braços erguidos ou de joelhos.
func _abbess(feet: Vector2, h: float, pose: String, lit: bool) -> Dictionary:
	var col := BONE.darkened(0.08) if lit else ASH
	var bw := h * 0.24
	var top_y := -h * 0.66 if pose != "kneel" else -h * 0.42
	var pts := PackedVector2Array([feet + Vector2(-bw, 0), feet + Vector2(bw, 0),
		feet + Vector2(bw * 0.55, top_y), feet + Vector2(-bw * 0.55, top_y)])
	if pose == "kneel":
		pts = PackedVector2Array([feet + Vector2(-bw * 1.3, 0), feet + Vector2(bw * 1.1, 0),
			feet + Vector2(bw * 0.7, top_y), feet + Vector2(-bw * 0.2, top_y - h * 0.02)])
	draw_colored_polygon(pts, col)
	# manto vermelho por cima
	draw_colored_polygon(PackedVector2Array([pts[0], pts[0] + Vector2(bw * 0.5, 0), pts[3] + Vector2(bw * 0.25, 0), pts[3]]), Color(RED, 0.85))
	var head := feet + Vector2(0, top_y - h * 0.1)
	if pose == "kneel":
		head = feet + Vector2(bw * 0.55, top_y + h * 0.02)
	draw_circle(head, h * 0.1, col)
	draw_circle(head + Vector2(h * 0.02, h * 0.01), h * 0.05, CARBON)
	if pose == "arms":
		for s in [-1.0, 1.0]:
			var sh := feet + Vector2(bw * 0.5 * s, top_y + h * 0.06)
			var hand := sh + Vector2(h * 0.24 * s, -h * 0.3)
			draw_line(sh, hand, col, h * 0.06, true)
			draw_circle(hand, h * 0.035, col)
	# auréola e chama
	draw_arc(head, h * 0.16, 0.0, TAU, 32, Color(GOLD, 0.8 if lit else 0.3), 1.6, true)
	var fb := head + Vector2(0, -h * 0.12)
	if lit:
		_flame(fb, h * 0.2, 0.0)
	return {"head": head, "fb": fb}


func _panel_lit(o: Vector2, rng: RandomNumberGenerator) -> void:
	_sky(o, NIGHT, LAPIS, PH * 0.62)
	for i in 14:
		draw_circle(o + Vector2(rng.randf_range(8, PW - 8), rng.randf_range(6, PH * 0.45)), rng.randf_range(0.8, 1.6), Color(GOLD_HI, 0.7))
	# o mosteiro: torre com o hexágono, arcos
	var base_y := o.y + PH * 0.7
	var tower := Rect2(o.x + PW * 0.42, o.y + PH * 0.18, PW * 0.16, base_y - o.y - PH * 0.18)
	draw_rect(tower, OCHRE.darkened(0.25))
	_hexagon(Vector2(tower.get_center().x, tower.position.y - 10), 12.0, GOLD, 1.6, 0.25)
	draw_rect(Rect2(o.x + 18, o.y + PH * 0.45, PW - 36, base_y - o.y - PH * 0.45), OCHRE.darkened(0.35))
	for k in 6:
		var ax := o.x + 30 + k * (PW - 60) / 5.0
		draw_arc(Vector2(ax, base_y - 14), 7.0, PI, TAU, 10, CARBON, 2.0, true)
		draw_line(Vector2(ax - 7, base_y - 14), Vector2(ax - 7, base_y), CARBON, 2.0)
		draw_line(Vector2(ax + 7, base_y - 14), Vector2(ax + 7, base_y), CARBON, 2.0)
	# chão e as velas vivas
	draw_rect(Rect2(o.x, base_y, PW, o.y + PH - base_y), VERDIGRIS.darkened(0.35))
	for row in 2:
		for k in 7:
			var x := o.x + 18 + k * 28.0 + row * 14.0
			if x > o.x + PW - 12:
				continue
			_monk(Vector2(x, base_y + 22 + row * 24), 22.0 - row * 2.0, true, rng.randf_range(-0.08, 0.08), BONE.darkened(0.1 + row * 0.1))


func _panel_shadow(o: Vector2, rng: RandomNumberGenerator) -> void:
	_sky(o, CARBON.lerp(RED, 0.25), RED.darkened(0.45), PH * 0.62)
	var base_y := o.y + PH * 0.7
	draw_rect(Rect2(o.x, base_y, PW, o.y + PH - base_y), VERDIGRIS.darkened(0.45))
	# a sombra que vem da esquerda: massa negra com dedos compridos
	var mass := PackedVector2Array([o + Vector2(0, 8), o + Vector2(PW * 0.3, 18), o + Vector2(PW * 0.42, PH * 0.4),
		o + Vector2(PW * 0.36, PH * 0.75), o + Vector2(PW * 0.2, PH - 6), o + Vector2(0, PH - 6)])
	draw_colored_polygon(mass, Color(CARBON, 0.92))
	for k in 9:
		var start := o + Vector2(PW * rng.randf_range(0.2, 0.36), PH * rng.randf_range(0.15, 0.85))
		var pts := PackedVector2Array([start])
		var p := start
		var ang := rng.randf_range(-0.4, 0.4)
		for s in 6:
			ang += rng.randf_range(-0.35, 0.35)
			p += Vector2(cos(ang), sin(ang)) * rng.randf_range(9.0, 15.0)
			pts.append(p)
		draw_polyline(pts, Color(CARBON, 0.85), rng.randf_range(2.0, 4.5), true)
	# os monges encolhidos, as chamas fugindo da sombra
	for k in 6:
		var x := o.x + PW * 0.58 + (k % 3) * 24.0 + (k / 3) * 10.0
		_monk(Vector2(x, base_y + 18 + (k / 3) * 22), 20.0, true, 0.45 + rng.randf_range(0.0, 0.15), BONE.darkened(0.2))


func _panel_oath(o: Vector2, rng: RandomNumberGenerator) -> void:
	_sky(o, NIGHT.lerp(LAPIS, 0.3), LAPIS.darkened(0.2), PH)
	var hex_c := o + Vector2(PW * 0.5, 34)
	var a := _abbess(o + Vector2(PW * 0.5, PH - 8), 118.0, "arms", true)
	_hexagon(hex_c, 26.0, GOLD, 2.2, 0.12)
	_hexagon(hex_c, 14.0, Color(GOLD, 0.7), 1.2, 0.0)
	# um fio de cada chama até o selo
	var monks := [Vector2(o.x + 22, o.y + PH - 10), Vector2(o.x + 44, o.y + PH - 30), Vector2(o.x + 30, o.y + PH - 52),
		Vector2(o.x + PW - 22, o.y + PH - 10), Vector2(o.x + PW - 44, o.y + PH - 30), Vector2(o.x + PW - 30, o.y + PH - 52)]
	var i := 0
	for m in monks:
		var fb := _monk(m, 22.0, true, 0.0, BONE.darkened(0.15))
		var v := hex_vertex(hex_c, 26.0, [4, 4, 5, 2, 2, 1][i])
		draw_line(fb + Vector2(0, -6), v, Color(GOLD, 0.75), 1.0, true)
		i += 1
	draw_line(a["fb"] + Vector2(0, -20), hex_c + Vector2(0, 26), Color(GOLD, 0.8), 1.4, true)


func _panel_seal(o: Vector2, rng: RandomNumberGenerator) -> void:
	_sky(o, LAPIS.darkened(0.4), NIGHT, PH)
	var c := o + Vector2(PW * 0.5, PH * 0.44)
	# o selo arde
	for k in 16:
		var ang := TAU * k / 16.0
		draw_line(c + Vector2(cos(ang), sin(ang)) * 40.0, c + Vector2(cos(ang), sin(ang)) * rng.randf_range(62.0, 84.0), Color(GOLD, 0.55), 2.0, true)
	_hexagon(c, 40.0, GOLD, 3.0, 0.75)
	_hexagon(c, 24.0, GOLD_HI, 1.6, 0.0)
	# a sombra se desfazendo nas bordas
	for k in 18:
		var side := -1.0 if k % 2 == 0 else 1.0
		var p := c + Vector2(side * rng.randf_range(70.0, 98.0), rng.randf_range(-70.0, 70.0))
		var sz := rng.randf_range(3.0, 8.0)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(sz, sz * 0.4), p + Vector2(sz * 0.2, sz)]), Color(CARBON, 0.8))
	# chamas puxadas para dentro do selo
	var base_y := o.y + PH - 6
	for k in 6:
		var x := o.x + 20 + k * 34.0
		var tilt := clampf((c.x - x) * 0.012, -0.9, 0.9)
		_monk(Vector2(x, base_y), 21.0, true, tilt, BONE.darkened(0.2))


func _panel_silence(o: Vector2, rng: RandomNumberGenerator) -> void:
	_sky(o, CARBON.lerp(LAPIS, 0.15), CARBON, PH)
	var hex_c := o + Vector2(PW * 0.5, 36)
	_hexagon(hex_c, 26.0, Color(ASH, 0.7), 1.6, 0.05)
	var base_y := o.y + PH - 8
	for k in 7:
		var x := o.x + 16 + k * 28.0
		if absf(x - (o.x + PW * 0.5)) < 26.0:
			continue
		_monk(Vector2(x, base_y - (k % 2) * 16), 21.0, false, 0.0, ASH.darkened(0.1 * (k % 2)), k == 1 or k == 5)
	_abbess(o + Vector2(PW * 0.5, base_y), 100.0, "kneel", false)


## Tempo: manchas, rachaduras e reboco caído.
func _weather(rng: RandomNumberGenerator) -> void:
	for k in 90:
		var p := Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		var r := rng.randf_range(4.0, 22.0)
		var c := PLASTER_DARK if rng.randf() < 0.6 else BONE
		draw_circle(p, r, Color(c, rng.randf_range(0.04, 0.12)))
	for k in 14:
		var p := Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		var pts := PackedVector2Array([p])
		var ang := rng.randf_range(0, TAU)
		for s in rng.randi_range(4, 9):
			ang += rng.randf_range(-0.6, 0.6)
			p += Vector2(cos(ang), sin(ang)) * rng.randf_range(5.0, 14.0)
			pts.append(p)
		draw_polyline(pts, Color(CARBON, 0.55), 1.0, true)
	# buracos onde o reboco caiu (a pedra aparece)
	for k in 6:
		var c := Vector2(rng.randf_range(20, SIZE.x - 20), rng.randf_range(10, SIZE.y - 10))
		var pts := PackedVector2Array()
		var n := 9
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 16.0))
		draw_colored_polygon(pts, STONE)
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(BONE, 0.35), 1.0, true)


## O que foi pintado em aura por cima (aditivo): só o Gyo ou o En mostram.
class Hidden extends Node2D:
	var mural: Mural
	var _t := 0.0

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		var k3 := mural.reveal(2)
		var k5 := mural.reveal(4)
		var col := Mural.HIDDEN
		if k3 > 0.01:
			var o := Vector2(2 * Mural.PW, Mural.BAND)
			var hex_c := o + Vector2(Mural.PW * 0.5, 34)
			# os fios eram correntes: elos em cada fio
			var monks := [Vector2(o.x + 22, o.y + Mural.PH - 10), Vector2(o.x + 44, o.y + Mural.PH - 30), Vector2(o.x + 30, o.y + Mural.PH - 52),
				Vector2(o.x + Mural.PW - 22, o.y + Mural.PH - 10), Vector2(o.x + Mural.PW - 44, o.y + Mural.PH - 30), Vector2(o.x + Mural.PW - 30, o.y + Mural.PH - 52)]
			var verts := [4, 4, 5, 2, 2, 1]
			for i in monks.size():
				var a: Vector2 = monks[i] + Vector2(0, -22.0 * 0.74 - 22.0 * 0.23 - 6.0)
				var b := mural.hex_vertex(hex_c, 26.0, verts[i])
				var d := b - a
				var n := int(d.length() / 7.0)
				for j in n:
					var p := a + d * (j + 0.5) / n
					draw_arc(p, 2.2, 0.0, TAU, 8, Color(col, 0.55 * k3), 1.0, true)
				# e uma argola em volta de cada monge
				draw_arc(monks[i] + Vector2(0, -9), 11.0, 0.0, TAU, 20, Color(col, 0.4 * k3), 1.2, true)
			# lágrimas da Abadessa
			var head := o + Vector2(Mural.PW * 0.5, Mural.PH - 8) + Vector2(0, -118.0 * 0.66 - 11.8)
			for s in [-1.0, 1.0]:
				var e := head + Vector2(2.0 + s * 3.0, 1.0)
				draw_line(e, e + Vector2(s * 0.6, 9.0 + 2.0 * sin(_t * 1.3 + s)), Color(col, 0.8 * k3), 1.2, true)
		if k5 > 0.01:
			var o5 := Vector2(4 * Mural.PW, Mural.BAND)
			# uma chama ficou acesa: alguém pequeno a leva para fora do quadro
			var feet := o5 + Vector2(Mural.PW - 14, Mural.PH - 8)
			var fig := PackedVector2Array([feet + Vector2(-5, 0), feet + Vector2(5, 0), feet + Vector2(3, -11), feet + Vector2(-3, -11)])
			draw_colored_polygon(fig, Color(col, 0.35 * k5))
			draw_circle(feet + Vector2(0, -14), 3.4, Color(col, 0.35 * k5))
			var fl := feet + Vector2(0, -20)
			var flick := 0.85 + 0.15 * sin(_t * 9.0)
			draw_circle(fl + Vector2(0, -3), 6.0 * flick, Color(col, 0.18 * k5))
			draw_colored_polygon(PackedVector2Array([fl + Vector2(-2.6, 0), fl + Vector2(2.6, 0), fl + Vector2(0, -8.0 * flick)]), Color(col, 0.95 * k5))
			# e ela chorava
			var kneel_head := o5 + Vector2(Mural.PW * 0.5, Mural.PH - 8) + Vector2(100.0 * 0.24 * 0.55, -100.0 * 0.42 + 2.0)
			draw_line(kneel_head + Vector2(3, 1), kneel_head + Vector2(3.5, 10), Color(col, 0.8 * k5), 1.2, true)
			# uma rachadura no selo, do tamanho de uma chama
			var hc := o5 + Vector2(Mural.PW * 0.5, 36)
			draw_polyline(PackedVector2Array([hc + Vector2(-4, -26), hc + Vector2(1, -12), hc + Vector2(-3, -2), hc + Vector2(3, 8)]), Color(col, 0.7 * k5), 1.3, true)
