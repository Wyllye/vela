extends RefCounted
## Base dos testes: asserções simples e ajudantes para montar uma sala de teste.

const DT := 1.0 / 60.0

var _failures: Array[String] = []
var _nodes: Array[Node] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func check_range(value: float, lo: float, hi: float, msg: String) -> void:
	check(value >= lo and value <= hi, "%s: esperado entre %.1f e %.1f, veio %.2f" % [msg, lo, hi, value])


## Cria uma Vela em pé na célula indicada (pés no topo da linha de baixo).
func make_player(rows: Array, cell: Vector2i) -> Player:
	var grid := LevelGrid.from_rows(PackedStringArray(rows))
	var p := Player.new()
	p.input = ScriptedInput.new()
	var x := cell.x * 32.0 + (32.0 - p.body.size.x) * 0.5
	var y := (cell.y + 1) * 32.0 - p.body.size.y
	p.setup(grid, Vector2(x, y))
	_nodes.append(p)
	return p


func inp(p: Player) -> ScriptedInput:
	return p.input as ScriptedInput


func run(p: Player, frames: int) -> void:
	for i in frames:
		p.step(DT)


## Aperta uma ação por um tick e solta.
func tap(p: Player, action: StringName) -> void:
	inp(p).set_held(action, true)
	p.step(DT)
	inp(p).set_held(action, false)


func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
