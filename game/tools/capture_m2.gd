extends Node
## Opens a WINDOW, plays scripted moments of every M2 law in the practice
## yard, saves screenshots and frame timings, and quits. About 30 seconds.
## Ask the owner before running this: it takes focus.
##
##   godot --path game res://scenes/tools/CaptureM2.tscn -- <absolute output dir>

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
var _cpu_ms := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://capture_m2")
	DirAccess.make_dir_recursive_absolute(out_dir)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _measuring and _last_usec > 0:
		_frames.append(now - _last_usec)
		_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
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
	await _wait(2)


func _impose(ticks: int = 2) -> void:
	input.hold(input.tick, ticks, "impose")
	await _wait(ticks + 18)


## Clear the board: opponents quiet, player rested and placed, old laws gone.
func _stage(encounter: int, gap: float) -> void:
	arena.set_encounter(encounter)
	await _wait(3)
	for e: Enemy in arena.enemies:
		e.ai_enabled = false
	for law: Dictionary in arena.bridge.world.laws.duplicate():
		if law.owner == arena.player.entity_id:
			arena.bridge.world._end_law(law, "cleared for the next shot")
	arena.bridge.rest(arena.player)
	arena.player.lock_target = null
	_place(arena.player, Vector3(0, 0, 5.0), 0.0)
	_place(arena.bailiff, Vector3(0, 0, 5.0 + gap), PI)
	await _wait(12)
	arena.player.lock_target = arena.bailiff
	await _wait(30)


func _until_strike() -> void:
	var before := strikes.size()
	for i in 80:
		await get_tree().physics_frame
		if strikes.size() > before:
			break
	await _wait(3)


func _run() -> void:
	Arena.test_mode = false
	Arena.capture_mouse = false
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	var p := arena.player
	await _wait(30)

	# 1. The Gatekeeper: preview while held, then the line, then a denial.
	await _stage(0, 3.4)
	input.hold(input.tick, 40, "impose")
	await _wait(30)
	await _shot("01_gatekeeper_preview_and_commit")
	await _wait(30)
	await _shot("02_gatekeeper_standing")
	arena.bailiff.press_light = true
	await _until_strike()
	await _shot("03_gatekeeper_denies")
	await _wait(40)

	# 2. A drawn line.
	await _stage(0, 7.0)
	input.hold(input.tick, 70, "impose")
	input.hold(input.tick, 70, "move", Vector2(1, 0))
	await _wait(55)
	await _shot("04_drawing_a_line")
	await _wait(40)

	# 3. The Divide: the player's own strike is refused.
	await _stage(0, 2.4)
	await _choose(2)
	await _impose()
	_press("light")
	await _until_strike()
	await _shot("05_divide_binds_its_author")
	await _wait(40)

	# 4. The Creditor: beads over the debtor, then the call-in.
	await _stage(0, 2.0)
	await _choose(3)
	await _impose()
	arena.bailiff.press_light = true
	await _until_strike()
	await _wait(40)
	arena.bailiff.press_light = true
	await _until_strike()
	await _wait(25)
	await _shot("06_creditor_he_owes")
	input.hold(input.tick, 3, "impose")
	_press("light")
	await _until_strike()
	await _shot("07_creditor_called_in")
	await _wait(40)

	# 5. The Debtor: struck, unharmed, owing.
	await _stage(0, 2.0)
	await _choose(4)
	await _impose()
	arena.bailiff.press_light = true
	await _until_strike()
	await _wait(20)
	await _shot("08_debtor_owes")
	_press("light")
	await _until_strike()
	await _shot("09_debtor_pays_forward")
	await _wait(40)

	# 6. The Twin: Bailiff and Ward bound by a thread.
	await _stage(2, 2.2)
	_place(arena.enemies[1], Vector3(1.0, 0, 7.0), PI)      # beside the Bailiff: one cut shows the blade to both
	await _wait(10)
	await _choose(5)
	await _impose()
	_press("light")
	await _until_strike()
	await _wait(30)
	await _shot("10_twin_bound")
	_press("light")
	await _until_strike()
	await _shot("11_twin_shares_the_blow")
	await _wait(40)

	# 7. The Answer: the mirrored strike, then a returned blow.
	await _stage(0, 2.0)
	await _choose(6)
	await _impose()
	_press("light")
	await _until_strike()
	await _wait(6)
	await _shot("12_answer_mirrored")
	await _wait(40)
	arena.bailiff.press_light = true
	var startup: int = arena.bailiff.machine.moves["light_1"].startup
	for i in 70:
		await get_tree().physics_frame
		if arena.bailiff.machine.state == S.ATTACK and arena.bailiff.machine.t == startup - 2:
			input.hold(input.tick, 8, "guard")
		if strikes.size() > 0 and strikes[-1].kind == "converted":
			break
	await _wait(4)
	await _shot("13_answer_returns_the_blow")
	await _wait(40)

	# 8. A Warrant against the Gatekeeper: OVERRIDE.
	await _stage(1, 3.4)
	await _choose(1)
	await _impose()
	arena.bailiff._keep_laws()
	await _wait(20)
	await _shot("14_bailiff_draws_his_warrant")
	arena.bailiff.press_light = true
	await _until_strike()
	await _shot("15_warrant_overrides_the_line")
	await _wait(40)

	# 9. Four Clerks, AI on, a Creditor among them. Frame time measured here.
	await _stage(3, 7.0)
	p.lock_target = null
	await _choose(3)
	await _impose()
	for e: Enemy in arena.enemies:
		e.ai_enabled = true
	_measuring = true
	await _wait(330)
	_measuring = false
	await _shot("16_four_clerks")

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
		"render_cpu_ms": snappedf(_cpu_ms / maxf(1.0, n), 0.01),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"shots": _shots,
	}
	var out := FileAccess.open(out_dir.path_join("metrics.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("CAPTURE " + JSON.stringify(report))
	get_tree().quit()
