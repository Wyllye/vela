class_name Altar
extends Node2D
## Altar de meditação: lugar de descanso. Na Etapa 1 encerra a demonstração.
## Origem = base, em cima do chão.

const STONE := Color("525c6a")
const STONE_DARK := Color("272e38")
const CUSHION := Color("5a3434")
const GOLD := Color("c8a96e")

var near := false
var glow := 0.0
## Ordem do altar na sala e a lição que ele dá ao meditar ("" = só descanso).
var index := 0
var lesson := ""
var _emblem: Node2D


func _ready() -> void:
	for x in [-34.0, 34.0]:
		var c := Candle.new()
		c.setup(14.0 if x < 0 else 20.0, 6.0, true, x)
		c.position = Vector2(x, -30)
		add_child(c)
	_emblem = Emblem.new()
	_emblem.altar = self
	add_child(_emblem)


func set_near(v: bool) -> void:
	near = v


func _process(delta: float) -> void:
	var g := move_toward(glow, 1.0 if near else 0.25, delta * 2.0)
	if g != glow:
		glow = g
		_emblem.queue_redraw()


func _draw() -> void:
	# degraus
	draw_rect(Rect2(-56, -8, 112, 8), STONE_DARK)
	draw_rect(Rect2(-48, -14, 96, 6), STONE_DARK.lerp(STONE, 0.4))
	# bloco principal
	draw_rect(Rect2(-40, -30, 80, 16), STONE)
	draw_rect(Rect2(14, -30, 26, 16), STONE_DARK.lerp(STONE, 0.5))
	draw_line(Vector2(-40, -30), Vector2(40, -30), STONE.lightened(0.25), 1.5)
	# almofada
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -30), Vector2(16, -30), Vector2(12, -36), Vector2(-12, -36)]), CUSHION)


class Emblem extends Node2D:
	var altar: Altar

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		var hex := PackedVector2Array()
		for i in 7:
			var a := -PI / 2.0 + i * TAU / 6.0
			hex.append(Vector2(0, -22) + Vector2(cos(a), sin(a)) * 6.5)
		draw_polyline(hex, Color(Altar.GOLD, 0.35 + altar.glow * 0.5), 1.5, true)
