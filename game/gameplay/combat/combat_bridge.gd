class_name CombatBridge
extends Node
## The only door between the node world and the Law Engine.
##
## Actors say what they attempted (a strike that reached someone, a step, a
## law they want to impose). The bridge tags the attempt, asks LawWorld what
## happened, and tells the actors and the presentation layer the answer.
## Nothing outside this file and core/ changes health, resonance or laws.

## Every strike the engine has judged. info: kind, attacker, defender, at,
## amount, heavy, rec. kind is one of: hit, guarded, parried, denied,
## converted, held, dodged, perfect_dodge.
signal struck(info: Dictionary)
## A record the HUD should show as a verdict line, with where it happened.
signal verdict(rec: Dictionary, at: Vector3)
## A law's harm reached someone. info: kind (mirrored, returned, copied,
## paid_forward, debt_due, sanction, defaulted), target, at, amount.
signal consequence(info: Dictionary)
signal law_ended(def_id: String, owner: Actor, reason: String)
## A clause of someone's law has spoken: which, and how much it moved.
## Recognition Trials listen to this.
signal noted(owner_id: int, law_id: String, clause: String, amount: int)
signal unveiled(actor: Actor)
signal actor_yielded(actor: Actor)
signal actor_died(actor: Actor)
## A Vow was sworn, kept, or fell. `what` is "sworn", "kept" or "fell".
signal vow_changed(actor: Actor, what: String, def_id: String)

const BEHIND_DOT := -0.25       # facing . direction-to-attacker below this is "from behind"
const GUARD_CHIP_PCT := 30
const PARRY_POISE := 30
const GAIN_PERFECT_DODGE := 12
const GAIN_PERFECT_PARRY := 18
const SHOWN := ["REJECTION", "OVERRIDE", "CONTEST", "CANCELLATION", "CONVERSION"]
const LOGGED := ["REJECTION", "OVERRIDE", "CONTEST", "CANCELLATION", "CONVERSION", "BREACH", "KEPT"]
const CONSEQUENCES := ["defaulted", "mirrored", "returned", "copied", "paid_forward", "debt_due", "sanction", "forfeit"]
const LOG_LIMIT := 4000
const UNVEIL_SHOCK := 6.5       # metres

var registry: LawRegistry
var world: LawWorld
var actors: Dictionary = {}     # entity id -> Actor
var tick: int = 0
var rng := RandomNumberGenerator.new()
var log_lines: Array = []       # the verdict log: one line per judged interaction


func _init() -> void:
	registry = LawRegistry.new()
	registry.load_roots("res://data/roots.json")
	registry.load_laws_dir("res://data/laws")
	world = LawWorld.new(registry)
	rng.seed = 20261110
	process_physics_priority = 100   # after every actor has moved this tick


# ------------------------------------------------------------ registration

func register(actor: Actor) -> int:
	var id: int = world.add_entity({
		"id": world.entities.size() + 1, "name": actor.display_name, "team": actor.team,
		"tags": actor.tags, "hp": actor.max_hp, "pos": to_cm(actor.global_position),
		"resonance": actor.start_resonance,
	})
	actors[id] = actor
	return id


func unregister(actor: Actor) -> void:
	actors.erase(actor.entity_id)


## An actor leaving the field (an encounter cleared away). Its laws end.
func retire(actor: Actor) -> void:
	world.retire(actor.entity_id)
	actors.erase(actor.entity_id)


static func to_cm(p: Vector3) -> Array:
	return [roundi(p.x * 100.0), roundi(p.z * 100.0)]


# ------------------------------------------------------------------ queries

func hp(id: int) -> int:
	return world.entities[id].hp


func hp_max(id: int) -> int:
	return world.entities[id].hp_max


func resonance(id: int) -> int:
	return world.entities[id].resonance


func form(actor: Actor) -> String:
	return world.entities[actor.entity_id].form


# -------------------------------------------------------------------- vows
# A Vow is a law of tier VOW that its author swears against themselves
# (data/laws/vow.json). The engine judges it; this only asks and reports.

## Every Vow that can be sworn, in the order a stone offers them.
func vows() -> Array:
	var out: Array = []
	for id: String in registry.defs:
		var def := registry.resolve(id)
		if def.get("tier", "") == "VOW":
			out.append(def)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return out


## The Vow an actor has standing (its definition), or {}.
func vow_of(actor: Actor) -> Dictionary:
	for law: Dictionary in world.laws:
		if law.active and law.owner == actor.entity_id:
			var def := registry.resolve(law.def_id, law.form)
			if def.get("tier", "") == "VOW":
				return def
	return {}


## What an actor's word weighs: added to the authority of every law they impose.
func standing(actor: Actor) -> int:
	return int(world.entities[actor.entity_id].get("standing", 0))


## One Vow at a time. False if one already stands or a law refuses it.
func swear(actor: Actor, def_id: String) -> bool:
	if not vow_of(actor).is_empty() or registry.resolve(def_id).get("tier", "") != "VOW":
		return false
	var rec := world.impose(actor.entity_id, def_id, {})
	if rec.verdict == "APPLIED":
		_log_line("SWORN", def_id, String(registry.resolve(def_id).thesis), actor.entity_id, 0)
		vow_changed.emit(actor, "sworn", def_id)
	_after(rec, actor.global_position + Vector3.UP * 1.6)
	return rec.verdict == "APPLIED"


## What the actor swore against has been done. False if nothing was sworn.
func keep_vows(actor: Actor) -> bool:
	var rec := world.keep(actor.entity_id)
	_after(rec, actor.global_position + Vector3.UP * 1.6)
	for o: Dictionary in rec.outcomes:
		if o.type == "KEPT":
			vow_changed.emit(actor, "kept", o.law)
	return rec.verdict == "APPLIED"


func forget_standing(actor: Actor) -> void:
	world.forget_standing(actor.entity_id)


func _vows_fallen(rec: Dictionary) -> void:
	for o: Dictionary in rec.outcomes:
		if o.type == "BREACH" and o.has("law") and registry.resolve(o.law).get("tier", "") == "VOW":
			vow_changed.emit(actors.get(o.owner), "fell", o.law)
	for c: Dictionary in rec.children:
		_vows_fallen(c)


## The actor speaks one of its standing laws aloud: every side can read it.
func declare(owner: Actor, def_id: String) -> bool:
	return world.declare(owner.entity_id, def_id)


## Laws standing that belong to an actor, with how well `team` knows each.
func laws_of(owner: Actor, team: int) -> Array:
	var out: Array = []
	for law: Dictionary in world.laws:
		if law.active and law.owner == owner.entity_id:
			var def := registry.resolve(law.def_id, law.form)
			out.append({"id": law.def_id, "name": def.name, "thesis": def.thesis,
				"known": world.knowledge_level(team, law.def_id),
				"ticks_left": law.ticks_left, "ticks": def.term.ticks,
				"events_left": law.events_left, "events": def.term.get("events", 0),
				"form": law.form, "shape": def.scope.shape, "args": law.args, "law": law.id})
	return out


## What `debtor` owes under any law of `creditor` that has not come due.
func owed_by(debtor: Actor, creditor: Actor) -> int:
	var sum := 0
	for h: Dictionary in world.held:
		if h.target == debtor.entity_id and h.release == "INVOKE" and _law_owner(h.law) == creditor.entity_id:
			sum += h.amount
	return sum


## Harm an actor has deferred and still owes: [{amount, ticks}], soonest first.
func debts_of(actor: Actor) -> Array:
	var out: Array = []
	for h: Dictionary in world.held:
		if h.target == actor.entity_id and h.release == "DUE":
			out.append({"amount": h.amount * (100 + h.interest) / 100, "ticks": h.due - world.tick})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ticks < b.ticks)
	return out


## How many of a team are mid-strike, other than `except`. Enemies use this
## so that a group takes turns instead of all swinging at once.
func attackers(team: int, except: Actor) -> int:
	var n := 0
	for id: int in actors:
		var a: Actor = actors[id]
		if a != except and a.team == team and a.machine.state == ActionMachine.S.ATTACK:
			n += 1
	return n


## Would moving to `to` carry this actor over a line of its own?
func would_breach(actor: Actor, to: Vector3) -> bool:
	return world.would_breach(actor.entity_id, to_cm(to))


func _law_owner(law_id: int) -> int:
	for law: Dictionary in world.laws:
		if law.id == law_id:
			return law.owner
	return 0


# --------------------------------------------------------------- the tick

func _physics_process(_delta: float) -> void:
	tick += 1
	for id: int in actors:
		var a: Actor = actors[id]
		var e: Dictionary = world.entities[id]
		if not e.alive or a.immovable:
			continue
		var p := to_cm(a.global_position)
		if p == e.pos:
			continue
		var rec := world.move(id, p)
		if rec.verdict == "REJECTED":
			# A law refused the step. One attempt, one refusal: the actor is
			# put back and knocked off the line so it cannot grind against it.
			a.bounce_back(Vector3(e.pos[0] / 100.0, a.global_position.y, e.pos[1] / 100.0))
		_after(rec, a.global_position + Vector3.UP * 1.2)
	var before := world.records.size()
	world.advance(1)
	# Whatever came due on its own this tick: debts, mostly.
	for i in range(before, world.records.size()):
		var rec: Dictionary = world.records[i]
		if rec.kind != "LAW_END":
			var where := Vector3.ZERO
			if actors.has(rec.target):
				where = actors[rec.target].global_position + Vector3.UP * 1.2
			_after(rec, where)
	for rec: Dictionary in world.records:
		if rec.kind == "LAW_END":
			_log_line("ENDED", rec.law, rec.reason, rec.owner, 0)
			law_ended.emit(rec.law, actors.get(rec.owner), rec.reason)
	_sync_deaths()
	world.records.clear()


# ----------------------------------------------------------------- strikes

## An attacker's weapon has reached a defender during its active ticks.
func resolve_strike(attacker: Actor, defender: Actor, m: Dictionary) -> void:
	if defender.yielded:
		return                      # the fight with them is over
	var at := defender.global_position + Vector3.UP * 1.1
	var heavy: bool = m.get("poise", 0) >= 25
	var dm: ActionMachine = defender.machine
	if dm.invulnerable():
		var perfect := dm.perfect_dodge()
		if perfect:
			world.add_resonance(defender.entity_id, GAIN_PERFECT_DODGE)
		struck.emit({"kind": "perfect_dodge" if perfect else "dodged", "attacker": attacker,
			"defender": defender, "at": at, "amount": 0, "heavy": heavy, "rec": {}})
		return

	var to_attacker := attacker.global_position - defender.global_position
	to_attacker.y = 0.0
	var from_behind := to_attacker.length() > 0.01 and defender.forward().dot(to_attacker.normalized()) < BEHIND_DOT
	var tags: Array = ["from_behind" if from_behind else "from_front"]
	tags.append_array(attacker.swing_tags)
	var amount: int = m.damage
	var parried := false
	var guarded := false
	if dm.guarding() and not from_behind:
		if dm.parrying():
			parried = true
			amount = 0
			tags.append("perfect_parry")
		else:
			guarded = true
			amount = amount * defender.guard_chip_pct / 100
			tags.append("guarded")
	var data := {"act": m.get("act", ""), "combo_index": attacker.machine.combo_index, "weight": int(m.damage), "swing": attacker.swing_serial}
	var rec := world.strike(attacker.entity_id, defender.entity_id, amount, tags, data)

	if parried:
		world.add_resonance(defender.entity_id, GAIN_PERFECT_PARRY)
		defender.on_parry_success()
	var kind := "hit"
	if rec.verdict == "REJECTED":
		kind = "denied"
		attacker.on_denied(defender)
	elif rec.verdict == "CONVERTED":
		# The blow was turned into something else (answered in kind).
		kind = "converted"
		attacker.on_parried(PARRY_POISE)
	elif parried:
		kind = "parried"
		attacker.on_parried(PARRY_POISE)
	elif guarded:
		kind = "guarded"
		attacker.machine.mark_connected()
		defender.on_guard_hit(attacker, m)
	else:
		# The body is struck even when a law holds the harm for later.
		if not rec.children.is_empty() and rec.children[0].verdict == "HELD":
			kind = "held"
		attacker.machine.mark_connected()
		world.add_resonance(attacker.entity_id, m.get("gain", 0))
		defender.on_hit(attacker, m)
	var stop: int = m.get("hitstop", 4) if kind != "parried" and kind != "converted" else 7
	attacker.machine.hit_stop(stop)
	defender.machine.hit_stop(stop)

	struck.emit({"kind": kind, "attacker": attacker, "defender": defender, "at": at,
		"amount": amount, "heavy": heavy, "rec": rec})
	_after(rec, at)
	_sync_deaths()


# -------------------------------------------------------------------- laws

func impose(owner: Actor, def_id: String, args: Dictionary = {}) -> Dictionary:
	var rec := world.impose(owner.entity_id, def_id, args)
	if rec.verdict == "APPLIED":
		_log_line("IMPOSED", def_id, "authority %d" % world.find_law(owner.entity_id, def_id).get("authority", 0), owner.entity_id, 0)
	_after(rec, owner.global_position + Vector3.UP * 1.6)
	return rec


## A strike is about to be made with the Axiom button held. If its author
## has a law standing that can be inscribed on a strike, and can pay, the
## cost is taken now and the tag returned.
func begin_inscription(actor: Actor) -> String:
	for law: Dictionary in world.laws:
		if not law.active or law.owner != actor.entity_id:
			continue
		var ins: Dictionary = registry.resolve(law.def_id, law.form).get("inscribe", {})
		if not ins.is_empty() and resonance(actor.entity_id) >= ins.cost:
			world.add_resonance(actor.entity_id, -ins.cost)
			return ins.tag
	return ""


func set_form(actor: Actor, to: String) -> void:
	world.set_form(actor.entity_id, to)


## The first Revelation. The actor's laws take their Unveiled form from now
## on, their Resonance is made whole, and everyone hostile within a few
## metres is thrown back off their feet. It harms no one.
func unveil(actor: Actor) -> void:
	world.set_form(actor.entity_id, "UNVEILED")
	world.add_resonance(actor.entity_id, 100)
	_log_line("UNVEILED", "", "the Instrument wakes", actor.entity_id, 0)
	for id: int in actors:
		var other: Actor = actors[id]
		if other.team != actor.team and other.global_position.distance_to(actor.global_position) <= UNVEIL_SHOCK:
			other.on_shock(actor)
	unveiled.emit(actor)


## Resting place: whole again, and full of Resonance. Practice yard only.
func rest(actor: Actor) -> void:
	world.restore(actor.entity_id)
	world.add_resonance(actor.entity_id, 100)


func grant(actor: Actor, amount: int) -> void:
	world.add_resonance(actor.entity_id, amount)


# ------------------------------------------------------- after every record

func _after(rec: Dictionary, at: Vector3) -> void:
	_digest(rec)
	_log(rec)
	_tell(rec)
	_vows_fallen(rec)
	if _worth_showing(rec):
		verdict.emit(rec, at)


## Find every harm a law did inside this record and tell whoever suffered it.
func _digest(rec: Dictionary) -> void:
	if rec.kind == "HARM" and rec.verdict == "APPLIED" and rec.amount_out > 0 and rec.tags.has("by_law"):
		var kind := "law"
		for k: String in CONSEQUENCES:
			if rec.tags.has(k):
				kind = k
				break
		var target: Actor = actors.get(rec.target)
		_log_line(kind.to_upper(), "", "%d harm by law" % rec.amount_out, rec.source, rec.target)
		if target != null:
			target.on_law_harm(kind, rec.amount_out)
			consequence.emit({"kind": kind, "target": target, "amount": rec.amount_out,
				"at": target.global_position + Vector3.UP * 1.1})
	for c: Dictionary in rec.children:
		_digest(c)


func _tell(rec: Dictionary) -> void:
	for o: Dictionary in rec.outcomes:
		if o.has("clause"):
			noted.emit(o.owner, o.law, o.clause, o.amount)
	for c: Dictionary in rec.children:
		_tell(c)


func _worth_showing(rec: Dictionary) -> bool:
	if rec.kind == "IMPOSE" and rec.verdict == "REJECTED":
		return true
	return _has_shown(rec)


func _has_shown(rec: Dictionary) -> bool:
	for o: Dictionary in rec.outcomes:
		if SHOWN.has(o.type) and o.has("law"):
			return true
	for c: Dictionary in rec.children:
		if _has_shown(c):
			return true
	return false


# ---------------------------------------------------------------- the log
# Plain text, one line per interaction, so that a fight can be read back,
# compared with another, or shared. This is the Codex's "Record" page.

func _log(rec: Dictionary) -> void:
	for o: Dictionary in rec.outcomes:
		# A law quietly changing a strike (a gate strike, a garnished hand, a
		# recognition) is worth a line too; copies and mirrors log as harm.
		var quiet: bool = o.type == "EFFECT" and o.has("clause") and rec.kind == "STRIKE"
		if (LOGGED.has(o.type) or quiet) and (o.has("law") or rec.kind == "IMPOSE"):
			var text: String = o.reason
			if o.has("over"):
				text += " (over %s)" % registry.resolve(o.over).get("name", o.over)
			_log_line(o.type, o.get("law", ""), text, rec.source, rec.target if rec.target != rec.source else 0)
	for c: Dictionary in rec.children:
		_log(c)


func _log_line(type: String, def_id: String, text: String, source: int, target: int) -> void:
	var law_name: String = registry.resolve(def_id).get("name", "") if def_id != "" else ""
	var who: String = world.entities[source].name if world.entities.has(source) else "?"
	if target != 0 and world.entities.has(target):
		who += " -> " + world.entities[target].name
	log_lines.append("%6d  %-12s  %-18s  %s  [%s]" % [tick, type, law_name, text, who])
	if log_lines.size() > LOG_LIMIT:
		log_lines = log_lines.slice(LOG_LIMIT / 4)


func export_log(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("  tick  outcome       law                 what happened  [who -> whom]\n")
	f.store_string("\n".join(log_lines) + "\n")
	f.close()
	return true


func _sync_deaths() -> void:
	for id: int in actors:
		var a: Actor = actors[id]
		if a.yields_at > 0 and not a.yielded and world.entities[id].hp <= a.yields_at:
			# He yields; he is not killed. His laws end with the fight.
			world.spare(id, a.yields_at)
			a.yielded = true
			_log_line("YIELDED", "", "the fight is over", id, 0)
			a.on_yield()
			actor_yielded.emit(a)
			continue
		if not world.entities[id].alive and not a.machine.dead():
			a.on_death()
			actor_died.emit(a)
