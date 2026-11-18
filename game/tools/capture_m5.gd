extends Node
## Opens a WINDOW, takes the Witness round the Assize Quarter, saves
## screenshots and frame timings, and quits. About 45 seconds. Ask the owner
## before running this: it takes focus.
##
##   godot --path game res://scenes/tools/CaptureM5.tscn -- <absolute output dir>
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/CaptureM5.tscn -- /tmp/x    # dry run

const SHOT_WIDTH := 1600

var out_dir := ""
var q: Quarter
var input: ScriptedInput
var _shots: Array = []
var _measuring := false
var _frames: Array = []
var _last_usec := 0
var _timings: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://capture_m5")
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
	_shots.append(label)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > SHOT_WIDTH:
		img.resize(SHOT_WIDTH, int(float(SHOT_WIDTH) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(label + ".png"))


## Stand the Witness somewhere, looking along `yaw` (0 is north; -PI/2 is west).
func _stand(at: Vector3, yaw: float, pitch: float = 0.26, settle: int = 36) -> void:
	var p := q.player
	p.lock_target = null
	p.global_position = at
	p.facing = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	q.camera.yaw = yaw
	q.camera.pitch = pitch
	q.camera.snap()
	await _wait(settle)


func _press(what: String) -> void:
	input.clear()
	input.at(0, what)
	await _wait(3)


## Walk forward for a while, timing every frame.
func _measure(label: String, ticks: int) -> void:
	_frames = []
	_measuring = true
	input.clear()
	input.hold(0, ticks, "move", Vector2(0, 1))
	await _wait(ticks)
	_measuring = false
	_frames.sort()
	var n := _frames.size()
	var sum := 0
	for f: int in _frames:
		sum += f
	_timings[label] = {
		"frames": n,
		"avg_ms": snappedf(float(sum) / maxf(1.0, n) / 1000.0, 0.01),
		"median_ms": snappedf(float(_frames[n / 2]) / 1000.0, 0.01) if n > 0 else 0.0,
		"p99_ms": snappedf(float(_frames[int(n * 0.99)]) / 1000.0, 0.01) if n > 0 else 0.0,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	}


func _run() -> void:
	Arena.test_mode = false
	Arena.capture_mouse = false
	Arena.fixed_instrument = ""
	q = (load("res://scenes/Quarter.tscn") as PackedScene).instantiate()
	add_child(q)
	input = ScriptedInput.new()
	q.player.input = input
	q.pacified = true                      # keepers notice, and stand where they are
	var half := PI * 0.5
	await _wait(50)
	await _shot("01_arriving_in_the_oath_market")
	await _measure("market", 240)
	await _stand(Vector3(0, 0, -11), 0.0, -0.25)
	await _shot("02_the_hanging_courts_over_the_stair")
	await _stand(Vector3(-2.5, 0, 1.0), -half)
	await _shot("03_where_the_vow_broke")
	await _stand(Vector3(-9.0, 0, -9.5), -half * 0.55)
	await _shot("03b_the_ruin_from_the_stone")
	await _stand(Vector3(12.0, 0, -15.0), 0.35, 0.10)
	await _shot("03c_vows_over_the_market")
	await _stand(Vector3(-7, 0, -5.2), PI + 0.55)
	await _shot("04_the_market_stone")
	await _press("interact")
	await _wait(10)
	await _shot("04b_the_stone_offers")
	input.clear()
	input.hold(0, 1, "select", 2)
	await _wait(40)
	await _shot("04c_sworn")
	await _stand(Vector3(5, 0, -14.7), PI)
	await _press("interact")
	await _wait(10)
	await _shot("05_reading_the_notice")
	await _press("interact")
	await _stand(Vector3(2.5, 0, 4.5), 0.0)
	await _wait(30)
	await _shot("06_the_bailiff_at_the_stair")
	await _stand(Vector3(0, 1.4, 23.5), 0.0)
	await _shot("07_the_scriveners_stair")
	await _stand(Vector3(0, 4, 36.2), 0.0)
	await _shot("08_four_clerks_on_the_landing")
	await _stand(Vector3(10.2, 4, 45), half)
	await _shot("09_the_docket_gate_from_the_landing")
	await _stand(Vector3(19, 0, 0), half)
	await _shot("10_the_way_down")
	await _stand(Vector3(45, -4, -7), 0.0)
	await _shot("11_the_drowned_docket")
	await _measure("docket", 180)
	await _stand(Vector3(41.5, -4, 14), 0.0)
	await _shot("12_a_bailiff_and_his_ward")
	await _stand(Vector3(50.5, -4, 46.2), 0.6)
	await _shot("13_the_docket_stone")
	await _stand(Vector3(13.8, 3.4, 45), -half)
	await _shot("14_the_gate_from_behind")
	await _press("interact")
	await _wait(95)
	await _shot("15_the_gate_open")
	await _stand(Vector3(0, 8, 68.5), 0.0)
	await _shot("16_the_forecourt_of_standing")
	await _stand(Vector3(0, 8, 68.5), 0.0, -0.25)
	await _shot("16b_the_courts_over_the_forecourt")
	await _stand(Vector3(-9.5, 8, 79.3), 0.0)
	await _press("interact")
	await _wait(10)
	await _shot("17_carved_beside_the_portal")
	await _press("interact")
	await _stand(Vector3(0, 8, 81), 0.0)
	input.clear()
	input.hold(0, 100, "move", Vector2(0, 1))
	await _wait(170)
	await _shot("18_the_hall_of_standing")
	await _measure("hall", 120)
	await _stand(q.player.global_position, PI)
	await _shot("19_the_bar_of_standing")
	await _stand(Vector3(0, 8, 92), 0.0, -0.25)
	await _shot("20_under_the_hanging_courts")

	var report := {"timings": _timings, "shots": _shots}
	var out := FileAccess.open(out_dir.path_join("metrics.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("CAPTURE " + JSON.stringify(report))
	get_tree().quit()
