class_name LevelGrid
extends RefCounted
## Grade de colisão de uma sala.
##
## Toda a física de plataforma do jogo passa por aqui: movimento por eixo contra
## tiles sólidos, plataformas de mão única e espinhos. Não depende da árvore de
## cenas, então os testes conseguem usar sem abrir o jogo.
##
## Legenda do mapa ASCII (ver levels/README.md):
##   #  sólido          =  plataforma de mão única
##   ^ v < >  espinhos (a ponta aponta nessa direção)
##   ~  véu de aura (sólido, menos para quem está em Zetsu)
##   *  casca de aura (sólida; o Ren quebra)
##   0-9  célula de porta (vazia; liga com outra sala)
##   .  vazio           qualquer outra letra = marcador de objeto (vela, estela...)

enum Tile { EMPTY, SOLID, ONE_WAY, SPIKE, VEIL, SHELL }
enum SpikeDir { UP, DOWN, LEFT, RIGHT }

const EPS := 0.001

var tile_size: int = 32
var width: int = 0
var height: int = 0
var cells := PackedByteArray()
var spike_dirs := PackedByteArray()
## Vector2i -> String (id da porta)
var door_cells: Dictionary = {}
## [{"ch": String, "cell": Vector2i}]
var markers: Array[Dictionary] = []
## Véus abertos para quem está se movendo agora (a Vela liga durante o Zetsu).
var veil_open := false


static func from_rows(rows: PackedStringArray, ts: int = 32) -> LevelGrid:
	var g := LevelGrid.new()
	g.tile_size = ts
	g.height = rows.size()
	for row in rows:
		g.width = maxi(g.width, row.length())
	g.cells.resize(g.width * g.height)
	g.spike_dirs.resize(g.width * g.height)
	for r in g.height:
		var row: String = rows[r]
		for c in g.width:
			var ch := row[c] if c < row.length() else "."
			var tile := Tile.EMPTY
			var dir := SpikeDir.UP
			match ch:
				"#":
					tile = Tile.SOLID
				"=":
					tile = Tile.ONE_WAY
				"^":
					tile = Tile.SPIKE
				"v":
					tile = Tile.SPIKE
					dir = SpikeDir.DOWN
				"<":
					tile = Tile.SPIKE
					dir = SpikeDir.LEFT
				">":
					tile = Tile.SPIKE
					dir = SpikeDir.RIGHT
				"~":
					tile = Tile.VEIL
				"*":
					tile = Tile.SHELL
				".", " ":
					pass
				_:
					if ch >= "0" and ch <= "9":
						g.door_cells[Vector2i(c, r)] = ch
					else:
						g.markers.append({"ch": ch, "cell": Vector2i(c, r)})
			g.cells[r * g.width + c] = tile
			g.spike_dirs[r * g.width + c] = dir
	return g


func pixel_size() -> Vector2:
	return Vector2(width * tile_size, height * tile_size)


## Fora da sala tudo é sólido, menos a continuação das portas.
func get_cell(c: int, r: int) -> int:
	if c >= 0 and r >= 0 and c < width and r < height:
		return cells[r * width + c]
	var key := Vector2i(clampi(c, 0, width - 1), clampi(r, 0, height - 1))
	if door_cells.has(key):
		return Tile.EMPTY
	return Tile.SOLID


## Bloqueia o movimento: rocha, casca de aura e véu fechado.
func is_solid(c: int, r: int) -> bool:
	return _tile_blocks(get_cell(c, r))


## Só a rocha (o desenho do terreno e o "chão seguro" usam isto).
func is_rock(c: int, r: int) -> bool:
	return get_cell(c, r) == Tile.SOLID


func _tile_blocks(t: int) -> bool:
	return t == Tile.SOLID or t == Tile.SHELL or (t == Tile.VEIL and not veil_open)


## Parede de verdade para deslizar e para o golpe faiscar (rocha ou casca, nunca véu).
func is_wall(c: int, r: int) -> bool:
	var t := get_cell(c, r)
	return t == Tile.SOLID or t == Tile.SHELL


func set_cell(c: int, r: int, t: int) -> void:
	if c >= 0 and r >= 0 and c < width and r < height:
		cells[r * width + c] = t


func spike_dir(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= width or r >= height:
		return SpikeDir.UP
	return spike_dirs[r * width + c]


# ---------------------------------------------------------------------------
# Movimento por eixo. Cada função move o corpo o máximo possível sem entrar em
# sólido e devolve true se bateu em algo. Varre todas as colunas/linhas do
# caminho, então não existe "atravessar parede" em alta velocidade.
# ---------------------------------------------------------------------------

func move_x(b: GridBody, dx: float) -> bool:
	if dx == 0.0:
		return false
	var ts := float(tile_size)
	var x := b.pos.x
	var w := b.size.x
	var r0 := floori(b.pos.y / ts)
	var r1 := floori((b.pos.y + b.size.y - EPS) / ts)
	if dx > 0.0:
		var c0 := floori((x + w) / ts)
		var c1 := floori((x + w + dx - EPS) / ts)
		for c in range(c0, c1 + 1):
			for r in range(r0, r1 + 1):
				if is_solid(c, r):
					b.pos.x = c * ts - w
					return true
	else:
		var c0 := floori((x - EPS) / ts)
		var c1 := floori((x + dx) / ts)
		for c in range(c0, c1 - 1, -1):
			for r in range(r0, r1 + 1):
				if is_solid(c, r):
					b.pos.x = (c + 1) * ts
					return true
	b.pos.x = x + dx
	return false


func move_y(b: GridBody, dy: float, drop_through: bool = false) -> bool:
	if dy == 0.0:
		return false
	var ts := float(tile_size)
	var y := b.pos.y
	var h := b.size.y
	var c0 := floori(b.pos.x / ts)
	var c1 := floori((b.pos.x + b.size.x - EPS) / ts)
	if dy > 0.0:
		var bottom := y + h
		var r0 := floori(bottom / ts)
		var r1 := floori((bottom + dy - EPS) / ts)
		for r in range(r0, r1 + 1):
			var top := r * ts
			for c in range(c0, c1 + 1):
				var t := get_cell(c, r)
				if _tile_blocks(t) or (t == Tile.ONE_WAY and not drop_through and top >= bottom - EPS):
					b.pos.y = top - h
					return true
	else:
		var r0 := floori((y - EPS) / ts)
		var r1 := floori((y + dy) / ts)
		for r in range(r0, r1 - 1, -1):
			for c in range(c0, c1 + 1):
				if is_solid(c, r):
					b.pos.y = (r + 1) * ts
					return true
	b.pos.y = y + dy
	return false


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func overlaps_solid(p: Vector2, s: Vector2) -> bool:
	var ts := float(tile_size)
	for r in range(floori(p.y / ts), floori((p.y + s.y - EPS) / ts) + 1):
		for c in range(floori(p.x / ts), floori((p.x + s.x - EPS) / ts) + 1):
			if is_solid(c, r):
				return true
	return false


## Encostado no chão (sólido ou mão única) com tolerância de meio pixel.
func is_grounded(b: GridBody, ignore_one_way: bool = false) -> bool:
	var ts := float(tile_size)
	var bottom := b.pos.y + b.size.y
	var r := floori((bottom + 0.5) / ts)
	if absf(r * ts - bottom) > 0.5:
		return false
	for c in range(floori(b.pos.x / ts), floori((b.pos.x + b.size.x - EPS) / ts) + 1):
		var t := get_cell(c, r)
		if _tile_blocks(t) or (t == Tile.ONE_WAY and not ignore_one_way):
			return true
	return false


## Em pé só sobre plataformas de mão única (dá para descer com baixo + pulo).
func standing_only_on_one_way(b: GridBody) -> bool:
	var ts := float(tile_size)
	var r := floori((b.pos.y + b.size.y + 0.5) / ts)
	var any_one_way := false
	for c in range(floori(b.pos.x / ts), floori((b.pos.x + b.size.x - EPS) / ts) + 1):
		var t := get_cell(c, r)
		if _tile_blocks(t):
			return false
		if t == Tile.ONE_WAY:
			any_one_way = true
	return any_one_way


## Rocha de verdade debaixo dos dois pés (para o "último chão seguro").
## Casca e véu não contam: podem sumir debaixo da Vela.
func fully_on_solid(b: GridBody) -> bool:
	var ts := float(tile_size)
	var r := floori((b.pos.y + b.size.y + 0.5) / ts)
	return is_rock(floori(b.pos.x / ts), r) and is_rock(floori((b.pos.x + b.size.x - EPS) / ts), r)


## Parede encostada do lado `dir` cobrindo o meio do corpo (véu não conta).
func touches_wall(b: GridBody, dir: int) -> bool:
	var ts := float(tile_size)
	var edge := b.pos.x + b.size.x if dir > 0 else b.pos.x
	var c := floori((edge + 0.5) / ts) if dir > 0 else floori((edge - 0.5) / ts)
	var boundary := c * ts if dir > 0 else (c + 1) * ts
	if absf(boundary - edge) > 0.6:
		return false
	for r in range(floori((b.pos.y + 4.0) / ts), floori((b.pos.y + b.size.y * 0.7) / ts) + 1):
		if is_wall(c, r):
			return true
	return false


## Retângulo encostado em rocha ou casca (o golpe faísca; véu não).
func overlaps_wall(p: Vector2, s: Vector2) -> bool:
	var ts := float(tile_size)
	for r in range(floori(p.y / ts), floori((p.y + s.y - EPS) / ts) + 1):
		for c in range(floori(p.x / ts), floori((p.x + s.x - EPS) / ts) + 1):
			if is_wall(c, r):
				return true
	return false


func overlaps_tile(p: Vector2, s: Vector2, tile: int) -> bool:
	var ts := float(tile_size)
	for r in range(floori(p.y / ts), floori((p.y + s.y - EPS) / ts) + 1):
		for c in range(floori(p.x / ts), floori((p.x + s.x - EPS) / ts) + 1):
			if c >= 0 and r >= 0 and c < width and r < height and cells[r * width + c] == tile:
				return true
	return false


func overlaps_veil(p: Vector2, s: Vector2) -> bool:
	return overlaps_tile(p, s, Tile.VEIL)


## Quebra as cascas de aura alcançadas pela explosão do Ren: toda casca
## encostada no círculo racha, e a rachadura corre pelas cascas vizinhas.
## Devolve as células quebradas.
func break_shells(center: Vector2, radius: float) -> Array[Vector2i]:
	var ts := float(tile_size)
	var out: Array[Vector2i] = []
	var queue: Array[Vector2i] = []
	var c0 := floori((center.x - radius) / ts)
	var c1 := floori((center.x + radius) / ts)
	var r0 := floori((center.y - radius) / ts)
	var r1 := floori((center.y + radius) / ts)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if c < 0 or r < 0 or c >= width or r >= height or cells[r * width + c] != Tile.SHELL:
				continue
			var nearest := Vector2(clampf(center.x, c * ts, (c + 1) * ts), clampf(center.y, r * ts, (r + 1) * ts))
			if nearest.distance_to(center) <= radius:
				queue.append(Vector2i(c, r))
	while not queue.is_empty():
		var k: Vector2i = queue.pop_back()
		if k.x < 0 or k.y < 0 or k.x >= width or k.y >= height or cells[k.y * width + k.x] != Tile.SHELL:
			continue
		cells[k.y * width + k.x] = Tile.EMPTY
		out.append(k)
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			queue.append(k + o)
	return out


## Todas as células de um tipo (para desenhar véus e cascas).
func cells_of(tile: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in height:
		for c in width:
			if cells[r * width + c] == tile:
				out.append(Vector2i(c, r))
	return out


## Linha de visão entre dois pontos (véu fechado e casca bloqueiam; amostras a cada 10 px).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var ts := float(tile_size)
	var d := b - a
	var n := maxi(1, ceili(d.length() / 10.0))
	for i in range(1, n):
		var p := a + d * (float(i) / n)
		if is_solid(floori(p.x / ts), floori(p.y / ts)):
			return false
	return true


func spike_rect(c: int, r: int) -> Rect2:
	var ts := float(tile_size)
	var o := Vector2(c * ts, r * ts)
	match spike_dir(c, r):
		SpikeDir.DOWN:
			return Rect2(o + Vector2(3, 0), Vector2(ts - 6, ts * 0.55))
		SpikeDir.LEFT:
			return Rect2(o + Vector2(ts * 0.45, 3), Vector2(ts * 0.55, ts - 6))
		SpikeDir.RIGHT:
			return Rect2(o + Vector2(0, 3), Vector2(ts * 0.55, ts - 6))
	return Rect2(o + Vector2(3, ts * 0.45), Vector2(ts - 6, ts * 0.55))


func spike_hit(rect: Rect2) -> bool:
	var ts := float(tile_size)
	for r in range(floori(rect.position.y / ts), floori((rect.end.y - EPS) / ts) + 1):
		for c in range(floori(rect.position.x / ts), floori((rect.end.x - EPS) / ts) + 1):
			if get_cell(c, r) == Tile.SPIKE and spike_rect(c, r).intersects(rect):
				return true
	return false


## Espinho dentro do golpe para baixo: vale como pogo.
func spike_in(rect: Rect2) -> bool:
	var ts := float(tile_size)
	for r in range(floori(rect.position.y / ts), floori((rect.end.y - EPS) / ts) + 1):
		for c in range(floori(rect.position.x / ts), floori((rect.end.x - EPS) / ts) + 1):
			if get_cell(c, r) == Tile.SPIKE:
				return true
	return false


func spike_near(b: GridBody, margin: float) -> bool:
	return spike_in(Rect2(b.pos - Vector2(margin, margin * 0.5), b.size + Vector2(margin * 2.0, margin)))


## Primeira linha sólida acima de (c, r), ou -1 se não achar em `max_up` tiles.
func ceiling_above(c: int, r: int, max_up: int) -> int:
	for k in range(1, max_up + 1):
		if r - k < 0:
			return -1
		if get_cell(c, r - k) == Tile.SOLID:
			return r - k
	return -1


# ---------------------------------------------------------------------------
# Portas
# ---------------------------------------------------------------------------

func door_cells_of(id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: Vector2i in door_cells:
		if door_cells[k] == id:
			out.append(k)
	return out


## Lado da sala em que a porta fica: "left", "right", "top" ou "bottom".
func door_side(id: String) -> String:
	for k in door_cells_of(id):
		if k.x == 0:
			return "left"
		if k.x == width - 1:
			return "right"
		if k.y == height - 1:
			return "bottom"
		if k.y == 0:
			return "top"
	return ""


## Porta tocada por um retângulo que está saindo da sala.
func door_touching(rect: Rect2) -> String:
	var ts := float(tile_size)
	var c0 := clampi(floori(rect.position.x / ts), 0, width - 1)
	var c1 := clampi(floori((rect.end.x - EPS) / ts), 0, width - 1)
	var r0 := clampi(floori(rect.position.y / ts), 0, height - 1)
	var r1 := clampi(floori((rect.end.y - EPS) / ts), 0, height - 1)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var k := Vector2i(c, r)
			if door_cells.has(k):
				return door_cells[k]
	return ""
