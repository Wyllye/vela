class_name PlayerInput
extends RefCounted
## Leitura dos controles com detecção própria de borda (apertou/soltou).
##
## Os eventos chegam por `feed()` (chamado em _input), então um toque rápido
## entre dois ticks de física não se perde, e nada quebra durante o hit-stop.

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"dash", &"zetsu", &"ren", &"gyo"]
const AXIS_THRESHOLD := 0.35

var enabled := true
## Direção digital (-1, 0, 1) nos dois eixos; y positivo = baixo.
var move := Vector2.ZERO

var _held: Dictionary = {}
var _taps: Dictionary = {}
var _rels: Dictionary = {}
var _pressed: Dictionary = {}
var _released: Dictionary = {}


func feed(event: InputEvent) -> void:
	if event.is_echo():
		return
	for a in ACTIONS:
		if event.is_action_pressed(a):
			_taps[a] = true
		elif event.is_action_released(a):
			_rels[a] = true


func poll() -> void:
	for a in ACTIONS:
		var h := enabled and Input.is_action_pressed(a)
		_apply(a, h, enabled and bool(_taps.get(a, false)), bool(_rels.get(a, false)))
	_taps.clear()
	_rels.clear()
	if enabled:
		move = Vector2(_digital(Input.get_axis(&"move_left", &"move_right")), _digital(Input.get_axis(&"move_up", &"move_down")))
	else:
		move = Vector2.ZERO


func held(a: StringName) -> bool:
	return bool(_held.get(a, false))


func pressed(a: StringName) -> bool:
	return bool(_pressed.get(a, false))


func released(a: StringName) -> bool:
	return bool(_released.get(a, false))


## Algum botão de ação apertado neste tick.
func any_pressed() -> bool:
	return pressed(&"jump") or pressed(&"attack") or pressed(&"dash")


func clear() -> void:
	_held.clear()
	_pressed.clear()
	_released.clear()
	_taps.clear()
	_rels.clear()
	move = Vector2.ZERO


func _apply(a: StringName, h: bool, tapped: bool, let_go: bool) -> void:
	var was := bool(_held.get(a, false))
	_pressed[a] = tapped or (h and not was)
	_released[a] = let_go or (was and not h)
	_held[a] = h


func _digital(v: float) -> float:
	if absf(v) < AXIS_THRESHOLD:
		return 0.0
	return signf(v)
