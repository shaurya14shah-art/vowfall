class_name Actor
extends CharacterBody3D
## Anything that can fight: the player, a Bailiff, a training post.
##
## Each physics tick: decide what is wanted (_think), advance the action
## machine, move, and report any strike that reached someone to the bridge.
## An actor never changes its own health: the Law Engine does.

const RUN_SPEED := 5.4
const LOCK_SPEED := 4.6
const GUARD_SPEED := 2.2
const TURN_RATE := 16.0
const DODGE_DIST := 3.4
const SLOW_DODGE_DIST := 2.0
const GRAVITY := 22.0
const POISE_REST_TICKS := 120
const ASSIST_RANGE := 4.5
const ASSIST_DOT := 0.35

var display_name: String = "Actor"
var team: int = 1
var max_hp: int = 100
var max_poise: int = 60
var tags: Array = ["person"]
var moveset_path: String = ""
var speed_scale: float = 1.0
var immovable: bool = false
var hurt_radius: float = 0.45
var start_resonance: int = 0
var guard_chip_pct: int = 30         # how much of a guarded blow gets through
var idle_clip: String = "Idle"
var yields_at: int = 0              # at or below this health they yield instead of dying (bosses)
var yielded: bool = false
var armoured_strikes: bool = false   # a strike under way is not stopped by a blow that leaves poise standing

var bridge: CombatBridge
var entity_id: int = 0
var machine: ActionMachine
var model: CharacterModel
var poise: int = 0
var since_hit: int = 999
var facing: float = 0.0            # yaw; 0 looks along +Z
var lock_target: Actor = null

# What this actor wants this tick. Filled by _think().
var wish: Vector3 = Vector3.ZERO   # world direction, length 0 to 1
var press_light: bool = false
var press_heavy: bool = false
var press_dodge: bool = false
var hold_guard: bool = false

var swing_serial: int = 0          # each swing has a number: the Law Engine judges a swing once, however many it reaches
var swing_tags: Array = []         # extra tags the current strike carries (an inscription)

var _hit_ids: Dictionary = {}
var _dodge_dir: Vector3 = Vector3.ZERO
var _knock: Vector3 = Vector3.ZERO
var _lunge_speed: float = 0.0


func _ready() -> void:
	var moveset: Dictionary = {}
	if moveset_path != "":
		moveset = LawRegistry.read_json(moveset_path)
	machine = ActionMachine.new(moveset)
	idle_clip = moveset.get("idle", "Idle")
	guard_chip_pct = moveset.get("guard_chip_pct", 30)
	poise = max_poise
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = hurt_radius
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_build_model()
	if bridge != null:
		entity_id = bridge.register(self)


## Override: create `model` or any other visuals.
func _build_model() -> void:
	pass


## Override: tags a strike carries beyond the usual ones (an inscription).
func _tags_for_swing() -> Array:
	return []


## Override: set wish, press_light, press_heavy, press_dodge, hold_guard.
func _think() -> void:
	pass


func forward() -> Vector3:
	return Vector3(sin(facing), 0.0, cos(facing))


func hp() -> int:
	return bridge.hp(entity_id)


func _physics_process(delta: float) -> void:
	if bridge == null:
		return
	wish = Vector3.ZERO
	hold_guard = false
	_think()
	var began := machine.tick(press_light, press_heavy, press_dodge, hold_guard)
	press_light = false
	press_heavy = false
	press_dodge = false
	for what: String in began:
		_on_begin(what)
	if model != null:
		model.set_paused(machine.freeze > 0)
	if machine.freeze > 0 or immovable:
		return
	_move(delta)
	if machine.is_active():
		_check_hits()
	since_hit += 1
	if since_hit >= POISE_REST_TICKS:
		poise = max_poise
	_animate()


# ----------------------------------------------------------------- movement

func _move(delta: float) -> void:
	var v := Vector3.ZERO
	var s := machine.state
	if s == ActionMachine.S.FREE:
		v = wish * (LOCK_SPEED if lock_target != null else RUN_SPEED) * speed_scale
		_face_wanted(delta, true)
	elif s == ActionMachine.S.GUARD:
		v = wish * GUARD_SPEED * speed_scale
		_face_wanted(delta, false)
	elif s == ActionMachine.S.ATTACK:
		if machine.in_startup():
			v = forward() * _lunge_speed
			# A lunge never carries you over your own line. A step does.
			if _lunge_speed > 0.0 and bridge.would_breach(self, global_position + v * 0.05):
				v = Vector3.ZERO
			if machine.t <= 5:
				_face_aim(delta)
	elif s == ActionMachine.S.DODGE:
		var total := float(ActionMachine.SLOW_DODGE_TICKS if machine.slow_dodge else ActionMachine.DODGE_TICKS)
		var dist := SLOW_DODGE_DIST if machine.slow_dodge else DODGE_DIST
		var k := clampf(1.0 - float(machine.t) / total, 0.0, 1.0)
		v = _dodge_dir * (2.0 * dist / (total / 60.0)) * k
	if _knock.length() > 0.05:
		v += _knock
		_knock *= 0.82
	else:
		_knock = Vector3.ZERO
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if model != null:
		model.rotation.y = facing


func _turn_to(yaw: float, delta: float, rate: float = TURN_RATE) -> void:
	facing = rotate_toward(facing, yaw, rate * delta)


func _yaw_to(point: Vector3) -> float:
	var d := point - global_position
	return atan2(d.x, d.z)


func _face_wanted(delta: float, follow_wish: bool) -> void:
	if _valid(lock_target):
		_turn_to(_yaw_to(lock_target.global_position), delta)
	elif follow_wish and wish.length() > 0.1:
		_turn_to(atan2(wish.x, wish.z), delta)


## At the start of a strike, turn toward what it is meant for: the locked
## target, else the nearest enemy roughly ahead, else where the stick points.
func _face_aim(delta: float) -> void:
	var aim := _aim_target()
	if aim != null:
		_turn_to(_yaw_to(aim.global_position), delta, 30.0)
	elif wish.length() > 0.3:
		_turn_to(atan2(wish.x, wish.z), delta, 30.0)


func _aim_target() -> Actor:
	if _valid(lock_target):
		return lock_target
	var best: Actor = null
	var best_d := ASSIST_RANGE
	var look := wish.normalized() if wish.length() > 0.3 else forward()
	for id: int in bridge.actors:
		var other: Actor = bridge.actors[id]
		if other == self or other.team == team or other.machine.dead() or other.yielded:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 1.2 or look.dot(to / d) > ASSIST_DOT):
			best = other
			best_d = d
	return best


## Untyped on purpose: a target that has been freed (an encounter cleared
## away) cannot be passed to a typed parameter at all.
static func _valid(a: Variant) -> bool:
	return a != null and is_instance_valid(a) and not a.machine.dead() and not a.yielded


# ------------------------------------------------------------------ actions

func _on_begin(what: String) -> void:
	if what == "attack":
		var m := machine.move()
		_hit_ids.clear()
		swing_tags = _tags_for_swing()
		swing_serial += 1
		var startup_s := float(m.startup) / 60.0
		# Do not lunge through a target that is already in reach.
		var aim := _aim_target()
		var reach_m := float(m.reach) / 100.0
		var gap := 99.0
		if aim != null:
			gap = global_position.distance_to(aim.global_position) - aim.hurt_radius
		var lunge := clampf(gap - reach_m * 0.55, 0.0, float(m.get("lunge", 0)) / 100.0)
		_lunge_speed = lunge / startup_s
		if model != null:
			model.play(m.anim, 0.06, float(m.anim_hit) / startup_s, true)
	elif what == "active":
		Sfx.play_at("swing", global_position, -8.0, 0.9 + 0.08 * machine.combo_index)
	elif what == "dodge":
		_dodge_dir = wish.normalized() if wish.length() > 0.2 else -forward()
		if model != null:
			var local_f := forward().dot(_dodge_dir)
			var local_r := Vector3(-cos(facing), 0.0, sin(facing)).dot(_dodge_dir)
			var clip := "Dodge_Forward"
			if absf(local_f) >= absf(local_r):
				clip = "Dodge_Forward" if local_f > 0.0 else "Dodge_Backward"
			else:
				clip = "Dodge_Right" if local_r > 0.0 else "Dodge_Left"
			model.play(clip, 0.04, 1.0, true)
		Sfx.play_at("cloth", global_position, -10.0, 1.1)


func _check_hits() -> void:
	var m := machine.move()
	var reach := float(m.reach) / 100.0
	var half_arc := deg_to_rad(float(m.arc) * 0.5)
	for id: int in bridge.actors:
		var other: Actor = bridge.actors[id]
		if other == self or other.team == team or other.machine.dead() or other.yielded or _hit_ids.has(id):
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d - other.hurt_radius > reach:
			continue
		if d > 0.5 and forward().angle_to(to) > half_arc:
			continue
		_hit_ids[id] = true
		bridge.resolve_strike(self, other, m)


# --------------------------------------------- what the bridge tells an actor

func on_hit(from: Actor, m: Dictionary) -> void:
	since_hit = 0
	poise -= int(m.get("poise", 10))
	_push_from(from, 2.4 if int(m.get("poise", 10)) < 25 else 4.0)
	if poise <= 0 and max_poise > 0:
		poise = max_poise
		machine.stagger()
		_play("Hit_B", 0.05, 0.55)
	elif armoured_strikes and machine.state == ActionMachine.S.ATTACK:
		_knock = Vector3.ZERO      # hurt, but the swing comes through
	else:
		machine.stun(int(m.get("stun", 14)))
		_play("Hit_A", 0.04, 1.2)


func on_guard_hit(from: Actor, m: Dictionary) -> void:
	since_hit = 0
	poise -= int(m.get("poise", 10))
	_push_from(from, 1.6)
	if poise <= 0 and max_poise > 0:
		poise = max_poise
		machine.stagger()
		_play("Hit_B", 0.05, 0.55)
	else:
		_play("Block_Hit", 0.03, 1.6)


func on_parry_success() -> void:
	_play("Block_Attack", 0.03, 1.8)


func on_parried(poise_loss: int) -> void:
	since_hit = 0
	poise -= poise_loss
	if poise <= 0 and max_poise > 0:
		poise = max_poise
		machine.stagger()
		_play("Hit_B", 0.05, 0.55)
	else:
		machine.recoil()
		_play("Hit_B", 0.04, 1.3)


## A law refused the strike. The weapon stops dead and the arm is thrown back.
func on_denied(by: Actor) -> void:
	machine.recoil()
	_push_from(by, 2.0)
	_play("Hit_B", 0.03, 1.5)


## A law has harmed this actor: a mirrored or returned strike, a copy from a
## twin, a debt paid forward or come due, a sanction. The body reacts to the
## ones that are blows; the rest are only suffered.
func on_law_harm(kind: String, _amount: int) -> void:
	since_hit = 0
	if machine.dead():
		return
	if kind == "defaulted":
		machine.stagger()
		_play("Hit_B", 0.05, 0.55)
	elif kind in ["mirrored", "returned", "copied", "paid_forward"]:
		machine.stun(10)
		_play("Hit_A", 0.04, 1.3)


## Brought to the point of falling, and choosing not to. Override.
func on_yield() -> void:
	pass


## Someone nearby has Unveiled. No harm, but nobody keeps their feet.
func on_shock(from: Actor) -> void:
	if machine.dead() or immovable:
		return
	since_hit = 0
	_push_from(from, 7.0)
	machine.stagger()
	_play("Hit_B", 0.05, 0.55)


func on_death() -> void:
	machine.die()
	collision_layer = 0
	collision_mask = 1
	lock_target = null
	_play("Death_A", 0.08, 1.0)


## Back on your feet after a rest. The engine has already restored health.
func revive() -> void:
	machine.revive()
	collision_layer = 2
	collision_mask = 1 | 2
	poise = max_poise
	_knock = Vector3.ZERO
	_play("Idle", 0.2, 1.0)


## A law refused a step: go back to where the engine says you are.
func bounce_back(to: Vector3) -> void:
	var away := to - global_position
	away.y = 0.0
	global_position = to
	if away.length() > 0.001:
		_knock = away.normalized() * 3.0
	machine.recoil()
	_play("Hit_B", 0.03, 1.5)


func _push_from(from: Actor, speed: float) -> void:
	if immovable or from == null:
		return
	var away := global_position - from.global_position
	away.y = 0.0
	if away.length() > 0.001:
		_knock = away.normalized() * speed


func _play(clip: String, blend: float = 0.12, speed: float = 1.0) -> void:
	if model != null:
		model.play(clip, blend, speed, true)


# ---------------------------------------------------------------- animation

func _animate() -> void:
	if model == null:
		return
	var s := machine.state
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if s == ActionMachine.S.GUARD:
		model.play("Blocking", 0.08)
	elif s == ActionMachine.S.FREE:
		if speed < 0.4:
			model.play(idle_clip, 0.18)
		elif _valid(lock_target):
			var f := forward().dot(flat / speed)
			var r := Vector3(-cos(facing), 0.0, sin(facing)).dot(flat / speed)
			if absf(r) > absf(f):
				model.play("Running_Strafe_Right" if r > 0.0 else "Running_Strafe_Left", 0.15, clampf(speed / 4.2, 0.6, 1.4))
			elif f < 0.0:
				model.play("Walking_Backwards", 0.15, clampf(speed / 1.9, 0.8, 2.4))
			else:
				model.play("Running_A", 0.15, clampf(speed / 5.0, 0.7, 1.4))
		elif speed < 3.0:
			model.play("Walking_A", 0.15, clampf(speed / 1.9, 0.7, 1.6))
		else:
			model.play("Running_A", 0.15, clampf(speed / 5.0, 0.8, 1.4))
