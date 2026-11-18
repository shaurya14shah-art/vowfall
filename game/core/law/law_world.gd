class_name LawWorld
extends RefCounted
## The Law Engine: a deterministic simulation of entities, the laws imposed
## on them, and every event those laws judge.
##
## Rules of this file (see docs/04_law_engine.md):
##   * No nodes, no floats, no wall clock, no unseeded randomness.
##   * No law is named here. Behaviour comes from data in data/laws/.
##   * Every event goes through the same pipeline and leaves a record that
##     says what happened and why, in words the Codex can show a player.

const MAX_DEPTH := 8
const CONTEST_MARGIN := 2
const READ_THRESHOLD := 3
const STAGES: Array[String] = ["NOTICE", "DENY", "REDIRECT", "MODIFY", "HOLD"]
const GATE_STAGES: Array[String] = ["DENY", "REDIRECT", "HOLD"]
const RANK := {"FUNDAMENTAL": 1, "TECHNIQUE": 2, "MANIFESTATION": 3, "EDICT": 4, "VOW": 1}
## The most a word can weigh. Standing is added to the authority of every
## law its holder imposes; it comes only from kept Vows.
const STANDING_MAX := 9
const SPECIFICITY := {"SELF": 4, "TARGET": 4, "PAIR": 3, "LINE": 3, "RING": 2, "ZONE": 2, "FIELD": 1}

var registry: LawRegistry
var tick: int = 0
var seq: int = 0
var entities: Dictionary = {}   # id -> entity
var laws: Array = []            # active law instances, in order of imposition
var held: Array = []            # deferred consequences (debts)
var knowledge: Dictionary = {}  # team -> {law id: times witnessed}
var records: Array = []         # resolution log, not part of the saved state


func _init(reg: LawRegistry) -> void:
	registry = reg


# ---------------------------------------------------------------- entities

func add_entity(spec: Dictionary) -> int:
	var id: int = spec.get("id", entities.size() + 1)
	var tags: Dictionary = {}
	for t: String in spec.get("tags", []):
		tags[t] = 0
	var hp: int = spec.get("hp", 100)
	var pos: Array = spec.get("pos", [0, 0])
	entities[id] = {
		"id": id, "name": spec.get("name", "entity_%d" % id), "team": spec.get("team", 0),
		"tags": tags, "hp": hp, "hp_max": spec.get("hp_max", hp),
		"resonance": spec.get("resonance", 100), "resonance_max": spec.get("resonance_max", 100),
		"mastery": spec.get("mastery", 0), "standing": spec.get("standing", 0),
		"form": spec.get("form", "DORMANT"), "pos": pos.duplicate(),
		"alive": true, "last_act": "", "last_swing": 0,
	}
	return id


## Adds a tag. ticks = 0 means until removed.
func add_tag(id: int, tag: String, ticks: int = 0) -> void:
	if entities.has(id):
		entities[id].tags[tag] = 0 if ticks <= 0 else tick + ticks


## Resonance is earned with the hands: landed strikes, perfect dodges and
## parries. The combat layer reports them here. The only other things that
## raise it are a rest and a kept Vow (see `keep`).
func add_resonance(id: int, amount: int) -> void:
	if entities.has(id):
		var e: Dictionary = entities[id]
		e.resonance = clampi(e.resonance + amount, 0, e.resonance_max)


## Rest: health back to full, and back on their feet. Used by resting
## places and training posts, never in the middle of resolving an event.
func restore(id: int) -> void:
	if entities.has(id):
		var e: Dictionary = entities[id]
		e.hp = e.hp_max
		e.alive = true


## A Vow is kept: whatever it was sworn against has been done without
## breaking it. Every Vow its author has standing ends, kept, and pays its
## reward: Resonance, and standing. A Vow is a law of tier VOW (docs/03).
func keep(owner: int) -> Dictionary:
	var rec := {"tick": tick, "event": 0, "kind": "KEEP", "source": owner, "target": owner, "tags": [],
		"amount_in": 0, "amount_out": 0, "verdict": "REJECTED", "outcomes": [], "children": []}
	if entities.has(owner) and entities[owner].alive:
		var e: Dictionary = entities[owner]
		for law: Dictionary in laws:
			if not law.active or law.owner != owner or _def(law).tier != "VOW":
				continue
			var reward: Dictionary = _def(law).get("reward", {})
			var weight: int = reward.get("standing", 0)
			e.resonance = clampi(e.resonance + int(reward.get("resonance", 0)), 0, e.resonance_max)
			e["standing"] = mini(STANDING_MAX, int(e.get("standing", 0)) + weight)
			rec.verdict = "APPLIED"
			_note(rec, "KEPT", law, {}, "the vow was kept", "kept", weight)
			_end_law(law, "it was kept")
	records.append(rec)
	_purge()
	return rec


## Standing does not outlast a rest: a word weighs what it has just been
## shown to be worth.
func forget_standing(id: int) -> void:
	if entities.has(id):
		entities[id]["standing"] = 0


## DORMANT or UNVEILED. Laws already standing keep the form they were
## imposed in; the next one imposed uses the new form.
func set_form(id: int, form: String) -> void:
	if entities.has(id):
		entities[id].form = form


## One who yields is not killed: back on their feet with a little health,
## and every law of theirs ended. The fight is over for them.
func spare(id: int, hp: int) -> void:
	if not entities.has(id):
		return
	var e: Dictionary = entities[id]
	e.alive = true
	e.hp = maxi(1, hp)
	for law: Dictionary in laws:
		if law.active and law.owner == id:
			_end_law(law, "its author yielded")
	_purge()


## Leaves the field for good (an encounter being cleared away). Its laws end.
func retire(id: int) -> void:
	if entities.has(id):
		entities[id].alive = false
		entities[id].hp = 0
		_check_breaches()
		_purge()


## Would this step end one of the mover's own laws? Lets a body refuse to be
## carried over its own line by a lunge. It changes nothing.
func would_breach(id: int, to: Array) -> bool:
	if not entities.has(id):
		return false
	var here: Array = entities[id].pos
	for law: Dictionary in laws:
		if not law.active or law.owner != id:
			continue
		for b: Dictionary in _def(law).get("breach", []):
			if b.type == "OWNER_CROSSES" and _crosses(law, here, to):
				return true
	return false


func has_tag(id: int, tag: String) -> bool:
	return entities.has(id) and entities[id].tags.has(tag)


# ------------------------------------------------------------- public acts
# Each returns the record of what happened. Gameplay code never changes hp,
# position or laws directly: it proposes, the engine disposes.

func strike(source: int, target: int, amount: int, tags: Array = [], data: Dictionary = {}) -> Dictionary:
	var t := tags.duplicate()
	if not t.has("by_law") and not t.has("by_hand"):
		t.append("by_hand")
	return _top(_event("STRIKE", source, target, amount, t, data))


func heal(source: int, target: int, amount: int) -> Dictionary:
	return _top(_event("HEAL", source, target, amount, ["by_hand"], {}))


func move(id: int, to: Array) -> Dictionary:
	var ev := _event("MOVE", id, id, 0, ["by_hand"], {})
	ev.to = to.duplicate()
	return _top(ev)


## args: line [x1,y1,x2,y2] | pair [a,b] | target id | centre [x,y] | commit n
func impose(owner: int, def_id: String, args: Dictionary = {}) -> Dictionary:
	var target := owner
	var pair: Array = args.get("pair", [])
	if not pair.is_empty():
		target = pair[0]
	elif args.has("target"):
		target = args["target"]
	return _top(_event("IMPOSE", owner, target, 0, ["by_hand"], {"def": def_id, "args": args.duplicate(true)}))


func advance(ticks: int) -> void:
	for i in ticks:
		tick += 1
		for id: int in entities:
			var tags: Dictionary = entities[id].tags
			for t: String in tags.keys():
				if tags[t] > 0 and tags[t] <= tick:
					tags.erase(t)
		var due: Array = []
		var keep: Array = []
		for h: Dictionary in held:
			if h.release == "DUE" and h.due <= tick:
				due.append(h)
			elif h.release == "INVOKE" and h.lapse <= tick:
				pass
			else:
				keep.append(h)
		held = keep
		for h: Dictionary in due:
			var amount: int = h.amount * (100 + h.interest) / 100
			var ev := _event(h.kind, h.source, h.target, amount, h.tags, {})
			ev.from = ev.to.duplicate()
			records.append(_resolve(ev))
		for law: Dictionary in laws:
			if law.active and law.ticks_left >= 0:      # below zero: no term in ticks (a Vow stands until kept or broken)
				law.ticks_left -= 1
				if law.ticks_left <= 0:
					_end_law(law, "its term ran out")
		_check_breaches()
		_purge()


# ------------------------------------------------------------------ queries

func find_law(owner: int, def_id: String) -> Dictionary:
	for law: Dictionary in laws:
		if law.active and law.owner == owner and law.def_id == def_id:
			return law
	return {}


## The author says a standing law aloud. Everyone present can then read it,
## as they can an Edict. False if the author has no such law standing.
func declare(owner: int, def_id: String) -> bool:
	if find_law(owner, def_id).is_empty():
		return false
	for team: String in _teams():
		if knowledge_level(int(team), def_id) < 2:
			_learn(team, def_id, READ_THRESHOLD)
	return true


func held_total(owner: int, def_id: String) -> int:
	var law := find_law(owner, def_id)
	if law.is_empty():
		return 0
	var sum := 0
	for h: Dictionary in held:
		if h.law == law.id:
			sum += h.amount
	return sum


## 0 unknown, 1 sensed (it has a name), 2 read (its clauses are visible).
func knowledge_level(team: int, def_id: String) -> int:
	var n: int = knowledge.get(str(team), {}).get(def_id, 0)
	if n >= READ_THRESHOLD:
		return 2
	return 1 if n > 0 else 0


# --------------------------------------------------------------- save state

func to_dict() -> Dictionary:
	var ids := entities.keys()
	ids.sort()
	var ents: Array = []
	for id: int in ids:
		ents.append(entities[id].duplicate(true))
	return {"version": 1, "tick": tick, "seq": seq, "entities": ents,
		"laws": laws.duplicate(true), "held": held.duplicate(true),
		"knowledge": knowledge.duplicate(true)}


static func from_dict(reg: LawRegistry, data: Dictionary) -> LawWorld:
	var d: Dictionary = LawRegistry.intify(data)
	var w := LawWorld.new(reg)
	w.tick = d.tick
	w.seq = d.seq
	for e: Dictionary in d.entities:
		w.entities[e.id] = e
	w.laws = d.laws
	w.held = d.held
	w.knowledge = d.knowledge
	return w


func state_hash() -> String:
	return JSON.stringify(to_dict(), "", true).sha256_text()


# ================================================================ pipeline

func _top(ev: Dictionary) -> Dictionary:
	var rec := _resolve(ev)
	records.append(rec)
	_check_breaches()
	_purge()
	return rec


func _event(kind: String, source: int, target: int, amount: int, tags: Array, data: Dictionary) -> Dictionary:
	seq += 1
	return {"id": seq, "kind": kind, "source": source, "target": target, "amount": amount,
		"tags": tags.duplicate(), "data": data.duplicate(true),
		"from": _pos(source), "to": _pos(target), "depth": 0, "voided": false}


func _pos(id: int) -> Array:
	if entities.has(id):
		var p: Array = entities[id].pos
		return p.duplicate()
	return [0, 0]


func _resolve(ev: Dictionary) -> Dictionary:
	var rec := {"tick": tick, "event": ev.id, "kind": ev.kind, "source": ev.source,
		"target": ev.target, "tags": ev.tags.duplicate(), "amount_in": ev.amount,
		"amount_out": 0, "verdict": "APPLIED", "outcomes": [], "children": []}
	var pending: Array = []
	if ev.depth > MAX_DEPTH:
		rec.verdict = "REJECTED"
		_note(rec, "CANCELLATION", {}, {}, "the chain of consequences folded in on itself")
		return rec
	var why := _validate(ev)
	if why != "":
		rec.verdict = "REJECTED"
		_note(rec, "REJECTION", {}, {}, why)
		return rec
	for stage: String in STAGES:
		for f: Dictionary in _settle(ev, _matching(ev, stage), rec):
			_apply(f, ev, rec, pending)
			if ev.voided:
				break
		if ev.voided:
			break
	if not ev.voided:
		_break_vows(ev, rec, pending)
		_commit(ev, rec, pending)
		for f: Dictionary in _matching(ev, "REACT"):
			_apply(f, ev, rec, pending)
		rec.amount_out = ev.amount
	for child: Dictionary in pending:
		child.depth = ev.depth + 1
		rec.children.append(_resolve(child))
	return rec


## Step 1: can this event exist at all? Returns the reason it cannot, or "".
func _validate(ev: Dictionary) -> String:
	if not entities.has(ev.source):
		return "there is no one to do it"
	var src: Dictionary = entities[ev.source]
	if ev.tags.has("by_hand") and not src.alive:
		return "the one who would act has fallen"
	if not entities.has(ev.target):
		return "there is nothing there to receive it"
	if ev.kind in ["STRIKE", "HARM", "HEAL"] and not entities[ev.target].alive:
		return "there is nothing there to receive it"
	if ev.kind != "IMPOSE":
		return ""
	var def := registry.resolve(ev.data.def, src.form)
	if def.is_empty():
		return "no such law is known"
	var args: Dictionary = ev.data.args
	var commit: int = clampi(args.get("commit", 0), 0, 10)
	if src.resonance < def.price.get("resonance", 0) + commit:
		return "the price could not be paid"
	var shape: String = def.scope.shape
	if shape == "LINE":
		var line: Array = args.get("line", [])
		if line.size() != 4:
			return "a line needs two ends"
		var max_len: int = def.scope.get("max_length", 0)
		if LawGeom.dist_sq([line[0], line[1]], [line[2], line[3]]) > max_len * max_len:
			return "the line is longer than the law allows"
	elif shape == "PAIR":
		var pair: Array = args.get("pair", [])
		if pair.size() != 2 or pair[0] == pair[1]:
			return "a pair needs two that are not the same"
		for id: int in pair:
			if not entities.has(id) or not entities[id].alive:
				return "one of the pair is not there"
	elif shape == "TARGET":
		if not args.has("target"):
			return "the law needs a subject"
	for cond: Dictionary in def.get("condition", []):
		if cond.pred == "PAIR_WITHIN":
			var p: Array = args.get("pair", [])
			var reach: int = cond.get("reach", 0)
			if LawGeom.dist_sq(_pos(p[0]), _pos(p[1])) > reach * reach:
				return "the pair stand too far apart to be bound"
		elif cond.pred == "OWNER_HAS_TAG":
			if not src.tags.has(cond.tag):
				return "its author lacks the standing to impose it"
	return ""


## Step 2-4: which clauses of which laws have something to say about this
## event at this stage? Order is order of imposition, then clause order.
func _matching(ev: Dictionary, stage: String) -> Array:
	var out: Array = []
	for law: Dictionary in laws:
		if not law.active:
			continue
		var clauses: Array = _def(law).clauses
		for ci in clauses.size():
			var c: Dictionary = clauses[ci]
			if c.stage == "GATES":
				if not GATE_STAGES.has(stage):
					continue
			elif c.stage != stage:
				continue
			if not c.on.has(ev.kind):
				continue
			if _where(law, c.get("where", {}), ev):
				out.append({"law": law, "clause": c, "ci": ci})
	return out


func _where(law: Dictionary, w: Dictionary, ev: Dictionary) -> bool:
	if w.has("source") and not _entity_ok(law, w.source, ev.source):
		return false
	if w.has("target") and not _entity_ok(law, w.target, ev.target):
		return false
	if w.has("tags") and not _tags_ok(w.tags, ev.tags):
		return false
	if w.has("path"):
		if w.path == "CROSSES" and not _crosses(law, ev.from, ev.to):
			return false
	if w.has("pair"):
		var pair: Array = law.args.get("pair", [])
		if w.pair == "TARGET_IN_PAIR" and not pair.has(ev.target):
			return false
		if w.pair == "SOURCE_IN_PAIR" and not pair.has(ev.source):
			return false
	for cond: Dictionary in w.get("data", []):
		var v: int = ev.data.get(cond.key, 0)
		if cond.has("gte") and v < cond.gte:
			return false
		if cond.has("eq") and v != cond.eq:
			return false
	# One swing that reaches two bodies is one act, judged once: the combat
	# layer numbers its swings, and a strike of the swing just committed is
	# neither a repeat nor a new act.
	var swing: int = ev.data.get("swing", 0)
	var same_swing: bool = swing != 0 and swing == int(entities[ev.source].get("last_swing", 0))
	if w.get("same_act_as_last", false):
		var act: String = ev.data.get("act", "")
		if act == "" or entities[ev.source].last_act != act or same_swing:
			return false
	if w.get("first_of_swing", false) and same_swing:
		return false
	if w.has("held"):
		if _held_sum(law, w.held.of, ev) < w.held.get("min", 1):
			return false
	return true


func _entity_ok(law: Dictionary, f: Dictionary, id: int) -> bool:
	if not entities.has(id):
		return false
	var e: Dictionary = entities[id]
	var rel: String = f.get("rel", "ANY")
	if rel == "OWNER" and id != law.owner:
		return false
	if rel == "HOSTILE" and e.team == law.team:
		return false
	if rel == "ALLY" and e.team != law.team:
		return false
	return _tags_ok(f, e.tags.keys())


static func _tags_ok(f: Dictionary, have: Array) -> bool:
	for t: String in f.get("all", []):
		if not have.has(t):
			return false
	for t: String in f.get("none", []):
		if have.has(t):
			return false
	var any_of: Array = f.get("any", [])
	if any_of.is_empty():
		return true
	for t: String in any_of:
		if have.has(t):
			return true
	return false


func _crosses(law: Dictionary, a: Array, b: Array) -> bool:
	var shape: String = _def(law).scope.shape
	if shape == "LINE":
		var l: Array = law.args.line
		return LawGeom.segments_cross(a, b, [l[0], l[1]], [l[2], l[3]])
	if shape == "RING":
		var r: int = _def(law).scope.radius
		var c: Array = law.args.centre
		return LawGeom.inside_circle(a, c, r) != LawGeom.inside_circle(b, c, r)
	return false


func _held_of(law: Dictionary, of: String, ev: Dictionary) -> int:
	if of == "TARGET":
		return ev.target
	if of == "SOURCE":
		return ev.source
	return law.owner


func _held_sum(law: Dictionary, of: String, ev: Dictionary) -> int:
	var who := _held_of(law, of, ev)
	var sum := 0
	for h: Dictionary in held:
		if h.law == law.id and h.target == who:
			sum += h.amount
	return sum


# ------------------------------------------------------- conflict of laws
# Step 5. A clause that FORBIDS or TAKES an event may meet an opposing
# clause that REQUIRES the event to proceed. Three questions settle it, in
# order: which law outranks the other by two tiers or more; which is the
# narrower; which carries more authority.

static func _stance(c: Dictionary) -> String:
	if c.op == "DENY" or c.op == "DIVIDE":
		return "FORBID"
	if c.op == "PRESERVE":
		return "REQUIRE"
	if c.op == "INVERT":
		return "TAKE"
	if c.op == "DEFER" and c.get("params", {}).get("mode", "") == "MOVE":
		return "TAKE"
	return ""


func _settle(ev: Dictionary, firing: Array, rec: Dictionary) -> Array:
	var require: Array = []
	var claims: Array = []
	var out: Array = []
	for f: Dictionary in firing:
		var s := _stance(f.clause)
		if s == "REQUIRE":
			require.append(f)
		elif s == "":
			out.append(f)
		else:
			claims.append(f)
	if require.is_empty():
		return firing
	for f: Dictionary in claims:
		var stands := true
		for q: Dictionary in require:
			var a: Dictionary = f.law
			var b: Dictionary = q.law
			if not a.active or not b.active or a.team == b.team:
				continue
			var d := _decide(a, b)
			if d.result == "A_OVERRIDE":
				_note(rec, "OVERRIDE", a, b, d.reason)
			elif d.result == "B_OVERRIDE":
				stands = false
				_note(rec, "OVERRIDE", b, a, d.reason)
				_count(q, ev)
			elif d.result == "A_CONTEST":
				_note(rec, "CONTEST", a, b, d.reason)
				_end_law(b, "it was broken in a contest of laws")
			elif d.result == "B_CONTEST":
				stands = false
				_note(rec, "CONTEST", b, a, d.reason)
				_end_law(a, "it was broken in a contest of laws")
				_count(q, ev)
			else:
				stands = false
				_note(rec, "CANCELLATION", a, b, d.reason)
				_end_law(a, "it was matched, and gave way")
				_end_law(b, "it was matched, and gave way")
			if not stands:
				break
		if stands and f.law.active:
			out.append(f)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x.law.id != y.law.id:
			return x.law.id < y.law.id
		return x.ci < y.ci)
	return out


func _decide(a: Dictionary, b: Dictionary) -> Dictionary:
	var ra: int = RANK[_def(a).tier]
	var rb: int = RANK[_def(b).tier]
	if absi(ra - rb) >= 2:
		return {"result": "A_OVERRIDE" if ra > rb else "B_OVERRIDE",
			"reason": "the higher law outranks the lower"}
	var sa: int = SPECIFICITY[_def(a).scope.shape]
	var sb: int = SPECIFICITY[_def(b).scope.shape]
	if sa != sb:
		return {"result": "A_OVERRIDE" if sa > sb else "B_OVERRIDE",
			"reason": "the narrower law carves its exception from the broader"}
	if absi(a.authority - b.authority) <= CONTEST_MARGIN:
		return {"result": "CANCEL", "reason": "the laws were matched, and both gave way"}
	return {"result": "A_CONTEST" if a.authority > b.authority else "B_CONTEST",
		"reason": "authority %d against %d" % [maxi(a.authority, b.authority), mini(a.authority, b.authority)]}


# ------------------------------------------------------------ operations

func _apply(f: Dictionary, ev: Dictionary, rec: Dictionary, pending: Array) -> void:
	var law: Dictionary = f.law
	var c: Dictionary = f.clause
	var p: Dictionary = c.get("params", {})
	if not law.active:
		return
	var fired := true
	if c.op == "DENY" or c.op == "DIVIDE":
		ev.voided = true
		rec.verdict = "REJECTED"
		_note(rec, "REJECTION", law, {}, c.reason, c.get("id", ""), 1)
		var sanction: int = p.get("sanction", 0)
		if sanction > 0:
			pending.append(_event("HARM", law.owner, ev.source, sanction, ["by_law", "sanction"], {}))
	elif c.op == "PRESERVE":
		fired = false  # it speaks only in _settle, when something opposes it
	elif c.op == "INVERT":
		ev.voided = true
		rec.verdict = "CONVERTED"
		_note(rec, "CONVERSION", law, {}, c.reason, c.get("id", ""), 1)
		var tags: Array = ev.tags.duplicate()
		tags.erase("by_hand")
		tags.erase("perfect_parry")
		tags.append_array(["by_law", "returned"])
		# A parried blow arrives with no harm left in it. What is returned is
		# the blow as it was thrown: its weight, if the combat layer gave one.
		var weight: int = maxi(ev.amount, int(ev.data.get("weight", 0)))
		var back := _event("STRIKE", ev.target, ev.source, weight, tags, ev.data)
		back.from = ev.to.duplicate()
		back.to = ev.from.duplicate()
		pending.append(back)
	elif c.op == "ALTER":
		if p.has("amount_pct"):
			ev.amount = ev.amount * p.amount_pct / 100
		if p.has("amount_add"):
			ev.amount = maxi(0, ev.amount + p.amount_add)
		if p.has("tag_add"):
			var who: int = ev.target if p.tag_add.who == "TARGET" else (ev.source if p.tag_add.who == "SOURCE" else law.owner)
			add_tag(who, p.tag_add.tag, p.tag_add.get("ticks", 0))
		_note(rec, "EFFECT", law, {}, c.reason, c.get("id", ""), ev.amount)
	elif c.op == "REVEAL":
		for team: String in _teams():
			_learn(team, law.def_id, READ_THRESHOLD)
	elif c.op == "TRANSFER":
		fired = _transfer(law, c, p, ev, rec, pending)
	elif c.op == "DEFER":
		fired = _defer(law, c, p, ev, rec, pending)
	if fired:
		_count(f, ev)


func _transfer(law: Dictionary, c: Dictionary, p: Dictionary, ev: Dictionary, rec: Dictionary, pending: Array) -> bool:
	var mode: String = p.mode
	if mode == "COPY_TO_PAIR":
		var pair: Array = law.args.pair
		var other: int = pair[1] if pair[0] == ev.target else pair[0]
		var amount: int = ev.amount * p.pct / 100
		if amount <= 0:
			return false
		var copy := _event(ev.kind, law.owner, other, amount, ["by_law", p.tag], {"origin": ev.source})
		copy.from = _pos(ev.target)
		pending.append(copy)
		_note(rec, "EFFECT", law, {}, c.reason, c.get("id", ""), amount)
		return true
	if mode == "MIRROR":
		var amount: int = ev.amount * p.pct / 100
		if amount <= 0:
			return false
		var tags: Array = ["by_law", p.tag]
		if ev.tags.has("from_front"):
			tags.append("from_behind")
		elif ev.tags.has("from_behind"):
			tags.append("from_front")
		var twin := _event("STRIKE", law.owner, ev.target, amount, tags, {})
		twin.from = [2 * ev.to[0] - ev.from[0], 2 * ev.to[1] - ev.from[1]]
		pending.append(twin)
		_note(rec, "EFFECT", law, {}, c.reason, c.get("id", ""), amount)
		return true
	if mode == "HELD_TO_EVENT":
		var who := _held_of(law, p.of, ev)
		var sum := 0
		var keep: Array = []
		for h: Dictionary in held:
			if h.law == law.id and h.target == who:
				sum += h.amount
			else:
				keep.append(h)
		if sum <= 0:
			return false
		held = keep
		ev.amount += sum
		_note(rec, "CONVERSION", law, {}, "%s (+%d)" % [c.reason, sum], c.get("id", ""), sum)
		return true
	if mode == "HELD_TO_TARGET":
		var who := _held_of(law, p.of, ev)
		var room: int = ev.amount
		var taken := 0
		var keep: Array = []
		for h: Dictionary in held:
			if h.law == law.id and h.target == who and room > 0:
				var part: int = mini(h.amount, room)
				h.amount -= part
				room -= part
				taken += part
			if h.amount > 0:
				keep.append(h)
		if taken <= 0:
			return false
		held = keep
		var amount: int = taken * p.get("pct", 100) / 100
		pending.append(_event("HARM", law.owner, ev.target, amount, ["by_law", p.tag], {}))
		_note(rec, "CONVERSION", law, {}, "%s (%d)" % [c.reason, amount], c.get("id", ""), amount)
		return true
	return false


func _defer(law: Dictionary, c: Dictionary, p: Dictionary, ev: Dictionary, rec: Dictionary, pending: Array) -> bool:
	# What is recorded: the harm itself, or (basis BLOCKED) what a guard kept
	# out of it, which the combat layer reports as the blow's weight.
	var basis: int = ev.amount
	if p.get("basis", "") == "BLOCKED":
		basis = maxi(0, int(ev.data.get("weight", 0)) - ev.amount)
	var amount: int = basis * p.pct / 100
	if amount <= 0:
		return false
	seq += 1
	var entry := {"id": seq, "law": law.id, "kind": p.emit, "amount": amount,
		"source": ev.source, "tags": ["by_law", p.tag], "release": p.release,
		"due": 0, "lapse": 0, "interest": p.get("interest_pct", 0), "target": 0}
	if p.mode == "MOVE":
		entry.target = law.owner
		entry.due = tick + p.due_ticks
		ev.amount -= amount
		if ev.amount <= 0:
			ev.voided = true
			rec.verdict = "HELD"
	else:
		entry.target = ev.source if p.to == "SOURCE" else ev.target
		entry.source = law.owner
		entry.lapse = tick + p.lapse_ticks
	held.append(entry)
	_note(rec, "CONVERSION", law, {}, "%s (%d)" % [c.reason, amount], c.get("id", ""), amount)
	for b: Dictionary in _def(law).get("breach", []):
		if b.type != "DEFAULT":
			continue
		var total := 0
		for h: Dictionary in held:
			if h.law == law.id:
				total += h.amount
		if total <= b.cap:
			continue
		var keep: Array = []
		for h: Dictionary in held:
			if h.law == law.id:
				var tags: Array = h.tags.duplicate()
				tags.append("defaulted")
				var due := _event(h.kind, h.source, h.target, h.amount * b.pct / 100, tags, {})
				due.from = due.to.duplicate()
				pending.append(due)
			else:
				keep.append(h)
		held = keep
		_note(rec, "BREACH", law, {}, "more was owed than could be carried, and all of it came due")
		_end_law(law, "its author defaulted")
	return true


## Just before an event stands: does it break anything sworn against it?
## A breach of type EVENT names the kind of event that ends its law. An act
## another law denied never stood, so it breaks nothing; nor does a harm of
## nothing. When what falls is a Vow its author pays the forfeit on the
## spot, and their word is worth nothing.
func _break_vows(ev: Dictionary, rec: Dictionary, pending: Array) -> void:
	if ev.kind == "HARM" and ev.amount <= 0:
		return
	for law: Dictionary in laws:
		if not law.active:
			continue
		var def := _def(law)
		for b: Dictionary in def.get("breach", []):
			if b.type != "EVENT" or not b.on.has(ev.kind) or not _where(law, b.get("where", {}), ev):
				continue
			_note(rec, "BREACH", law, {}, b.reason, "fell", 1)
			_end_law(law, "it fell")
			if def.tier == "VOW":
				entities[law.owner]["standing"] = 0
				var harm: int = def.get("forfeit", {}).get("harm", 0)
				if harm > 0:
					pending.append(_event("HARM", law.owner, law.owner, harm, ["by_law", "forfeit"], {}))
			break


## Step 6: the event stands. Change the world.
func _commit(ev: Dictionary, rec: Dictionary, pending: Array) -> void:
	var src: Dictionary = entities[ev.source]
	var tgt: Dictionary = entities[ev.target]
	if ev.kind == "STRIKE":
		if ev.data.has("act"):
			src.last_act = ev.data.act
			src["last_swing"] = int(ev.data.get("swing", 0))
		var harm := _event("HARM", ev.source, ev.target, ev.amount, ev.tags, ev.data)
		harm.from = ev.from.duplicate()
		harm.to = ev.to.duplicate()
		pending.append(harm)
	elif ev.kind == "HARM":
		tgt.hp = maxi(0, tgt.hp - ev.amount)
		if tgt.hp == 0:
			tgt.alive = false
	elif ev.kind == "HEAL":
		tgt.hp = mini(tgt.hp_max, tgt.hp + ev.amount)
	elif ev.kind == "MOVE":
		for law: Dictionary in laws:
			if not law.active or law.owner != ev.source:
				continue
			for b: Dictionary in _def(law).get("breach", []):
				if b.type == "OWNER_CROSSES" and _crosses(law, ev.from, ev.to):
					_note(rec, "BREACH", law, {}, "its author crossed their own line")
					_end_law(law, "its author crossed their own line")
		src.pos = ev.to.duplicate()
	elif ev.kind == "IMPOSE":
		_establish(ev, rec)


func _establish(ev: Dictionary, rec: Dictionary) -> void:
	var src: Dictionary = entities[ev.source]
	var def := registry.resolve(ev.data.def, src.form)
	var args: Dictionary = ev.data.args.duplicate(true)
	var commit: int = clampi(args.get("commit", 0), 0, 10)
	src.resonance -= def.price.get("resonance", 0) + commit
	for old: Dictionary in laws:
		if old.active and old.owner == ev.source and old.def_id == ev.data.def:
			_end_law(old, "its author imposed it anew")
	if def.scope.shape == "RING" and not args.has("centre"):
		args["centre"] = _pos(ev.source)
	seq += 1
	var term: Dictionary = def.term
	laws.append({"id": seq, "def_id": ev.data.def, "form": src.form, "owner": ev.source,
		"team": src.team, "args": args, "started": tick, "active": true, "ended": "",
		"authority": RANK[def.tier] * 10 + commit + src.mastery + int(src.get("standing", 0)),
		"ticks_left": -1 if term.get("until", "") != "" else int(term.ticks), "events_left": term.get("events", -1)})
	_note(rec, "EFFECT", laws.back(), {}, "the law is imposed")
	if def.tier == "EDICT":  # an Edict is spoken aloud: everyone present can read it
		for team: String in _teams():
			_learn(team, ev.data.def, READ_THRESHOLD)


# ------------------------------------------------------------- lifecycle

func _def(law: Dictionary) -> Dictionary:
	return registry.resolve(law.def_id, law.form)


func _count(f: Dictionary, ev: Dictionary) -> void:
	var law: Dictionary = f.law
	_learn(str(entities[ev.source].team), law.def_id, 1)
	if entities[ev.target].team != entities[ev.source].team:
		_learn(str(entities[ev.target].team), law.def_id, 1)
	if f.clause.get("counts", false) and law.events_left > 0:
		law.events_left -= 1
		if law.events_left == 0:
			_end_law(law, "its term of acts was spent")


func _learn(team: String, def_id: String, n: int) -> void:
	if not knowledge.has(team):
		knowledge[team] = {}
	knowledge[team][def_id] = knowledge[team].get(def_id, 0) + n


func _teams() -> Array:
	var out: Array = []
	for id: int in entities:
		var t := str(entities[id].team)
		if not out.has(t):
			out.append(t)
	out.sort()
	return out


func _end_law(law: Dictionary, why: String) -> void:
	if not law.active:
		return
	law.active = false
	law.ended = why
	records.append({"tick": tick, "kind": "LAW_END", "law": law.def_id, "owner": law.owner, "reason": why})


func _check_breaches() -> void:
	for law: Dictionary in laws:
		if not law.active:
			continue
		if not entities[law.owner].alive:
			_end_law(law, "its author fell")
			continue
		var pair: Array = law.args.get("pair", [])
		for b: Dictionary in _def(law).get("breach", []):
			if b.type == "PAIR_MEMBER_DOWN":
				if not entities[pair[0]].alive or not entities[pair[1]].alive:
					_end_law(law, "one of the pair fell")
			elif b.type == "PAIR_SEPARATED":
				var reach: int = b.reach
				if LawGeom.dist_sq(_pos(pair[0]), _pos(pair[1])) > reach * reach:
					_end_law(law, "the pair were parted")


## Ended laws leave the list. Loans recorded by a law that has ended are
## forgotten; debts already owed still come due.
func _purge() -> void:
	var live: Dictionary = {}
	var keep_laws: Array = []
	for law: Dictionary in laws:
		if law.active:
			keep_laws.append(law)
			live[law.id] = true
	laws = keep_laws
	var keep_held: Array = []
	for h: Dictionary in held:
		if h.release == "DUE" or live.has(h.law):
			keep_held.append(h)
	held = keep_held


## clause and amount say which clause of the law spoke and how much it
## moved, so that play can be measured (Recognition Trials) without parsing
## sentences.
func _note(rec: Dictionary, type: String, law: Dictionary, other: Dictionary, reason: String, clause: String = "", amount: int = 0) -> void:
	var o := {"type": type, "reason": reason}
	if not law.is_empty():
		o["law"] = law.def_id
		o["name"] = _def(law).get("name", law.def_id)
		o["owner"] = law.owner
		if clause != "":
			o["clause"] = clause
			o["amount"] = amount
	if not other.is_empty():
		o["over"] = other.def_id
	rec.outcomes.append(o)
