class_name ScriptedInput
extends PlayerInput
## Entrada roteirizada para testes e para a demo gravada.
##
## `set_held()` controla o estado frame a frame; `timeline` segura ações entre
## dois instantes: [{"from": 0.0, "to": 0.4, "action": "move_right"}].

var manual: Dictionary = {}
var timeline: Array = []
var time := 0.0
var dt := 1.0 / 60.0


func set_held(action: StringName, value: bool) -> void:
	manual[action] = value


func release_all() -> void:
	manual.clear()


func poll() -> void:
	var now: Dictionary = {}
	for a in ACTIONS:
		now[a] = bool(manual.get(a, false))
	for seg in timeline:
		if time >= float(seg["from"]) and time < float(seg["to"]):
			now[StringName(seg["action"])] = true
	for a in ACTIONS:
		_apply(a, enabled and bool(now[a]), false, false)
	move = Vector2(
		float(int(held(&"move_right")) - int(held(&"move_left"))),
		float(int(held(&"move_down")) - int(held(&"move_up"))))
	time += dt
