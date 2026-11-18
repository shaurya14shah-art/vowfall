extends Node
## Headless tests for milestone M2: every Assertion of the slice, imposed and
## used through the real input path (ScriptedInput -> Player -> CombatBridge
## -> LawWorld), against the M2 opponents. Then one fight played three ways,
## with each verdict log written to docs/m2_logs/. No window.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/TestM2.tscn

const S := ActionMachine.S
const GATEKEEPER := 1
const DIVIDE := 2
const CREDITOR := 3
const DEBTOR := 4
const TWIN := 5
const ANSWER := 6

var passed := 0
var failed := 0
var verbose := false
var arena: Arena
var input: ScriptedInput
var strikes: Array = []
var verdicts: Array = []
var consequences: Array = []


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run()


func _run() -> void:
	_section("IMPOSE, COMMIT, DRAW")
	await _test_tap_bars_the_way()
	await _test_commit()
	await _test_draw()
	await _test_cannot_pay()
	await _test_unveiled_form()

	_section("THRESHOLD in play")
	await _test_gatekeeper_denies()
	await _test_divide_binds_author()

	_section("DEBT in play")
	await _test_creditor()
	await _test_debtor()

	_section("REFLECTION in play")
	await _test_twin()
	await _test_answer()

	_section("COURT LAWS against the player's")
	await _test_warrant_overrides()
	await _test_escort_cancels()
	await _test_commit_breaks_escort()

	_section("OPPONENTS")
	await _test_clerks()

	_section("AS THE PLAYER SEES IT (HUD and law effects on, headless)")
	await _test_presentation()

	_section("ONE FIGHT, THREE WAYS")
	await _three_ways()

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


func _fresh(test_mode: bool = true, encounter: int = 0) -> void:
	if arena != null:
		arena.queue_free()
		await get_tree().process_frame
	Arena.test_mode = test_mode
	Arena.fixed_instrument = "counterpart"      # Instruments are M3's subject; here the law is
	strikes = []
	verdicts = []
	consequences = []
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	arena.bridge.verdict.connect(func(rec: Dictionary, _at: Vector3) -> void: verdicts.append(rec))
	arena.bridge.consequence.connect(func(info: Dictionary) -> void: consequences.append(info))
	await _wait(2)
	if encounter != 0:
		arena.set_encounter(encounter)
		for e: Enemy in arena.enemies:
			e.ai_enabled = false
		await _wait(2)
	arena.bridge.rest(arena.player)


func _place(actor: Actor, at: Vector3, yaw: float) -> void:
	actor.global_position = at
	actor.facing = yaw
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()


func _press(what: String) -> void:
	input.at(input.tick, what)


func _choose(n: int) -> void:
	input.hold(input.tick, 1, "select", n)


## Press the Axiom button for `ticks` and let go.
func _impose(ticks: int = 2) -> void:
	input.hold(input.tick, ticks, "impose")
	await _wait(ticks + 4)


func _law(id: String) -> Dictionary:
	return arena.bridge.world.find_law(arena.player.entity_id, id)


func _res() -> int:
	return arena.bridge.resonance(arena.player.entity_id)


func _face_off(gap: float, at_z: float = 0.0) -> void:
	_place(arena.player, Vector3(0, 0, at_z), 0.0)
	_place(arena.bailiff, Vector3(0, 0, at_z + gap), PI)
	await _wait(2)


func _kinds(kind: String, attacker: Actor = null) -> Array:
	var out: Array = []
	for s: Dictionary in strikes:
		if s.kind == kind and (attacker == null or s.attacker == attacker):
			out.append(s)
	return out


func _cons(kind: String) -> Array:
	var out: Array = []
	for c: Dictionary in consequences:
		if c.kind == kind:
			out.append(c)
	return out


func _outcome(rec: Dictionary, type: String, law: String, over: String = "") -> bool:
	for o: Dictionary in rec.outcomes:
		if o.type == type and o.get("law", "") == law and (over == "" or o.get("over", "") == over):
			return true
	for c: Dictionary in rec.children:
		if _outcome(c, type, law, over):
			return true
	return false


func _any_verdict(type: String, law: String, over: String = "") -> bool:
	for rec: Dictionary in verdicts:
		if _outcome(rec, type, law, over):
			return true
	return false


## The Bailiff throws one light strike; wait until it has resolved.
func _bailiff_strikes() -> void:
	var before := strikes.size()
	arena.bailiff.press_light = true
	for i in 70:
		await get_tree().physics_frame
		if strikes.size() > before:
			break
	await _wait(3)


func _player_strikes(inscribed: bool = false) -> void:
	var before := strikes.size()
	if inscribed:
		input.hold(input.tick, 3, "impose")
	_press("light")
	for i in 50:
		await get_tree().physics_frame
		if strikes.size() > before:
			break
	await _wait(3)


# ---------------------------------------------------------------- imposing

func _test_tap_bars_the_way() -> void:
	await _fresh()
	await _face_off(6.0)
	_check(arena.player.law_id == "threshold.gatekeeper", "the Gatekeeper is the law in hand to begin with")
	_check(_res() == 100, "resting fills Resonance")
	await _impose()
	var law := _law("threshold.gatekeeper")
	_check(not law.is_empty(), "tapping the Axiom button imposes it")
	if not law.is_empty():
		var l: Array = law.args.line
		_check(absi(l[1] - 140) <= 3 and absi(l[3] - 140) <= 3 and absi(absi(l[0] - l[2]) - 596) <= 3,
			"as a line just under six metres, 1.4 m ahead, square to the way the player faces (%s)" % str(l))
		_check(law.authority == 20, "with a Technique's plain authority, 20 (%d)" % law.authority)
	_check(_res() == 70, "for its price of 30 (%d left)" % _res())
	_check(arena.bridge.log_lines.size() >= 1 and String(arena.bridge.log_lines[0]).contains("IMPOSED"), "and the verdict log records it")


func _test_commit() -> void:
	await _fresh()
	await _face_off(6.0)
	input.hold(input.tick, 61, "impose")
	await _wait(30)
	_check(arena.player.imposing and arena.player.commit_now() == 4, "holding the button commits Resonance as it is held (%d at half a second)" % arena.player.commit_now())
	await _wait(40)
	var law := _law("threshold.gatekeeper")
	_check(not law.is_empty() and law.authority == 30, "a full second commits 10: authority 30 (%d)" % law.get("authority", 0))
	_check(_res() == 60, "and costs 30 + 10 (%d left)" % _res())


func _test_draw() -> void:
	await _fresh()
	await _face_off(8.0)
	input.hold(input.tick, 60, "impose")
	input.hold(input.tick, 60, "move", Vector2(1, 0))
	await _wait(66)
	var law := _law("threshold.gatekeeper")
	_check(not law.is_empty(), "walking with the button held draws the line where the player walked")
	if not law.is_empty():
		var l: Array = law.args.line
		var length := sqrt(float(LawGeom.dist_sq([l[0], l[1]], [l[2], l[3]])))
		_check(absi(l[0]) <= 2 and absi(l[1]) <= 2, "starting where the button went down (%s)" % str(l))
		_check(l[2] < -100 and absi(l[3]) <= 5, "running to the camera's right, the way the player walked")
		var walked := -arena.player.global_position.x * 100.0
		_check(absf(walked - length - 40.0) < 12.0, "and stopping 40 cm short of their feet (line %.0f cm, walked %.0f)" % [length, walked])
	input.hold(input.tick, 20, "move", Vector2(1, 0))
	await _wait(24)
	_check(not _law("threshold.gatekeeper").is_empty(), "so walking on past its end does not cross it")


func _test_cannot_pay() -> void:
	await _fresh()
	arena.bridge.grant(arena.player, -100)
	await _impose()
	_check(_law("threshold.gatekeeper").is_empty(), "with no Resonance, nothing is imposed")
	_check(verdicts.size() == 1 and verdicts[0].verdict == "REJECTED", "and the HUD is told it was refused")
	_check(_res() == 0, "at no cost")


func _test_unveiled_form() -> void:
	await _fresh()
	await _face_off(8.0)
	_press("unveil")
	await _wait(2)
	_check(arena.bridge.form(arena.player) == "UNVEILED", "the practice yard can switch the player to the Unveiled form")
	await _impose()
	var law := _law("threshold.gatekeeper")
	_check(not law.is_empty() and law.form == "UNVEILED" and law.events_left == 4, "an Unveiled Gatekeeper has four denials")
	input.hold(input.tick, 40, "move", Vector2(0, 1))
	await _wait(44)
	_check(arena.player.global_position.z > 1.8 and not _law("threshold.gatekeeper").is_empty(), "and its author may walk through it")


# --------------------------------------------------------------- threshold

func _test_gatekeeper_denies() -> void:
	await _fresh()
	await _face_off(3.4)
	await _impose()
	await _bailiff_strikes()
	var denied := _kinds("denied", arena.bailiff)
	_check(denied.size() == 1 and _outcome(denied[0].rec, "REJECTION", "threshold.gatekeeper"), "a Bailiff's strike across the line is denied by the Gatekeeper")
	_check(arena.player.hp() == 100, "the player is unharmed")
	_check(_law("threshold.gatekeeper").events_left == 2, "one of three denials is spent")
	_check(arena.bailiff.machine.state == S.RECOIL or arena.bailiff.machine.freeze > 0, "and the Bailiff's weapon is thrown back")
	await _wait(30)
	await _player_strikes()
	_check(_kinds("hit", arena.player).size() == 1, "the player may strike out across their own line")
	await _wait(30)
	await _bailiff_strikes()
	await _wait(30)
	await _bailiff_strikes()
	_check(_law("threshold.gatekeeper").is_empty(), "after three denials the line is spent")
	await _wait(40)
	await _bailiff_strikes()
	_check(arena.player.hp() < 100, "and the next strike lands")


func _test_divide_binds_author() -> void:
	await _fresh()
	await _face_off(2.4)
	_choose(DIVIDE)
	await _wait(2)
	await _impose()
	_check(not _law("threshold.divide").is_empty(), "the Divide is drawn between the player and the Bailiff")
	await _player_strikes()
	var mine := _kinds("denied", arena.player)
	_check(mine.size() == 1 and _outcome(mine[0].rec, "REJECTION", "threshold.divide"), "and the player's own strike across it is denied: it binds its author")
	await _wait(30)
	await _bailiff_strikes()
	_check(_kinds("denied", arena.bailiff).size() == 1 and arena.player.hp() == 100, "as is the Bailiff's")


# -------------------------------------------------------------------- debt

func _test_creditor() -> void:
	await _fresh()
	await _face_off(2.0)
	_choose(CREDITOR)
	await _wait(2)
	await _impose()
	_check(not _law("debt.creditor").is_empty() and _res() == 80, "the Creditor is imposed on oneself for 20")
	await _bailiff_strikes()
	_check(arena.player.hp() == 88, "a Bailiff's strike still hurts: 12")
	_check(arena.bridge.owed_by(arena.bailiff, arena.player) == 12, "but it is recorded: he owes 12")
	await _wait(35)
	await _player_strikes(true)
	var hits := _kinds("hit", arena.player)
	_check(hits.size() == 1 and hits[0].rec.tags.has("call_in"), "holding the Axiom button while striking inscribes the strike")
	_check(arena.bailiff.hp() == 60 - 22, "and it lands with everything he owes: 10 + 12 (hp %d)" % arena.bailiff.hp())
	_check(arena.bridge.owed_by(arena.bailiff, arena.player) == 0, "clearing the debt")
	_check(_res() == 80 - 5 + 4, "the inscription costs 5 Resonance (%d)" % _res())
	_check(_any_verdict("CONVERSION", "debt.creditor"), "and both the loan and the call-in reach the verdict line")
	_check(not _law("debt.creditor").is_empty(), "the law is still standing: holding the button to inscribe did not re-impose it")


func _test_debtor() -> void:
	await _fresh()
	await _face_off(2.0)
	_choose(DEBTOR)
	await _wait(2)
	await _impose()
	await _bailiff_strikes()
	_check(arena.player.hp() == 100, "a Debtor struck for 12 loses nothing now")
	_check(_kinds("held", arena.bailiff).size() == 1, "the blow still lands on the body, and is reported as held")
	var debts := arena.bridge.debts_of(arena.player)
	_check(debts.size() == 1 and debts[0].amount == 15, "15 is owed: the 12, and a quarter more")
	await _wait(35)
	await _player_strikes()
	_check(arena.bailiff.hp() == 60 - 10 - 10, "the player's strike pays 10 of it forward onto the Bailiff (hp %d)" % arena.bailiff.hp())
	_check(_cons("paid_forward").size() == 1 and _cons("paid_forward")[0].target == arena.bailiff, "and he is told so")
	debts = arena.bridge.debts_of(arena.player)
	_check(debts.size() == 1 and debts[0].amount == 2, "2 is still owed")
	await _wait(480)
	_check(arena.player.hp() == 98 and arena.bridge.debts_of(arena.player).is_empty(), "and comes due eight seconds after the blow (hp %d)" % arena.player.hp())
	_check(_cons("debt_due").size() == 1, "which the player is told")


# -------------------------------------------------------------- reflection

func _test_twin() -> void:
	await _fresh(true, 2)
	var ward: Enemy = arena.enemies[1]
	_place(arena.player, Vector3(0, 0, 9.0), 0.0)
	_place(arena.bailiff, Vector3(0, 0, 11.0), PI)
	_place(ward, Vector3(6.0, 0, 9.0), PI)
	await _wait(2)
	_choose(TWIN)
	await _wait(2)
	await _impose()
	_check(arena.player.marking and _law("reflection.twin").is_empty() and _res() == 100,
		"imposing the Twin binds nothing yet and costs nothing: it arms the blade")
	await _player_strikes()
	_check(arena.player.marks == [arena.bailiff] and arena.bailiff.hp() == 50, "the first one struck is marked")
	await _wait(30)        # let that swing finish before anyone is moved into it
	_place(arena.bailiff, Vector3(-4.0, 0, 9.0), PI)
	_place(ward, Vector3(0, 0, 11.0), PI)
	await _wait(30)
	await _player_strikes()
	var law := _law("reflection.twin")
	_check(not law.is_empty() and law.args.pair == [arena.bailiff.entity_id, ward.entity_id] and not arena.player.marking,
		"the second one struck completes the pair, and the law is imposed")
	_check(_res() == 70, "at its price of 30 (%d left)" % _res())
	_check(ward.hp() == 30, "the blow that bound them was struck before the bond, and is not shared")
	await _wait(30)
	await _player_strikes()
	_check(ward.hp() == 20 and arena.bailiff.hp() == 50 - 6, "the next blow on the Ward does 6 to the Bailiff four metres away (hp %d)" % arena.bailiff.hp())
	_check(_cons("copied").size() == 1 and _cons("copied")[0].target == arena.bailiff, "who flinches from a blow that never touched him")


func _test_answer() -> void:
	await _fresh()
	await _face_off(2.0)
	_choose(ANSWER)
	await _wait(2)
	await _impose()
	await _player_strikes()
	_check(arena.bailiff.hp() == 60 - 10 - 5, "under the Answer, a strike for 10 is struck again from the far side for 5 (hp %d)" % arena.bailiff.hp())
	_check(_cons("mirrored").size() == 1, "and the reflection is reported")
	await _wait(40)
	var hp_before := arena.bailiff.hp()
	arena.bailiff.press_light = true
	var startup: int = arena.bailiff.machine.moves["light_1"].startup
	for i in 60:
		await get_tree().physics_frame
		if arena.bailiff.machine.state == S.ATTACK and arena.bailiff.machine.t == startup - 2:
			input.hold(input.tick, 20, "guard")
	await _wait(10)
	_check(_kinds("converted", arena.bailiff).size() == 1, "a perfect parry under the Answer converts the blow")
	_check(arena.bailiff.hp() == hp_before - 12, "returning all 12 of it to the Bailiff (hp %d)" % arena.bailiff.hp())
	_check(arena.player.hp() == 100, "the player is untouched")
	_check(_cons("returned").size() == 1 and _any_verdict("CONVERSION", "reflection.answer"), "and the verdict line says it was answered in kind")


# -------------------------------------------------------------- court laws

func _test_warrant_overrides() -> void:
	await _fresh(true, 1)
	await _face_off(3.4)
	arena.bailiff._keep_laws()
	_check(arena.bridge.laws_of(arena.bailiff, 1).is_empty(), "a Bailiff does not draw his Warrant until his quarry has a law standing")
	await _impose()
	arena.bailiff._keep_laws()
	_check(arena.bridge.laws_of(arena.bailiff, 1).size() == 1, "once the Gatekeeper stands, he draws it")
	await _bailiff_strikes()
	_check(_kinds("hit", arena.bailiff).size() == 1 and arena.player.hp() == 88, "and his strike passes the line")
	_check(_any_verdict("OVERRIDE", "court.warrant", "threshold.gatekeeper"), "OVERRIDE: the narrower law carves its exception, and the verdict line says so")
	_check(_law("threshold.gatekeeper").events_left == 3, "the line itself is not spent by it")


func _test_escort_cancels() -> void:
	await _fresh(true, 2)
	await _face_off(3.4, 6.0)
	_place(arena.enemies[1], Vector3(2.0, 0, 10.5), PI)
	await _impose()
	arena.bailiff._keep_laws()
	_check(arena.bridge.laws_of(arena.bailiff, 1).size() == 1, "a Bailiff with a Ward answers a law with an Escort over the pair")
	await _bailiff_strikes()
	_check(_any_verdict("CANCELLATION", "threshold.gatekeeper"), "CANCELLATION: an uncommitted line and an Escort are matched, and both give way")
	_check(_law("threshold.gatekeeper").is_empty() and arena.bridge.laws_of(arena.bailiff, 1).is_empty(), "neither law is left standing")
	_check(arena.player.hp() == 88, "and the strike lands")


func _test_commit_breaks_escort() -> void:
	await _fresh(true, 2)
	await _face_off(3.4, 6.0)
	_place(arena.enemies[1], Vector3(2.0, 0, 10.5), PI)
	await _impose(61)
	arena.bailiff._keep_laws()
	await _bailiff_strikes()
	_check(_any_verdict("CONTEST", "threshold.gatekeeper", "court.escort"), "CONTEST: a line with 10 committed outweighs the Escort")
	_check(arena.bridge.laws_of(arena.bailiff, 1).is_empty(), "the Escort is broken")
	_check(not _law("threshold.gatekeeper").is_empty() and arena.player.hp() == 100, "the line holds and the strike is denied")


# ---------------------------------------------------------------- opponents

func _test_clerks() -> void:
	await _fresh(true, 3)
	_check(arena.enemies.size() == 4, "the fourth encounter is four Clerks")
	_place(arena.player, Vector3(0, 0, 6.0), 0.0)
	_choose(CREDITOR)
	await _wait(2)
	await _impose()
	for e: Enemy in arena.enemies:
		e.ai_enabled = true
	var most := 0
	var ok := true
	var owed := 0
	for i in 840:
		await get_tree().physics_frame
		most = maxi(most, arena.bridge.attackers(2, null))
		var now := 0
		for e: Variant in arena.enemies:
			if is_instance_valid(e):
				now += arena.bridge.owed_by(e, arena.player)
		owed = maxi(owed, now)
		for id: int in arena.bridge.actors:
			var pos: Vector3 = arena.bridge.actors[id].global_position
			if absf(pos.x) > 30.0 or absf(pos.z) > 30.0:
				ok = false
	var hits := _kinds("hit").size()
	_check(hits >= 4, "left alone for fourteen seconds, four Clerks land plenty of small hits (%d)" % hits)
	_check(most >= 1 and most <= Enemy.MAX_ATTACKERS + 1, "taking turns: never more than about two swinging at once (most %d)" % most)
	_check(owed >= 15, "and a Creditor's ledger fills up among them (%d owed)" % owed)
	_check(ok, "nobody leaves the yard")


# ------------------------------------------------------------- presentation

func _test_presentation() -> void:
	await _fresh(false)
	arena.bailiff.ai_enabled = false
	arena.bridge.rest(arena.player)
	await _face_off(3.4)
	input.hold(input.tick, 30, "impose")
	await _wait(20)
	_check(arena.law_fx.visual_count() == 1, "while the button is held, the line to be is previewed on the floor")
	await _wait(30)
	_check(arena.law_fx.visual_count() == 1 and not _law("threshold.gatekeeper").is_empty(), "once imposed, the standing line is drawn in its place")
	_choose(CREDITOR)
	await _wait(2)
	await _impose()
	await _bailiff_strikes()
	await _bailiff_strikes()
	await _wait(20)
	_check(arena.law_fx.visual_count() >= 2, "a law on oneself is ringed at the feet, and what is owed hangs over the debtor as beads (%d things drawn)" % arena.law_fx.visual_count())
	var canvas: Hud.HudCanvas = arena.hud.get_child(0)
	_check(canvas.draws > 60, "the HUD, law panel included, drew every frame without error (%d frames)" % canvas.draws)
	arena.player.lock_target = arena.bailiff
	await _wait(3)
	arena.set_encounter(3)
	await _wait(5)
	_check(arena.player.lock_target == null, "changing opponents while locked on one of them lets go of the lock")
	_check(canvas.banner == "Four Clerks" and arena.enemies.size() == 4, "changing opponents announces them")
	_check(_law("debt.creditor").is_empty() == false, "and the player's own law survives the change")
	Arena.test_mode = true


# ------------------------------------------------------------- three ways
# The same Bailiff, the same seed, three different laws. Each is played by a
# small scripted policy, not by a person: the point is that the engine makes
# them different fights, and that the difference can be read in a log.

func _three_ways() -> void:
	var results: Dictionary = {}
	for way: Array in [["gatekeeper", GATEKEEPER], ["creditor", CREDITOR], ["answer", ANSWER]]:
		results[way[0]] = await _fight(way[0], way[1])
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/m2_logs").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	for key: String in results:
		var r: Dictionary = results[key]
		var f := FileAccess.open(dir.path_join(key + ".txt"), FileAccess.WRITE)
		f.store_string("VOWFALL verdict log. One Court Bailiff, same seed. The player's law: %s.\n" % r.law)
		f.store_string("Played by a scripted policy, not a person. %s after %.1f s; the player ended on %d health.\n" % [
			"The Bailiff fell" if r.won else ("The player fell" if r.lost else "Unfinished"), r.ticks / 60.0, r.hp])
		f.store_string("Outcomes: %s\n\n" % str(r.counts))
		f.store_string("  tick  outcome       law                 what happened  [who -> whom]\n")
		f.store_string("\n".join(r.log) + "\n")
		f.close()
		print("      %-10s %s in %5.1f s, player on %3d hp, %s" % [key, "won " if r.won else ("LOST" if r.lost else "open"), r.ticks / 60.0, r.hp, str(r.counts)])
	var g: Dictionary = results["gatekeeper"]
	var c: Dictionary = results["creditor"]
	var a: Dictionary = results["answer"]
	_check(g.won and c.won and a.won, "all three policies bring the Bailiff down")
	_check(g.counts.get("REJECTION", 0) >= 3, "under the Gatekeeper the fight is decided by denials (%d)" % g.counts.get("REJECTION", 0))
	_check(c.counts.get("CONVERSION", 0) >= 2 and c.counts.get("REJECTION", 0) == 0, "under the Creditor by loans and call-ins, and nothing is denied (%d conversions)" % c.counts.get("CONVERSION", 0))
	_check(a.counts.get("MIRRORED", 0) >= 1 and a.counts.get("RETURNED", 0) >= 2 and a.counts.get("REJECTION", 0) == 0, "under the Answer by reflections and returned blows (%d mirrored, %d returned)" % [a.counts.get("MIRRORED", 0), a.counts.get("RETURNED", 0)])
	_check(g.log != c.log and c.log != a.log and g.log != a.log, "three different logs from one encounter")
	_check(a.hp == 100 and c.hp < 100, "and three different costs: the Answer is never touched, the Creditor pays in health for what it collects (%d, %d, %d)" % [g.hp, c.hp, a.hp])
	print("      logs written to " + dir)


func _fight(policy: String, law_index: int) -> Dictionary:
	await _fresh()
	var p := arena.player
	var b := arena.bailiff
	b.ai_enabled = true
	_choose(law_index)
	await _wait(2)
	var law_id: String = Player.LAWS[law_index - 1]
	var ticks := 0
	var guard_until := -1
	for i in 5400:
		ticks = i
		if b.machine.dead() or p.machine.dead():
			break
		if not is_instance_valid(p.lock_target):
			p.lock_target = b
		var d := p.global_position.distance_to(b.global_position)
		var free := p.machine.state == S.FREE and not p.imposing
		var standing := not _law(law_id).is_empty()
		var threat := b.machine.state == S.ATTACK and b.machine.in_startup()
		var startup: int = b.machine.move().get("startup", 0) if b.machine.state == S.ATTACK else 0

		var recoiling := b.machine.state == S.RECOIL or b.machine.state == S.STAGGER or b.machine.state == S.HITSTUN
		if policy == "gatekeeper":
			# Bar the way, stand behind the line, and strike only when a
			# denial has thrown him back. Never step over the line.
			if not standing and free and _res() >= 30 and d > 2.8 and d < 6.0:
				input.hold(input.tick, 2, "impose")
			elif standing and free and recoiling and d < 3.3 and i % 6 == 0:
				_press("light")
			elif not standing and _res() < 30:
				_brawl(p, b, d, free, threat, i)
		elif policy == "creditor":
			# Face him, take the blow, and strike only to call the debt in.
			if not standing and free and _res() >= 20 and not threat:
				input.hold(input.tick, 2, "impose")
			elif d > 2.2 and not threat:
				input.hold(input.tick, 1, "move", Vector2(0, 1))
			elif free and not threat and arena.bridge.owed_by(b, p) >= 12 and _res() >= 5 and i % 6 == 0:
				input.hold(input.tick, 3, "impose")
				_press("light")
		elif policy == "answer":
			# Parry everything; strike only into the opening that makes.
			if not standing and free and _res() >= 25 and not threat:
				input.hold(input.tick, 2, "impose")
			elif threat and b.machine.t == startup - 2 and d < 3.6:
				input.hold(input.tick, 7, "guard")
				guard_until = i + 7
			elif i < guard_until:
				pass
			elif d > 2.2 and not threat:
				input.hold(input.tick, 1, "move", Vector2(0, 1))
			elif free and recoiling and i % 5 == 0:
				_press("light")
		await get_tree().physics_frame
	await _wait(5)
	var counts: Dictionary = {}
	for line: String in arena.bridge.log_lines:
		var type := line.substr(8, 12).strip_edges()
		counts[type] = counts.get(type, 0) + 1
	return {"law": Player.LAWS[law_index - 1], "ticks": ticks, "hp": p.hp(), "won": b.machine.dead(),
		"lost": p.machine.dead(), "counts": counts, "log": arena.bridge.log_lines.duplicate()}


## No law to lean on: close in, strike when he is not striking, guard when he is.
func _brawl(_p: Player, _b: Enemy, d: float, free: bool, threat: bool, i: int) -> void:
	if threat and d < 3.4:
		input.hold(input.tick, 1, "guard")
	elif d > 2.3:
		input.hold(input.tick, 1, "move", Vector2(0, 1))
	elif free and i % 7 == 0:
		_press("light")
