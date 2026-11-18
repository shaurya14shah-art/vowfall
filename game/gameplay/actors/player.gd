class_name Player
extends Actor
## The Witness in the practice yard: a body, one Axiom at a time chosen from
## the six of the slice, and the Instrument that Axiom's Root binds to them.
##
## Axiom input (docs/05_combat.md):
##   Impose    press and release the Axiom button. A line law is drawn from
##             where you pressed to where you released; a tap bars the way
##             in front of you. A pair law arms the blade: the next two you
##             strike are bound.
##   Commit    keep holding before release: up to 10 more Resonance goes into
##             the law's authority.
##   Inscribe  hold the Axiom button and strike: the strike carries your
##             standing law's mark (the Creditor's "call in").
##   Counter   a perfect parry while your law stands (the Answer returns it).
##   Unveil    once your law's Recognition Trial is done: hold the Axiom
##             button and Guard together, and stay unstruck.
##
## The Instrument (docs/06) follows the law's Root: the Lintel for Threshold,
## the Tally for Debt, the Counterpart for Reflection. Each is a moveset and
## a verb. Motion clips are borrowed; everything else here is the game's own.

const LOCK_RANGE := 16.0
const LAWS := [
	"threshold.gatekeeper", "threshold.divide",
	"debt.creditor", "debt.debtor",
	"reflection.twin", "reflection.answer",
]
const COMMIT_TICKS_PER_POINT := 6
const DRAW_SPEED := 0.45          # how fast you may walk while drawing a law
const TAP_SPAN := 1.0             # a drawn line shorter than this is a tap
const BAR_DISTANCE := 1.4         # a tapped line is laid this far ahead
const BAR_HALF_WIDTH := 3.0
const LINE_END_GAP := 0.4         # a drawn line stops short of your feet
const IMPOSE_TICKS := 14
const INSCRIBE_MEMORY := 15
const TAP_MEMORY := 12
const MARK_TICKS := 480           # how long an armed blade waits for its pair
const RITE_TICKS := 75            # how long the Unveiling must be held
const RITE_POSE_TICKS := 60
const PLANT_HEIGHT := 0.88        # the Lintel's grip above the floor when planted

## A choice has been put to the Witness (a licence offered); 1 or 2 answers it.
signal chose(option: int)
## The interact button was pressed. Whatever place this is decides what it meant.
signal interacted

var input: PlayerInput
var camera: FollowCamera
var choosing: bool = false
var choice_count: int = 2           # how many numbered options are on offer
var free_rest: bool = true         # the practice yard's keys (R restores you anywhere, U flips the Unveiled form); a real place has neither
var law_id: String = LAWS[0]
var imposing: bool = false
var impose_ticks: int = 0
var anchor: Vector3 = Vector3.ZERO

var recognition: Recognition
var instruments: Dictionary = {}
var instrument_id: String = ""
var instrument: Dictionary = {}
var instrument_lock: String = ""  # tests: carry this Instrument whatever the law
var planted: bool = false         # the Lintel is standing on a line; the short half is in hand
var marking: bool = false         # the Counterpart is armed: the next two struck are bound
var marks: Array = []
var rite_ticks: int = 0

var _q_was: bool = false
var _q_spent: bool = false        # this hold of the button has already been used
var _tap_memory: int = 0
var _inscribe_for: int = 0        # ticks for which the next strike to start is inscribed
var _mark_left: int = 0
var _mark_commit: int = 0
var _equipped: String = ""
var _planted_prop: Node3D


func _init() -> void:
	display_name = "The Witness"
	team = 1
	max_hp = 100
	max_poise = 60
	collision_layer = 2
	collision_mask = 1 | 2
	input = PlayerInput.new()
	recognition = Recognition.new()
	var index: Variant = LawRegistry.read_json("res://data/instruments/index.json")
	if index is Dictionary:
		instruments = index


func _ready() -> void:
	super._ready()
	if bridge != null:
		bridge.struck.connect(_on_struck)
		bridge.noted.connect(_on_noted)
		_update_instrument()


func _build_model() -> void:
	model = CharacterModel.new()
	add_child(model)
	model.setup("res://assets/models/figures/witness.glb")


func _exit_tree() -> void:
	if _planted_prop != null and is_instance_valid(_planted_prop):
		_planted_prop.queue_free()


# ------------------------------------------------------------------ thinking

func _think() -> void:
	var i := input.read()
	var yaw := camera.yaw if camera != null else 0.0
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var mv: Vector2 = i.move
	wish = (fwd * mv.y + right * mv.x).limit_length(1.0)
	press_light = i.light
	press_heavy = i.heavy
	press_dodge = i.dodge
	hold_guard = i.guard
	if not _valid(lock_target):
		lock_target = null
	if i.lock:
		lock_target = null if lock_target != null else _find_lock(fwd)

	var chosen: int = i.get("select", 0)
	if choosing:
		if chosen >= 1 and chosen <= choice_count:
			chose.emit(chosen)
		chosen = 0
	if chosen >= 1 and chosen <= LAWS.size():
		law_id = LAWS[chosen - 1]
		marking = false
	if i.get("unveil", false) and free_rest:    # a yard key, like R: not in a real place
		bridge.set_form(self, "UNVEILED" if bridge.form(self) == "DORMANT" else "DORMANT")
	if i.get("rest", false) and free_rest:
		bridge.rest(self)
	if i.get("interact", false) and not machine.dead():
		interacted.emit()
	var q: bool = i.get("impose", false)
	if not _think_rite(q, i.guard):
		_think_axiom(q)
	if marking:
		_mark_left -= 1
		if _mark_left <= 0:
			marking = false
	_update_instrument()


## The Unveiling: the Axiom button and Guard, held together, unstruck.
## Returns true while it has the player's hands.
func _think_rite(q: bool, guard: bool) -> bool:
	if not (q and guard and can_unveil()) or machine.busy():
		rite_ticks = 0
		return false
	rite_ticks += 1
	imposing = false
	_q_spent = true
	hold_guard = false
	press_light = false
	press_heavy = false
	press_dodge = false
	wish = Vector3.ZERO
	if rite_ticks >= RITE_TICKS:
		rite_ticks = 0
		bridge.unveil(self)
		_update_instrument(true)             # the Instrument wakes now, in the hand
		machine.impose_act(RITE_POSE_TICKS)
		_play("Cheer", 0.12, 1.3)
	return true


func can_unveil() -> bool:
	return bridge.form(self) == "DORMANT" and recognition.complete(law_id)


func _think_axiom(q: bool) -> void:
	if _inscribe_for > 0:
		_inscribe_for -= 1
	if q and (press_light or press_heavy):
		_inscribe_for = INSCRIBE_MEMORY
		imposing = false
		_q_spent = true                      # this hold was for the strike
	elif imposing:
		if machine.busy() or press_dodge:
			imposing = false                 # struck, or chose to move: the drawing is lost
			_q_spent = true
		elif not q:
			imposing = false
			_impose()
			_q_spent = false
		else:
			impose_ticks += 1
			hold_guard = false
			wish *= DRAW_SPEED
	elif q and not _q_spent and not machine.busy():
		# Pressed now, or pressed during another action and still held.
		imposing = true
		impose_ticks = 0
		anchor = global_position
		_tap_memory = 0
	elif _tap_memory > 0 and not q and not machine.busy():
		# Tapped during another action: the tap is honoured as soon as it can be.
		_tap_memory = 0
		impose_ticks = 0
		anchor = global_position
		_impose()
	if q and not _q_was and machine.busy():
		_tap_memory = TAP_MEMORY
	elif _tap_memory > 0:
		_tap_memory -= 1
	if not q:
		_q_spent = false
	_q_was = q


func _tags_for_swing() -> Array:
	if _inscribe_for <= 0:
		return []
	_inscribe_for = 0
	var tag := bridge.begin_inscription(self)
	return [tag] if tag != "" else []


# ----------------------------------------------------------------- imposing

## The Resonance holding the button has committed so far (0 to 10).
func commit_now() -> int:
	if not imposing:
		return 0
	return _commit_for(impose_ticks)


func _commit_for(ticks: int) -> int:
	var def := bridge.registry.resolve(law_id, bridge.form(self))
	var spare: int = bridge.resonance(entity_id) - int(def.price.get("resonance", 0))
	return clampi(mini(ticks / COMMIT_TICKS_PER_POINT, spare), 0, 10)


## Where the line would lie if the button were released now: [a, b].
func line_preview(drawing: bool = true) -> Array:
	var def := bridge.registry.resolve(law_id, bridge.form(self))
	var max_len: float = float(def.scope.get("max_length", 600)) / 100.0
	var span := global_position - anchor
	span.y = 0.0
	if not drawing or span.length() < TAP_SPAN:
		var across := Vector3(-cos(facing), 0.0, sin(facing))
		var centre := global_position + forward() * BAR_DISTANCE
		# A hair inside the law's limit: the ends are rounded to the centimetre.
		var half := minf(max_len * 0.5, BAR_HALF_WIDTH) - 0.02
		return [centre - across * half, centre + across * half]
	var length := minf(span.length(), max_len + LINE_END_GAP - 0.03) - LINE_END_GAP
	return [anchor, anchor + span.normalized() * maxf(length, 0.5)]


func _impose() -> void:
	var def := bridge.registry.resolve(law_id, bridge.form(self))
	var shape: String = def.scope.shape
	machine.impose_act(IMPOSE_TICKS)
	_play("Interact", 0.05, 2.4)
	if shape == "PAIR":
		# The Counterpart's verb: nothing is bound yet. The blade is armed,
		# and the next two it is shown to are the pair.
		marking = true
		marks = []
		_mark_left = MARK_TICKS
		_mark_commit = _commit_for(impose_ticks)
		Sfx.play_at("dodge", global_position, -4.0, 1.4)
		return
	var args: Dictionary = {}
	if shape == "LINE":
		var ends := line_preview(true)
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		args["line"] = [roundi(a.x * 100.0), roundi(a.z * 100.0), roundi(b.x * 100.0), roundi(b.z * 100.0)]
	args["commit"] = _commit_for(impose_ticks)
	var rec := bridge.impose(self, law_id, args)
	Sfx.play_at("seal" if rec.verdict == "APPLIED" else "denied", global_position, 0.0, 1.0)


func _on_struck(info: Dictionary) -> void:
	if not marking or info.attacker != self:
		return
	if not (info.kind in ["hit", "guarded", "held"]):
		return
	var shown: Actor = info.defender
	if marks.has(shown):
		return
	marks.append(shown)
	if marks.size() < 2:
		return
	marking = false
	var first: Actor = marks[0]
	var rec := bridge.impose(self, law_id, {"pair": [first.entity_id, shown.entity_id], "commit": _mark_commit})
	Sfx.play_at("seal" if rec.verdict == "APPLIED" else "denied", shown.global_position, 0.0, 1.2)


func _on_noted(owner_id: int, noted_law: String, clause: String, amount: int) -> void:
	if owner_id == entity_id:
		recognition.observe(noted_law, clause, amount)


# -------------------------------------------------------------- instrument

func _wanted_instrument() -> String:
	if instrument_lock != "":
		return instrument_lock
	var root: String = bridge.registry.resolve(law_id).get("root", "")
	return instruments.get("roots", {}).get(root, "counterpart")


func _has_boundary() -> Dictionary:
	for law: Dictionary in bridge.laws_of(self, team):
		if law.shape == "LINE" or law.shape == "RING":
			return law
	return {}


## Keep what is in the hands, and the moves that go with it, in step with
## the law in hand, the form, and (for the Lintel) whether it is planted.
## Never mid-action: a moveset does not change under a swing.
func _update_instrument(force: bool = false) -> void:
	if instruments.is_empty() or (machine.busy() and not force):
		return
	var id := _wanted_instrument()
	var inst: Dictionary = instruments.instruments[id]
	var form := bridge.form(self)
	var boundary: Dictionary = {}
	if instrument_lock == "" and inst.get("verb", "") == "plant":
		boundary = _has_boundary()
	var key := "%s|%s|%s" % [id, form, str(boundary.get("law", 0))]
	if key == _equipped:
		return
	_equipped = key
	instrument_id = id
	instrument = inst
	planted = not boundary.is_empty()
	var moveset: Dictionary = LawRegistry.read_json(inst.planted_moveset if planted else inst.moveset)
	var was_guarding := machine.guarding()
	machine = ActionMachine.new(moveset, form == "UNVEILED")
	idle_clip = moveset.get("idle", "Idle")
	guard_chip_pct = moveset.get("guard_chip_pct", 30)
	if was_guarding:
		machine.tick(false, false, false, true)
	var held: Dictionary = inst.held_planted if planted else inst.held[form]
	if model != null:
		model.set_held(held.get("right", ""), held.get("left", ""))
	_place_planted(boundary, inst, form)


## The Lintel's verb: while your line stands, the stave stands on it.
func _place_planted(boundary: Dictionary, inst: Dictionary, form: String) -> void:
	if _planted_prop != null and is_instance_valid(_planted_prop):
		_planted_prop.queue_free()
	_planted_prop = null
	if boundary.is_empty() or not inst.has("planted_model"):
		return
	var scene := load(inst.planted_model[form]) as PackedScene
	if scene == null:
		return
	_planted_prop = scene.instantiate()
	get_parent().add_child(_planted_prop)
	var at := Vector3.ZERO
	if boundary.shape == "LINE":
		var l: Array = boundary.args.line
		at = Vector3((l[0] + l[2]) / 200.0, 0.0, (l[1] + l[3]) / 200.0)
		_planted_prop.rotation.y = atan2(float(l[2] - l[0]), float(l[3] - l[1])) + PI * 0.5
	else:
		var c: Array = boundary.args.centre
		at = Vector3(c[0] / 100.0, 0.0, c[1] / 100.0)
	_planted_prop.position = at + Vector3.UP * PLANT_HEIGHT


func planted_at() -> Vector3:
	if _planted_prop != null and is_instance_valid(_planted_prop):
		return _planted_prop.position
	return Vector3.INF


# ------------------------------------------------------------------ lock-on

func _find_lock(look: Vector3) -> Actor:
	var best: Actor = null
	var best_score := -INF
	for id: int in bridge.actors:
		var other: Actor = bridge.actors[id]
		if other.team == team or other.machine.dead() or other.yielded:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > LOCK_RANGE or d < 0.01:
			continue
		var score := look.dot(to / d) * 2.0 - d / LOCK_RANGE
		if score > best_score:
			best_score = score
			best = other
	return best
