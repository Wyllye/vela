class_name Lantern
extends Node2D
## Lanterna de aura pendurada no teto. O golpe para baixo nela vira pogo:
## ela devolve o impulso, acende forte e balança.
## Origem = ponto de ancoragem (no teto); o corpo fica `chain_len` abaixo.

const BRONZE := Color("6d5a3c")
const BRONZE_HI := Color("c8a96e")
const CHAIN := Color("3c4148")

var chain_len := 96.0
var color := Color("8fd3ff")
var swing := 0.0
var swing_v := 0.0
var flare := 0.0
var bob_t := 0.0
var floating := false
var _light: PointLight2D
var _glow: Sprite2D
var _orb: Node2D


func setup(length: float, aura: Color, phase: float) -> void:
	chain_len = length
	floating = length <= 0.0
	color = aura
	bob_t = phase
	swing = sin(phase) * 0.05


func _ready() -> void:
	_orb = Orb.new()
	_orb.lantern = self
	add_child(_orb)
	_glow = FX.make_glow(Color(color, 0.5), 110.0)
	add_child(_glow)
	_light = FX.make_light(color, 220.0, 0.9)
	add_child(_light)
	_place()


func body_pos() -> Vector2:
	if floating:
		return Vector2(0, sin(bob_t * 1.4) * 4.0)
	return Vector2(0, chain_len).rotated(swing)


func hit_rect() -> Rect2:
	var origin := global_position if is_inside_tree() else position
	var p := origin + body_pos()
	return Rect2(p + Vector2(-17, -20), Vector2(34, 40))


func on_struck(player: Player, dir: int, is_pogo: bool) -> bool:
	flare = 1.0
	if dir == 0:
		swing_v += player.facing * 2.2
	elif is_pogo:
		swing_v += (player.vel.x / 300.0) * 1.2 + 0.4 * (1.0 if randf() > 0.5 else -1.0)
	else:
		swing_v += 0.8 * player.facing
	return true


func _process(delta: float) -> void:
	bob_t += delta
	if not floating:
		var steps := maxi(1, ceili(delta / 0.01))
		var h := delta / steps
		for i in steps:
			swing_v += (-swing * (980.0 / maxf(chain_len, 40.0)) - swing_v * 1.4) * h
			swing += swing_v * h
	flare = move_toward(flare, 0.0, delta * 1.8)
	_place()
	queue_redraw()
	_orb.queue_redraw()


func _place() -> void:
	var p := body_pos()
	_glow.position = p
	_light.position = p
	_light.energy = 0.9 + flare * 2.2
	_glow.modulate.a = 0.45 + flare * 0.5
	_glow.scale = Vector2.ONE * ((110.0 + flare * 70.0) / 128.0)


func _draw() -> void:
	var p := body_pos()
	if not floating:
		var n := int(chain_len / 9.0)
		for i in n:
			var q := Vector2(0, i * 9.0 + 4.0).rotated(swing)
			if i % 2 == 0:
				draw_circle(q, 3.0, CHAIN, false, 1.6, true)
			else:
				draw_line(q + Vector2(0, -3).rotated(swing), q + Vector2(0, 3).rotated(swing), CHAIN, 1.6, true)
	draw_set_transform(p, swing, Vector2.ONE)
	# gaiola hexagonal de bronze
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(Vector2(cos(a) * 15.0, sin(a) * 18.0))
	draw_colored_polygon(hex, Color(BRONZE, 0.35))
	draw_polyline(hex, BRONZE, 2.4, true)
	for i in 3:
		var a := -PI / 2.0 + (i * 2 + 1) * TAU / 6.0
		draw_line(Vector2.ZERO + Vector2(cos(a), sin(a)) * 3.0, Vector2(cos(a) * 15.0, sin(a) * 18.0), Color(BRONZE, 0.8), 1.2, true)
	draw_rect(Rect2(-6, -23, 12, 5), BRONZE)
	draw_line(Vector2(-6, -22), Vector2(6, -22), BRONZE_HI, 1.0)
	draw_rect(Rect2(-5, 18, 10, 4), BRONZE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Esfera de aura dentro da lanterna (aditiva, sem sombra).
class Orb extends Node2D:
	var lantern: Lantern

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		var p := lantern.body_pos()
		var c := lantern.color
		var pulse := 0.85 + 0.15 * sin(lantern.bob_t * 3.0) + lantern.flare * 0.6
		draw_circle(p, 9.0 * pulse, Color(c, 0.35))
		draw_circle(p, 6.0 * pulse, Color(c.lightened(0.3), 0.75))
		draw_circle(p, 3.0, Color(1, 1, 1, 0.95))
