class_name Enemy
extends Actor
## A Court enemy. What it is comes from data/enemies/<id>.json: its body,
## its moveset, how patient it is, and which laws it keeps standing.
##
## It closes in, circles, and throws readable strings. Groups take turns:
## no more than two of a side swing at once. It presses the same buttons the
## player does and is judged by the same engine. Randomness comes from the
## bridge's seeded generator so a fight can be replayed.

enum Mode { APPROACH, CIRCLE, ATTACK, GUARD, RECOVER }

const MAX_ATTACKERS := 2
const UPKEEP_EVERY := 30
const UPKEEP_RESONANCE := 3

var archetype: Dictionary = {}
var target: Actor
var partner: Actor                 # the other half of an Escort, if any
var ai_enabled: bool = true
var mode: int = Mode.APPROACH
## A post to keep. With its AI off and a post set, it walks back and waits.
var has_home: bool = false
var home: Vector3 = Vector3.ZERO
var home_facing: float = PI

var _near: float = 2.3
var _far: float = 3.6
var _wait: Array = [35, 85]
var _p_heavy: float = 0.3
var _p_double: float = 0.35
var _p_guard: float = 0.5
var _p_riposte: float = 0.0
var _riposte: bool = false
var _timer: int = 0
var _side: float = 1.0
var _queued: Array = []            # [ticks until press, "light" or "heavy"]
var _recent_hits: int = 0
var _hit_memory: int = 0


func _init() -> void:
	team = 2
	collision_layer = 2
	collision_mask = 1 | 2
	start_resonance = 100


## Call before the enemy enters the tree.
func load_archetype(id: String) -> void:
	archetype = LawRegistry.read_json("res://data/enemies/%s.json" % id)
	display_name = archetype.name
	max_hp = archetype.hp
	max_poise = archetype.poise
	speed_scale = archetype.speed
	moveset_path = archetype.moveset
	var ai: Dictionary = archetype.get("ai", {})
	_near = ai.get("near", _near)
	_far = ai.get("far", _far)
	_wait = ai.get("wait", _wait)
	_p_heavy = ai.get("heavy", _p_heavy)
	_p_double = ai.get("double", _p_double)
	_p_guard = ai.get("guard_when_hit", _p_guard)
	_p_riposte = ai.get("riposte", 0.0)
	armoured_strikes = archetype.get("armoured", false)


func _build_model() -> void:
	model = CharacterModel.new()
	add_child(model)
	model.setup(archetype.model, archetype.get("right", ""), archetype.get("left", ""), archetype.get("scale", 1.0))


func on_hit(from: Actor, m: Dictionary) -> void:
	super.on_hit(from, m)
	_recent_hits += 1
	_hit_memory = 90
	_queued.clear()
	# Hit twice in quick succession: some of the time it turtles up next.
	if _recent_hits >= 2 and bridge.rng.randf() < _p_guard:
		_enter(Mode.GUARD, bridge.rng.randi_range(45, 80))
	elif mode == Mode.ATTACK:
		_enter(Mode.RECOVER, bridge.rng.randi_range(15, 35))


func on_guard_hit(from: Actor, m: Dictionary) -> void:
	super.on_guard_hit(from, m)
	# Having caught a blow on the shield, it may answer at once.
	if mode == Mode.GUARD and bridge.rng.randf() < _p_riposte:
		_riposte = true
		_timer = mini(_timer, 12)


func _think() -> void:
	if not ai_enabled or not _valid(target):
		lock_target = null
		if has_home and not machine.busy():
			var back := home - global_position
			back.y = 0.0
			if back.length() > 0.6:
				wish = back.normalized() * 0.7
			else:
				facing = rotate_toward(facing, home_facing, 0.08)
		return
	lock_target = target
	if (bridge.tick + entity_id) % UPKEEP_EVERY == 0:
		_keep_laws()
	var to := target.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	_timer -= 1
	if _hit_memory > 0:
		_hit_memory -= 1
		if _hit_memory == 0:
			_recent_hits = 0

	for q: Array in _queued:
		q[0] -= 1
		if q[0] <= 0:
			if q[1] == "light":
				press_light = true
			else:
				press_heavy = true
	_queued = _queued.filter(func(q: Array) -> bool: return q[0] > 0)

	if machine.busy():
		return   # mid-strike, stunned or recoiling: nothing to decide

	if mode == Mode.APPROACH:
		wish = dir
		if d <= _near + 0.2:
			_enter(Mode.CIRCLE, bridge.rng.randi_range(_wait[0], _wait[1]))
	elif mode == Mode.CIRCLE:
		var tangent := Vector3(-dir.z, 0.0, dir.x) * _side
		var radial := 0.0
		if d > _near + 0.5:
			radial = 0.6
		elif d < _near - 0.5:
			radial = -0.5
		wish = (tangent * 0.55 + dir * radial).limit_length(1.0)
		if d > _far:
			_enter(Mode.APPROACH, 0)
		elif _timer <= 0:
			_choose_attack(d)
	elif mode == Mode.ATTACK:
		if _queued.is_empty():
			_enter(Mode.RECOVER, bridge.rng.randi_range(25, 55))
	elif mode == Mode.GUARD:
		hold_guard = true
		if _timer <= 0:
			_recent_hits = 0
			if _riposte and d <= _far:
				_riposte = false
				hold_guard = false
				mode = Mode.ATTACK
				press_light = true
			else:
				_riposte = false
				_enter(Mode.CIRCLE, bridge.rng.randi_range(20, 50))
	elif mode == Mode.RECOVER:
		wish = -dir * 0.45
		if _timer <= 0:
			_enter(Mode.CIRCLE if d <= _far else Mode.APPROACH, bridge.rng.randi_range(_wait[0], _wait[1]))


func _choose_attack(d: float) -> void:
	if d > _far:
		_enter(Mode.APPROACH, 0)
		return
	if bridge.attackers(team, self) >= MAX_ATTACKERS:
		_timer = bridge.rng.randi_range(10, 25)   # wait for a turn
		return
	var roll := bridge.rng.randf()
	mode = Mode.ATTACK
	if roll < _p_heavy:
		press_heavy = true
	elif roll < 1.0 - _p_double:
		press_light = true
	else:
		press_light = true
		var first: Dictionary = machine.moves[machine.entry["light"]]
		_queued.append([int(first.cancel_whiff), "light"])   # inside the first strike's cancel window


## Keep the laws this enemy carries standing, when it can pay and when its
## data says the moment calls for them.
func _keep_laws() -> void:
	bridge.grant(self, UPKEEP_RESONANCE)
	for spec: Dictionary in archetype.get("laws", []):
		if not bridge.world.find_law(entity_id, spec.id).is_empty():
			continue
		if spec.get("when", "ALWAYS") == "TARGET_HAS_LAW" and bridge.laws_of(target, team).is_empty():
			continue
		var def := bridge.registry.resolve(spec.id)
		if bridge.resonance(entity_id) < int(def.price.get("resonance", 0)):
			continue
		var args: Dictionary = {}
		if spec.get("pair_with_partner", false):
			if not _valid(partner):
				continue
			args["pair"] = [entity_id, partner.entity_id]
		bridge.impose(self, spec.id, args)


func _enter(to: int, ticks: int) -> void:
	mode = to
	_timer = ticks
	if to == Mode.CIRCLE:
		_side = 1.0 if bridge.rng.randf() < 0.5 else -1.0
