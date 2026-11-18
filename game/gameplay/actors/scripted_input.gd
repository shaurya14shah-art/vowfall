class_name ScriptedInput
extends PlayerInput
## A timeline of inputs for headless tests. Each read() is one tick.
##
##   var s := ScriptedInput.new()
##   s.at(10, "light"); s.at(22, "light")      # presses, on those ticks
##   s.hold(0, 60, "move", Vector2(0, 1))      # held from tick 0 for 60 ticks
##   s.hold(30, 20, "guard")

var tick: int = 0
var _presses: Dictionary = {}   # tick -> [names]
var _holds: Array = []          # {from, to, name, value}


func at(when: int, what: String) -> void:
	if not _presses.has(when):
		_presses[when] = []
	_presses[when].append(what)


func hold(from: int, ticks: int, what: String, value: Variant = true) -> void:
	_holds.append({"from": from, "to": from + ticks, "name": what, "value": value})


func clear() -> void:
	tick = 0
	_presses.clear()
	_holds.clear()


func read() -> Dictionary:
	var out := {"move": Vector2.ZERO, "light": false, "heavy": false, "dodge": false, "guard": false,
		"lock": false, "impose": false, "select": 0, "rest": false, "unveil": false, "interact": false}
	for name: String in _presses.get(tick, []):
		out[name] = true
	for h: Dictionary in _holds:
		if tick >= h.from and tick < h.to:
			out[h.name] = h.value
	tick += 1
	return out
