class_name NenHud
extends Node2D
## HUD da Vela, no canto: uma vela pequena cuja chama é a aura (cresce, encolhe,
## escorre antes do Ten, apaga no Zetsu, explode no Ren) e as gotas de cera ao
## lado, que são a Vitalidade. Quando uma gota se perde, ela derrete e cai.

const WAX := Color("ebe0ca")
const WAX_SHADE := Color("b9a98f")
const WAX_DEEP := Color("7d6f5c")
const EMPTY := Color("2a2622")
const AURA := Color("ffc56a")
const DROP_GAP := 25.0

var player: Player
var font: Font
var _t := 0.0
var _shown_vit := -1
var _melting: Array = []
var _pop: Dictionary = {}
var _drip_y := 0.0
var _flash := 0.0
var _ak := 1.0
var _cap_k := 1.0
var _zk := 0.0
var _rk := 0.0
var _glow: Sprite2D


func _ready() -> void:
	_glow = FX.make_glow(Color(AURA, 0.4), 120.0)
	_glow.position = Vector2(0, -22)
	add_child(_glow)
	z_index = 1


## Pisca a chama do HUD (aura devolvida pelo Eco, lição aprendida).
func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var p := player
	var base := maxf(p.nen.aura_max, 1.0)
	_ak = lerpf(_ak, clampf(p.aura / base, 0.0, 1.0), 1.0 - exp(-14.0 * delta))
	_cap_k = lerpf(_cap_k, clampf(p.aura_cap() / base, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	_zk = move_toward(_zk, 1.0 if p.zetsu else 0.0, delta * 6.0)
	_rk = move_toward(_rk, 1.0 if p.ren else 0.0, delta * 8.0)
	_flash = move_toward(_flash, 0.0, delta * 1.5)
	# gotas: animação de perder e de ganhar
	if _shown_vit < 0:
		_shown_vit = p.vitality
	if p.vitality < _shown_vit:
		for i in range(p.vitality, _shown_vit):
			_melting.append({"i": i, "t": 0.0})
	elif p.vitality > _shown_vit:
		for i in range(_shown_vit, p.vitality):
			_pop[i] = 0.0
	_shown_vit = p.vitality
	for m in _melting:
		m["t"] += delta
	_melting = _melting.filter(func(m): return m["t"] < 0.7)
	for k in _pop.keys():
		_pop[k] += delta
		if _pop[k] > 0.35:
			_pop.erase(k)
	if p.is_leaking():
		_drip_y = fmod(_drip_y + delta * 16.0, 30.0)
	_glow.modulate = Color(AURA.lerp(Color.WHITE, 0.3 * _rk + 0.5 * _flash), (0.18 + 0.4 * _ak + 0.35 * _rk + 0.5 * _flash) * (1.0 - 0.9 * _zk))
	_glow.scale = Vector2.ONE * ((100.0 + 70.0 * _ak + 60.0 * _rk) / 128.0)
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	_draw_candle()
	_draw_drops()
	_draw_techniques()


func _draw_candle() -> void:
	var p := player
	# prato
	var dish := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		dish.append(Vector2(cos(a) * 17.0, 38.0 + sin(a) * 4.0))
	draw_colored_polygon(dish, Color(0.25, 0.22, 0.2, 0.9))
	# corpo da vela (encolhe um pouco quando falta aura máxima)
	var top := lerpf(8.0, 0.0, _cap_k)
	var body := PackedVector2Array([Vector2(-9, 37), Vector2(-9, top + 2), Vector2(-6, top - 1), Vector2(6, top - 1), Vector2(9, top + 2), Vector2(9, 37)])
	var cols := PackedColorArray([WAX_SHADE, WAX_SHADE, WAX, WAX, WAX, WAX_SHADE.lerp(WAX, 0.5)])
	draw_polygon(body, cols)
	draw_polyline(body, Color(0.17, 0.15, 0.13, 0.7), 1.2, true)
	# escorridos de cera
	draw_line(Vector2(-7, top + 3), Vector2(-7, top + 12), WAX, 3.0, true)
	draw_circle(Vector2(-7, top + 13), 2.0, WAX)
	draw_line(Vector2(6, top + 2), Vector2(6, top + 7), WAX, 2.4, true)
	if p.is_leaking():
		var y := top + 6.0 + _drip_y
		draw_circle(Vector2(9.5, y), 1.8, Color(WAX, 1.0 - _drip_y / 30.0))
	# pavio
	draw_line(Vector2(0, top - 1), Vector2(0.6, top - 7), Color(0.16, 0.13, 0.11), 2.0, true)
	var fb := Vector2(0.6, top - 6)
	# chama-fantasma do que a aura máxima ainda comporta
	var cap_h := 9.0 + 30.0 * _cap_k
	FX.draw_flame(self, fb, cap_h, 10.0 + 4.0 * _cap_k, 0.0, Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
	# a chama: aura atual
	var low := 1.0 - clampf(_ak / 0.22, 0.0, 1.0)
	var flick := 0.92 + 0.06 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)
	flick += low * 0.12 * sin(_t * 31.0)
	if p.is_leaking():
		flick += 0.1 * sin(_t * 15.0) * sin(_t * 4.1)
	var h := (7.0 + 30.0 * _ak) * (1.0 + 0.55 * _rk) * flick
	var w := (8.0 + 5.0 * _ak) * (1.0 + 0.25 * _rk)
	h = lerpf(h, 3.0, _zk)
	w = lerpf(w, 3.0, _zk)
	var outer := AURA.lerp(Color(0.62, 0.74, 1.0), low * 0.55).lerp(Color(0.8, 0.3, 0.2), _zk).lerp(Color.WHITE, _flash * 0.4)
	FX.draw_flame(self, fb, h, w, sin(_t * 1.7) * 0.06, Color(outer, 0.95), Color(1.0, 0.9, 0.7, 0.9 * (1.0 - _zk * 0.6)), Color(1, 1, 1, 0.95 * (1.0 - _zk * 0.7)))
	if _zk > 0.5:
		# fumacinha do pavio apagado
		for i in 3:
			var k := fmod(_t * 0.6 + i / 3.0, 1.0)
			draw_circle(fb + Vector2(sin(_t * 2.0 + i) * 3.0 * k, -8.0 - k * 22.0), 2.0 + 3.0 * k, Color(0.7, 0.72, 0.78, 0.18 * (1.0 - k) * _zk))


func _drop_poly(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -9.0 * s))
	for i in range(1, 14):
		var a := lerpf(-PI * 0.2, PI * 1.2, i / 13.0)
		pts.append(c + Vector2(cos(a) * 6.0, 2.0 + sin(a) * 6.0) * s)
	return pts


func _draw_drops() -> void:
	var p := player
	var x0 := 34.0
	for i in p.vitality_max:
		var c := Vector2(x0 + i * DROP_GAP, 18.0)
		var empty := _drop_poly(c, 1.0)
		draw_colored_polygon(empty, Color(EMPTY, 0.55))
		draw_polyline(empty + PackedVector2Array([empty[0]]), Color(WAX_DEEP, 0.7), 1.2, true)
		if i < p.vitality:
			var s := 1.0
			if _pop.has(i):
				var k: float = _pop[i] / 0.35
				s = 1.0 + 0.35 * sin(k * PI) * (1.0 - k)
			var pts := _drop_poly(c, s)
			var cols := PackedColorArray()
			for q in pts:
				var k := clampf((q.x - c.x + 6.0) / 12.0, 0.0, 1.0)
				cols.append(WAX_SHADE.lerp(WAX, 1.0 - k * 0.7))
			draw_polygon(pts, cols)
			draw_circle(c + Vector2(-2.0, 1.0), 1.6 * s, Color(1, 1, 1, 0.65))
	# gotas derretendo
	for m in _melting:
		var k: float = m["t"] / 0.7
		var c := Vector2(x0 + int(m["i"]) * DROP_GAP, 18.0 + k * k * 22.0)
		var pts := _drop_poly(c, 1.0 - 0.35 * k)
		for j in pts.size():
			pts[j] = c + (pts[j] - c) * Vector2(1.0 + 0.4 * k, 1.0 - 0.3 * k)
		draw_colored_polygon(pts, Color(WAX.lerp(Color(1, 0.7, 0.5), 0.5 * (1.0 - k)), 1.0 - k))


func _draw_techniques() -> void:
	if font == null:
		return
	var p := player
	var x := 30.0
	var y := 54.0
	var names := [["ten", "Ten"], ["zetsu", "Zetsu"], ["ren", "Ren"]]
	for n in names:
		if not p.learned.get(n[0], false):
			continue
		var active: bool = (n[0] == "zetsu" and p.zetsu) or (n[0] == "ren" and p.ren) or (n[0] == "ten" and not p.zetsu and not p.ren)
		var col := Color(1.0, 0.86, 0.6, 0.95) if active else Color(0.75, 0.78, 0.84, 0.5)
		draw_string(font, Vector2(x, y), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		x += font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14.0
