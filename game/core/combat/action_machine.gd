class_name ActionMachine
extends RefCounted
## What a fighter is doing, one 60 Hz tick at a time. Pure logic: integers
## only, no nodes. It decides which action is running, when it can be
## cancelled, and when the fighter is striking, invulnerable or parrying.
## It knows nothing about space; the actor that owns it handles movement and
## asks the Law Engine what a strike did.

enum S { FREE, ATTACK, DODGE, GUARD, HITSTUN, STAGGER, RECOIL, DEAD, IMPOSE }

const BUFFER_TICKS := 10
const DODGE_TICKS := 24
const SLOW_DODGE_TICKS := 36
const IFRAME_FROM := 3
const IFRAME_TO := 14
const PERFECT_DODGE_TO := 8
const DODGE_CHAIN_WINDOW := 20
const PARRY_TICKS := 6
const PARRY_LOCKOUT := 24
const RECOIL_TICKS := 18
const STAGGER_TICKS := 60

var moves: Dictionary = {}
var entry: Dictionary = {}

var state: int = S.FREE
var t: int = 0                 # ticks spent in the current state
var move_id: String = ""
var combo_index: int = 0       # 1 for the first strike of a string
var connected: bool = false    # the current strike has touched something
var freeze: int = 0            # hit-stop ticks left
var stun_left: int = 0
var slow_dodge: bool = false
var dodge_chain: int = 0
var since_dodge: int = 999
var since_guard: int = 999
var guard_t: int = 0
var parry_armed: bool = false

var _buffered: String = ""
var _buffer_age: int = 0


## awakened: merge the moveset's "awakened" block (an Unveiled Instrument):
## its extra moves, and the new routes into them from existing moves.
func _init(moveset: Dictionary = {}, awakened: bool = false) -> void:
	moves = moveset.get("moves", {}).duplicate(true)
	entry = moveset.get("entry", {})
	if awakened and moveset.has("awakened"):
		var extra: Dictionary = moveset["awakened"]
		for id: String in extra.get("moves", {}):
			moves[id] = extra["moves"][id].duplicate(true)
		for id: String in extra.get("links", {}):
			if moves.has(id):
				for button: String in extra["links"][id]:
					moves[id]["next"][button] = extra["links"][id][button]


## Advance one tick. light, heavy and dodge are true only on the tick the
## button went down; guard is true while held. Returns what began this tick:
## "attack", "active", "dodge", "guard", "free".
func tick(light: bool, heavy: bool, dodge: bool, guard: bool) -> Array:
	var out: Array = []
	if state == S.DEAD:
		return out
	if dodge:
		_buffer("dodge")
	elif heavy:
		_buffer("heavy")
	elif light:
		_buffer("light")
	if _buffered != "":
		_buffer_age += 1
		if _buffer_age > BUFFER_TICKS:
			_buffered = ""
	if freeze > 0:
		freeze -= 1
		return out
	t += 1
	since_dodge += 1
	since_guard += 1
	if state == S.ATTACK:
		_tick_attack(out)
	elif state == S.DODGE:
		if t >= (SLOW_DODGE_TICKS if slow_dodge else DODGE_TICKS):
			since_dodge = 0
			_free(out)
	elif state == S.GUARD:
		guard_t += 1
		since_guard = 0
		if _buffered == "dodge":
			_start_dodge(out)
		elif _buffered != "":
			_start_attack(entry.get(_buffered, ""), out)
		elif not guard:
			_free(out)
	elif state == S.HITSTUN or state == S.STAGGER or state == S.RECOIL or state == S.IMPOSE:
		stun_left -= 1
		if stun_left <= 0:
			_free(out)
	if state == S.FREE:
		_tick_free(guard, out)
	return out


func _tick_free(guard: bool, out: Array) -> void:
	if _buffered == "dodge":
		_start_dodge(out)
	elif _buffered != "":
		_start_attack(entry.get(_buffered, ""), out)
	elif guard:
		state = S.GUARD
		t = 0
		guard_t = 0
		parry_armed = since_guard > PARRY_LOCKOUT
		out.append("guard")


func _tick_attack(out: Array) -> void:
	var m: Dictionary = moves[move_id]
	var startup: int = m.startup
	if t == startup + 1:
		out.append("active")
	var gate: int = m.get("cancel_hit", startup + m.active + 1) if connected else m.get("cancel_whiff", startup + m.active + m.recovery)
	if t >= gate and _buffered != "":
		if _buffered == "dodge":
			_start_dodge(out)
			return
		var next: String = m.get("next", {}).get(_buffered, "")
		if next != "":
			_start_attack(next, out)
			return
	if t >= startup + m.active + m.recovery:
		_free(out)


func _start_attack(id: String, out: Array) -> void:
	_buffered = ""
	if id == "" or not moves.has(id):
		return
	combo_index = combo_index + 1 if state == S.ATTACK else 1
	state = S.ATTACK
	t = 0
	move_id = id
	connected = false
	out.append("attack")


func _start_dodge(out: Array) -> void:
	_buffered = ""
	dodge_chain = dodge_chain + 1 if since_dodge <= DODGE_CHAIN_WINDOW else 1
	slow_dodge = dodge_chain >= 3
	state = S.DODGE
	t = 0
	combo_index = 0
	out.append("dodge")


func _free(out: Array) -> void:
	state = S.FREE
	t = 0
	move_id = ""
	combo_index = 0
	connected = false
	out.append("free")


func _buffer(what: String) -> void:
	_buffered = what
	_buffer_age = 0


# ------------------------------------------------------------------ queries

func move() -> Dictionary:
	return moves.get(move_id, {})


## True on the ticks the weapon can connect.
func is_active() -> bool:
	if state != S.ATTACK:
		return false
	var m: Dictionary = moves[move_id]
	return t > m.startup and t <= m.startup + m.active


func in_startup() -> bool:
	return state == S.ATTACK and t <= moves[move_id].startup


func invulnerable() -> bool:
	return state == S.DODGE and not slow_dodge and t >= IFRAME_FROM and t <= IFRAME_TO


func perfect_dodge() -> bool:
	return state == S.DODGE and not slow_dodge and t >= IFRAME_FROM and t <= PERFECT_DODGE_TO


func guarding() -> bool:
	return state == S.GUARD


## The first ticks of a fresh guard. Tapping guard repeatedly does not re-arm it.
func parrying() -> bool:
	return state == S.GUARD and parry_armed and guard_t < PARRY_TICKS


func busy() -> bool:
	return state != S.FREE and state != S.GUARD


func dead() -> bool:
	return state == S.DEAD


# ----------------------------------------------------- commands from outside

func hit_stop(ticks: int) -> void:
	freeze = maxi(freeze, ticks)


func mark_connected() -> void:
	connected = true


func stun(ticks: int) -> void:
	_interrupt(S.HITSTUN, ticks)


func stagger() -> void:
	_interrupt(S.STAGGER, STAGGER_TICKS)


func recoil() -> void:
	_interrupt(S.RECOIL, RECOIL_TICKS)


## The gesture of imposing a law. Short, and it can be interrupted.
func impose_act(ticks: int) -> void:
	_interrupt(S.IMPOSE, ticks)


func die() -> void:
	state = S.DEAD
	t = 0
	move_id = ""
	_buffered = ""


func revive() -> void:
	state = S.FREE
	t = 0
	move_id = ""
	combo_index = 0
	freeze = 0
	_buffered = ""


func _interrupt(to: int, ticks: int) -> void:
	if state == S.DEAD:
		return
	state = to
	t = 0
	stun_left = ticks
	move_id = ""
	combo_index = 0
	connected = false
	_buffered = ""
