extends SceneTree
## Gera o Input Map do projeto (project.godot) a partir do código.
## Uso: godot --headless --path . -s res://tools/setup_input.gd

const MOVE_DEADZONE := 0.3

func _initialize() -> void:
	var actions := {
		"move_left": [_key(KEY_LEFT), _key(KEY_A), _btn(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_RIGHT), _key(KEY_D), _btn(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"move_up": [_key(KEY_UP), _key(KEY_W), _btn(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_down": [_key(KEY_DOWN), _key(KEY_S), _btn(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"jump": [_key(KEY_Z), _key(KEY_SPACE), _btn(JOY_BUTTON_A)],
		"attack": [_key(KEY_X), _key(KEY_J), _btn(JOY_BUTTON_X)],
		"dash": [_key(KEY_C), _key(KEY_K), _btn(JOY_BUTTON_RIGHT_SHOULDER), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"zetsu": [_key(KEY_SHIFT), _btn(JOY_BUTTON_LEFT_SHOULDER)],
		"ren": [_key(KEY_V), _key(KEY_L), _btn(JOY_BUTTON_Y)],
		"gyo": [_key(KEY_F), _key(KEY_Q), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _btn(JOY_BUTTON_START)],
		"toggle_music": [_key(KEY_M)],
		"debug": [_key(KEY_F3)],
	}
	for action_name: String in actions:
		var deadzone := MOVE_DEADZONE if action_name.begins_with("move_") or action_name in ["dash", "zetsu", "gyo"] else 0.5
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": deadzone, "events": actions[action_name]})
	var err := ProjectSettings.save()
	print("Input Map salvo em project.godot (erro=%d)" % err)
	quit(0 if err == OK else 1)

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e

func _btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e
