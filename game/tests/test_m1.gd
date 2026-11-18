extends Node
## Headless tests for milestone M1: the action machine on its own, then the
## real arena scene driven by scripted input, tick by tick. No window.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/TestM1.tscn
##   ... -- --verbose

const S := ActionMachine.S

var passed := 0
var failed := 0
var verbose := false
var arena: Arena
var input: ScriptedInput
var strikes: Array = []     # every info the bridge emitted since the arena was made
var verdicts: Array = []


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run()


func _run() -> void:
	_section("ACTION MACHINE (pure)")
	_machine_tests()

	_section("ARENA: movement and the bridge")
	await _test_movement()
	await _test_lock_on()
	await _test_line_bounces()

	_section("ARENA: striking")
	await _test_plain_post_string()
	await _test_sealed_post_order()
	await _test_sealed_post_standing()

	_section("ARENA: defence")
	await _test_bailiff_hits()
	await _test_guard_chip()
	await _test_perfect_parry()
	await _test_perfect_dodge()

	_section("ARENA: life and death")
	await _test_kill_bailiff()
	await _test_player_falls_and_stands()

	_section("ARENA: the Bailiff's AI")
	await _test_ai_pressure()
	await _test_soak()

	_section("ARENA: as the player sees it (HUD on, headless)")
	await _test_hud()

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
	Arena.fixed_instrument = "counterpart"      # these checks were written against the Edge moveset
	strikes = []
	verdicts = []
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	arena.bridge.verdict.connect(func(rec: Dictionary, _at: Vector3) -> void: verdicts.append(rec))
	await _wait(2)


func _place(actor: Actor, at: Vector3, yaw: float) -> void:
	actor.global_position = at
	actor.facing = yaw
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()


func _press(what: String) -> void:
	input.at(input.tick, what)


func _by(kind: String, attacker: Actor = null) -> Array:
	var out: Array = []
	for s: Dictionary in strikes:
		if s.kind == kind and (attacker == null or s.attacker == attacker):
			out.append(s)
	return out


func _denied_by(rec: Dictionary, law: String) -> bool:
	for o: Dictionary in rec.outcomes:
		if o.type == "REJECTION" and o.get("law", "") == law:
			return true
	return false


## Press light every few ticks until the player has landed `count` strikes
## on anything (or `limit` ticks pass).
func _mash_until(count: int, limit: int) -> void:
	for i in limit:
		var mine := 0
		for s: Dictionary in strikes:
			if s.attacker == arena.player:
				mine += 1
		if mine >= count:
			return
		if i % 5 == 0:
			_press("light")
		await get_tree().physics_frame


# ------------------------------------------------------------ pure machine

func _edge() -> Dictionary:
	return LawRegistry.read_json("res://data/instruments/counterpart.json")


func _step(m: ActionMachine, n: int, guard: bool = false) -> void:
	for i in n:
		m.tick(false, false, false, guard)


func _machine_tests() -> void:
	var m := ActionMachine.new(_edge())
	var began := m.tick(true, false, false, false)
	_check(began.has("attack") and m.state == S.ATTACK and m.move_id == "light_1", "a light press from rest starts light_1 on the same tick")
	var active := 0
	var first_active := 0
	var ticks := 0
	while m.state == S.ATTACK and ticks < 200:
		m.tick(false, false, false, false)
		ticks += 1
		if m.is_active():
			active += 1
			if first_active == 0:
				first_active = ticks
	_check(first_active == 10 and active == 3, "light_1 is active on ticks 10 to 12 (got first %d, count %d)" % [first_active, active])
	_check(ticks == 26, "light_1 returns to rest after 26 ticks (got %d)" % ticks)

	m = ActionMachine.new(_edge())
	m.tick(true, false, false, false)
	_step(m, 11)
	m.tick(true, false, false, false)          # buffered at t=12, whiffed
	_check(m.move_id == "light_1", "a whiffed strike does not chain before its whiff window")
	_step(m, 7)                                 # t=19
	_check(m.move_id == "light_1", "still light_1 one tick before the whiff window")
	_step(m, 1)                                 # t=20
	_check(m.move_id == "light_2" and m.combo_index == 2, "the buffered press chains to light_2 at the whiff window")

	m = ActionMachine.new(_edge())
	m.tick(true, false, false, false)
	_step(m, 1)
	m.tick(true, false, false, false)          # pressed at t=2: far too early
	_step(m, 30)
	_check(m.state == S.FREE, "a press more than ten ticks early is forgotten")

	m = ActionMachine.new(_edge())
	m.tick(true, false, false, false)
	_step(m, 10)                                # t=10, first active tick
	m.mark_connected()
	m.tick(true, false, false, false)          # t=11
	_step(m, 1)                                 # t=12
	_check(m.move_id == "light_1", "on hit, light_1 holds until its cancel tick")
	_step(m, 1)                                 # t=13
	_check(m.move_id == "light_2", "on hit, the chain comes out at tick 13, seven ticks sooner than a whiff")

	m = ActionMachine.new(_edge())
	m.tick(true, false, false, false)
	_step(m, 10)
	m.mark_connected()
	m.hit_stop(4)
	var t_before := m.t
	m.tick(true, false, false, false)          # pressed during hit-stop
	_step(m, 3)
	_check(m.t == t_before, "hit-stop holds the action in place for its four ticks")
	_step(m, 3)
	_check(m.move_id == "light_2", "a press made during hit-stop is kept and chains afterwards")

	m = ActionMachine.new(_edge())
	var seen: Array = []
	for i in 140:
		var b := m.tick(i % 4 == 0, false, false, false)
		if b.has("attack"):
			seen.append("%s:%d" % [m.move_id, m.combo_index])
			m.mark_connected()
	_check(seen.size() >= 4 and seen.slice(0, 4) == ["light_1:1", "light_2:2", "light_3:3", "light_1:1"],
		"mashing light gives light_1, light_2, light_3, then the string starts over (%s)" % str(seen.slice(0, 4)))

	m = ActionMachine.new(_edge())
	m.tick(false, false, true, false)
	var inv := 0
	var perfect := 0
	var len := 0
	while m.state == S.DODGE and len < 100:
		if m.invulnerable():
			inv += 1
		if m.perfect_dodge():
			perfect += 1
		m.tick(false, false, false, false)
		len += 1
	_check(len == 24 and inv == 12 and perfect == 6, "a dodge lasts 24 ticks, 12 invulnerable, the first 6 of those perfect (got %d, %d, %d)" % [len, inv, perfect])
	m.tick(false, false, true, false)
	_step(m, 24)
	m.tick(false, false, true, false)
	_check(m.state == S.DODGE and m.slow_dodge and not m.invulnerable(), "the third dodge in a row is slow")
	var any := false
	len = 0
	while m.state == S.DODGE and len < 100:
		any = any or m.invulnerable()
		m.tick(false, false, false, false)
		len += 1
	_check(len == 36 and not any, "and it lasts 36 ticks with no invulnerability at all (got %d)" % len)

	m = ActionMachine.new(_edge())
	m.tick(false, false, false, true)
	var parry := 0
	for i in 20:
		if m.parrying():
			parry += 1
		m.tick(false, false, false, true)
	_check(parry == 6 and m.guarding(), "a fresh guard parries for its first 6 ticks, then only guards (got %d)" % parry)
	m.tick(false, false, false, false)
	_step(m, 3)
	m.tick(false, false, false, true)
	_check(m.guarding() and not m.parrying(), "tapping guard again straight away does not re-arm the parry")
	m.tick(false, false, false, false)
	_step(m, 30)
	m.tick(false, false, false, true)
	_check(m.parrying(), "after a short wait the parry is armed again")

	m = ActionMachine.new(_edge())
	m.tick(true, false, false, false)
	_step(m, 3)
	m.tick(true, false, false, false)
	m.stun(14)
	_check(m.state == S.HITSTUN and not m.is_active(), "being hit interrupts a strike")
	_step(m, 14)
	_check(m.state == S.FREE, "and the press made before the hit is not carried through the stun")

	m = ActionMachine.new(_edge())
	m.die()
	m.tick(true, true, true, true)
	_check(m.dead() and m.state == S.DEAD, "the dead do not act")


# ------------------------------------------------------------------- arena

func _test_movement() -> void:
	await _fresh()
	var p := arena.player
	var z0 := p.global_position.z
	input.hold(input.tick, 60, "move", Vector2(0, 1))
	await _wait(62)
	var moved := p.global_position.z - z0
	_check(moved > 4.6 and moved < 5.8, "holding forward for a second runs about 5.4 m (went %.2f)" % moved)
	_check(absf(p.global_position.x) < 0.05, "in a straight line")
	await _wait(2)
	var e: Dictionary = arena.bridge.world.entities[p.entity_id]
	_check(absi(e.pos[1] - roundi(p.global_position.z * 100.0)) <= 2, "and the Law Engine knows where the player is, to the centimetre")
	_check(absf(angle_difference(p.facing, 0.0)) < 0.05, "facing the way they ran")
	input.hold(input.tick, 30, "move", Vector2(1, 0))
	await _wait(32)
	_check(p.global_position.x < -1.5, "stick right moves to the camera's right (x %.2f)" % p.global_position.x)


func _test_lock_on() -> void:
	await _fresh()
	_press("lock")
	await _wait(3)
	_check(arena.player.lock_target != null, "lock-on picks a target ahead of the camera")
	_press("lock")
	await _wait(3)
	_check(arena.player.lock_target == null, "and pressing it again lets go")


func _test_line_bounces() -> void:
	await _fresh()
	var b := arena.bridge
	b.world.add_resonance(arena.bailiff.entity_id, 100)
	var rec := b.impose(arena.bailiff, "threshold.gatekeeper", {"line": [-300, -300, 300, -300]})
	_check(rec.verdict == "APPLIED", "an enemy draws a Gatekeeper line across the yard")
	input.hold(input.tick, 70, "move", Vector2(0, 1))
	var max_z := -99.0
	for i in 70:
		await get_tree().physics_frame
		max_z = maxf(max_z, arena.player.global_position.z)
	var law := b.world.find_law(arena.bailiff.entity_id, "threshold.gatekeeper")
	_check(max_z < -2.9, "the player cannot walk through it (furthest z %.2f, line at -3.00)" % max_z)
	_check(not verdicts.is_empty() and _denied_by(verdicts[0], "threshold.gatekeeper"), "the step is refused by the law, and the HUD is told which")
	var bounces := 3 - int(law.get("events_left", 0)) if not law.is_empty() else 3
	_check(bounces >= 1 and bounces <= 2 and verdicts.size() == bounces,
		"each walk into the line is one refusal, not one per tick (%d in 70 ticks)" % bounces)


func _test_plain_post_string() -> void:
	await _fresh()
	var p := arena.player
	var post := arena.plain_post
	_place(p, post.global_position + Vector3(0, 0, -1.7), 0.0)
	await _mash_until(3, 120)
	await _wait(2)
	var mine := _by("hit", p)
	_check(mine.size() == 3, "three presses land three strikes on the plain post (%d)" % mine.size())
	if mine.size() == 3:
		var acts: Array = []
		var total := 0
		for s: Dictionary in mine:
			acts.append(s.rec.children[0].tags.has("from_front"))
			total += int(s.amount)
		_check(acts == [true, true, true], "all struck from the front")
		_check(post.hp() == 300 - 33 and total == 33, "the post has lost 10 + 10 + 13 (hp %d)" % post.hp())
		_check(arena.bridge.resonance(p.entity_id) == 13, "and the player has earned 4 + 4 + 5 Resonance (%d)" % arena.bridge.resonance(p.entity_id))
	_check(verdicts.is_empty(), "plain hits put nothing on the verdict line")


func _test_sealed_post_order() -> void:
	await _fresh()
	var p := arena.player
	var post := arena.sealed_post
	await _wait(35)
	_check(arena.bridge.laws_of(post, 1).size() == 2, "the sealed post keeps two Writs standing")
	_check(arena.bridge.laws_of(post, 1)[0].known == 0, "which the player has not met: they show as struck-out bars")
	_place(p, post.global_position + Vector3(0, 0, -1.7), 0.0)
	await _mash_until(3, 140)
	await _wait(1)
	var all: Array = []
	for s: Dictionary in strikes:
		if s.attacker == p:
			all.append(s)
	_check(all.size() == 3 and all[0].kind == "hit" and all[1].kind == "hit" and all[2].kind == "denied",
		"the first two strikes land and the third is denied")
	if all.size() == 3:
		_check(_denied_by(all[2].rec, "voss.writ_of_order"), "denied by the Writ of Order, and the record says so")
		_check(p.hp() == 94, "the sanction costs the player 6 (hp %d)" % p.hp())
		_check(post.hp() == 300 - 20, "and the third strike did nothing to the post (hp %d)" % post.hp())
		_check(p.machine.state == S.RECOIL or p.machine.freeze > 0, "the player's weapon is thrown back")
	_check(verdicts.size() == 1, "one verdict line is shown")
	var known := 0
	for law: Dictionary in arena.bridge.laws_of(post, 1):
		if law.id == "voss.writ_of_order":
			known = law.known
	_check(known == 1, "the Writ of Order is now sensed: its name shows above the post")


func _test_sealed_post_standing() -> void:
	await _fresh()
	var p := arena.player
	var post := arena.sealed_post
	await _wait(35)
	_place(p, post.global_position + Vector3(0, 0, 1.7), PI)
	_press("light")
	await _wait(30)
	var mine: Array = []
	for s: Dictionary in strikes:
		if s.attacker == p:
			mine.append(s)
	_check(mine.size() == 1 and mine[0].kind == "denied" and _denied_by(mine[0].rec, "voss.writ_of_standing"),
		"a strike from behind the sealed post is denied by the Writ of Standing")
	_check(p.hp() == 92, "and sanctioned for 8 (hp %d)" % p.hp())
	_place(p, post.global_position + Vector3(0, 0, -1.7), 0.0)
	await _wait(20)
	_press("light")
	await _wait(30)
	_check(_by("hit", p).size() == 1, "the same strike from the front lands")


func _face_off(gap: float) -> void:
	_place(arena.player, Vector3(0, 0, 0), 0.0)
	_place(arena.bailiff, Vector3(0, 0, gap), PI)
	await _wait(2)


func _test_bailiff_hits() -> void:
	await _fresh()
	await _face_off(2.0)
	arena.bailiff.press_light = true
	await _wait(45)
	var hits := _by("hit", arena.bailiff)
	_check(hits.size() == 1, "an unanswered Bailiff strike lands")
	_check(arena.player.hp() == 88, "for 12 (hp %d)" % arena.player.hp())
	_check(arena.player.poise == 45, "and 15 poise (%d)" % arena.player.poise)


func _test_guard_chip() -> void:
	await _fresh()
	await _face_off(2.0)
	input.hold(input.tick, 80, "guard")
	await _wait(12)
	arena.bailiff.press_light = true
	await _wait(45)
	_check(_by("guarded", arena.bailiff).size() == 1, "a held guard blocks the strike")
	_check(arena.player.hp() == 97, "taking 30 percent as chip: 3 (hp %d)" % arena.player.hp())
	_check(arena.player.machine.guarding(), "and the guard holds")


func _test_perfect_parry() -> void:
	await _fresh()
	await _face_off(2.0)
	arena.bailiff.press_light = true
	var startup: int = arena.bailiff.machine.moves["light_1"].startup
	var thrown := false
	for i in 60:
		await get_tree().physics_frame
		if arena.bailiff.machine.state == S.ATTACK and arena.bailiff.machine.t == startup - 2:
			input.hold(input.tick, 20, "guard")
		if not _by("parried", arena.bailiff).is_empty() and arena.bailiff.machine.state == S.RECOIL:
			thrown = true
	await _wait(10)
	var parried := _by("parried", arena.bailiff)
	_check(parried.size() == 1, "raising the guard just before the blow parries it")
	if parried.size() == 1:
		_check(parried[0].rec.tags.has("perfect_parry"), "the strike reaches the Law Engine tagged perfect_parry")
	_check(arena.player.hp() == 100, "no harm is taken")
	_check(arena.bridge.resonance(arena.player.entity_id) == 18, "18 Resonance is earned (%d)" % arena.bridge.resonance(arena.player.entity_id))
	_check(thrown, "and the Bailiff is thrown back")
	_check(arena.bailiff.poise == 15, "losing 30 poise (%d)" % arena.bailiff.poise)


func _test_perfect_dodge() -> void:
	await _fresh()
	await _face_off(2.0)
	arena.bailiff.press_light = true
	var startup: int = arena.bailiff.machine.moves["light_1"].startup
	for i in 60:
		await get_tree().physics_frame
		if arena.bailiff.machine.state == S.ATTACK and arena.bailiff.machine.t == startup - 4:
			input.hold(input.tick, 6, "move", Vector2(0, 1))
			_press("dodge")
	await _wait(10)
	_check(_by("perfect_dodge", arena.bailiff).size() == 1, "dodging into the blow at the last moment passes through it")
	_check(arena.player.hp() == 100, "untouched")
	_check(arena.bridge.resonance(arena.player.entity_id) == 12, "and 12 Resonance is earned (%d)" % arena.bridge.resonance(arena.player.entity_id))


func _test_kill_bailiff() -> void:
	await _fresh()
	await _face_off(1.8)
	var b := arena.bailiff
	var id := b.entity_id
	for i in 400:
		if b.machine.dead():
			break
		if i % 5 == 0:
			_press("light")
		await get_tree().physics_frame
	_check(b.machine.dead() and arena.bridge.hp(id) == 0, "the Bailiff falls when his health is gone")
	_check(_by("hit", arena.player).size() >= 5 and _by("hit", arena.player).size() <= 7, "after five or six strikes, not thirty (%d)" % _by("hit", arena.player).size())
	await _wait(250)
	_check(not arena.bridge.actors.has(id), "and his body is cleared away")


func _test_player_falls_and_stands() -> void:
	await _fresh()
	var p := arena.player
	arena.bridge.world.strike(arena.bailiff.entity_id, p.entity_id, 500, ["from_front"])
	await _wait(3)
	_check(p.machine.dead() and p.hp() == 0, "the player can fall")
	_press("light")
	await _wait(20)
	_check(p.machine.dead(), "and cannot act while down")
	await _wait(Arena.PLAYER_RESPAWN_TICKS)
	_check(not p.machine.dead() and p.hp() == 100, "then stands again, whole")
	_check(p.global_position.distance_to(Arena.PLAYER_SPAWN) < 0.2, "where they began")


func _test_ai_pressure() -> void:
	await _fresh()
	arena.bailiff.ai_enabled = true
	var first := -1
	var landed := 0
	for i in 1500:
		await get_tree().physics_frame
		var n := _by("hit", arena.bailiff).size()
		if n > landed:
			landed = n
			if first < 0:
				first = i
	_check(first > 0 and first < 420, "left alone, the Bailiff crosses the yard and lands a strike within seven seconds (tick %d)" % first)
	_check(landed >= 5 and landed <= 14, "and keeps up steady, readable pressure: 5 to 14 hits in 25 seconds (%d)" % landed)


func _test_hud() -> void:
	await _fresh(false)
	arena.bailiff.ai_enabled = false
	var p := arena.player
	await _wait(35)
	_place(p, arena.sealed_post.global_position + Vector3(0, 0, -1.7), 0.0)
	_press("lock")
	await _wait(3)
	_check(p.lock_target == arena.sealed_post, "locking on beside the sealed post takes the sealed post")
	await _mash_until(3, 140)
	await _wait(20)
	var canvas: Hud.HudCanvas = arena.hud.get_child(0)
	_check(canvas._verdicts.size() == 1 and canvas._verdicts[0].type == "REJECTION", "the verdict line shows one REJECTION")
	if canvas._verdicts.size() == 1:
		_check(String(canvas._verdicts[0].name) == "Writ of Order", "naming the Writ of Order")
		_check(String(canvas._verdicts[0].reason).contains("third time") and String(canvas._verdicts[0].reason).contains("sanction 6"),
			"with its reason and its sanction: \"%s\"" % canvas._verdicts[0].reason)
	_check(canvas.draws > 30, "the HUD's drawing code ran every frame without error (%d frames)" % canvas.draws)
	await _wait(240)
	_check(canvas._verdicts.is_empty(), "and it clears after a few seconds")
	Arena.test_mode = true


func _test_soak() -> void:
	await _fresh()
	arena.bailiff.ai_enabled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var why := ""
	var t0 := Time.get_ticks_usec()
	var n := 3600
	var counts := {"enemy": 0, "player": 0}
	arena.bridge.struck.connect(func(info: Dictionary) -> void:
		if info.attacker is Bailiff:
			counts.enemy += 1
		elif info.kind == "hit":
			counts.player += 1)
	for i in n:
		if i % 20 == 0:
			input.hold(input.tick, 20, "move", Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1)))
		var roll := rng.randf()
		if roll < 0.05:
			_press("light")
		elif roll < 0.07:
			_press("heavy")
		elif roll < 0.09:
			_press("dodge")
		elif roll < 0.10:
			input.hold(input.tick, 25, "guard")
		await get_tree().physics_frame
		for id: int in arena.bridge.actors:
			var a: Actor = arena.bridge.actors[id]
			var pos := a.global_position
			var e: Dictionary = arena.bridge.world.entities[id]
			if not (is_finite(pos.x) and is_finite(pos.z)) or absf(pos.x) > 30.0 or absf(pos.z) > 30.0 or pos.y < -1.0 or pos.y > 3.0:
				ok = false
				why = "%s left the yard at %s" % [a.display_name, str(pos)]
			if e.hp < 0 or e.hp > e.hp_max:
				ok = false
				why = "%s has impossible health %d" % [a.display_name, e.hp]
	var per_tick := float(Time.get_ticks_usec() - t0) / float(n)
	_check(ok, "a minute of random play against the AI keeps every actor in the yard with sane health  " + why)
	_check(counts.enemy > 0, "the Bailiff's AI closed in and his strikes reached the player (%d times)" % counts.enemy)
	_check(counts.player > 0, "and the player landed something (%d)" % counts.player)
	print("      whole simulation, headless: %.0f us per tick (frame budget 16667)" % per_tick)
