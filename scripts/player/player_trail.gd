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
	var n := _snaps.size()
	if n == 0:
		return
	var light := color.lightened(0.35)
	# fita de luz ao longo do caminho (mais larga e forte perto da Vela)
	if n >= 2:
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		var cols_t := PackedColorArray()
		var cols_b := PackedColorArray()
		for i in n:
			var s: Dictionary = _snaps[i]
			var k: float = s["life"] / LIFE
			var c: Vector2 = s["pos"] + Vector2(0, -24)
			var w := 3.0 + 13.0 * k
			top.append(c + Vector2(0, -w))
			bottom.append(c + Vector2(0, w * 0.8))
			cols_t.append(Color(light, 0.0))
			cols_b.append(Color(light, 0.0))
		for i in n:
			var k: float = _snaps[i]["life"] / LIFE
			cols_t[i] = Color(light, 0.22 * k)
			cols_b[i] = Color(light, 0.14 * k)
		var pts := top.duplicate()
		var cols := cols_t.duplicate()
		for i in range(n - 1, -1, -1):
			pts.append(bottom[i])
			cols.append(cols_b[i])
		draw_polygon(pts, cols)
		var core := PackedVector2Array()
		for i in n:
			core.append(_snaps[i]["pos"] + Vector2(0, -26))
		draw_polyline(core, Color(1, 0.95, 0.85, 0.35), 2.0, true)
	# silhuetas bem tênues
	for i in range(0, n, 4):
		var s: Dictionary = _snaps[i]
		var k: float = s["life"] / LIFE
		var p: Vector2 = s["pos"]
		var f: int = s["facing"]
		var c := Color(light, 0.09 * k)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-9.0 * f, -30), p + Vector2(8.0 * f, -29), p + Vector2(13.0 * f, -4), p + Vector2(-14.0 * f, -5)]), c)
		draw_circle(p + Vector2(2.0 * f, -38.5), 10.0, c)
