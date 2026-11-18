class_name Voss
extends Enemy
## Aurel Voss, the Last Arbiter. The slice's Sovereign.
##
## He fights as any Court enemy does (Enemy), and on top of that he conducts
## a hearing in three phases, read from data/enemies/voss.json:
##   Arraignment        one Writ at a time, each spoken before it is enforced
##   Cross-examination  two Writs together; he turns his back to tempt a
##                      strike his Writ of Standing forbids
##   The Hearing        his Edict: no one may repeat their own last act,
##                      himself included, so he chooses only acts it permits
## Where his stamp lands it leaves a Seal. Brought low, he yields.

signal spoke(text: String)

const MAX_SEALS := 3
const SEAL_AHEAD := 2.5
const BAIT_TICKS := 55
const BAIT_CHANCE := 0.006        # per tick, while circling under the Writ of Standing
const IMPOSE_POSE_TICKS := 34

var phase: int = -1
var seals: Array = []
var _boss: Dictionary = {}
var _writ_index: int = 0
var _bait: int = 0
## False while he waits in his Hall for the Witness to come in: he says nothing yet.
var hearing_open: bool = true


func _init() -> void:
	super._init()
	load_archetype("voss")
	_boss = archetype.boss


func _ready() -> void:
	super._ready()
	yields_at = max_hp * int(_boss.yield_pct) / 100


func title() -> String:
	return archetype.get("title", "")


## He has a figure of his own and the Imprimatur in his hand.
func instrument_ok() -> bool:
	return model != null and model.skeleton != null and model.skeleton.get_node_or_null("handslot_r") != null


## Fractions of his health at which the hearing turns, for the HUD.
func phase_marks() -> Array:
	var out: Array = []
	for ph: Dictionary in _boss.phases:
		if int(ph.above_pct) > 0:
			out.append(float(int(ph.above_pct)) / 100.0)
	return out


func phase_name() -> String:
	if phase < 0:
		return ""
	return _boss.phases[phase].name


func _think() -> void:
	if yielded:
		lock_target = null
		return
	_clean_seals()
	if hearing_open:
		_enter_phase()
	if ai_enabled and (bridge.tick + entity_id) % UPKEEP_EVERY == 0:
		bridge.grant(self, int(_boss.get("resonance_per_upkeep", 5)))
		_keep_agenda()
	if _bait > 0 and ai_enabled and _valid(target) and not machine.busy():
		# Cross-examination: he shows his back. To strike it is to be denied.
		_bait -= 1
		lock_target = null
		_turn_to(_yaw_to(target.global_position) + PI, 1.0 / 60.0, 6.0)
		return
	_bait = 0
	super._think()
	var ph: Dictionary = _boss.phases[phase]
	if ai_enabled and ph.get("baits", false) and mode == Mode.CIRCLE and not machine.busy() \
			and not bridge.world.find_law(entity_id, "voss.writ_of_standing").is_empty() \
			and bridge.rng.randf() < BAIT_CHANCE:
		_bait = BAIT_TICKS


func _enter_phase() -> void:
	var pct := hp() * 100 / max_hp
	var now := 0
	for i in _boss.phases.size():
		if pct > int(_boss.phases[i].above_pct):
			now = i
			break
		now = i
	if now == phase:
		return
	phase = now
	spoke.emit(String(_boss.phases[phase].get("says", "")))


## Keep the laws this phase calls for standing: its Edict if it has one,
## then as many Writs as it allows, taken in turn. Each is announced.
func _keep_agenda() -> void:
	if machine.busy() or phase < 0:
		return
	var ph: Dictionary = _boss.phases[phase]
	var edict: String = ph.get("edict", "")
	if edict != "" and bridge.world.find_law(entity_id, edict).is_empty():
		_proclaim(edict)
		return
	var writs: Array = ph.writs
	var standing := 0
	for id: String in writs:
		if not bridge.world.find_law(entity_id, id).is_empty():
			standing += 1
	if standing >= int(ph.standing):
		return
	for step in writs.size():
		var id: String = writs[(_writ_index + step) % writs.size()]
		if bridge.world.find_law(entity_id, id).is_empty():
			if _proclaim(id):
				_writ_index = (_writ_index + step + 1) % writs.size()
			return


func _proclaim(def_id: String) -> bool:
	var def := bridge.registry.resolve(def_id)
	if bridge.resonance(entity_id) < int(def.price.get("resonance", 0)):
		return false
	var rec := bridge.impose(self, def_id)
	if rec.verdict != "APPLIED":
		return false
	bridge.declare(self, def_id)  # he says every rule before he enforces it
	spoke.emit("%s. %s" % [def.name, def.thesis])
	machine.impose_act(IMPOSE_POSE_TICKS)
	_play("Spellcast_Shoot", 0.1, 0.9)
	Sfx.play_at("seal", global_position, 4.0, 0.7)
	return true


## What he may do next. Under The Hearing he will not make the same
## argument twice: the act he opens with is never his last one.
func _choose_attack(d: float) -> void:
	if d > _far:
		_enter(Mode.APPROACH, 0)
		return
	var last: String = bridge.world.entities[entity_id].last_act
	var hearing := not bridge.world.find_law(entity_id, "voss.the_hearing").is_empty()
	var open_with := "stamp" if bridge.rng.randf() < _p_heavy else "sweep"
	if hearing and open_with == last:
		open_with = "sweep" if open_with == "stamp" else "stamp"
	mode = Mode.ATTACK
	if open_with == "stamp":
		press_heavy = true
		if phase >= 1 and bridge.rng.randf() < 0.45:
			_queued.append([int(machine.moves["stamp"].cancel_whiff), "heavy"])    # on into the circle
	else:
		press_light = true
		if bridge.rng.randf() < _p_double:
			_queued.append([int(machine.moves["sweep"].cancel_whiff), "light"])    # on into the thrust


func _on_begin(what: String) -> void:
	super._on_begin(what)
	if what == "active" and machine.move().get("act", "") == "stamp":
		_leave_seal()


func _leave_seal() -> void:
	while seals.size() >= MAX_SEALS:
		_remove_seal(seals[0])
	var seal := Seal.new()
	seal.bridge = bridge
	var at := global_position + forward() * SEAL_AHEAD
	seal.position = Vector3(at.x, 0.0, at.z)
	get_parent().add_child(seal)
	seals.append(seal)
	Sfx.play_at("seal", seal.position, 6.0, 0.55)


func _clean_seals() -> void:
	for s: Variant in seals.duplicate():
		if not is_instance_valid(s) or s.spent:
			_remove_seal(s)


func _remove_seal(s: Variant) -> void:
	seals.erase(s)
	if is_instance_valid(s):
		bridge.retire(s)
		s.queue_free()


func clear_seals() -> void:
	for s: Variant in seals.duplicate():
		_remove_seal(s)


func on_yield() -> void:
	ai_enabled = false
	lock_target = null
	_queued.clear()
	clear_seals()
	machine.revive()
	idle_clip = "Sit_Floor_Idle"
	_play("Sit_Floor_Down", 0.2, 1.0)
	spoke.emit(String(_boss.get("yields", "")))
