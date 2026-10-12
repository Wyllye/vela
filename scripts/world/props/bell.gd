class_name Bell
extends Node2D
## O grande sino do Campanário. O cajado comum só arranca um gemido dele; o Ko
## — toda a aura num ponto — faz o sino cantar, e o som abre os portões da sala.
## Origem = ponto de ancoragem no teto; o sino fica `rope_len` abaixo.

signal rung(strong: bool)

const BRONZE := Color("7d6138")
const BRONZE_HI := Color("e0bb73")
const BRONZE_DEEP := Color("2e220f")
const VERDIGRIS := Color("4f7f72")
const ROPE := Color("3b3229")
const AURA := Color("ffc56a")

var rope_len := 110.0
var swing := 0.0
var swing_v := 0.0
## 0..1: o sino ainda vibra depois de tocar (brilho e ondas).
var ring := 0.0
var tolled := false
var _t := 0.0
var _light: PointLight2D
var _glow: Glow


func setup(length: float, phase: float) -> void:
	rope_len = length
	swing = sin(phase) * 0.03


func _ready() -> void:
	_glow = Glow.new()
	_glow.bell = self
	add_child(_glow)
	_light = FX.make_light(AURA, 260.0, 0.0)
	add_child(_light)


func body_pos() -> Vector2:
	return Vector2(0, rope_len).rotated(swing)


func hit_rect() -> Rect2:
	var origin := global_position if is_inside_tree() else position
	var p := origin + body_pos()
	return Rect2(p + Vector2(-36, -44), Vector2(72, 76))


func on_struck(player: Player, dir: int, _is_pogo: bool) -> bool:
	if player.ko_strike:
		swing_v += player.facing * 3.2
		ring = 1.0
		tolled = true
		rung.emit(true)
	else:
		swing_v += player.facing * (0.45 if dir == 0 else 0.2)
		ring = maxf(ring, 0.22)
		rung.emit(false)
	return true


func _process(delta: float) -> void:
	_t += delta
	var steps := maxi(1, ceili(delta / 0.01))
	var h := delta / steps
	for i in steps:
		swing_v += (-swing * (980.0 / maxf(rope_len + 40.0, 60.0)) - swing_v * 0.9) * h
		swing += swing_v * h
	ring = move_toward(ring, 0.0, delta * 0.22)
	if _light:
		_light.position = body_pos()
		_light.energy = ring * 1.3
	queue_redraw()
	_glow.queue_redraw()


## Perfil do sino (olhando de lado): coroa, ombro, cintura e boca aberta.
func _profile() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := [[-40.0, 8.0], [-36.0, 13.0], [-26.0, 19.0], [-12.0, 23.0], [4.0, 27.0], [20.0, 33.0], [26.0, 36.0], [30.0, 37.0]]
	for q in half:
		pts.append(Vector2(-q[1], q[0]))
	for i in range(half.size() - 1, -1, -1):
		pts.append(Vector2(half[i][1], half[i][0]))
	return pts


func _draw() -> void:
	var p := body_pos()
	var top := p + Vector2(0, -44).rotated(swing)
	# corda e travessa
	draw_line(Vector2.ZERO, top, ROPE, 4.0, true)
	draw_line(Vector2(-14, 0), Vector2(14, 0), ROPE.darkened(0.3), 6.0, true)
	draw_set_transform(p, swing, Vector2.ONE)
	# alça (coroa)
	draw_arc(Vector2(0, -44), 7.0, PI, TAU, 12, BRONZE_DEEP, 4.0, true)
	var prof := _profile()
	var vib := sin(_t * 47.0) * ring * 1.2
	var cols := PackedColorArray()
	for q in prof:
		var k := clampf((q.x + 36.0) / 72.0, 0.0, 1.0)
		var c := BRONZE_DEEP.lerp(BRONZE, smoothstep(0.0, 0.45, k)).lerp(BRONZE_HI, smoothstep(0.55, 0.85, k) * 0.7)
		c = c.lerp(BRONZE.darkened(0.35), smoothstep(0.85, 1.0, k))
		cols.append(c)
	for i in prof.size():
		prof[i] += Vector2(vib * (1.0 if prof[i].x > 0.0 else -1.0) * clampf((prof[i].y + 20.0) / 50.0, 0.0, 1.0), 0)
	draw_polygon(prof, cols)
	var edge := prof.duplicate()
	edge.append(prof[0])
	draw_polyline(edge, BRONZE_DEEP, 1.5, true)
	# frisos, pátina e o hexágono do mosteiro
	draw_line(Vector2(-23, -18), Vector2(23, -18), Color(BRONZE_DEEP, 0.7), 1.4, true)
	draw_line(Vector2(-33, 26), Vector2(33, 26), Color(BRONZE_DEEP, 0.7), 1.6, true)
	draw_line(Vector2(-35, 30), Vector2(35, 30), Color(BRONZE_HI, 0.35), 1.0, true)
	for k in 5:
		var x := -18.0 + k * 9.0
		draw_line(Vector2(x, -36), Vector2(x - 2.0, -24), Color(VERDIGRIS, 0.35), 2.0, true)
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(Vector2(2, 2) + Vector2(cos(a), sin(a)) * 9.0)
	draw_polyline(hex, Color(BRONZE_DEEP, 0.85), 1.6, true)
	# badalo na boca
	draw_line(Vector2(0, -30), Vector2(-swing_v * 3.0, 30), BRONZE_DEEP, 2.4, true)
	draw_circle(Vector2(-swing_v * 3.0, 32), 5.0, BRONZE_DEEP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Brilho e ondas do som (aditivo).
class Glow extends Node2D:
	var bell: Bell

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		if bell.ring < 0.02:
			return
		var p := bell.body_pos()
		var k := bell.ring
		draw_circle(p, 40.0 + 30.0 * k, Color(Bell.AURA, 0.05 * k))
		for i in 3:
			var ph := fmod(bell._t * 0.9 + i / 3.0, 1.0)
			var r := 46.0 + ph * 260.0 * (0.5 + 0.5 * k)
			draw_arc(p, r, 0.0, TAU, 64, Color(Bell.AURA, 0.18 * k * (1.0 - ph)), 2.0, true)
