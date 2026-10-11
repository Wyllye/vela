class_name Candle
extends Node2D
## Vela decorativa (acesa ou apagada). Origem = base, em cima do chão.

const WAX := Color("e6dac4")
const WAX_SHADE := Color("b8a78d")
const WICK := Color("2a2420")

var height := 18.0
var width := 6.0
var lit := true
var phase := 0.0
var _light: PointLight2D
var _glow: Sprite2D
var _flame: FlameNode
var _t := 0.0


func setup(h: float, w: float, is_lit: bool, p: float) -> void:
	height = h
	width = w
	lit = is_lit
	phase = p


func _ready() -> void:
	if lit:
		var tip := Vector2(0.6, -height - 3.0)
		_flame = FlameNode.new()
		_flame.position = tip
		_flame.phase = phase
		_flame.height = 7.0 + width * 0.4
		_flame.width = 3.6 + width * 0.1
		add_child(_flame)
		_glow = FX.make_glow(Color(1.0, 0.72, 0.4, 0.42), 54.0)
		_glow.position = tip + Vector2(0, -4)
		add_child(_glow)
		_light = FX.make_light(Color(1.0, 0.72, 0.44), 170.0, 0.85)
		_light.position = tip
		add_child(_light)
	set_process(lit)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var f := 0.88 + 0.08 * sin(_t * 9.3 + phase) + 0.04 * sin(_t * 23.0 + phase * 1.7)
	_light.energy = 0.85 * f
	_glow.modulate.a = 0.42 * f


func _draw() -> void:
	var w := width
	var h := height
	draw_rect(Rect2(-w * 0.5, -h, w, h), WAX)
	draw_rect(Rect2(w * 0.08, -h, w * 0.42, h), WAX_SHADE)
	# borda derretida e pingos
	draw_circle(Vector2(-w * 0.32, -h + 1.0), w * 0.24, WAX)
	draw_rect(Rect2(-w * 0.55, -h + 2.0, w * 0.22, h * 0.35), WAX)
	draw_circle(Vector2(-w * 0.44, -h + 2.0 + h * 0.35), w * 0.12, WAX)
	draw_rect(Rect2(w * 0.32, -h + 1.5, w * 0.2, h * 0.2), WAX_SHADE)
	# poça de cera na base
	draw_rect(Rect2(-w * 0.85, -2.0, w * 1.7, 2.0), WAX_SHADE)
	draw_line(Vector2(0, -h), Vector2(0.6, -h - 3.5), WICK, 1.3, true)
