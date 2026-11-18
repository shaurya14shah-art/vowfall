class_name PlayerInput
extends RefCounted
## Where the player's intent comes from. The live version reads the input
## map. Tests replace it with ScriptedInput so the same controller can be
## driven tick by tick without a keyboard.


func read() -> Dictionary:
	return {
		"move": Input.get_vector("move_left", "move_right", "move_back", "move_forward"),
		"light": Input.is_action_just_pressed("light"),
		"heavy": Input.is_action_just_pressed("heavy"),
		"dodge": Input.is_action_just_pressed("dodge"),
		"guard": Input.is_action_pressed("guard"),
		"lock": Input.is_action_just_pressed("lock_on"),
		"impose": Input.is_action_pressed("impose"),
		"select": _selected(),
		"rest": Input.is_action_just_pressed("rest"),
		"unveil": Input.is_action_just_pressed("unveil"),
		"interact": Input.is_action_just_pressed("interact"),
	}


func _selected() -> int:
	for n in 6:
		if Input.is_action_just_pressed("law_%d" % (n + 1)):
			return n + 1
	return 0
