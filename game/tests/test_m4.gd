extends Node
## Headless tests for milestone M4: Aurel Voss. First the rules of the fight
## (phases, Writs, seals, yielding, the choice). Then six scripted lines, two
## for each Root, played against his real AI, with each verdict log written
## to docs/m4_logs/. No window.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/TestM4.tscn
##   ... -- --rules      only the rules      ... -- --lines     only the six lines

const S := ActionMachine.S
const VOSS := 4
const GATEKEEPER := 1
const CREDITOR := 3
const DEBTOR := 4
const TWIN := 5
const ANSWER := 6
const LIMIT_TICKS := 16200          # four and a half minutes

var passed := 0
var failed := 0
var verbose := false
var arena: Arena
var input: ScriptedInput
var strikes: Array = []
var said: Array = []


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--lines"):
		_section("THE ARBITER ARRIVES")
		await _test_arrival()
		_section("THREE PHASES")
		await _test_phases()
		await _test_hearing_binds_him()
		_section("SEALS")
		await _test_seals()
		_section("YIELDING AND THE CHOICE")
		await _test_yield_and_licence()
		await _test_refusal()
		_section("AS THE PLAYER SEES IT (HUD on, headless)")
		await _test_presentation()
	if not args.has("--rules"):
		_section("SIX LINES AGAINST THE ARBITER")
		await _six_lines()
	print("\n%d passed, %d failed" % [passed, failed])
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ helpers

func _section(title: String) -> void:
	print("\n== " + title)


func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		if verbose:
			print("  ok    " + label)
	else:
		failed += 1
		print("  FAIL  " + label)


func _wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _fresh(test_mode: bool = true) -> void:
	if arena != null:
		arena.queue_free()
		await get_tree().process_frame
	Arena.test_mode = test_mode
	Arena.fixed_instrument = ""
	strikes = []
	said = []
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	await _wait(2)
	arena.set_encounter(VOSS)
	arena.boss.spoke.connect(func(text: String) -> void: said.append(text))
	arena.boss.ai_enabled = false
	await _wait(2)


func _place(actor: Actor, at: Vector3, yaw: float) -> void:
	actor.global_position = at
	actor.facing = yaw
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()


func _press(what: String) -> void:
	input.at(input.tick, what)


func _choose(n: int) -> void:
	input.hold(input.tick, 1, "select", n)
	await _wait(3)


func _laws() -> Array:
	var out: Array = []
	for law: Dictionary in arena.bridge.laws_of(arena.boss, 1):
		out.append(law.id)
	return out


func _wound(to_hp: int) -> void:
	var b := arena.bridge
	var now: int = b.hp(arena.boss.entity_id)
	if now > to_hp:
		b.world.strike(arena.player.entity_id, arena.boss.entity_id, now - to_hp, ["from_front"])


func _count(lines: Array, type: String, has: String = "") -> int:
	var n := 0
	for line: String in lines:
		if line.substr(8, 12).strip_edges() == type and (has == "" or line.contains(has)):
			n += 1
	return n


# -------------------------------------------------------------------- rules

func _test_arrival() -> void:
	await _fresh()
	var v := arena.boss
	_check(v != null and v.display_name == "Aurel Voss" and v.title() == "The Last Arbiter", "the fifth encounter is Aurel Voss, the Last Arbiter")
	_check(v.hp() == 420 and v.yields_at == 33, "420 health, and he will yield at 33")
	_check(v.instrument_ok(), "carrying the Imprimatur, in a body of his own")
	_place(arena.player, Vector3(0, 0, -20), 0.0)
	v.ai_enabled = true
	await _wait(45)
	_check(v.phase == 0 and v.phase_name() == "Arraignment", "the hearing opens with the Arraignment")
	_check(_laws() == ["voss.writ_of_standing"], "one Writ stands: the Writ of Standing")
	_check(said.size() >= 2 and String(said[-1]) == "Writ of Standing. No one may strike the Arbiter unseen.",
		"and he said it aloud before enforcing it")
	_check(arena.bridge.world.knowledge_level(arena.player.team, "voss.writ_of_standing") == 2,
		"so the Witness can read it before it has ever been enforced")


func _test_phases() -> void:
	await _fresh()
	var v := arena.boss
	_place(arena.player, Vector3(0, 0, -24), 0.0)
	v.ai_enabled = true
	await _wait(45)
	_wound(260)
	await _wait(150)
	_check(v.phase == 1 and v.phase_name() == "Cross-examination", "below two thirds of his health: Cross-examination")
	_check(_laws().size() == 2, "two Writs stand together (%s)" % str(_laws()))
	var unread := 0
	for law: Dictionary in arena.bridge.laws_of(v, arena.player.team):
		if law.known < 2:
			unread += 1
	_check(unread == 0, "both were spoken, so neither is struck out on the Arbiter's panel")
	_wound(120)
	await _wait(420)
	_check(v.phase == 2 and v.phase_name() == "The Hearing", "below one third: The Hearing")
	_check(_laws().has("voss.the_hearing"), "his Edict is spoken")
	_check(arena.bridge.world.knowledge_level(1, "voss.the_hearing") == 2, "and being an Edict, the player can read it at once")
	_check(said.has("Then let it be a hearing. It binds me as it binds you."), "he says what it is, and that it binds him")


func _test_hearing_binds_him() -> void:
	await _fresh()
	var v := arena.boss
	var p := arena.player
	_place(p, Vector3(0, 0, 9.0), 0.0)
	_wound(110)
	v.ai_enabled = true
	p.lock_target = v
	var attacks := 0
	var was_attacking := false
	for i in 2400:
		if i % 40 == 0:
			arena.bridge.rest(p)          # a patient witness: this test is about him, not the player
		input.hold(input.tick, 1, "guard")
		await get_tree().physics_frame
		var now := v.machine.state == S.ATTACK
		if now and not was_attacking:
			attacks += 1
		was_attacking = now
	var denied_himself := 0
	for line: String in arena.bridge.log_lines:
		if line.contains("The Hearing") and line.contains("REJECTION") and line.contains("[Aurel Voss"):
			denied_himself += 1
	_check(attacks >= 6, "over forty seconds under his own Edict he attacks freely (%d times)" % attacks)
	_check(denied_himself == 0, "and never once repeats himself: his AI chooses only what The Hearing permits")
	_check(_count(arena.bridge.log_lines, "IMPOSED", "The Hearing") >= 2, "when its nine acts are spent he speaks it again")


func _test_seals() -> void:
	await _fresh()
	var v := arena.boss
	_place(arena.player, Vector3(0, 0, 0.0), 0.0)
	_place(v, Vector3(0, 0, 9.0), PI)
	await _wait(2)
	for n in 4:
		v.press_heavy = true
		await _wait(100)
		if n == 0:
			_check(v.seals.size() == 1 and arena.bridge.actors.has(v.seals[0].entity_id), "where his stamp lands it leaves a seal, and the seal is a thing in the fight")
			var s: Seal = v.seals[0]
			_check(s.global_position.distance_to(Vector3(0, 0, 9.0 - 2.5)) < 1.6 and s.hp() == 50, "two and a half metres in front of him, with 50 health")
	_check(v.seals.size() == Voss.MAX_SEALS, "he keeps at most three; the oldest is lifted")
	var first_id: int = v.seals[0].entity_id
	arena.bridge.world.strike(arena.player.entity_id, first_id, 60, ["from_front"])
	await _wait(4)
	_check(v.seals.size() == 2 and not arena.bridge.actors.has(first_id), "a broken seal is cleared away")


func _test_yield_and_licence() -> void:
	await _fresh()
	var v := arena.boss
	var p := arena.player
	_place(p, Vector3(0, 0, -20), 0.0)
	v.ai_enabled = true
	await _wait(45)
	_check(not _laws().is_empty(), "with a Writ standing")
	_wound(0)
	await _wait(3)
	_check(v.yielded and v.hp() == 33 and not v.machine.dead(), "a blow that would have killed him does not: he yields, on 33")
	_check(_laws().is_empty(), "his Writs end with the fight")
	_check(String(said[-1]).begins_with("Enough."), "he says so, and offers his licence")
	_check(p.choosing, "the choice is put to the Witness")
	_place(p, v.global_position + Vector3(0, 0, -1.6), 0.0)
	await _wait(2)
	_press("light")
	await _wait(40)
	_check(v.hp() == 33 and strikes.is_empty(), "he cannot be struck now")
	var law_before := p.law_id
	await _choose(1)
	_check(arena.flags.get("voss", "") == "licensed" and not p.choosing, "pressing 1 takes the licence")
	_check(arena.bridge.world.has_tag(p.entity_id, "recognised") and arena.bridge.world.has_tag(p.entity_id, "licensed"),
		"and the Court recognises this Witness from now on")
	_check(p.law_id == law_before, "the key answered the question; it did not change the law in hand")
	_check(_count(arena.bridge.log_lines, "YIELDED") == 1 and _count(arena.bridge.log_lines, "CHOSE") == 1, "both are in the verdict log")


func _test_refusal() -> void:
	await _fresh()
	_wound(0)
	await _wait(3)
	await _choose(2)
	_check(arena.flags.get("voss", "") == "refused", "pressing 2 refuses it")
	_check(not arena.bridge.world.has_tag(arena.player.entity_id, "recognised"), "and the Witness stands unrecognised")
	arena.set_encounter(0)
	await _wait(3)
	_check(arena.boss == null and not arena.player.choosing and arena.enemies.size() == 1, "the yard can move on to other opponents")


func _test_presentation() -> void:
	await _fresh(false)
	var v := arena.boss
	v.ai_enabled = true
	_place(arena.player, Vector3(0, 0, 4.0), 0.0)
	await _wait(120)
	var canvas: Hud.HudCanvas = arena.hud.get_child(0)
	_check(canvas.boss == v and canvas.banner != "", "the HUD shows the Arbiter without a lock-on, and what he says")
	_wound(0)
	await _wait(10)
	_check(canvas.choice.size() == 2, "and puts his offer on screen")
	await _choose(1)
	await _wait(10)
	_check(canvas.choice.is_empty() and canvas.draws > 100, "all of it drawn without error (%d frames)" % canvas.draws)
	Arena.test_mode = true


# -------------------------------------------------------------------- lines
# Six ways to bring him to yield, two for each Root. Played by scripted
# policies with perfect timing: they show that each law has a line through
# his three phases, not that the fight is fun or fair for a person.

func _six_lines() -> void:
	var lines := [
		["gatekeeper", "Threshold: bar the way, and strike only after a denial", GATEKEEPER, false],
		["gate_unveiled", "Threshold, Unveiled: fight through your own gate", GATEKEEPER, true],
		["creditor", "Debt: catch his blows on the Tally and call them in", CREDITOR, false],
		["debtor", "Debt: take the blow, owe it, and pay it forward", DEBTOR, false],
		["answer", "Reflection: answer every blow in kind", ANSWER, false],
		["twin", "Reflection: bind him to his own seal and strike the seal", TWIN, false],
	]
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/m4_logs").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var results: Dictionary = {}
	for line: Array in lines:
		var r: Dictionary = await _duel(line[0], line[2], line[3])
		results[line[0]] = r
		var f := FileAccess.open(dir.path_join(String(line[0]) + ".txt"), FileAccess.WRITE)
		f.store_string("VOWFALL verdict log. Aurel Voss, the Last Arbiter. %s.\n" % line[1])
		f.store_string("Played by a scripted policy, not a person. %s after %.0f s; the Witness ended on %d health; the Arbiter on %d.\n" % [
			"He yielded" if r.won else ("The Witness fell" if r.lost else "Unfinished"), r.ticks / 60.0, r.hp, r.boss_hp])
		f.store_string("Outcomes: %s\n\n" % str(r.counts))
		f.store_string("  tick  outcome       law                 what happened  [who -> whom]\n")
		f.store_string("\n".join(r.log) + "\n")
		f.close()
		print("      %-14s %s in %5.0f s, Witness %3d hp, Arbiter %3d hp   %s" % [line[0], "yields" if r.won else ("FELL  " if r.lost else "open  "), r.ticks / 60.0, r.hp, r.boss_hp, str(r.counts)])
	var g: Dictionary = results["gatekeeper"]
	var gu: Dictionary = results["gate_unveiled"]
	var c: Dictionary = results["creditor"]
	var d: Dictionary = results["debtor"]
	var a: Dictionary = results["answer"]
	var t: Dictionary = results["twin"]
	for key: String in results:
		_check(results[key].won, "%s: the Arbiter yields" % key)
	_check(_count(g.log, "REJECTION", "The Gatekeeper") >= 3, "the Gatekeeper's line is made of denials (%d)" % _count(g.log, "REJECTION", "The Gatekeeper"))
	_check(_count(gu.log, "EFFECT", "struck from the threshold") >= 3, "the Unveiled line of strikes through the gate (%d)" % _count(gu.log, "EFFECT", "struck from the threshold"))
	_check(_count(c.log, "CONVERSION", "called in") >= 3 and _count(c.log, "CONVERSION", "guard caught") >= 3,
		"the Creditor's of blows caught and called in (%d, %d)" % [_count(c.log, "CONVERSION", "guard caught"), _count(c.log, "CONVERSION", "called in")])
	_check(d.counts.get("PAID_FORWARD", 0) >= 3, "the Debtor's of debts paid forward (%d)" % d.counts.get("PAID_FORWARD", 0))
	_check(a.counts.get("RETURNED", 0) >= 3, "the Answer's of blows returned (%d)" % a.counts.get("RETURNED", 0))
	_check(t.counts.get("COPIED", 0) >= 3, "the Twin's of harm done to a seal and suffered by him (%d)" % t.counts.get("COPIED", 0))
	var met_licence := 0
	var met_hearing := 0
	for key: String in results:
		if _count(results[key].log, "IMPOSED", "The Hearing") > 0:
			met_hearing += 1
		if _count(results[key].log, "IMPOSED", "Writ of Licence") > 0:
			met_licence += 1
	_check(met_hearing == 6 and met_licence == 6, "every line went through all three phases: each met the Writ of Licence and The Hearing")
	print("      logs written to " + dir)


func _law(id: String) -> Dictionary:
	return arena.bridge.world.find_law(arena.player.entity_id, id)


func _res() -> int:
	return arena.bridge.resonance(arena.player.entity_id)


func _between(line: Array, a: Vector3, b: Vector3) -> bool:
	return LawGeom.segments_cross(CombatBridge.to_cm(a), CombatBridge.to_cm(b), [line[0], line[1]], [line[2], line[3]])


func _duel(policy: String, law_index: int, unveiled: bool) -> Dictionary:
	await _fresh()
	var p := arena.player
	var v := arena.boss
	var b := arena.bridge
	if unveiled:
		b.set_form(p, "UNVEILED")
	await _choose(law_index)
	_place(p, Vector3(0, 0, 0), 0.0)
	v.ai_enabled = true
	var law_id: String = Player.LAWS[law_index - 1]
	var ticks := 0
	var busy_until := 0            # the policy has committed its hands until this tick
	var second_at := -1            # when to press the second strike of a string
	for i in LIMIT_TICKS:
		ticks = i
		if v.yielded or p.machine.dead():
			break
		var vm := v.machine
		var pm := p.machine
		var hearing := not b.world.find_law(v.entity_id, "voss.the_hearing").is_empty()
		var licence := not b.world.find_law(v.entity_id, "voss.writ_of_licence").is_empty()
		var order := not b.world.find_law(v.entity_id, "voss.writ_of_order").is_empty()
		var recognised := b.world.has_tag(p.entity_id, "recognised")
		var may_impose: bool = not licence or recognised
		var standing := not _law(law_id).is_empty()
		var free := pm.state == S.FREE and not p.imposing and i >= busy_until
		var threat := vm.state == S.ATTACK and vm.in_startup()
		var startup: int = vm.move().get("startup", 0) if vm.state == S.ATTACK else 0
		var active: int = vm.move().get("active", 0) if vm.state == S.ATTACK else 0
		var open := (vm.state == S.ATTACK and vm.t > startup + active) or vm.state == S.RECOIL \
				or vm.state == S.STAGGER or vm.state == S.HITSTUN or vm.state == S.IMPOSE
		var d := p.global_position.distance_to(v.global_position)
		var to_me := (p.global_position - v.global_position).normalized()
		var seen := v.forward().dot(to_me) > 0.3
		var my_reach: float = float(pm.moves[pm.entry["light"]].reach) / 100.0
		var seal: Seal = null
		for s: Variant in v.seals:
			if is_instance_valid(s) and not s.spent and not s.machine.dead():
				seal = s
		var target: Actor = v
		var defend := "parry"

		# ---- what this line does with its law
		if policy == "gatekeeper" or policy == "gate_unveiled":
			var line: Array = _law(law_id).get("args", {}).get("line", [])
			var barred := standing and not line.is_empty() and _between(line, p.global_position, v.global_position)
			if barred:
				defend = "none"               # the line is the defence
			if not standing and free and may_impose and not threat and _res() >= 30 and d > 2.3 and d < 7.0 and seen:
				input.hold(input.tick, 2, "impose")
				busy_until = i + 24
		elif policy == "creditor":
			if standing:
				defend = "catch"              # an ordinary guard: the Tally records the whole blow
			if not standing and free and may_impose and not threat and _res() >= 20:
				input.hold(input.tick, 2, "impose")
				busy_until = i + 24
		elif policy == "debtor":
			var owed := 0
			for debt: Dictionary in b.debts_of(p):
				owed += int(debt.amount)
			if standing and owed < 30:
				defend = "none"               # take it: it is owed, not suffered
			if not standing and free and may_impose and not threat and _res() >= 25:
				input.hold(input.tick, 2, "impose")
				busy_until = i + 24
		elif policy == "answer":
			if not standing and free and may_impose and not threat and _res() >= 25:
				input.hold(input.tick, 2, "impose")
				busy_until = i + 24
		elif policy == "twin":
			if standing and seal != null and not threat:
				target = seal                 # strike the seal; he suffers it
			elif p.marking:
				target = seal if (p.marks.size() == 1 and seal != null) else v
			elif not standing and seal != null and free and may_impose and not threat and _res() >= 30 \
					and seal.global_position.distance_to(v.global_position) < 8.5:
				input.hold(input.tick, 2, "impose")
				busy_until = i + 24

		# ---- defence, by the clock of his wind-up
		if threat and d < float(vm.move().reach) / 100.0 + 1.6:
			if defend == "parry" and vm.t == startup - 2:
				p.lock_target = v
				input.hold(input.tick, 7, "guard")
				busy_until = i + 9
			elif defend == "catch" and vm.t == maxi(1, startup - 16):
				p.lock_target = v
				input.hold(input.tick, 24, "guard")
				busy_until = i + 26

		# ---- footwork and strikes
		p.lock_target = target if i >= busy_until or target == v else p.lock_target
		var td := p.global_position.distance_to(target.global_position)
		var want := my_reach - 0.15 + target.hurt_radius
		var holding_line := (policy == "gatekeeper") and standing
		if i >= busy_until and pm.state == S.FREE and not p.imposing:
			if td > want and not holding_line and not (threat and target == v):
				input.hold(input.tick, 1, "move", Vector2(0, 1))
			elif td < 1.1:
				input.hold(input.tick, 1, "move", Vector2(0, -1))
		var chance := (target != v and not threat) or (target == v and open and seen)
		if chance and td <= want + 0.9 and i >= busy_until:
			var last: String = b.world.entities[p.entity_id].last_act
			if pm.state == S.FREE and not p.imposing:
				var button := "light"
				if hearing and String(pm.moves[pm.entry["light"]].act) == last:
					button = "heavy"
				if policy == "creditor" and standing and target == v and b.owed_by(v, p) >= 18 and _res() >= 5:
					input.hold(input.tick, 3, "impose")      # inscribe: call it in
				_press(button)
				second_at = i + 9
				busy_until = i + 2
			elif pm.state == S.ATTACK and pm.combo_index == 1 and i == second_at:
				var limit := 2 if (order and target == v) else 2
				if limit >= 2 and pm.move().get("next", {}).has("light"):
					_press("light")
		await get_tree().physics_frame
	await _wait(5)
	var counts: Dictionary = {}
	for line: String in b.log_lines:
		var type := line.substr(8, 12).strip_edges()
		counts[type] = counts.get(type, 0) + 1
	return {"ticks": ticks, "hp": p.hp(), "boss_hp": v.hp(), "won": v.yielded, "lost": p.machine.dead(),
		"counts": counts, "log": b.log_lines.duplicate()}
