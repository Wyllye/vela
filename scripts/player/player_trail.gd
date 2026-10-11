class_name PlayerTrail
extends Node2D
## Imagens residuais do Passo de Ren: silhuetas de aura que ficam para trás.

const LIFE := 0.26
const EVERY := 0.01

var player: Player
var color := Color("ffc56a")
var _snaps: Array = []
var _acc := 0.0


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	z_index = -1
	material = FX.additive()
	light_mask = 0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	global_position = Vector2.ZERO
	if player.state == Player.State.DASH:
		_acc += delta
		while _acc >= EVERY:
			_acc -= EVERY
			_snaps.append({"pos": player.global_position, "facing": player.facing, "life": LIFE})
	else:
		_acc = EVERY
	for s in _snaps:
		s["life"] -= delta
	_snaps = _snaps.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	for s in _snaps:
		var k: float = s["life"] / LIFE
		var p: Vector2 = s["pos"]
		var f: int = s["facing"]
		var c := Color(color, 0.16 * k * k)
		var stretch := 1.0 + (1.0 - k) * 0.6
		var robe := PackedVector2Array([
			p + Vector2(-9.0 * f * stretch, -30), p + Vector2(8.0 * f, -29), p + Vector2(13.0 * f, -4),
			p + Vector2(-14.0 * f * stretch, -5)])
		draw_colored_polygon(robe, c)
		draw_circle(p + Vector2(2.0 * f, -38.5), 10.0 * (0.8 + 0.2 * k), c)
