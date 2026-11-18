extends Node
## Headless tests for milestone M3: the three Instruments (a moveset and a
## verb each), Recognition Trials, and the Unveiling. Driven through real
## input, as before. No window.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/TestM3.tscn

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
var unveilings := 0


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run()


func _run() -> void:
	_section("THREE INSTRUMENTS, THREE BODIES (pure)")
	_moveset_tests()

	_section("THE INSTRUMENT FOLLOWS THE ROOT")
	await _test_follows_root()
	await _test_reach_differs()

	_section("VERBS")
	await _test_plant()
	await _test_catch()
	await _test_show()

	_section("RECOGNITION AND UNVEILING")
	await _test_trial_counts()
	await _test_unveiling()
	await _test_rite_interrupted()
	await _test_awakened_kit()

	_section("AS THE PLAYER SEES IT (HUD on, headless)")
	await _test_presentation()

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
	Arena.fixed_instrument = ""
	strikes = []
	verdicts = []
	unveilings = 0
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	arena.bridge.verdict.connect(func(rec: Dictionary, _at: Vector3) -> void: verdicts.append(rec))
	arena.bridge.unveiled.connect(func(_a: Actor) -> void: unveilings += 1)
	await _wait(2)
	if encounter != 0:
		arena.set_encounter(encounter)
		await _wait(2)
	for e: Enemy in arena.enemies:
		e.ai_enabled = false
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
	await _wait(3)


func _impose(ticks: int = 2) -> void:
	input.hold(input.tick, ticks, "impose")
	await _wait(ticks + 20)


func _law(id: String) -> Dictionary:
	return arena.bridge.world.find_law(arena.player.entity_id, id)


func _res() -> int:
	return arena.bridge.resonance(arena.player.entity_id)


func _face_off(gap: float, at_z: float = 6.0) -> void:
	_place(arena.player, Vector3(0, 0, at_z), 0.0)
	_place(arena.bailiff, Vector3(0, 0, at_z + gap), PI)
	await _wait(2)


func _kinds(kind: String, attacker: Actor = null) -> Array:
	var out: Array = []
	for s: Dictionary in strikes:
		if s.kind == kind and (attacker == null or s.attacker == attacker):
			out.append(s)
	return out


func _bailiff_strikes() -> void:
	var before := strikes.size()
	arena.bailiff.press_light = true
	for i in 70:
		await get_tree().physics_frame
		if strikes.size() > before:
			break
	await _wait(3)


## One press; wait for it to land, or for the swing to be over.
func _player_strikes(button: String = "light", inscribed: bool = false) -> bool:
	var before := strikes.size()
	if inscribed:
		input.hold(input.tick, 3, "impose")
	_press(button)
	for i in 70:
		await get_tree().physics_frame
		if strikes.size() > before:
			await _wait(3)
			return true
	return false


# ------------------------------------------------------------ pure movesets

func _first_active(path: String, button: String) -> Array:
	var data: Dictionary = LawRegistry.read_json(path)
	var m := ActionMachine.new(data)
	m.tick(button == "light", button == "heavy", false, false)
	var first := 0
	var total := 0
	while m.state == S.ATTACK and total < 200:
		m.tick(false, false, false, false)
		total += 1
		if m.is_active() and first == 0:
			first = total
	return [first, total, int(data.moves[data.entry[button]].reach), int(data.moves[data.entry[button]].damage)]


func _string(path: String, awakened: bool, button: String = "light") -> Array:
	var data: Dictionary = LawRegistry.read_json(path)
	var m := ActionMachine.new(data, awakened)
	var seen: Array = []
	for i in 260:
		var began := m.tick(button == "light" and i % 4 == 0, button == "heavy" and i % 4 == 0, false, false)
		if began.has("attack"):
			if seen.has(m.move_id):
				break
			seen.append(m.move_id)
			m.mark_connected()
	return seen


func _moveset_tests() -> void:
	var edge := _first_active("res://data/instruments/counterpart.json", "light")
	var reach := _first_active("res://data/instruments/lintel.json", "light")
	var vessel := _first_active("res://data/instruments/tally.json", "light")
	var short := _first_active("res://data/instruments/lintel_short.json", "light")
	_check(reach[2] > edge[2] and edge[2] > vessel[2], "reach: the Lintel %d cm, the Counterpart %d, the Tally %d" % [reach[2], edge[2], vessel[2]])
	_check(reach[0] > edge[0] and reach[1] > edge[1], "the Lintel's opening strike is the slowest to land and to recover (%d and %d ticks against %d and %d)" % [reach[0], reach[1], edge[0], edge[1]])
	_check(vessel[1] < edge[1], "the Tally's is the quickest to be over (%d ticks against %d)" % [vessel[1], edge[1]])
	_check(reach[3] > edge[3] and edge[3] > vessel[3], "and they hit in that order: %d, %d, %d" % [reach[3], edge[3], vessel[3]])
	_check(short[2] < edge[2] and short[1] < edge[1], "the Lintel's short half is shorter and quicker than either blade (%d cm, %d ticks)" % [short[2], short[1]])
	_check(_string("res://data/instruments/counterpart.json", false) == ["light_1", "light_2", "light_3"], "dormant, the Counterpart's string is three cuts")
	_check(_string("res://data/instruments/counterpart.json", true) == ["light_1", "light_2", "light_3", "light_4"], "awakened, a fourth turning cut follows the third")
	_check(_string("res://data/instruments/lintel.json", true, "heavy") == ["heavy_1", "spin"] and _string("res://data/instruments/lintel.json", false, "heavy") == ["heavy_1"],
		"awakened, the Lintel's heavy blow runs on into a full circle")
	_check(_string("res://data/instruments/tally.json", true).has("cast") and not _string("res://data/instruments/tally.json", false).has("cast"),
		"awakened, the Tally's string ends by casting its cord")
	var tally: Dictionary = LawRegistry.read_json("res://data/instruments/tally.json")
	_check(int(tally.guard_chip_pct) == 15 and int(tally.awakened.moves.cast.reach) >= 450, "the Tally lets 15 percent through its guard; its cast reaches %d cm" % tally.awakened.moves.cast.reach)


# -------------------------------------------------------------------- arena

func _test_follows_root() -> void:
	await _fresh()
	var p := arena.player
	_check(p.instrument_id == "lintel" and p.idle_clip == "2H_Melee_Idle", "with a Threshold law in hand the Witness carries the Lintel")
	await _choose(CREDITOR)
	_check(p.instrument_id == "tally" and p.guard_chip_pct == 15, "choosing a Debt law puts the Tally on")
	await _choose(ANSWER)
	_check(p.instrument_id == "counterpart" and p.machine.moves.has("light_3"), "a Reflection law, the Counterpart")
	_press("light")
	await _wait(4)
	await _choose(GATEKEEPER)
	_check(p.instrument_id == "counterpart" and p.machine.state == S.ATTACK, "an Instrument is never changed in the middle of a swing")
	await _wait(40)
	_check(p.instrument_id == "lintel", "it changes when the swing is over")


func _test_reach_differs() -> void:
	await _fresh()
	var p := arena.player
	var post := arena.plain_post
	# 3.5 m from the post's face: inside the Lintel's sweep, outside the others.
	_place(p, post.global_position + Vector3(0, 0, -3.9), 0.0)
	await _wait(2)
	var hit := await _player_strikes()
	_check(hit and _kinds("hit", p).size() == 1, "from 3.9 m the Lintel reaches the post")
	await _wait(40)
	await _choose(ANSWER)
	_place(p, post.global_position + Vector3(0, 0, -4.4), 0.0)
	await _wait(2)
	hit = await _player_strikes()
	_check(not hit, "from 4.4 m the Counterpart does not, even with its lunge")
	await _wait(20)
	await _choose(GATEKEEPER)
	_place(p, post.global_position + Vector3(0, 0, -4.4), 0.0)
	await _wait(2)
	hit = await _player_strikes()
	_check(hit, "the Lintel does")


func _test_plant() -> void:
	await _fresh()
	var p := arena.player
	await _face_off(5.0)
	_check(not p.planted and p.machine.moves["light_1"].reach == 340, "before a line is drawn the Lintel is whole")
	await _impose()
	var law := _law("threshold.gatekeeper")
	_check(not law.is_empty() and p.planted, "drawing the line plants the Lintel")
	_check(p.machine.moves["light_1"].reach == 210 and p.idle_clip == "Idle", "and the short half is what is left in hand: reach 210")
	var l: Array = law.args.line
	var mid := Vector3((l[0] + l[2]) / 200.0, 0, (l[1] + l[3]) / 200.0)
	_check(Vector3(p.planted_at().x, 0, p.planted_at().z).distance_to(mid) < 0.05, "the stave stands at the middle of the line")
	arena.bridge.world.advance(600)
	await _wait(4)
	_check(_law("threshold.gatekeeper").is_empty() and not p.planted and p.machine.moves["light_1"].reach == 340,
		"when the line ends the Lintel is whole again")
	_check(p.planted_at() == Vector3.INF, "and nothing is left standing in the yard")


func _test_catch() -> void:
	await _fresh()
	var p := arena.player
	await _choose(CREDITOR)
	await _face_off(2.0)
	await _impose()
	input.hold(input.tick, 90, "guard")
	await _wait(14)
	await _bailiff_strikes()
	_check(_kinds("guarded", arena.bailiff).size() == 1, "a Bailiff's strike is caught on the Tally's guard")
	_check(p.hp() == 99, "15 percent of 12 gets through: 1 (hp %d)" % p.hp())
	_check(arena.bridge.owed_by(arena.bailiff, p) == 12, "and he owes all 12: what the guard caught is owed in full (%d)" % arena.bridge.owed_by(arena.bailiff, p))


func _test_show() -> void:
	await _fresh(true, 2)
	var p := arena.player
	var ward: Enemy = arena.enemies[1]
	await _choose(TWIN)
	_place(p, Vector3(0, 0, 6.0), 0.0)
	_place(arena.bailiff, Vector3(-0.5, 0, 7.9), PI)
	_place(ward, Vector3(0.6, 0, 7.8), PI)
	await _wait(2)
	await _impose()
	_check(p.marking and _law("reflection.twin").is_empty(), "the Counterpart's verb: imposing the Twin arms the blade and binds nothing")
	await _player_strikes()
	await _wait(6)
	var law := _law("reflection.twin")
	_check(not law.is_empty() and law.args.pair.has(arena.bailiff.entity_id) and law.args.pair.has(ward.entity_id),
		"one cut that is shown to two binds those two")
	_check(not p.marking, "and the blade is no longer armed")


func _test_trial_counts() -> void:
	await _fresh()
	var p := arena.player
	_check(p.recognition.progress("threshold.gatekeeper") == [0, 5] and not p.can_unveil(), "the Gatekeeper's trial asks for five denials")
	await _face_off(3.4)
	await _impose()
	for i in 3:
		await _bailiff_strikes()
		await _wait(30)
	_check(p.recognition.progress("threshold.gatekeeper") == [3, 5], "three denied strikes are three toward it")
	_check(p.recognition.progress("debt.creditor") == [0, 40], "and nothing toward another law's")
	await _wait(20)
	arena.bridge.rest(p)
	await _impose()
	await _bailiff_strikes()
	await _wait(30)
	await _bailiff_strikes()
	_check(p.recognition.complete("threshold.gatekeeper") and p.can_unveil(), "five, and the Witness is recognised")
	var saved := p.recognition.to_dict()
	var again := Recognition.new()
	again.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(again.complete("threshold.gatekeeper"), "which survives being saved and loaded")


func _recognise(law: String) -> void:
	var need: int = arena.player.recognition.trials[law].need
	arena.player.recognition.have[law] = need


func _test_unveiling() -> void:
	await _fresh()
	var p := arena.player
	await _face_off(3.0)
	input.hold(input.tick, 100, "impose")
	input.hold(input.tick, 100, "guard")
	await _wait(110)
	_check(unveilings == 0 and arena.bridge.form(p) == "DORMANT", "without recognition, holding the two buttons unveils nothing")
	await _wait(30)
	for law: Dictionary in arena.bridge.world.laws.duplicate():
		if law.owner == p.entity_id:
			arena.bridge.world._end_law(law, "test")
	arena.bridge.grant(p, -100)
	_recognise("threshold.gatekeeper")
	await _wait(4)
	input.hold(input.tick, 90, "impose")
	input.hold(input.tick, 90, "guard")
	await _wait(40)
	_check(p.rite_ticks > 30 and arena.bridge.form(p) == "DORMANT", "recognised, the rite begins and takes time")
	_check(_law("threshold.gatekeeper").is_empty() and not p.machine.guarding(), "while it runs, the buttons neither impose nor guard")
	await _wait(42)
	_check(unveilings == 1 and arena.bridge.form(p) == "UNVEILED", "held to the end, the Witness is Unveiled")
	_check(arena.bailiff.machine.state == S.STAGGER, "the Bailiff three metres away is thrown off his feet")
	_check(arena.bailiff.hp() == arena.bailiff.max_hp, "unharmed")
	_check(_res() == 100, "Resonance is made whole")
	await _wait(70)
	_check(p.machine.moves.has("spin"), "the Lintel has woken: its moveset has the circle")
	await _impose()
	var law2 := _law("threshold.gatekeeper")
	_check(not law2.is_empty() and law2.form == "UNVEILED" and law2.events_left == 4, "and the next line drawn is the Unveiled Gatekeeper: four denials")
	input.hold(input.tick, 40, "move", Vector2(0, 1))
	await _wait(44)
	_check(not _law("threshold.gatekeeper").is_empty(), "which its author may walk through")
	_check(not p.can_unveil(), "there is no second Unveiling")


func _test_rite_interrupted() -> void:
	await _fresh()
	var p := arena.player
	_recognise("threshold.gatekeeper")
	await _face_off(2.0)
	input.hold(input.tick, 90, "impose")
	input.hold(input.tick, 90, "guard")
	await _wait(20)
	await _bailiff_strikes()
	await _wait(70)
	_check(unveilings == 0 and arena.bridge.form(p) == "DORMANT", "struck during the rite, the Witness is not Unveiled")
	_check(p.hp() < 100, "the rite is no guard: the blow lands in full (hp %d)" % p.hp())
	_check(p.can_unveil(), "but recognition is not lost; the rite can be tried again")


func _test_awakened_kit() -> void:
	await _fresh()
	var p := arena.player
	await _choose(ANSWER)
	_recognise("reflection.answer")
	_place(p, Vector3(0, 0, 6.0), 0.0)
	_place(arena.bailiff, Vector3(12, 0, 0), PI)
	input.hold(input.tick, 80, "impose")
	input.hold(input.tick, 80, "guard")
	await _wait(150)
	_check(arena.bridge.form(p) == "UNVEILED" and p.machine.moves.has("light_4"), "Unveiled with a Reflection law, the Counterpart gains its fourth cut")
	var post := arena.plain_post
	_place(p, post.global_position + Vector3(0, 0, -1.7), 0.0)
	await _wait(2)
	var seen: Array = []
	for i in 160:
		if i % 5 == 0:
			_press("light")
		await get_tree().physics_frame
		if p.machine.state == S.ATTACK and not seen.has(p.machine.move_id):
			seen.append(p.machine.move_id)
		if seen.size() >= 4:
			break
	_check(seen == ["light_1", "light_2", "light_3", "light_4"], "and mashing light now walks all four (%s)" % str(seen))


func _test_presentation() -> void:
	await _fresh(false)
	arena.bailiff.ai_enabled = false
	var p := arena.player
	arena.bridge.rest(p)
	await _face_off(5.0)
	await _impose()
	await _wait(10)
	var canvas: Hud.HudCanvas = arena.hud.get_child(0)
	_check(p.planted and p.planted_at() != Vector3.INF, "with the HUD on, the planted Lintel is placed in the yard")
	_recognise("threshold.gatekeeper")
	input.hold(input.tick, 90, "impose")
	input.hold(input.tick, 90, "guard")
	await _wait(120)
	_check(arena.bridge.form(p) == "UNVEILED" and canvas.banner.begins_with("Unveiled"), "the Unveiling is announced")
	await _choose(TWIN)
	await _impose()
	await _wait(10)
	_check(p.marking and canvas.draws > 100, "the law panel drew through planting, the rite and an armed blade without error (%d frames)" % canvas.draws)
	Arena.test_mode = true
