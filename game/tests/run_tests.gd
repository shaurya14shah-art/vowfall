extends SceneTree
## Headless test runner for the Law Engine. No window.
##
##   godot --headless --path game --script res://tests/run_tests.gd
##   godot --headless --path game --script res://tests/run_tests.gd -- --verbose
##
## Exit code 0 only if every check passes.

var passed := 0
var failed := 0
var verbose := false
var reg: LawRegistry


func _init() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	reg = LawRegistry.new()
	_check(reg.load_roots("res://data/roots.json"), "roots.json loads")
	_check(reg.roots.size() == 18, "there are eighteen Roots")
	var n := reg.load_laws_dir("res://data/laws")
	_check(n > 0, "law definitions load (%d)" % n)

	_section("VALIDATION: every shipped law is sound")
	var bad := LawValidator.validate_all(reg)
	_check(bad.is_empty(), "no shipped law fails validation")
	for key: String in bad:
		for e: Dictionary in bad[key]:
			print("      %s  %s  %s" % [key, e.code, e.msg])
	_print_budgets()

	_section("VALIDATION: impossible laws are refused")
	_run_invalid("res://tests/invalid_laws.json")

	_section("SCENARIOS")
	var files := DirAccess.get_files_at("res://tests/scenarios")
	files.sort()
	var hashes: Dictionary = {}
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var data: Dictionary = LawRegistry.read_json("res://tests/scenarios/" + f)
		for sc: Dictionary in data.scenarios:
			hashes[f + "/" + sc.name] = _run_scenario(data.cast, sc, true, false)

	_section("DETERMINISM: the same inputs give the same world, bit for bit")
	var same := true
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var data: Dictionary = LawRegistry.read_json("res://tests/scenarios/" + f)
		for sc: Dictionary in data.scenarios:
			if _run_scenario(data.cast, sc, false, false) != hashes[f + "/" + sc.name]:
				same = false
				print("      differs: " + sc.name)
	_check(same, "replaying all %d scenarios reproduces every state hash" % hashes.size())

	_section("SAVE/LOAD: saving and loading between every step changes nothing")
	same = true
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var data: Dictionary = LawRegistry.read_json("res://tests/scenarios/" + f)
		for sc: Dictionary in data.scenarios:
			if _run_scenario(data.cast, sc, false, true) != hashes[f + "/" + sc.name]:
				same = false
				print("      differs: " + sc.name)
	_check(same, "all %d scenarios survive a JSON round trip at every step" % hashes.size())

	_section("ENGINE GUARDS")
	_test_loop_guard()

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ helpers

func _section(title: String) -> void:
	print("\n== " + title)


func _check(ok: bool, label: String) -> bool:
	if ok:
		passed += 1
		if verbose:
			print("  ok    " + label)
	else:
		failed += 1
		print("  FAIL  " + label)
	return ok


func _print_budgets() -> void:
	var ids := reg.defs.keys()
	ids.sort()
	for id: String in ids:
		for form: String in reg.forms_of(id):
			var b := LawValidator.budget(reg.resolve(id, form))
			if verbose:
				print("      %-26s %-9s power %2d / allowance %2d" % [id, form, b.power, b.allowance])


func _run_invalid(path: String) -> void:
	var data: Dictionary = LawRegistry.read_json(path)
	for item: Dictionary in data.cases:
		var def: Dictionary = data.base.duplicate(true)
		for k: String in item.patch:
			def[k] = item.patch[k]
		var codes: Array = []
		for e: Dictionary in LawValidator.validate(def, reg.roots):
			codes.append(e.code)
		if item.expect == "":
			_check(codes.is_empty(), "%s  %s" % [item.name, str(codes)])
		else:
			_check(codes.has(item.expect), "refused: %s  [%s] got %s" % [item.name, item.expect, str(codes)])


func _run_scenario(cast: Dictionary, sc: Dictionary, checking: bool, round_trip: bool) -> String:
	var w := LawWorld.new(reg)
	for item: Variant in sc.entities:
		var spec: Dictionary = {}
		if item is String:
			spec = cast[item].duplicate(true)
		else:
			spec = cast[item.use].duplicate(true)
			for k: String in item:
				if k != "use":
					spec[k] = item[k]
		w.add_entity(spec)
	var ok := true
	var index := 0
	for step: Dictionary in sc.steps:
		index += 1
		var why := _step(w, step)
		if why != "":
			ok = false
			if checking:
				print("        step %d (%s): %s" % [index, step["do"], why])
		if round_trip:
			var text := JSON.stringify(w.to_dict())
			var parsed: Dictionary = JSON.parse_string(text)
			w = LawWorld.from_dict(reg, parsed)
	if checking:
		_check(ok, sc.name)
	return w.state_hash()


## Runs one step. Returns "" or the reason an expectation was not met.
func _step(w: LawWorld, s: Dictionary) -> String:
	var rec: Dictionary = {}
	var kind: String = s["do"]
	if kind == "impose":
		rec = w.impose(s.owner, s.def, s.get("args", {}))
	elif kind == "strike":
		rec = w.strike(s.source, s.target, s.amount, s.get("tags", []), s.get("data", {}))
	elif kind == "heal":
		rec = w.heal(s.source, s.target, s.amount)
	elif kind == "move":
		rec = w.move(s.entity, s.to)
	elif kind == "advance":
		w.advance(s.ticks)
	elif kind == "keep":
		rec = w.keep(s.owner)
	elif kind == "forget":
		w.forget_standing(s.entity)
	elif kind == "assert":
		var got: int = w.entities[s.entity][s.stat]
		if got != s.eq:
			return "%s of %d is %d, expected %d" % [s.stat, s.entity, got, s.eq]
	elif kind == "assert_pos":
		if w.entities[s.entity].pos != s.eq:
			return "position is %s, expected %s" % [str(w.entities[s.entity].pos), str(s.eq)]
	elif kind == "assert_tag":
		if w.has_tag(s.entity, s.tag) != s.has:
			return "tag %s presence is %s" % [s.tag, str(not s.has)]
	elif kind == "assert_law":
		var active := not w.find_law(s.owner, s.def).is_empty()
		if active != s.active:
			return "%s active is %s, expected %s" % [s.def, str(active), str(s.active)]
	elif kind == "assert_held":
		var total := w.held_total(s.owner, s.def)
		if total != s.eq:
			return "%s holds %d, expected %d" % [s.def, total, s.eq]
	elif kind == "assert_knowledge":
		var level := w.knowledge_level(s.team, s.def)
		if level != s.eq:
			return "knowledge of %s is %d, expected %d" % [s.def, level, s.eq]
	else:
		return "unknown step '%s'" % kind
	if not s.has("expect"):
		return ""
	var x: Dictionary = s.expect
	if x.has("verdict") and rec.verdict != x.verdict:
		return "verdict %s, expected %s  %s" % [rec.verdict, x.verdict, _why(rec)]
	var all: Array = []
	_flatten(rec, all)
	for want: Dictionary in x.get("outcomes", []):
		var found := false
		for o: Dictionary in all:
			if o.get("type", "") != want.type:
				continue
			if want.has("law") and o.get("law", "") != want.law:
				continue
			if want.has("over") and o.get("over", "") != want.over:
				continue
			found = true
		if not found:
			return "no outcome %s  %s" % [str(want), _why(rec)]
	if x.has("child_tags"):
		if not _has_child_tags(rec, x.child_tags):
			return "no consequence carried tags %s" % str(x.child_tags)
	return ""


func _flatten(rec: Dictionary, into: Array) -> void:
	into.append_array(rec.outcomes)
	for c: Dictionary in rec.children:
		_flatten(c, into)


func _has_child_tags(rec: Dictionary, tags: Array) -> bool:
	for c: Dictionary in rec.children:
		var all_in := true
		for t: String in tags:
			if not c.tags.has(t):
				all_in = false
		if all_in or _has_child_tags(c, tags):
			return true
	return false


func _why(rec: Dictionary) -> String:
	var all: Array = []
	_flatten(rec, all)
	var parts: Array = []
	for o: Dictionary in all:
		parts.append("%s:%s(%s)" % [o.type, o.get("law", "-"), o.reason])
	return "[" + ", ".join(parts) + "]"


## The validator refuses laws that act on their own output. If one got in
## anyway (a bug, a bad mod), the engine must still terminate.
func _test_loop_guard() -> void:
	var r := LawRegistry.new()
	r.roots = reg.roots
	r.add_def({
		"id": "test.runaway", "root": "REFLECTION", "name": "Runaway", "thesis": "t", "text": "t",
		"operation": "INVERT", "tier": "TECHNIQUE", "scope": {"shape": "SELF"},
		"term": {"ticks": 600}, "price": {"resonance": 10}, "counterplay": ["EXHAUST", "OUTLAST"],
		"clauses": [{"on": ["HARM"], "stage": "REACT", "op": "TRANSFER",
			"params": {"mode": "MIRROR", "pct": 100, "tag": "mirrored"},
			"where": {"source": {"rel": "OWNER"}}, "reason": "runaway"}],
	})
	var codes: Array = []
	for e: Dictionary in LawValidator.validate(r.resolve("test.runaway"), r.roots):
		codes.append(e.code)
	_check(codes.has("E_LOOP"), "the validator refuses a law that acts on its own output")
	var w := LawWorld.new(r)
	w.add_entity({"id": 1, "team": 1, "pos": [0, 0]})
	w.add_entity({"id": 2, "team": 2, "hp": 100000, "pos": [0, 400]})
	w.impose(1, "test.runaway")
	var rec := w.strike(1, 2, 10)
	var all: Array = []
	_flatten(rec, all)
	var folded := false
	for o: Dictionary in all:
		if o.type == "CANCELLATION":
			folded = true
	_check(folded, "a runaway chain of consequences is cut off, not followed forever")
	_check(w.entities[2].hp == 100000 - 40, "and it did exactly four strikes' worth of harm before it was cut")
