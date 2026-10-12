class_name TerrainView
extends Node2D
## Rocha da sala. Desenha os tiles sólidos com cantos arredondados e um shader
## que escurece a pedra conforme a distância da borda (fica claro onde a Vela
## anda, escuro no fundo da rocha). Os detalhes (bordas, espinhos, plataformas)
## ficam no filho TerrainDetail, sem shader.

const CORNER := 9.0
const FILLET := 7.0

var grid: LevelGrid
var palette: Dictionary


func build(g: LevelGrid, pal: Dictionary, seed_value: int) -> void:
	grid = g
	palette = pal
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("dist_tex", _distance_texture())
	mat.set_shader_parameter("room_px", g.pixel_size())
	mat.set_shader_parameter("edge_color", pal["stone_edge"])
	mat.set_shader_parameter("mid_color", pal["stone_mid"])
	mat.set_shader_parameter("deep_color", pal["stone_deep"])
	mat.set_shader_parameter("offset", Vector2(seed_value * 137 % 4096, seed_value * 71 % 4096))
	material = mat
	var detail := TerrainDetail.new()
	detail.name = "Detail"
	add_child(detail)
	detail.build(g, pal, seed_value)
	queue_redraw()


## Distância (em tiles) de cada célula sólida até o vazio mais próximo, 1 px por tile.
func _distance_texture() -> ImageTexture:
	var w := grid.width
	var h := grid.height
	var dist := PackedInt32Array()
	dist.resize(w * h)
	var queue: Array[Vector2i] = []
	for r in h:
		for c in w:
			if grid.is_rock(c, r):
				dist[r * w + c] = 999
			else:
				dist[r * w + c] = 0
				queue.append(Vector2i(c, r))
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := dist[p.y * w + p.x]
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + o
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if dist[q.y * w + q.x] > d + 1:
				dist[q.y * w + q.x] = d + 1
				queue.append(q)
	var img := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for r in h:
		for c in w:
			var d := mini(dist[r * w + c], 8)
			img.set_pixel(c, r, Color(d / 8.0, d / 8.0, d / 8.0))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	var ts := float(grid.tile_size)
	for r in grid.height:
		var c := 0
		while c < grid.width:
			if not grid.is_rock(c, r):
				c += 1
				continue
			if has_convex(c, r):
				draw_colored_polygon(tile_polygon(c, r), Color.WHITE)
				c += 1
				continue
			var c0 := c
			while c < grid.width and grid.is_rock(c, r) and not has_convex(c, r):
				c += 1
			draw_rect(Rect2(c0 * ts, r * ts, (c - c0) * ts, ts), Color.WHITE)
	# filetes nos cantos côncavos (a rocha "escorre" para dentro do vão)
	for r in grid.height:
		for c in grid.width:
			if grid.is_rock(c, r):
				continue
			var x0 := c * ts
			var y0 := r * ts
			var x1 := x0 + ts
			var y1 := y0 + ts
			if grid.is_rock(c - 1, r) and grid.is_rock(c, r - 1):
				draw_colored_polygon(_fillet(Vector2(x0, y0), Vector2(1, 1)), Color.WHITE)
			if grid.is_rock(c + 1, r) and grid.is_rock(c, r - 1):
				draw_colored_polygon(_fillet(Vector2(x1, y0), Vector2(-1, 1)), Color.WHITE)
			if grid.is_rock(c + 1, r) and grid.is_rock(c, r + 1):
				draw_colored_polygon(_fillet(Vector2(x1, y1), Vector2(-1, -1)), Color.WHITE)
			if grid.is_rock(c - 1, r) and grid.is_rock(c, r + 1):
				draw_colored_polygon(_fillet(Vector2(x0, y1), Vector2(1, -1)), Color.WHITE)


# ---------------------------------------------------------------------------
# Geometria dos cantos (também usada pelo TerrainDetail)
# ---------------------------------------------------------------------------

func corner_tl(c: int, r: int) -> bool:
	return not grid.is_rock(c - 1, r) and not grid.is_rock(c, r - 1)


func corner_tr(c: int, r: int) -> bool:
	return not grid.is_rock(c + 1, r) and not grid.is_rock(c, r - 1)


func corner_br(c: int, r: int) -> bool:
	return not grid.is_rock(c + 1, r) and not grid.is_rock(c, r + 1)


func corner_bl(c: int, r: int) -> bool:
	return not grid.is_rock(c - 1, r) and not grid.is_rock(c, r + 1)


func has_convex(c: int, r: int) -> bool:
	return corner_tl(c, r) or corner_tr(c, r) or corner_br(c, r) or corner_bl(c, r)


## Polígono do tile no sentido horário, com os cantos convexos arredondados.
func tile_polygon(c: int, r: int) -> PackedVector2Array:
	var ts := float(grid.tile_size)
	var x0 := c * ts
	var y0 := r * ts
	var x1 := x0 + ts
	var y1 := y0 + ts
	var pts := PackedVector2Array()
	_corner(pts, Vector2(x0, y0), Vector2(x0 + CORNER, y0 + CORNER), PI, corner_tl(c, r))
	_corner(pts, Vector2(x1, y0), Vector2(x1 - CORNER, y0 + CORNER), PI * 1.5, corner_tr(c, r))
	_corner(pts, Vector2(x1, y1), Vector2(x1 - CORNER, y1 - CORNER), 0.0, corner_br(c, r))
	_corner(pts, Vector2(x0, y1), Vector2(x0 + CORNER, y1 - CORNER), PI * 0.5, corner_bl(c, r))
	return pts


func _corner(pts: PackedVector2Array, sharp: Vector2, center: Vector2, a0: float, rounded: bool) -> void:
	if not rounded:
		pts.append(sharp)
		return
	var steps := 5
	for i in range(steps + 1):
		var a := a0 + (PI * 0.5) * float(i) / steps
		pts.append(center + Vector2(cos(a), sin(a)) * CORNER)


func _fillet(p: Vector2, inward: Vector2) -> PackedVector2Array:
	# canto côncavo em p; inward aponta para dentro do vão
	var pts := PackedVector2Array([p, p + Vector2(FILLET * inward.x, 0)])
	var center := p + inward * FILLET
	var steps := 5
	var start := atan2(-inward.y, 0.0)
	var end := atan2(0.0, -inward.x)
	# do ponto no lado horizontal até o ponto no lado vertical, pela parte de perto de p
	for i in range(1, steps):
		var t := float(i) / steps
		var a := lerp_angle(start, end, t)
		pts.append(center + Vector2(cos(a), sin(a)) * FILLET)
	pts.append(p + Vector2(0, FILLET * inward.y))
	return pts
