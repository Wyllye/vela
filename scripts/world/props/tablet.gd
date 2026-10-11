class_name Tablet
extends Node2D
## Estela com inscrição. Quando a Vela chega perto, a escrita acende e o texto
## aparece na tela (sem botão). Origem = base, em cima do chão.

const STONE := Color("4a5462")
const STONE_DARK := Color("252c36")
const CARVE := Color("161b22")

var text_key := ""
var glow := 0.0
var target := 0.0
var aura := Color("ffe2a8")
var _lines: Array = []
var _writing: Node2D
var _light: PointLight2D


func setup(key: String, seed_value: int) -> void:
	text_key = key
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for row in 6:
		var y := -44.0 + row * 6.2
		var x := -10.0
		var segs: Array = []
		while x < 9.0:
			var w := rng.randf_range(2.0, 6.0)
			segs.append(Vector2(x, minf(x + w, 10.0)))
			x += w + rng.randf_range(1.5, 3.0)
		_lines.append({"y": y, "segs": segs})


func _ready() -> void:
	_writing = Writing.new()
	_writing.tablet = self
	add_child(_writing)
	_light = FX.make_light(aura, 120.0, 0.0)
	_light.position = Vector2(0, -30)
	add_child(_light)


func set_active(active: bool) -> void:
	target = 1.0 if active else 0.0


func _process(delta: float) -> void:
	if glow != target:
		glow = move_toward(glow, target, delta * 2.5)
		_light.energy = glow * 0.8
		_writing.queue_redraw()


func _draw() -> void:
	var w := 34.0
	var h := 60.0
	# pedestal
	draw_rect(Rect2(-w * 0.7, -6, w * 1.4, 6), STONE_DARK)
	# corpo com topo arredondado
	var pts := PackedVector2Array([Vector2(-w * 0.5, -6), Vector2(w * 0.5, -6), Vector2(w * 0.5, -h + w * 0.5)])
	for i in range(1, 12):
		var a := float(i) / 12.0 * PI
		pts.append(Vector2(cos(a) * w * 0.5, -h + w * 0.5 - sin(a) * w * 0.5))
	pts.append(Vector2(-w * 0.5, -h + w * 0.5))
	draw_colored_polygon(pts, STONE)
	draw_rect(Rect2(w * 0.18, -h + w * 0.5, w * 0.32, h - w * 0.5 - 6), STONE_DARK.lerp(STONE, 0.45))
	draw_polyline(pts + PackedVector2Array([pts[0]]), STONE_DARK, 1.5, true)
	# hexágono gravado no topo
	var hex := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 6.0
		hex.append(Vector2(0, -h + 13) + Vector2(cos(a), sin(a)) * 5.0)
	draw_polyline(hex, CARVE, 1.4, true)
	for line in _lines:
		for seg in line["segs"]:
			draw_line(Vector2(seg.x, line["y"]), Vector2(seg.y, line["y"]), CARVE, 1.6)


## Escrita que acende (aditiva).
class Writing extends Node2D:
	var tablet: Tablet

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		if tablet.glow <= 0.01:
			return
		var c := Color(tablet.aura, tablet.glow * 0.9)
		for line in tablet._lines:
			for seg in line["segs"]:
				draw_line(Vector2(seg.x, line["y"]), Vector2(seg.y, line["y"]), c, 1.6)
		var hex := PackedVector2Array()
		for i in 7:
			var a := -PI / 2.0 + i * TAU / 6.0
			hex.append(Vector2(0, -47) + Vector2(cos(a), sin(a)) * 5.0)
		draw_polyline(hex, c, 1.4, true)
