class_name ShellView
extends Node2D
## Cascas de aura: aura cristalizada que lacra passagens. O golpe só tilinta
## nelas; a explosão do Ren racha a casca inteira de uma vez.

const AMBER := Color("e9c27e")
const AMBER_DEEP := Color("6e5126")
const AMBER_HI := Color("fff0c8")

var grid: LevelGrid
var _cells: Array[Vector2i] = []
var _shards: Dictionary = {}
var _t := 0.0
var _glow: Node2D
var _lights: Array[PointLight2D] = []


func setup(g: LevelGrid, seed_value: int) -> void:
	grid = g
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 9
	for k in g.cells_of(LevelGrid.Tile.SHELL):
		_shards[k] = _make_shards(rng)
	refresh()


func _ready() -> void:
	z_index = 1
	_glow = Glow.new()
	_glow.view = self
	add_child(_glow)
	refresh()


## Relê a grade (depois que o Ren quebrou alguma casca).
func refresh() -> void:
	if grid == null:
		return
	_cells = grid.cells_of(LevelGrid.Tile.SHELL)
	if not is_inside_tree():
		return
	for l in _lights:
		l.queue_free()
	_lights.clear()
	# uma luz por grupo de cascas (aproximação: a cada 3 células)
	for i in range(0, _cells.size(), 3):
		var l := FX.make_light(AMBER, 120.0, 0.35)
		l.position = (Vector2(_cells[i]) + Vector2(0.5, 0.5)) * float(grid.tile_size)
		add_child(l)
		_lights.append(l)
	queue_redraw()


## Cristais de uma célula: nascem de um ponto da célula em ângulos variados,
## passando um pouco das bordas para as células vizinhas virarem uma massa só.
func _make_shards(rng: RandomNumberGenerator) -> Array:
	var out := []
	for i in 5:
		var root := Vector2(rng.randf_range(4.0, 28.0), rng.randf_range(10.0, 30.0))
		var ang := rng.randf_range(-0.7, 0.7) + (PI if rng.randf() < 0.18 else 0.0)
		out.append({"root": root, "w": rng.randf_range(7.0, 12.0), "h": rng.randf_range(16.0, 30.0), "ang": ang})
	return out


func _process(delta: float) -> void:
	if _cells.is_empty():
		return
	_t += delta
	_glow.queue_redraw()


func _draw() -> void:
	var ts := float(grid.tile_size)
	# massa escura de aura cristalizada atrás dos cristais
	for k in _cells:
		var o := Vector2(k.x * ts, k.y * ts)
		draw_rect(Rect2(o + Vector2(-2, -2), Vector2(ts + 4, ts + 4)), Color(AMBER_DEEP, 0.42))
	for k in _cells:
		var o := Vector2(k.x * ts, k.y * ts)
		for sh in _shards.get(k, []):
			var base: Vector2 = o + sh["root"]
			var u := Vector2(sin(sh["ang"]), -cos(sh["ang"]))
			var n := Vector2(-u.y, u.x)
			var hw: float = sh["w"] * 0.5
			var h: float = sh["h"]
			var tip := base + u * h
			var pts := PackedVector2Array([base - n * hw, base + u * h * 0.55 - n * hw * 0.8, tip,
				base + u * h * 0.6 + n * hw * 0.8, base + n * hw])
			var cols := PackedColorArray([AMBER_DEEP, AMBER.darkened(0.15), AMBER_HI, AMBER, AMBER_DEEP.lerp(AMBER, 0.4)])
			draw_polygon(pts, cols)
			draw_line(base, tip, Color(AMBER_HI, 0.45), 1.0, true)


## Brilho interno da casca (aditivo).
class Glow extends Node2D:
	var view: ShellView

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		var ts := float(view.grid.tile_size)
		for k in view._cells:
			var c := (Vector2(k) + Vector2(0.5, 0.55)) * ts
			var pulse := 0.5 + 0.5 * sin(view._t * 1.7 + k.x * 0.9 + k.y * 1.3)
			draw_circle(c, 9.0 + 3.0 * pulse, Color(ShellView.AMBER, 0.08 + 0.05 * pulse))
			draw_circle(c, 3.0, Color(ShellView.AMBER_HI, 0.18 + 0.1 * pulse))
