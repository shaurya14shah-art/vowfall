class_name LawValidator
extends RefCounted
## Static checks every law definition must pass before the game will load it.
## This is the Axiom grammar's gatekeeper: it is what stops a combination of
## valid parts from being an impossible or unanswerable power.
##
## The budget (E_BUDGET) is a lint, not a balance proof. It catches laws that
## are broad, long and cheap all at once. Playtests decide the rest.

const TIER_BUDGET := {"FUNDAMENTAL": 6, "TECHNIQUE": 9, "MANIFESTATION": 13, "EDICT": 16, "VOW": 6}
const VOW_MIN_FORFEIT := 10
const VOW_MAX_STANDING := 4
const TIER_MAX_TICKS := {"FUNDAMENTAL": 300, "TECHNIQUE": 900, "MANIFESTATION": 1200, "EDICT": 1800}
const SCOPE_POINTS := {"SELF": 1, "TARGET": 2, "PAIR": 2, "LINE": 3, "RING": 3, "ZONE": 4, "FIELD": 5}
const OP_POINTS := {"DENY": 4, "DIVIDE": 3, "PRESERVE": 3, "INVERT": 3, "DEFER": 3, "TRANSFER": 2, "ALTER": 2, "REVEAL": 0}
const STAGE_OPS := {
	"NOTICE": ["ALTER", "REVEAL"],
	"DENY": ["DENY", "DIVIDE"],
	"GATES": ["PRESERVE"],
	"REDIRECT": ["INVERT"],
	"MODIFY": ["ALTER", "TRANSFER"],
	"HOLD": ["DEFER"],
	"REACT": ["TRANSFER", "DEFER", "ALTER", "REVEAL"],
}
const KINDS := ["STRIKE", "HARM", "HEAL", "MOVE", "IMPOSE"]
const COUNTERPLAY := [
	"GO_AROUND", "EXHAUST", "BAIT_OWNER", "OUTLAST", "SHARE_A_SIDE",
	"STRIKE_UNWITNESSED", "STARVE", "FORCE_DEFAULT", "DENY_STRIKES",
	"SEPARATE", "TURN_IT", "GUARD_BOTH_SIDES", "FEINT_THE_PARRY",
	"FACE_HIM", "USE_LAWS_NOT_HANDS", "SHORT_STRINGS", "EARN_STANDING",
	"VARY_ACTS", "OUTRANK", "CONTEST",
]


## Returns [{code, msg}], empty when the definition is sound.
static func validate(def: Dictionary, roots: Dictionary) -> Array:
	var errs: Array = []
	var id: String = def.get("id", "?")
	for key: String in ["id", "root", "name", "thesis", "text", "operation", "tier", "scope", "term", "price", "counterplay", "clauses"]:
		if not def.has(key):
			errs.append(_e("E_SHAPE", "%s: missing '%s'" % [id, key]))
	if not errs.is_empty():
		return errs
	var tier: String = def.tier
	var shape: String = def.scope.get("shape", "")
	if not TIER_BUDGET.has(tier):
		return [_e("E_SHAPE", "%s: unknown tier %s" % [id, tier])]
	if not SCOPE_POINTS.has(shape):
		return [_e("E_SHAPE", "%s: unknown scope %s" % [id, shape])]
	if not roots.has(def.root):
		return [_e("E_SHAPE", "%s: unknown root %s" % [id, def.root])]
	var allowed: Array = roots[def.root].get("ops", [])
	if not allowed.has(def.operation):
		errs.append(_e("E_ROOT_OP", "%s: %s cannot %s" % [id, def.root, def.operation]))
	if tier == "VOW":
		errs.append_array(_vow(def, id))
		return errs

	var ticks: int = def.term.get("ticks", 0)
	var events: int = def.term.get("events", 0)
	if ticks <= 0 or ticks > TIER_MAX_TICKS[tier]:
		errs.append(_e("E_TERM", "%s: a %s must end within %d ticks" % [id, tier, TIER_MAX_TICKS[tier]]))
	if def.price.get("resonance", 0) <= 0 and tier != "FUNDAMENTAL":
		errs.append(_e("E_PRICE", "%s: only a Fundamental may be free" % id))
	var cp: Array = def.counterplay
	if cp.size() < 2:
		errs.append(_e("E_COUNTERPLAY", "%s: a law needs at least two ways to answer it" % id))
	for c: String in cp:
		if not COUNTERPLAY.has(c):
			errs.append(_e("E_COUNTERPLAY", "%s: unknown counterplay %s" % [id, c]))

	var has_default := false
	for b: Dictionary in def.get("breach", []):
		if b.get("type", "") == "DEFAULT":
			has_default = true

	var clauses: Array = def.clauses
	if clauses.is_empty():
		errs.append(_e("E_SHAPE", "%s: a law with no clauses does nothing" % id))
	for c: Dictionary in clauses:
		var op: String = c.get("op", "")
		var stage: String = c.get("stage", "")
		var w: Dictionary = c.get("where", {})
		var p: Dictionary = c.get("params", {})
		if not OP_POINTS.has(op) or not STAGE_OPS.has(stage):
			errs.append(_e("E_SHAPE", "%s: unknown op '%s' or stage '%s'" % [id, op, stage]))
			continue
		if c.get("reason", "") == "":
			errs.append(_e("E_SHAPE", "%s: every clause must be able to state its reason" % id))
		var on: Array = c.get("on", [])
		if on.is_empty():
			errs.append(_e("E_SHAPE", "%s: a clause must name the events it judges" % id))
		for k: String in on:
			if not KINDS.has(k):
				errs.append(_e("E_SHAPE", "%s: unknown event kind %s" % [id, k]))
		if not STAGE_OPS[stage].has(op):
			errs.append(_e("E_STAGE_OP", "%s: %s cannot act at %s" % [id, op, stage]))
		if not allowed.has(op):
			errs.append(_e("E_ROOT_OP", "%s: %s cannot %s" % [id, def.root, op]))

		var sided: bool = w.has("source") and w.source.has("rel") or w.has("target") and w.target.has("rel")
		if op == "DIVIDE" and (w.has("source") or w.has("target")):
			errs.append(_e("E_DIVIDE_SIDED", "%s: a Divide cannot take a side" % id))
		if tier == "EDICT" and (op == "DENY" or op == "DIVIDE") and sided:
			errs.append(_e("E_EDICT_EXEMPT", "%s: an Edict binds its author" % id))
		if op == "DENY" and (shape == "FIELD" or shape == "ZONE") and restrictions(c) == 0:
			errs.append(_e("E_TOTAL_LOCK", "%s: a field may not forbid everything" % id))

		var shields_owner: bool = on.has("HARM") and w.get("target", {}).get("rel", "") == "OWNER"
		if shields_owner and op == "DENY" and events <= 0:
			errs.append(_e("E_IMMORTAL", "%s: harm to the author cannot be refused without limit" % id))
		if shields_owner and op == "DEFER" and p.get("mode", "") == "MOVE":
			if p.get("release", "") != "DUE" or not has_default:
				errs.append(_e("E_IMMORTAL", "%s: deferred harm must come due and must be able to default" % id))

		if op == "DEFER":
			var rel: String = p.get("release", "")
			var ok: bool = (rel == "DUE" and p.get("due_ticks", 0) > 0) or (rel == "INVOKE" and p.get("lapse_ticks", 0) > 0)
			if not ok:
				errs.append(_e("E_DEFER_RELEASE", "%s: what is deferred must have a day it ends" % id))
		var none: Array = w.get("tags", {}).get("none", [])
		if op == "INVERT" and not none.has("returned"):
			errs.append(_e("E_LOOP", "%s: an inversion must not invert what was already returned" % id))
		if op == "TRANSFER" and p.get("mode", "") in ["COPY_TO_PAIR", "MIRROR", "HELD_TO_TARGET"]:
			if p.get("tag", "") == "" or not none.has(p.get("tag", "")):
				errs.append(_e("E_LOOP", "%s: a law must not act on its own output" % id))

	var cost := budget(def)
	if cost.power > cost.allowance:
		errs.append(_e("E_BUDGET", "%s: power %d exceeds allowance %d" % [id, cost.power, cost.allowance]))
	return errs


## A Vow is a law its author swears against themselves. It gives nothing
## while it stands, so it needs no answer and no price in Resonance: its
## price is what it costs to break. It must be possible to break, must cost
## something when it is, must concern its author, and must not pay too much.
static func _vow(def: Dictionary, id: String) -> Array:
	var errs: Array = []
	if def.scope.get("shape", "") != "SELF":
		errs.append(_e("E_VOW", "%s: a vow binds only the one who swears it" % id))
	if def.term.get("until", "") != "KEPT" or def.term.get("ticks", 0) != 0:
		errs.append(_e("E_TERM", "%s: a vow stands until it is kept or broken, not for a time" % id))
	if not (def.clauses as Array).is_empty():
		errs.append(_e("E_VOW", "%s: a vow grants nothing while it stands" % id))
	if def.get("forfeit", {}).get("harm", 0) < VOW_MIN_FORFEIT:
		errs.append(_e("E_PRICE", "%s: a vow that costs nothing to break is not a vow" % id))
	var reward: Dictionary = def.get("reward", {})
	if reward.get("standing", 0) < 1 or reward.get("standing", 0) > VOW_MAX_STANDING or reward.get("resonance", 0) > 100:
		errs.append(_e("E_BUDGET", "%s: a kept vow pays between 1 and %d standing" % [id, VOW_MAX_STANDING]))
	var ways := 0
	for b: Dictionary in def.get("breach", []):
		if b.get("type", "") != "EVENT":
			continue
		ways += 1
		var w: Dictionary = b.get("where", {})
		var about_owner: bool = w.get("source", {}).get("rel", "") == "OWNER" or w.get("target", {}).get("rel", "") == "OWNER"
		if not about_owner:
			errs.append(_e("E_VOW", "%s: a vow can only be broken by what its author does or suffers" % id))
		if b.get("reason", "") == "" or (b.get("on", []) as Array).is_empty():
			errs.append(_e("E_SHAPE", "%s: a vow must say what breaks it" % id))
		for k: String in b.get("on", []):
			if not KINDS.has(k):
				errs.append(_e("E_SHAPE", "%s: unknown event kind %s" % [id, k]))
	if ways == 0:
		errs.append(_e("E_IMMORTAL", "%s: a vow that cannot be broken is a boast" % id))
	return errs


## How many ways a clause narrows what it applies to (capped at 3).
static func restrictions(c: Dictionary) -> int:
	var w: Dictionary = c.get("where", {})
	var n := 0
	for side: String in ["source", "target"]:
		if w.has(side):
			for k: String in ["all", "any", "none"]:
				if not w[side].get(k, []).is_empty():
					n += 1
	if w.has("tags"):
		n += mini(2, w.tags.get("all", []).size())
		if not w.tags.get("none", []).is_empty():
			n += 1
		if not w.tags.get("any", []).is_empty():
			n += 1
	for k: String in ["path", "pair", "held", "data"]:
		if w.has(k):
			n += 1
	if w.get("same_act_as_last", false):
		n += 1
	if w.get("first_of_swing", false):
		n += 1
	return mini(n, 3)


## power: how much a law reaches, lasts and does.
## allowance: what its tier grants, plus what its price and breaches pay back.
static func budget(def: Dictionary) -> Dictionary:
	var ticks: int = def.term.get("ticks", 0)
	var term_pts: int = (ticks + 299) / 300
	if def.term.get("events", 0) > 0:
		term_pts = maxi(1, term_pts - 1)
	var power: int = SCOPE_POINTS.get(def.scope.shape, 0) + term_pts
	for c: Dictionary in def.clauses:
		var base: int = OP_POINTS.get(c.get("op", ""), 0)
		if base > 0:
			power += maxi(1, base - restrictions(c))
	var allowance: int = TIER_BUDGET.get(def.tier, 0)
	allowance += mini(6, def.price.get("resonance", 0) / 10)
	allowance += mini(2, def.get("breach", []).size())
	if def.tier == "EDICT":
		allowance += 2  # it binds its author, enforced by E_EDICT_EXEMPT
	return {"power": power, "allowance": allowance}


## Validates every definition in every form. Returns {id|form: [errors]}.
static func validate_all(reg: LawRegistry) -> Dictionary:
	var out: Dictionary = {}
	var ids := reg.defs.keys()
	ids.sort()
	for id: String in ids:
		for form: String in reg.forms_of(id):
			var errs := validate(reg.resolve(id, form), reg.roots)
			if not errs.is_empty():
				out[id + "|" + form] = errs
	return out


static func _e(code: String, msg: String) -> Dictionary:
	return {"code": code, "msg": msg}
