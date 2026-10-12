class_name VeilView
extends Node2D
## Véus de aura: cortinas de fios de luz que os monges deixaram nas passagens.
## Para quem tem a chama acesa são parede; no Zetsu, a Vela atravessa e os fios
## se abrem em volta dela (aditivo, sem sombra).

const COLOR := Color("d8c8ff")
const STRANDS_PER_CELL := 5

var grid: LevelGrid
var player: Player
var _cells: Array[Vector2i] = []
var _phase: Dictionary = {}
var _t := 0.0
var _part := 0.0
var _light: PointLight2D


func setup(g: LevelGrid, seed_value: int) -> void:
	grid = g
	_cells = g.cells_of(LevelGrid.Tile.VEIL)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + 5
	for k in _cells:
		_phase[k] = rng.randf() * TAU


func _ready() -> void:
	material = FX.additive()
	light_mask = 0
	z_index = 2
	if _cells.is_empty():
		return
	# uma luz fraca no meio do véu
	var sum := Vector2.ZERO
	for k in _cells:
		sum += Vector2(k) + Vector2(0.5, 0.5)
	_light = FX.make_light(COLOR, 180.0, 0.45)
	_light.position = sum / _cells.size() * float(grid.tile_size)
	add_child(_light)


func has_veils() -> bool:
	return not _cells.is_empty()


func _process(delta: float) -> void:
	if _cells.is_empty():
		return
	_t += delta
	var inside := player != null and is_instance_valid(player) and grid.overlaps_veil(player.body.pos - Vector2(10, 0), player.body.size + Vector2(20, 0))
	_part = move_toward(_part, 1.0 if inside else 0.0, delta * 4.0)
	if _light:
		_light.energy = 0.4 + 0.08 * sin(_t * 2.1) + 0.25 * _part
	queue_redraw()


func _draw() -> void:
	var ts := float(grid.tile_size)
	var pc := Vector2(-9999, -9999)
	if player != null and is_instance_valid(player):
		pc = player.body.center()
	for k in _cells:
		var x0 := k.x * ts
		var y0 := k.y * ts
		var ph: float = _phase[k]
		# névoa de fundo
		draw_rect(Rect2(x0, y0, ts, ts), Color(COLOR, 0.045 + 0.015 * sin(_t * 1.3 + ph)))
		var top_cell := grid.get_cell(k.x, k.y - 1) != LevelGrid.Tile.VEIL
		var bottom_cell := grid.get_cell(k.x, k.y + 1) != LevelGrid.Tile.VEIL
		for i in STRANDS_PER_CELL:
			var sx := x0 + (i + 0.5) * ts / STRANDS_PER_CELL
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for j in 7:
				var y := y0 + ts * j / 6.0
				var wob := sin(_t * 1.6 + y * 0.045 + ph + i * 1.3) * 2.2
				var x := sx + wob
				# os fios se abrem em volta da Vela
				var d := Vector2(x, y) - pc
				if absf(d.y) < 46.0 and absf(d.x) < 34.0:
					var push := (1.0 - absf(d.y) / 46.0) * (34.0 - absf(d.x)) * 0.8 * _part
					x += signf(d.x if d.x != 0.0 else 1.0) * push
				pts.append(Vector2(x, y))
				var a := 0.2 + 0.1 * sin(_t * 2.3 + ph * 2.0 + i + j * 0.7)
				if top_cell and j == 0:
					a *= 0.2
				if bottom_cell and j == 6:
					a *= 0.6
				cols.append(Color(COLOR, a))
			draw_polyline_colors(pts, cols, 1.1, true)
		# contas de luz descendo pelos fios
		var bead_y := fmod(_t * 18.0 + ph * 10.0, ts)
		draw_circle(Vector2(x0 + ts * 0.3 + sin(_t + ph) * 2.0, y0 + bead_y), 1.6, Color(COLOR, 0.45))
