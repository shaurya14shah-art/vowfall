extends Node
## Autoload "InputSetup". Defines the input map in code, so the bindings in
## docs/09_ui_ux.md live in one readable table instead of project.godot.

const STICK_DEADZONE := 0.25


func _init() -> void:
	_action("move_left", [KEY_A], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("move_forward", [KEY_W], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_back", [KEY_S], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("look_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_action("look_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_action("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_action("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_action("light", [], [JOY_BUTTON_RIGHT_SHOULDER], [], [MOUSE_BUTTON_LEFT])
	_action("heavy", [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], [MOUSE_BUTTON_RIGHT])
	_action("dodge", [KEY_SPACE], [JOY_BUTTON_B])
	_action("guard", [KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER])
	_action("impose", [KEY_Q], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("lock_on", [KEY_TAB], [JOY_BUTTON_RIGHT_STICK], [], [MOUSE_BUTTON_MIDDLE])
	_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_action("reset", [KEY_BACKSPACE], [JOY_BUTTON_BACK])
	_action("toggle_help", [KEY_H])
	# Practice-yard controls (M2): choose a law, rest, try the Unveiled form,
	# change who you are fighting, write the verdict log to a file.
	for n in 6:
		_action("law_%d" % (n + 1), [KEY_1 + n])
	_action("rest", [KEY_R])
	_action("unveil", [KEY_U])
	_action("next_encounter", [KEY_N])
	_action("export_log", [KEY_L])
	# The Assize Quarter (M5): read, rest and open things; go between the
	# yard and the Quarter.
	_action("interact", [KEY_E], [JOY_BUTTON_A])
	_action("travel", [KEY_T])


func _action(action: String, keys: Array, pad_buttons: Array = [], pad_axes: Array = [], mouse: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, STICK_DEADZONE)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)
	for b: int in pad_buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b as JoyButton
		InputMap.action_add_event(action, ev)
	for a: Array in pad_axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[0] as JoyAxis
		ev.axis_value = a[1]
		InputMap.action_add_event(action, ev)
	for m: int in mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = m as MouseButton
		InputMap.action_add_event(action, ev)
