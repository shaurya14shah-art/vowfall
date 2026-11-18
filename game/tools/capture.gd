extends Node
## Opens a WINDOW, plays a short scripted sequence in the practice yard,
## saves screenshots and frame timings, and quits. About 20 seconds.
## Ask the owner before running this: it takes focus.
##
##   godot --path game res://scenes/tools/Capture.tscn -- <absolute output dir>

const S := ActionMachine.S
const SHOT_WIDTH := 1600

var out_dir := ""
var arena: Arena
var input: ScriptedInput
var strikes: Array = []
var _measuring := false
var _frames: Array = []
var _last_usec := 0
var _shots: Array = []
var _cpu_ms := 0.0
var _gpu_ms := 0.0
var _setup_ms := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://capture")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _measuring and _last_usec > 0:
		_frames.append(now - _last_usec)
		# What the frame actually cost, which the display's refresh cap hides.
		var rid := get_viewport().get_viewport_rid()
		_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_setup_ms += RenderingServer.get_frame_setup_time_cpu()
	_last_usec = now


func _wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _shot(label: String) -> void:
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


func _mine() -> int:
	var n := 0
	for s: Dictionary in strikes:
		if s.attacker == arena.player:
			n += 1
	return n


func _kind(kind: String) -> int:
	var n := 0
	for s: Dictionary in strikes:
		if s.kind == kind:
			n += 1
	return n


func _run() -> void:
	Arena.test_mode = false
	Arena.capture_mouse = false
	arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	input = ScriptedInput.new()
	arena.player.input = input
	arena.bailiff.ai_enabled = false
	arena.bridge.struck.connect(func(info: Dictionary) -> void: strikes.append(info))
	var p := arena.player
	var cam := arena.camera

	await _wait(50)
	await _shot("01_yard_from_spawn")

	cam.yaw = 0.95
	cam.pitch = 0.16
	await _wait(12)
	await _shot("02_yard_low_angle")
	cam.yaw = 0.0
	cam.pitch = 0.32

	# The sealed post, locked on: its laws are struck-out bars.
	_place(p, arena.sealed_post.global_position + Vector3(0, 0, -1.9), 0.0)
	p.lock_target = arena.sealed_post
	await _wait(30)
	await _shot("03_sealed_post_locked")

	_press("light")
	for i in 60:
		await get_tree().physics_frame
		if _mine() >= 1:
			break
	await _wait(1)
	await _shot("04_first_strike_lands")

	for i in 160:
		if _mine() >= 3:
			break
		if i % 5 == 0:
			_press("light")
		await get_tree().physics_frame
	await _wait(8)
	await _shot("05_third_strike_denied")
	await _wait(40)
	await _shot("06_verdict_line_and_sensed_law")

	# The Bailiff.
	p.lock_target = null
	_place(p, Vector3(0, 0, 6.0), 0.0)
	_place(arena.bailiff, Vector3(0, 0, 8.3), PI)
	await _wait(20)
	p.lock_target = arena.bailiff
	await _wait(25)
	arena.bailiff.press_light = true
	var startup: int = arena.bailiff.machine.moves["light_1"].startup
	var took_telegraph := false
	for i in 80:
		await get_tree().physics_frame
		var bm := arena.bailiff.machine
		if bm.state == S.ATTACK and bm.t == 14 and not took_telegraph:
			took_telegraph = true
			await _shot("07_bailiff_telegraph")
		if bm.state == S.ATTACK and bm.t == startup - 2:
			input.hold(input.tick, 20, "guard")
		if _kind("parried") >= 1:
			break
	await _wait(3)
	await _shot("08_parry")
	await _wait(30)

	var before := _kind("hit")
	_press("heavy")
	for i in 80:
		await get_tree().physics_frame
		if _kind("hit") > before:
			break
	await _wait(2)
	await _shot("09_heavy_lands")
	await _wait(50)

	input.hold(input.tick, 40, "guard")
	await _wait(16)
	await _shot("10_guard")
	await _wait(30)
	input.hold(input.tick, 8, "move", Vector2(1, 0))
	_press("dodge")
	await _wait(9)
	await _shot("11_dodge")
	await _wait(30)

	# Frame time with the AI on and the player moving and striking.
	arena.bailiff.ai_enabled = true
	input.hold(input.tick, 400, "move", Vector2(0.4, 0.3))
	_measuring = true
	for i in 300:
		if i % 25 == 0:
			_press("light")
		await get_tree().physics_frame
	_measuring = false
	await _shot("12_free_fight")

	_frames.sort()
	var n := _frames.size()
	var sum := 0
	for f: int in _frames:
		sum += f
	var win := DisplayServer.window_get_size()
	var report := {
		"frames": n,
		"avg_ms": snappedf(float(sum) / maxf(1.0, n) / 1000.0, 0.01),
		"median_ms": snappedf(float(_frames[n / 2]) / 1000.0, 0.01) if n > 0 else 0.0,
		"p99_ms": snappedf(float(_frames[int(n * 0.99)]) / 1000.0, 0.01) if n > 0 else 0.0,
		"worst_ms": snappedf(float(_frames[n - 1]) / 1000.0, 0.01) if n > 0 else 0.0,
		"render_cpu_ms": snappedf(_cpu_ms / maxf(1.0, n), 0.01),
		"render_gpu_ms": snappedf(_gpu_ms / maxf(1.0, n), 0.01),
		"frame_setup_cpu_ms": snappedf(_setup_ms / maxf(1.0, n), 0.01),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"window": [win.x, win.y],
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"scale_3d": get_viewport().scaling_3d_scale,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"video_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"adapter": RenderingServer.get_video_adapter_name(),
		"shots": _shots,
	}
	var f := FileAccess.open(out_dir.path_join("metrics.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("CAPTURE " + JSON.stringify(report))
	get_tree().quit()
