extends Node
## Opens a WINDOW, plays scripted moments of the fight with Aurel Voss, saves
## screenshots and frame timings, and quits. About 40 seconds. Ask the owner
## before running this: it takes focus.
##
##   godot --path game res://scenes/tools/CaptureM4.tscn -- <absolute output dir>
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/CaptureM4.tscn -- /tmp/x    # dry run

const S := ActionMachine.S
const SHOT_WIDTH := 1600

var out_dir := ""
var arena: Arena
var input: ScriptedInput
var _shots: Array = []
var _measuring := false
var _frames: Array = []
var _last_usec := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://capture_m4")
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
		_shots.append(label)
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


func _wound(to_hp: int) -> void:
	var now: int = arena.bridge.hp(arena.boss.entity_id)
	if now > to_hp:
		arena.bridge.world.strike(arena.player.entity_id, arena.boss.entity_id, now - to_hp, ["from_front"])


func _run() -> void:
	Arena.test_mode = false
	Arena.capture_mouse = false
	Arena.fixed_instrument = ""
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	await _wait(20)
	arena.set_encounter(4)
	var p := arena.player
	var v := arena.boss
	arena.bridge.rest(p)
	await _wait(10)
	_place(p, Vector3(0, 0, 4.0), 0.0)
	_place(v, Vector3(0, 0, 9.0), PI)
	await _wait(40)
	await _shot("01_the_arbiter_arrives")
	await _wait(50)
	await _shot("02_writ_of_standing_spoken")

	# His stamp, and the seal it leaves.
	v.ai_enabled = false
	p.lock_target = v
	_place(p, Vector3(0, 0, 3.4), 0.0)
	await _wait(30)
	v.press_heavy = true
	for i in 90:
		await get_tree().physics_frame
		if v.machine.state == S.ATTACK and v.machine.t == 30:
			await _shot("03_the_stamp_winds_up")
		if v.machine.state == S.ATTACK and v.machine.is_active():
			break
	await _wait(6)
	await _shot("04_the_stamp_lands")
	await _wait(70)
	_place(p, Vector3(-3.0, 0, 5.0), 0.6)
	await _wait(30)
	await _shot("05_the_seal_it_left")

	# A strike from behind, under the Writ of Standing.
	_place(p, v.global_position + Vector3(0, 0, 2.6), PI)
	p.lock_target = v
	await _wait(20)
	input.at(input.tick, "light")
	await _wait(26)
	await _shot("06_struck_from_behind_denied")
	await _wait(60)

	# Cross-examination: two Writs.
	_place(p, Vector3(0, 0, 3.0), 0.0)
	_place(v, Vector3(0, 0, 8.5), PI)
	v.ai_enabled = true
	_wound(260)
	await _wait(160)
	await _shot("07_cross_examination_two_writs")

	# The Hearing.
	_wound(120)
	for i in 420:
		await get_tree().physics_frame
		if not arena.bridge.world.find_law(v.entity_id, "voss.the_hearing").is_empty():
			break
	await _wait(20)
	await _shot("08_the_hearing_spoken")
	_measuring = true
	for i in 300:
		input.hold(input.tick, 1, "guard")
		await get_tree().physics_frame
	_measuring = false
	await _shot("09_fighting_under_the_hearing")

	# He yields, and offers his licence.
	v.ai_enabled = false
	arena.bridge.rest(p)
	_place(p, Vector3(0, 0, 3.0), 0.0)
	_place(v, Vector3(0, 0, 8.5), PI)
	p.lock_target = v
	await _wait(40)
	_wound(0)
	await _wait(50)
	await _shot("10_he_yields_and_offers")
	input.hold(input.tick, 1, "select", 1)
	await _wait(40)
	await _shot("11_licensed")

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
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"shots": _shots,
	}
	var out := FileAccess.open(out_dir.path_join("metrics.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("CAPTURE " + JSON.stringify(report))
	get_tree().quit()
