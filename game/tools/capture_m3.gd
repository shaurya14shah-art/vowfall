extends Node
## Opens a WINDOW, plays scripted moments of the three Instruments and the
## Unveiling in the practice yard, saves screenshots and frame timings, and
## quits. About 35 seconds. Ask the owner before running this: it takes focus.
##
##   godot --path game res://scenes/tools/CaptureM3.tscn -- <absolute output dir>
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/CaptureM3.tscn -- /tmp/x    # dry run

const S := ActionMachine.S
const SHOT_WIDTH := 1600

var out_dir := ""
var arena: Arena
var input: ScriptedInput
var strikes: Array = []
var _shots: Array = []
var _measuring := false
var _frames: Array = []
var _last_usec := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://capture_m3")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _measuring and _last_usec > 0:
		_frames.append(now - _last_usec)
	_last_usec = now


func _wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		_shots.append(label)      # a dry run: checks the sequence, saves nothing
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > SHOT_WIDTH:
		img.resize(SHOT_WIDTH, int(float(SHOT_WIDTH) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(label + ".png"))
	_shots.append(label)


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


func _clear_laws() -> void:
	for law: Dictionary in arena.bridge.world.laws.duplicate():
		if law.owner == arena.player.entity_id:
			arena.bridge.world._end_law(law, "cleared for the next shot")
	arena.player.marking = false


func _stage(encounter: int, gap: float, law: int) -> void:
	arena.set_encounter(encounter)
	await _wait(3)
	for e: Enemy in arena.enemies:
		e.ai_enabled = false
	_clear_laws()
	arena.bridge.rest(arena.player)
	arena.player.lock_target = null
	_place(arena.player, Vector3(0, 0, 5.0), 0.0)
	_place(arena.bailiff, Vector3(0, 0, 5.0 + gap), PI)
	await _choose(law)
	await _wait(10)
	arena.player.lock_target = arena.bailiff
	await _wait(34)


func _until_strike(limit: int = 80) -> void:
	var before := strikes.size()
	for i in limit:
		await get_tree().physics_frame
		if strikes.size() > before:
			break
	await _wait(3)


func _unveil(law: String) -> void:
	var p := arena.player
	p.recognition.have[law] = p.recognition.trials[law].need
	await _wait(3)
	input.hold(input.tick, 90, "impose")
	input.hold(input.tick, 90, "guard")
	await _wait(45)
	await _shot("%s_rite" % law.replace(".", "_"))
	await _wait(36)
	await _shot("%s_unveiled" % law.replace(".", "_"))
	await _wait(90)


func _run() -> void:
	Arena.test_mode = false
	Arena.capture_mouse = false
	Arena.fixed_instrument = ""
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	var p := arena.player
	await _wait(30)

	# The Lintel: whole, mid-sweep at range, then planted with the short half in hand.
	await _stage(0, 3.6, 1)
	await _shot("01_lintel_carried")
	_press("light")
	await _until_strike()
	await _shot("02_lintel_reaches")
	await _wait(50)
	_place(arena.bailiff, Vector3(0, 0, 9.4), PI)
	await _impose()
	await _shot("03_lintel_planted_short_half")
	arena.bailiff.press_light = true
	await _wait(10)
	_place(arena.bailiff, Vector3(0, 0, 7.6), PI)
	await _until_strike(90)
	await _shot("04_planted_line_denies")
	await _wait(40)

	# The Tally: jabs, then a blow caught on its guard.
	await _stage(0, 1.7, 3)
	await _shot("05_tally_worn")
	_press("light")
	await _until_strike()
	await _shot("06_tally_jab")
	await _wait(40)
	await _impose()
	input.hold(input.tick, 100, "guard")
	await _wait(14)
	arena.bailiff.press_light = true
	await _until_strike()
	await _wait(8)
	await _shot("07_tally_catches_owed_in_full")
	await _wait(50)

	# The Counterpart: armed, then shown to two.
	await _stage(2, 2.1, 5)
	_place(arena.enemies[1], Vector3(1.0, 0, 6.9), PI)
	await _wait(10)
	await _impose()
	await _shot("08_counterpart_armed")
	_press("light")
	await _until_strike()
	await _wait(24)
	await _shot("09_counterpart_shown_to_two")
	await _wait(40)

	# The Unveiling, with each Instrument.
	await _stage(0, 3.2, 1)
	await _unveil("threshold.gatekeeper")
	_place(arena.bailiff, Vector3(0, 0, 9.6), PI)
	await _impose()
	await _shot("12_lintel_awakened_planted")
	input.hold(input.tick, 50, "move", Vector2(0, 1))
	await _wait(52)
	await _shot("13_walking_through_your_own_gate")
	await _wait(20)

	arena.bridge.set_form(p, "DORMANT")
	await _stage(0, 2.2, 6)
	await _unveil("reflection.answer")
	await _shot("16_counterpart_and_its_reflection")
	_place(arena.bailiff, Vector3(0, 0, 7.0), PI)
	for i in 4:
		_press("light")
		await _wait(14)
	await _shot("17_fourth_cut")
	await _wait(50)

	arena.bridge.set_form(p, "DORMANT")
	await _stage(0, 4.2, 3)
	await _unveil("debt.creditor")
	_place(arena.bailiff, Vector3(0, 0, 9.0), PI)
	await _wait(10)
	_press("heavy")
	await _wait(30)
	_press("heavy")
	await _until_strike(70)
	await _shot("20_tally_casts_its_cord")
	await _wait(40)

	# Frame time: four Clerks, AI on, an Unveiled Creditor among them.
	await _stage(3, 7.0, 3)
	p.lock_target = null
	await _impose()
	for e: Enemy in arena.enemies:
		e.ai_enabled = true
	_measuring = true
	await _wait(300)
	_measuring = false
	await _shot("21_four_clerks_unveiled_creditor")

	_frames.sort()
	var n := _frames.size()
	var sum := 0
	for f: int in _frames:
		sum += f
	var report := {
		"frames": n,
		"avg_ms": snappedf(float(sum) / maxf(1.0, n) / 1000.0, 0.01),
		"median_ms": snappedf(float(_frames[n / 2]) / 1000.0, 0.01) if n > 0 else 0.0,
		"p99_ms": snappedf(float(_frames[int(n * 0.99)]) / 1000.0, 0.01) if n > 0 else 0.0,
		"worst_ms": snappedf(float(_frames[n - 1]) / 1000.0, 0.01) if n > 0 else 0.0,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"shots": _shots,
	}
	var out := FileAccess.open(out_dir.path_join("metrics.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("CAPTURE " + JSON.stringify(report))
	get_tree().quit()
