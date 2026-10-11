class_name TerrainDetail
extends Node2D
## Detalhes do terreno sem shader: bordas iluminadas e irregulares, sombra
## ambiente nos cantos, gotejos no teto, plataformas de madeira e espinhos.

var grid: LevelGrid
var palette: Dictionary
var rng := RandomNumberGenerator.new()
var base_seed := 0
var terrain: TerrainView


func build(g: LevelGrid, pal: Dictionary, seed_value: int) -> void:
	grid = g
	palette = pal
	base_seed = seed_value
	terrain = get_parent() as TerrainView
	queue_redraw()


func _jitter(x: float, y: float) -> float:
	return sin(x * 0.13 + y * 0.7 + base_seed) * 0.7 + sin(x * 0.051 + base_seed * 1.7) * 0.6


func _draw() -> void:
	rng.seed = base_seed * 31 + 7
	_draw_ambient_occlusion()
	_draw_ceilings()
	_draw_sides()
	_draw_tops()
	_draw_one_way()
	_draw_spikes()


# ---------------------------------------------------------------------------

func _draw_ambient_occlusion() -> void:
	var ts := float(grid.tile_size)
	var shadow := Color(0, 0, 0, 0.42)
	var clear := Color(0, 0, 0, 0)
	for r in grid.height:
		for c in grid.width:
			if grid.is_solid(c, r):
				continue
			var x0 := c * ts
			var y0 := r * ts
			# sombra embaixo do teto
			if grid.is_solid(c, r - 1):
				draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + ts, y0), Vector2(x0 + ts, y0 + 14), Vector2(x0, y0 + 14)]),
					PackedColorArray([shadow, shadow, clear, clear]))
			# sombra ao lado das paredes
			if grid.is_solid(c - 1, r):
				draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + 10, y0), Vector2(x0 + 10, y0 + ts), Vector2(x0, y0 + ts)]),
					PackedColorArray([Color(0, 0, 0, 0.3), clear, clear, Color(0, 0, 0, 0.3)]))
			if grid.is_solid(c + 1, r):
				draw_polygon(PackedVector2Array([Vector2(x0 + ts - 10, y0), Vector2(x0 + ts, y0), Vector2(x0 + ts, y0 + ts), Vector2(x0 + ts - 10, y0 + ts)]),
					PackedColorArray([clear, Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), clear]))


func _draw_tops() -> void:
	var ts := float(grid.tile_size)
	var rim: Color = palette["rim"]
	var hi: Color = palette["rim_hi"]
	var moss: Color = palette["moss"]
	for r in grid.height:
		var c := 0
		while c < grid.width:
			if not (grid.is_solid(c, r) and not grid.is_solid(c, r - 1)):
				c += 1
				continue
			var c0 := c
			while c < grid.width and grid.is_solid(c, r) and not grid.is_solid(c, r - 1):
				c += 1
			var c1 := c - 1
			var y := r * ts
			var pts := PackedVector2Array()
			var x_start := c0 * ts
			var x_end := (c1 + 1) * ts
			if terrain.corner_tl(c0, r):
				for i in range(2, 6):
					var a := PI + PI * 0.5 * i / 5.0
					pts.append(Vector2(x_start + TerrainView.CORNER, y + TerrainView.CORNER) + Vector2(cos(a), sin(a)) * (TerrainView.CORNER - 1.0))
				x_start += TerrainView.CORNER
			if terrain.corner_tr(c1, r):
				x_end -= TerrainView.CORNER
			var x := x_start
			while x < x_end:
				pts.append(Vector2(x, y + 1.2 + _jitter(x, y) * 0.8))
				x += 5.0
			pts.append(Vector2(x_end, y + 1.2 + _jitter(x_end, y) * 0.8))
			if terrain.corner_tr(c1, r):
				for i in range(0, 4):
					var a := PI * 1.5 + PI * 0.5 * i / 5.0
					pts.append(Vector2(x_end, y + TerrainView.CORNER) + Vector2(cos(a), sin(a)) * (TerrainView.CORNER - 1.0))
			if pts.size() >= 2:
				draw_polyline(pts, rim, 3.0, true)
				var hi_pts := PackedVector2Array()
				for p in pts:
					hi_pts.append(p + Vector2(0, -0.9))
				draw_polyline(hi_pts, Color(hi, 0.5), 1.1, true)
			# pedrinhas e musgo seco
			for cc in range(c0, c1 + 1):
				if rng.randf() < 0.32:
					var px := cc * ts + rng.randf_range(4, ts - 4)
					draw_circle(Vector2(px, y - 1.0), rng.randf_range(1.0, 2.4), rim.darkened(0.25), true, -1.0, true)
				if rng.randf() < 0.2:
					var mx := cc * ts + rng.randf_range(6, ts - 6)
					for k in 4:
						var ang := deg_to_rad(rng.randf_range(-130, -50))
						var l := rng.randf_range(3, 7)
						draw_line(Vector2(mx + k * 1.6, y), Vector2(mx + k * 1.6, y) + Vector2(cos(ang), sin(ang)) * l, Color(moss, 0.9), 1.0, true)


func _draw_sides() -> void:
	var ts := float(grid.tile_size)
	var side: Color = palette["side"]
	for c in grid.width:
		for dir in [-1, 1]:
			var r := 0
			while r < grid.height:
				if not (grid.is_solid(c, r) and not grid.is_solid(c + dir, r)):
					r += 1
					continue
				var r0 := r
				while r < grid.height and grid.is_solid(c, r) and not grid.is_solid(c + dir, r):
					r += 1
				var r1 := r - 1
				var x := c * ts + (ts - 1.2 if dir > 0 else 1.2)
				var y0 := r0 * ts
				var y1 := (r1 + 1) * ts
				var top_round := terrain.corner_tr(c, r0) if dir > 0 else terrain.corner_tl(c, r0)
				var bottom_round := terrain.corner_br(c, r1) if dir > 0 else terrain.corner_bl(c, r1)
				if top_round:
					y0 += TerrainView.CORNER
				if bottom_round:
					y1 -= TerrainView.CORNER
				if y1 <= y0:
					continue
				var pts := PackedVector2Array()
				var y := y0
				while y < y1:
					pts.append(Vector2(x + _jitter(y, x) * 0.5, y))
					y += 6.0
				pts.append(Vector2(x, y1))
				var a := 0.55 if dir < 0 else 0.32
				draw_polyline(pts, Color(side, a), 1.6, true)


func _draw_ceilings() -> void:
	var ts := float(grid.tile_size)
	var col: Color = palette["stone_mid"]
	for r in grid.height:
		for c in grid.width:
			if not (grid.is_solid(c, r) and not grid.is_solid(c, r + 1)):
				continue
			var y := (r + 1) * ts
			var n := rng.randi_range(0, 3)
			for k in n:
				var x := c * ts + rng.randf_range(5, ts - 5)
				if (terrain.corner_bl(c, r) and x < c * ts + TerrainView.CORNER) or (terrain.corner_br(c, r) and x > c * ts + ts - TerrainView.CORNER):
					continue
				var w := rng.randf_range(2.0, 5.0)
				var l := rng.randf_range(4.0, 15.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - w, y - 1), Vector2(x + w, y - 1), Vector2(x + rng.randf_range(-1, 1), y + l)]), col)


func _draw_one_way() -> void:
	var ts := float(grid.tile_size)
	var wood: Color = palette["wood"]
	var hi: Color = palette["wood_hi"]
	var dark: Color = palette["wood_dark"]
	var metal: Color = palette["metal"]
	for r in grid.height:
		var c := 0
		while c < grid.width:
			if grid.get_cell(c, r) != LevelGrid.Tile.ONE_WAY:
				c += 1
				continue
			var c0 := c
			while c < grid.width and grid.get_cell(c, r) == LevelGrid.Tile.ONE_WAY:
				c += 1
			var x0 := c0 * ts
			var x1 := c * ts
			var y := r * ts
			# sombra embaixo da viga
			draw_polygon(PackedVector2Array([Vector2(x0, y + 10), Vector2(x1, y + 10), Vector2(x1, y + 22), Vector2(x0, y + 22)]),
				PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
			draw_rect(Rect2(x0, y, x1 - x0, 10), wood)
			draw_rect(Rect2(x0, y + 7, x1 - x0, 3), dark)
			draw_line(Vector2(x0, y + 0.8), Vector2(x1, y + 0.8), hi, 1.6, true)
			# emendas das tábuas
			var x := x0 + ts
			while x < x1 - 1:
				draw_line(Vector2(x, y + 1), Vector2(x, y + 9), dark, 1.4)
				x += ts
			# braçadeiras de metal nas pontas
			for ex in [x0 + 5, x1 - 9]:
				draw_rect(Rect2(ex, y - 1, 4, 12), metal)
			# mãos-francesas se houver parede ao lado
			if grid.is_solid(c0 - 1, r):
				draw_line(Vector2(x0, y + 26), Vector2(x0 + 18, y + 10), wood.darkened(0.2), 4.0, true)
			if grid.is_solid(c, r):
				draw_line(Vector2(x1, y + 26), Vector2(x1 - 18, y + 10), wood.darkened(0.2), 4.0, true)


func _draw_spikes() -> void:
	var ts := float(grid.tile_size)
	var base: Color = palette["spike_base"]
	var tip: Color = palette["spike_tip"]
	for r in grid.height:
		for c in grid.width:
			if grid.get_cell(c, r) != LevelGrid.Tile.SPIKE:
				continue
			var dir := grid.spike_dir(c, r)
			var o := Vector2(c * ts, r * ts)
			for k in 3:
				var along := (k + 0.5) / 3.0 * ts + rng.randf_range(-1.5, 1.5)
				var half := rng.randf_range(4.5, 6.0)
				var spike_len := rng.randf_range(ts * 0.5, ts * 0.72)
				var b0: Vector2
				var b1: Vector2
				var t: Vector2
				match dir:
					LevelGrid.SpikeDir.DOWN:
						b0 = o + Vector2(along - half, 0)
						b1 = o + Vector2(along + half, 0)
						t = o + Vector2(along, spike_len)
					LevelGrid.SpikeDir.LEFT:
						b0 = o + Vector2(ts, along - half)
						b1 = o + Vector2(ts, along + half)
						t = o + Vector2(ts - spike_len, along)
					LevelGrid.SpikeDir.RIGHT:
						b0 = o + Vector2(0, along - half)
						b1 = o + Vector2(0, along + half)
						t = o + Vector2(spike_len, along)
					_:
						b0 = o + Vector2(along - half, ts)
						b1 = o + Vector2(along + half, ts)
						t = o + Vector2(along, ts - spike_len)
				draw_polygon(PackedVector2Array([b0, b1, t]), PackedColorArray([base, base.lerp(tip, 0.3), tip]))
