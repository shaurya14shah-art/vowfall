extends Node
## Headless tests for milestone M5: the Assize Quarter. The Witness is walked
## through the real district by scripted input: up the Stair to the Hall,
## down through the Docket and out by its gate. Then vow-stones, those who
## keep each place, the Hall's bar, and what can be read. No window.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/TestM5.tscn

var passed := 0
var failed := 0
var verbose := false
var q: Quarter
var input: ScriptedInput
var lowest := 0.0


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run()


func _run() -> void:
	_section("THE QUARTER AS BUILT")
	await _test_structure()
	_section("UP THE STAIR TO THE HALL")
	await _test_route_stair()
	_section("DOWN THROUGH THE DOCKET, OUT BY ITS GATE")
	await _test_gate_is_one_way()
	await _test_route_docket()
	_section("VOW-STONES")
	await _test_stones()
	await _test_falling()
	_section("VOWS")
	await _test_vow_menu()
	await _test_vow_kept()
	await _test_vow_falls()
	await _test_vow_and_rest_and_death()
	_section("THOSE WHO KEEP EACH PLACE")
	await _test_posts()
	_section("THE HALL OF STANDING")
	await _test_hall()
	await _test_falling_in_the_hall()
	_section("WHAT CAN BE READ")
	await _test_records()
	_section("AS THE PLAYER SEES IT (HUD on, headless)")
	await _test_presentation()
	_section("COST")
	await _test_cost()
	print("\n%d passed, %d failed" % [passed, failed])
	q.queue_free()
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
	if q != null:
		q.queue_free()
		await get_tree().process_frame
	Arena.test_mode = test_mode
	Arena.capture_mouse = false
	Arena.fixed_instrument = "counterpart"
	q = (load("res://scenes/Quarter.tscn") as PackedScene).instantiate()
	add_child(q)
	input = ScriptedInput.new()
	q.player.input = input
	lowest = 0.0
	await _wait(4)


func _place(actor: Actor, at: Vector3, yaw: float = 0.0) -> void:
	actor.global_position = at
	actor.facing = yaw
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()


## Walk the real player toward a point with the stick, as a person would.
func _walk_to(target: Vector3, limit: int = 900, stop: float = 0.6) -> bool:
	var p := q.player
	input.clear()
	for i in limit:
		var to := target - p.global_position
		to.y = 0.0
		if to.length() < stop:
			return true
		var d := to.normalized()
		var yaw := q.camera.yaw
		var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
		var right := Vector3(-cos(yaw), 0.0, sin(yaw))
		input.hold(input.tick, 1, "move", Vector2(d.dot(right), d.dot(fwd)))
		await get_tree().physics_frame
		lowest = minf(lowest, p.global_position.y)
	return false


func _walk(points: Array) -> bool:
	for p: Vector3 in points:
		if not await _walk_to(p):
			return false
	return true


func _interact() -> void:
	input.clear()
	input.at(0, "interact")
	await _wait(3)


func _choose(n: int) -> void:
	input.clear()
	input.hold(0, 1, "select", n)
	await _wait(3)


func _floor_under(at: Vector3) -> float:
	var space := q.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN * 4.0, 1)
	var hit := space.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else -999.0


func _hurt(target: Actor, amount: int) -> void:
	# A plain harm from the first keeper of the market, by no one's hand.
	var from: Actor = q.groups["bailiff"].enemies[0]
	if target != q.player:
		from = q.player
	q.bridge.world.strike(from.entity_id, target.entity_id, amount, ["from_front"])


func _alive(id: String) -> int:
	var n := 0
	for e: Variant in q.groups[id].enemies:
		if is_instance_valid(e) and not e.machine.dead():
			n += 1
	return n


# -------------------------------------------------------------- the place

func _test_structure() -> void:
	await _fresh()
	_check(q.data.name == "The Assize Quarter" and q.data.areas.size() == 4, "one district of four places")
	_check(q.area_at(q.player.global_position).get("id", "") == "market", "the Witness starts in the Oath-Market")
	_check(q.area_at(Vector3(0, 4, 42)).get("id", "") == "stair" and q.area_at(Vector3(45, -4, 20)).get("id", "") == "docket"
		and q.area_at(Vector3(0, 8, 100)).get("id", "") == "hall", "the Stair, the Docket and the Hall are where the map says")
	_check(q.missing_props.is_empty(), "every model the Quarter asks for exists (%s)" % str(q.missing_props))
	var stone := q.get_node("Massing/Stone") as MeshInstance3D
	_check(stone != null and stone.mesh.get_surface_count() <= 9,
		"all its stone is one mesh of %d surfaces" % (stone.mesh.get_surface_count() if stone != null else -1))
	var wrong: Array = []
	for s: Dictionary in q.data.stones:
		if absf(_floor_under(Quarter._v(s.stand)) - float(s.stand[1])) > 0.15:
			wrong.append(s.id)
	for g: Dictionary in q.data.encounters:
		for entry: Array in g.spawn:
			if absf(_floor_under(Quarter._v(entry[1])) - float(entry[1][1])) > 0.15:
				wrong.append(g.id)
	for r: Dictionary in q.data.records:
		var f := float(r.get("facing", 0.0))
		var front := Quarter._v(r.at) + Vector3(sin(f), 0.0, cos(f)) * 1.2
		if absf(_floor_under(front) - float(r.at[1])) > 0.15:
			wrong.append(r.id)
	_check(wrong.is_empty(), "every stone, keeper and record stands on the floor it claims (%s)" % str(wrong))
	var total := 0
	for id: String in q.groups:
		total += q.groups[id].enemies.size()
	_check(q.groups.size() == 5 and total == 9, "five posts are kept, by nine in all")
	var asleep := true
	for e: Variant in q.enemies:
		if e.ai_enabled:
			asleep = false
	_check(asleep and not q._fighting(), "and none of them has noticed the Witness yet")
	_check(q.gates.size() == 2 and not (q.gates["docket_gate"] as Gate).is_open and (q.gates["hall_gate"] as Gate).is_open,
		"the Docket Gate is shut; the Hall stands open")
	await _wait(60)
	_check(absf(q.player.global_position.y) < 0.1 and absf(q.boss.global_position.y - 8.0) < 0.1,
		"after a second everyone is standing on stone, not falling through it")


func _test_route_stair() -> void:
	await _fresh()
	var p := q.player
	_check(await _walk([Vector3(3.5, 0, 6), Vector3(3.5, 0, 17.5)]), "across the market, past the Bailiff")
	_check(q.groups["bailiff"].awake and q.said() == "A Bailiff at the Stair", "he notices; the encounter is named")
	_check(await _walk([Vector3(3.5, 2, 26), Vector3(4.5, 4, 36)]), "up the first flight")
	_check(absf(p.global_position.y - 4.0) < 0.2, "onto the landing, four metres up (%.2f)" % p.global_position.y)
	_check(not q.groups["bailiff"].awake, "the Bailiff does not follow up the Stair: he keeps his post")
	_check(q.area_id == "stair", "the Stair is announced as the Witness enters it")
	_check(await _walk([Vector3(5.4, 4, 44), Vector3(4.6, 4, 50.5)]), "along the landing, past four Clerks")
	_check(q.groups["clerks"].awake, "who notice")
	_check(await _walk([Vector3(4.0, 6, 58), Vector3(4.5, 8, 68)]), "up the second flight")
	_check(absf(p.global_position.y - 8.0) < 0.2, "onto the forecourt, eight metres up (%.2f)" % p.global_position.y)
	_check(await _walk([Vector3(6.0, 8, 76), Vector3(2.5, 8, 81.5), Vector3(0, 8, 84.5), Vector3(0, 8, 88.5)]),
		"past the Bailiff with the Warrant and through the portal")
	_check(q.area_at(p.global_position).get("id", "") == "hall" and q.groups["voss"].awake, "into the Hall of Standing, where the Arbiter waits")
	_check(lowest > -0.3, "without once falling through the world (lowest %.2f)" % lowest)


func _test_gate_is_one_way() -> void:
	await _fresh()
	var p := q.player
	var gate: Gate = q.gates["docket_gate"]
	_place(p, Vector3(8.5, 4, 45))
	await _wait(10)
	await _walk_to(Vector3(16, 4, 45), 150)
	_check(p.global_position.x < 12.0, "from the landing the Docket Gate is a wall (x %.2f)" % p.global_position.x)
	_check(q.prompt == "It does not open from this side.", "and says so")
	await _interact()
	_check(not gate.is_open and q.said() == "It does not open from this side.", "trying it changes nothing")


func _test_route_docket() -> void:
	await _fresh()
	var p := q.player
	var gate: Gate = q.gates["docket_gate"]
	_check(await _walk([Vector3(13, 0, -0.5), Vector3(19, 0, 0), Vector3(30, -2.5, 0), Vector3(39.5, -4, 0)]),
		"through the colonnade and down the ramp")
	_check(absf(p.global_position.y + 4.0) < 0.2 and q.area_id == "docket", "into the Drowned Docket, four metres down (%.2f)" % p.global_position.y)
	_check(await _walk([Vector3(40, -4, 12), Vector3(40, -4, 40), Vector3(38.5, -4, 45)]), "the length of it, past the Bailiff and his Ward")
	_check(q.groups["escort"].awake, "who notice")
	_check(await _walk([Vector3(30, -2, 45), Vector3(15.5, 2.8, 45)]) and await _walk_to(Vector3(13.6, 3.4, 45), 200, 0.4),
		"up the far ramp to the back of the gate")
	_check(q.prompt == "Open the gate" and gate.can_open_from(p.global_position), "from this side it can be opened")
	await _interact()
	_check(gate.is_open and q.said() == "The Docket Gate is open", "and it opens")
	await _wait(90)
	_check(await _walk_to(Vector3(8.5, 4, 45), 300), "through it, onto the landing")
	_check(absf(p.global_position.y - 4.0) < 0.2 and p.global_position.x < 11.0, "the loop is closed: the Docket leads back to the Stair")
	_check(lowest > -4.4, "without falling through the Docket's bed (lowest %.2f)" % lowest)
	await _walk_to(Vector3(16, 3, 45), 400, 1.0)
	_check(p.global_position.x > 13.0, "and once open it stays open, both ways")


# ------------------------------------------------------------------ stones

func _test_stones() -> void:
	await _fresh()
	var p := q.player
	var b := q.bridge
	_hurt(p, 40)
	_check(b.hp(p.entity_id) == 60, "the Witness is hurt")
	input.clear()
	input.hold(0, 2, "rest", true)
	await _wait(4)
	_check(b.hp(p.entity_id) == 60, "the yard's free rest does not work here")
	input.clear()
	input.hold(0, 1, "unveil", true)
	await _wait(3)
	_check(b.form(p) == "DORMANT", "nor does its key for trying the Unveiled form")
	_check(await _walk_to(Vector3(-7, 0, -5.2), 400, 0.5), "to the Market Stone")
	_check(q.prompt == "The vow-stone: rest, or swear", "it offers rest, or a Vow")
	# Put a keeper down first, so there is something for the stone to undo.
	var bailiff: Enemy = q.groups["bailiff"].enemies[0]
	_hurt(bailiff, 999)
	await _wait(6)
	_check(q.groups["bailiff"].cleared and _alive("bailiff") == 0, "the Bailiff at the Stair is down, and his post is cleared")
	await _interact()
	_check(q.menu == "stone" and q.menu_lines[0] == "1    Rest" and q.rests == 0, "E opens the stone's choices; nothing has happened yet")
	await _choose(1)
	_check(q.rests == 1 and b.hp(p.entity_id) == 100 and b.resonance(p.entity_id) == 100, "resting makes the Witness whole")
	_check(q.stone_id == "market" and q.respawn_at.distance_to(Vector3(-7, 0, -5.4)) < 0.01, "and this is where they will stand again")
	await _wait(4)
	_check(not q.groups["bailiff"].cleared and _alive("bailiff") == 1, "and the Bailiff is back at his post")
	_check(q.groups["bailiff"].enemies[0] != bailiff, "a new man, not the old one stood up")
	# Not in the middle of a fight.
	q.wake("clerks")
	_check(not q.rest_at("market") and q.rests == 1, "no rest while a post is roused")
	q.sleep("clerks")
	_check(q.rest_at("forecourt") and q.stone_id == "forecourt", "any stone will do once they have settled")


func _test_falling() -> void:
	await _fresh()
	var p := q.player
	_check(q.rest_at("docket"), "rested at the Docket Stone")
	_place(p, Vector3(45, -4, 5))
	await _wait(4)
	var clerk: Enemy = q.groups["clerks"].enemies[0]
	_hurt(clerk, 999)
	await _wait(4)
	_hurt(p, 999)
	await _wait(6)
	_check(p.machine.dead(), "the Witness falls")
	await _wait(Arena.PLAYER_RESPAWN_TICKS + 10)
	_check(not p.machine.dead() and q.bridge.hp(p.entity_id) == 100, "and stands again, whole")
	_check(p.global_position.distance_to(Vector3(50.5, -4, 46.4)) < 0.5, "at the stone last rested at")
	_check(_alive("clerks") == 4 and not q._fighting(), "everyone is back at their post, asleep")
	# Out of the world altogether.
	_place(p, Vector3(200, -40, 200))
	await _wait(4)
	_check(p.global_position.distance_to(Vector3(50.5, -4, 46.4)) < 1.0, "a Witness who leaves the world is put back at the stone")


# -------------------------------------------------------------------- vows

func _logged(type: String) -> int:
	var n := 0
	for line: String in q.bridge.log_lines:
		if line.substr(8, 12).strip_edges() == type:
			n += 1
	return n


func _test_vow_menu() -> void:
	await _fresh()
	var p := q.player
	var b := q.bridge
	_check(b.vows().size() == 4 and String(b.vows()[0].id) == "vow.watched_back", "four Vows can be sworn in Veyr")
	_place(p, Vector3(-7, 0, -5.4))
	await _wait(4)
	await _interact()
	_check(q.menu_lines.size() == 6 and p.choice_count == 5, "the stone offers rest, four Vows, and leave to step away")
	_check(String(q.menu_lines[1]) == "2    Swear: I will not be struck from behind.   (stake 15, weight +2)", "each Vow says its sentence, its stake and what it is worth")
	await _interact()
	_check(q.menu == "" and not p.choosing, "E again steps away")
	await _interact()
	await _walk_to(Vector3(-7, 0, 1), 300)
	_check(q.menu == "", "so does walking off")
	_place(p, Vector3(-7, 0, -5.4))
	await _wait(4)
	await _interact()
	await _choose(2)
	_check(String(b.vow_of(p).get("id", "")) == "vow.watched_back" and q.menu == "", "choosing one swears it")
	_check(q.said() == "Sworn: I will not be struck from behind." and q.rests == 0, "it is said aloud; swearing is not resting")
	_check(_logged("SWORN") == 1, "and written in the verdict log")
	await _interact()
	_check(q.menu_lines.size() == 3 and String(q.menu_lines[1]) == "Sworn: I will not be struck from behind." and p.choice_count == 1,
		"sworn, the stone shows the Vow and offers only rest")
	await _choose(2)
	_check(String(b.vow_of(p).get("id", "")) == "vow.watched_back", "there is no second Vow to choose")
	await _interact()
	_check(not q.swear("vow.unmarked") and q.said() == "You are already sworn", "one Vow at a time")


func _test_vow_kept() -> void:
	await _fresh()
	var p := q.player
	var b := q.bridge
	_check(q.swear("vow.watched_back") and b.standing(p) == 0, "sworn, with a word that weighs nothing yet")
	_hurt(q.groups["bailiff"].enemies[0], 999)
	await _wait(8)
	_check(q.groups["bailiff"].cleared and b.vow_of(p).is_empty(), "a post cleared under a Vow: the Vow is kept and ends")
	_check(b.standing(p) == 2 and b.resonance(p.entity_id) == 100, "the Witness's word weighs 2 and their Resonance is whole")
	_check(q.vows_kept == 1 and q.said() == "The vow is kept. Your word weighs 2." and _logged("KEPT") == 1, "said, counted and logged")
	b.impose(p, "threshold.gatekeeper", {"line": [-300, 200, 300, 200]})
	_check(int(b.world.find_law(p.entity_id, "threshold.gatekeeper").get("authority", 0)) == 22, "a law imposed now carries that weight: authority 22, not 20")
	for e: Variant in q.groups["clerks"].enemies:
		_hurt(e, 999)
	await _wait(8)
	_check(q.vows_kept == 1 and b.standing(p) == 2, "clearing a post with nothing sworn earns nothing")
	_check(q.rest_at("market") and b.standing(p) == 0, "and a rest forgets what the word weighed")
	# The Arbiter yielding is a post cleared too.
	_check(q.swear("vow.varied_hand"), "sworn again, before the Hall")
	_place(p, Vector3(0, 8, 92))
	await _wait(6)
	_hurt(q.boss, 999)
	await _wait(10)
	_check(q.boss.yielded and q.vows_kept == 2 and b.standing(p) == 3, "the Arbiter yields under a Vow: kept, and worth 3")


func _test_vow_falls() -> void:
	await _fresh()
	q.force_ai = true
	var p := q.player
	var b := q.bridge
	var bailiff: Enemy = q.groups["bailiff"].enemies[0]
	_check(q.swear("vow.watched_back"), "sworn: I will not be struck from behind")
	# The Witness stands with their back to a roused Bailiff.
	_place(p, Vector3(0, 0, 4.0), 0.0)
	_place(bailiff, Vector3(0, 0, 1.9), 0.0)
	q.wake("bailiff")
	for i in 600:
		await get_tree().physics_frame
		if q.vows_fallen > 0:
			break
	_check(q.vows_fallen == 1 and b.vow_of(p).is_empty(), "the Bailiff's blow lands from behind and the Vow falls")
	_check(q.said() == "The vow fell", "it is said")
	await _wait(2)
	_check(b.hp(p.entity_id) <= 84 and _logged("BREACH") == 1 and _logged("FORFEIT") == 1,
		"the forfeit is paid on top of the blow (health %d), and both are in the log" % b.hp(p.entity_id))
	_check(b.standing(p) == 0 and q.vows_kept == 0, "nothing was kept")
	# A blow from the front does not break this Vow.
	await _fresh()
	q.force_ai = true
	p = q.player
	b = q.bridge
	bailiff = q.groups["bailiff"].enemies[0]
	q.swear("vow.watched_back")
	_place(p, Vector3(0, 0, 4.0), 0.0)
	_place(bailiff, Vector3(0, 0, 6.4), PI)
	q.wake("bailiff")
	var hp0 := b.hp(p.entity_id)
	for i in 600:
		await get_tree().physics_frame
		if b.hp(p.entity_id) < hp0:
			break
	_check(b.hp(p.entity_id) < hp0 and not b.vow_of(p).is_empty() and q.vows_fallen == 0, "struck from the front, the same Vow stands")


func _test_vow_and_rest_and_death() -> void:
	await _fresh()
	var p := q.player
	var b := q.bridge
	q.swear("vow.bare_hands")
	_check(q.rest_at("market") and String(b.vow_of(p).get("id", "")) == "vow.bare_hands", "a Vow still stands after a rest")
	b.impose(p, "threshold.gatekeeper", {"line": [-300, 200, 300, 200]})
	await _wait(3)
	_check(b.vow_of(p).is_empty() and q.vows_fallen == 1 and b.hp(p.entity_id) == 80, "Bare Hands falls to the first law imposed, for 20")
	# (A fresh Quarter: the line just drawn would refuse the blow that follows.)
	await _fresh()
	p = q.player
	b = q.bridge
	q.swear("vow.watched_back")
	_hurt(p, 999)
	await _wait(Arena.PLAYER_RESPAWN_TICKS + 12)
	_check(not p.machine.dead() and b.vow_of(p).is_empty(), "a Vow ends with its author")
	_check(q.vows_fallen == 0 and q.vows_kept == 0 and b.hp(p.entity_id) == 100, "unkept, and without a forfeit: falling was price enough")


# ------------------------------------------------------------------- posts

func _test_posts() -> void:
	await _fresh()
	q.force_ai = true
	var p := q.player
	var bailiff: Enemy = q.groups["bailiff"].enemies[0]
	var home := bailiff.home
	_place(p, Vector3(0, 0, 4))
	await _wait(150)
	_check(q.groups["bailiff"].awake and bailiff.ai_enabled, "roused, the Bailiff fights")
	_check(bailiff.global_position.distance_to(home) > 1.5, "and leaves his post to do it (%.1f m)" % bailiff.global_position.distance_to(home))
	_place(p, Vector3(0, 0, -16))
	await _wait(3)
	_check(not q.groups["bailiff"].awake and not bailiff.ai_enabled, "beyond his leash he gives up")
	await _wait(420)
	_check(bailiff.global_position.distance_to(home) < 0.9, "and walks back to his post (%.2f m from it)" % bailiff.global_position.distance_to(home))
	_check(absf(angle_difference(bailiff.facing, PI)) < 0.2, "facing the way he was set to watch")
	# A sleeper struck from outside his notice wakes the post.
	q.force_ai = false
	_place(bailiff, Vector3(0, 0, -6), PI)
	_place(p, Vector3(0, 0, -7.6), 0.0)
	input.clear()
	input.at(1, "light")
	await _wait(40)
	_check(q.groups["bailiff"].awake, "strike a keeper who has not noticed you, and he notices")
	# The Escort still binds the pair in the Docket.
	var pair: Array = q.groups["escort"].enemies
	_check(pair[0].partner == pair[1] and pair[1].partner == pair[0], "the Bailiff and his Ward are partnered, as in the yard")
	# Clearing a post.
	for e: Variant in q.groups["clerks"].enemies:
		_hurt(e, 999)
	await _wait(6)
	_check(q.groups["clerks"].cleared, "four Clerks down: the landing is cleared")
	_place(p, Vector3(0, 4, 42))
	await _wait(6)
	_check(not q.groups["clerks"].awake, "and a cleared post does not rouse again until the Witness rests")


# -------------------------------------------------------------------- hall

func _test_hall() -> void:
	await _fresh()
	var p := q.player
	var gate: Gate = q.gates["hall_gate"]
	_place(p, Vector3(0, 8, 81.5))
	await _wait(6)
	_check(not q.groups["voss"].awake and gate.is_open and q.boss.phase < 0, "from the forecourt the Hall is open and the Arbiter has not stirred")
	_check(await _walk_to(Vector3(0, 8, 88.5), 300), "the Witness walks in")
	_check(q.groups["voss"].awake and q.said() == "Aurel Voss, the Last Arbiter", "the hearing is called")
	await _wait(3)
	_check(q.boss.phase == 0 and q.boss.phase_name() == "Arraignment", "and only now does it open: the Arraignment")
	_check(not gate.is_open, "and the Bar of Standing comes down behind them")
	await _wait(30)
	await _walk_to(Vector3(0, 8, 79), 200)
	_check(p.global_position.z > 84.0, "there is no walking out (z %.2f)" % p.global_position.z)
	var v := q.boss
	_check(v != null and v.hp() == 420, "the Arbiter is whole")
	_hurt(v, 999)
	await _wait(8)
	_check(v.yielded and v.hp() == 33, "struck down, he yields, as in the yard")
	_check(gate.is_open and p.choosing, "the bar lifts, and his offer is put")
	input.clear()
	input.hold(0, 1, "select", 2)
	await _wait(4)
	_check(q.flags.get("voss", "") == "refused" and not p.choosing, "the Witness refuses his licence")
	await _wait(80)
	_check(await _walk_to(Vector3(0, 8, 80), 400), "and walks out")
	_check(q.groups["warrant"].awake and not q.rest_at("forecourt"), "the Bailiff with the Warrant is roused: no rest yet")
	_hurt(q.groups["warrant"].enemies[0], 999)
	await _wait(6)
	_check(q.rest_at("forecourt"), "with him down, the Witness rests at the Stone of Standing")
	await _wait(4)
	_check(q.boss == v and v.yielded and _alive("warrant") == 1, "the keepers return; the Arbiter does not rise to be fought again")
	_place(p, Vector3(0, 8, 95))
	await _wait(6)
	_check(gate.is_open and not q.groups["voss"].awake, "and the Hall stays open")


func _test_falling_in_the_hall() -> void:
	await _fresh()
	var p := q.player
	var gate: Gate = q.gates["hall_gate"]
	_place(p, Vector3(0, 8, 90))
	await _wait(6)
	var v := q.boss
	_hurt(v, 100)
	_check(q.groups["voss"].awake and not gate.is_open and v.hp() == 320, "in the Hall, the Arbiter hurt, the bar down")
	_hurt(p, 999)
	await _wait(Arena.PLAYER_RESPAWN_TICKS + 16)
	_check(not p.machine.dead() and p.global_position.distance_to(q.respawn_at) < 0.5, "the Witness falls and stands again at their stone")
	_check(q.boss != v and q.boss.hp() == 420 and not q.groups["voss"].awake, "the Arbiter is whole again and waiting")
	_check(gate.is_open, "and the Hall is open")


# ------------------------------------------------------------------ records

func _test_records() -> void:
	await _fresh()
	var p := q.player
	_check(q.data.records.size() == 8, "eight things can be read")
	var empty := 0
	for r: Dictionary in q.data.records:
		if String(r.title) == "" or String(r.text).length() < 40:
			empty += 1
	_check(empty == 0, "each has a title and something to say")
	_check(String(q.record("notice").text).contains("cannot break") and String(q.record("chalk").text).contains("It broke"),
		"two of them contradict each other, and the player is left holding both")
	_check(await _walk_to(Vector3(5, 0, -14.6), 300, 0.4), "to the notice by the Witness Gate")
	_check(q.prompt == "Read: Notice of the Meridian Court", "it can be read")
	await _interact()
	_check(q.reading == "notice" and q.prompt == "", "reading it")
	await _interact()
	_check(q.reading == "", "putting it down")
	await _interact()
	_check(q.reading == "notice", "picking it up again")
	await _walk_to(Vector3(5, 0, -9), 300)
	_check(q.reading == "", "walking away puts it down")
	var unreachable: Array = []
	for r: Dictionary in q.data.records:
		var f := float(r.get("facing", 0.0))
		_place(p, Quarter._v(r.at) + Vector3(sin(f), 0.0, cos(f)) * 1.3)
		await _wait(8)
		if q.nearest_interactable().get("id", "") != r.id:
			unreachable.append(r.id)
	_check(unreachable.is_empty(), "every record can be reached and read from in front of it (%s)" % str(unreachable))


# ------------------------------------------------------------- presentation

func _test_presentation() -> void:
	await _fresh(false)
	var p := q.player
	var canvas: Control = q.hud.get_child(0)
	_check(q.hud != null and canvas.help_lines.size() == 5 and String(canvas.help_lines[3]).contains("E read"), "the help panel names the Quarter's keys")
	_check(canvas.banner == "The Assize Quarter", "the Quarter is named on arrival (banner: %s)" % canvas.banner)
	_place(p, Vector3(-7, 0, -5.4))
	await _wait(6)
	_check(canvas.prompt == "E    The vow-stone: rest, or swear", "by a stone the prompt says what E will do")
	_place(p, Vector3(5, 0, -14.8))
	await _wait(6)
	await _interact()
	_check(canvas.record_title == "Notice of the Meridian Court" and String(canvas.record_text).contains("cannot break"), "a record opens as a leaf of text")
	await _wait(20)
	await _interact()
	_check(canvas.record_text == "", "and closes")
	_place(p, Vector3(10.2, 4, 45))
	await _wait(8)
	_check(canvas.prompt == "It does not open from this side.", "a gate that will not open says so without offering a key")
	q.swear("vow.watched_back")
	_place(p, Vector3(-7, 0, -5.4))
	await _wait(6)
	await _interact()
	_check(canvas.choice.size() == 3 and String(canvas.choice[1]).begins_with("Sworn:"), "the stone's choices are put on screen")
	await _wait(10)
	_check(is_equal_approx(canvas._top, 44.0), "a sworn Vow is written at the top of the page")
	await _interact()
	_hurt(q.groups["bailiff"].enemies[0], 999)
	await _wait(12)
	_check(canvas.banner.begins_with("The vow is kept") and is_equal_approx(canvas._top, 44.0), "kept: it is announced, and the word's weight stays written there")
	_check(canvas.draws > 60, "all of it drawn without error (%d frames)" % canvas.draws)


# --------------------------------------------------------------------- cost

func _test_cost() -> void:
	await _fresh()
	q.force_ai = true
	for id: String in ["bailiff", "clerks", "escort", "warrant"]:
		q.wake(id)
	q.player.global_position = Vector3(0, 0, 6)
	var t0 := Time.get_ticks_usec()
	await _wait(300)
	var per := float(Time.get_ticks_usec() - t0) / 300.0
	print("      the whole Quarter, eight keepers awake, headless: %d us per tick (frame budget 16667)" % int(per))
	_check(per < 8000.0, "the simulation fits in half a frame")
