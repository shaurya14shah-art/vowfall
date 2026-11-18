class_name Arena
extends Node3D
## The practice yard (milestones M1 and M2). One player with an Axiom, a
## plain post to hit, a sealed post that keeps two of the Arbiter's Writs
## standing, and a choice of opponents who come back a few seconds after
## they fall.
##
## Greybox. The geometry is stand-in; the palette is not.

const PLAYER_SPAWN := Vector3(0.0, 0.0, -6.0)
const BAILIFF_SPAWN := Vector3(0.0, 0.0, 12.0)
const BAILIFF_RESPAWN_TICKS := 210
## Who there is to fight. Each entry: a name, and [enemy id, where] pairs.
## The first enemy of an encounter is `bailiff`; with "escort" the first is
## partnered with the second.
const ENCOUNTERS := [
	{"name": "A Bailiff", "spawn": [["bailiff", Vector3(0.0, 0.0, 12.0)]]},
	{"name": "A Bailiff with a Warrant", "spawn": [["bailiff_warrant", Vector3(0.0, 0.0, 12.0)]]},
	{"name": "A Bailiff and his Ward", "escort": true,
		"spawn": [["bailiff_escort", Vector3(1.3, 0.0, 12.0)], ["ward", Vector3(-1.3, 0.0, 12.6)]]},
	{"name": "Four Clerks",
		"spawn": [["clerk", Vector3(3.2, 0.0, 11.0)], ["clerk", Vector3(1.1, 0.0, 12.6)],
			["clerk", Vector3(-1.1, 0.0, 12.6)], ["clerk", Vector3(-3.2, 0.0, 11.0)]]},
	{"name": "Aurel Voss, the Last Arbiter", "boss": true, "spawn": [["voss", Vector3(0.0, 0.0, 13.0)]]},
]
const PLAYER_RESPAWN_TICKS := 150

## Set before the arena enters the tree (tests): no HUD, no mouse capture,
## and the Bailiff waits to be told what to do.
static var test_mode: bool = false
## Capture tools set this false so a screenshot run does not take the mouse.
static var capture_mouse: bool = true
## Tests written before Instruments existed hold the player to one of them.
static var fixed_instrument: String = ""

var bridge: CombatBridge
var player: Player
var camera: FollowCamera
var bailiff: Enemy              # the first enemy of the current encounter
var enemies: Array = []         # every enemy of the current encounter
var encounter: int = 0
var law_fx: LawFx
var plain_post: Post
var sealed_post: Post
var hud: Hud

var boss: Voss                  # set while the Arbiter is here
var flags: Dictionary = {}      # what has been decided: {"voss": "licensed" or "refused"}
var respawn_at: Vector3 = PLAYER_SPAWN   # where the Witness stands again after falling

var _want_encounter: int = -1
var _bailiff_timer: int = -1
var _player_timer: int = -1
var _corpses: Array = []     # [actor, ticks left]


func _ready() -> void:
	_build_world()
	bridge = CombatBridge.new()
	bridge.name = "CombatBridge"
	add_child(bridge)

	_place_fixtures()

	player = Player.new()
	player.instrument_lock = fixed_instrument
	player.bridge = bridge
	player.position = respawn_at
	add_child(player)

	camera = FollowCamera.new()
	camera.target = player
	add_child(camera)
	camera.snap()
	player.camera = camera

	_populate()
	bridge.struck.connect(_on_struck)
	bridge.consequence.connect(_on_consequence)
	bridge.actor_died.connect(_on_died)
	bridge.unveiled.connect(_on_unveiled)
	bridge.actor_yielded.connect(_on_yielded)
	player.chose.connect(_on_chose)

	law_fx = LawFx.new()
	law_fx.bridge = bridge
	law_fx.player = player
	add_child(law_fx)

	if not test_mode:
		hud = Hud.new()
		add_child(hud)
		hud.bind(bridge, player, camera)
		# Draw each effect once, almost invisibly, so its render pipeline is
		# built now and not on the first hit (the second look had one 59 ms
		# frame in three hundred).
		_spark(respawn_at + Vector3(0.0, 1.0, 1.0), Look.INK, 0.03)
		_flash(player, Color(1, 1, 1), 0.02)
		_flash(bailiff, Color(1, 1, 1), 0.02)
		if capture_mouse and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_after_ready()


## What stands in the place before the Witness does. The yard: two posts.
func _place_fixtures() -> void:
	# +X is the camera's left at the start, so the plain post is on the left.
	plain_post = _spawn_post(Vector3(4.0, 0.0, 1.5), false)
	sealed_post = _spawn_post(Vector3(-4.0, 0.0, 1.5), true)


## Who is here when the Witness arrives. The yard: the first encounter.
func _populate() -> void:
	_spawn_encounter(0)


## A place built on the yard (the Assize Quarter) finishes its own setup here.
func _after_ready() -> void:
	pass


func _spawn_post(at: Vector3, sealed: bool) -> Post:
	var p := Post.new()
	p.bridge = bridge
	p.position = at
	p.facing = PI          # its face looks back toward the player's start
	p.sealed = sealed
	if sealed:
		p.display_name = "Sealed post"
		p.standing_laws = ["voss.writ_of_standing", "voss.writ_of_order"]
	add_child(p)
	return p


## Clear whoever is here and bring in encounter `index`. Never call this
## from inside a signal the bridge emits: it changes who is registered.
func set_encounter(index: int) -> void:
	player.lock_target = null     # whoever was locked is about to be gone
	player.choosing = false
	boss = null
	if hud != null:
		hud.set_boss(null)
		hud.set_choice([])
	for e: Variant in enemies:
		if is_instance_valid(e):
			if e is Voss:
				(e as Voss).clear_seals()
			bridge.retire(e)
			e.queue_free()
	for c: Array in _corpses:
		if is_instance_valid(c[0]):
			bridge.unregister(c[0])
			c[0].queue_free()
	_corpses.clear()
	_bailiff_timer = -1
	_spawn_encounter(index)
	if hud != null:
		hud.announce(ENCOUNTERS[encounter].name)


## One enemy of a kind named in data/enemies, standing at `at`.
func _make_enemy(id: String, at: Vector3, yaw: float = PI) -> Enemy:
	var e: Enemy
	if id == "bailiff":
		e = Bailiff.new()
	elif id == "voss":
		boss = Voss.new()
		boss.spoke.connect(_on_spoke)
		e = boss
	else:
		e = Enemy.new()
		e.load_archetype(id)
	e.bridge = bridge
	e.position = at
	e.facing = yaw
	e.target = player
	e.ai_enabled = not test_mode
	add_child(e)
	return e


func _spawn_encounter(index: int) -> void:
	encounter = posmod(index, ENCOUNTERS.size())
	enemies = []
	var spec: Dictionary = ENCOUNTERS[encounter]
	for entry: Array in spec.spawn:
		enemies.append(_make_enemy(entry[0], entry[1]))
	bailiff = enemies[0]
	if boss != null and hud != null:
		hud.set_boss(boss)
	if spec.get("escort", false) and enemies.size() >= 2:
		enemies[0].partner = enemies[1]
		enemies[1].partner = enemies[0]


func _unhandled_input(event: InputEvent) -> void:
	# A capture run (capture_mouse off) must not obey the keyboard: its window
	# takes focus, and a stray Backspace or T typed by the owner would reload
	# or leave the scene under it.
	if test_mode or not capture_mouse:
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif capture_mouse and event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("travel"):
		get_tree().change_scene_to_file(_travel_to())
	elif event.is_action_pressed("next_encounter") and _has_encounter_list():
		_want_encounter = encounter + 1
	elif event.is_action_pressed("export_log"):
		var path := ProjectSettings.globalize_path("user://verdict_log.txt")
		if bridge.export_log(path) and hud != null:
			hud.announce("Log saved")
			print("verdict log: " + path)


## The scene the travel key leads to, and whether N cycles opponents here.
func _travel_to() -> String:
	return "res://scenes/Quarter.tscn"


func _has_encounter_list() -> bool:
	return true


func _physics_process(_delta: float) -> void:
	if _want_encounter >= 0:
		set_encounter(_want_encounter)
		_want_encounter = -1
	if _bailiff_timer > 0:
		_bailiff_timer -= 1
		if _bailiff_timer == 0:
			_spawn_encounter(encounter)
	_tick_fallen()


## The Witness stands again after a while; the fallen are cleared away.
func _tick_fallen() -> void:
	if _player_timer > 0:
		_player_timer -= 1
		if _player_timer == 0:
			bridge.world.restore(player.entity_id)
			player.global_position = respawn_at
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			player.revive()
			_on_player_stood()
	for c: Array in _corpses:
		c[1] -= 1
		if c[1] <= 0:
			bridge.unregister(c[0])
			c[0].queue_free()
	_corpses = _corpses.filter(func(c: Array) -> bool: return c[1] > 0)


func _on_player_stood() -> void:
	pass


func _on_died(actor: Actor) -> void:
	if actor is Enemy:
		_corpses.append([actor, 240])
		var all_down := true
		for e: Variant in enemies:
			if is_instance_valid(e) and not e.machine.dead():
				all_down = false
		if all_down and not test_mode and boss == null:
			_bailiff_timer = BAILIFF_RESPAWN_TICKS
	elif actor is Player:
		_player_timer = PLAYER_RESPAWN_TICKS


# ---------------------------------------------------------------- feedback
# Presentation only. Everything here reacts to what the bridge reported.

func _on_struck(info: Dictionary) -> void:
	var kind: String = info.kind
	var at: Vector3 = info.at
	var defender: Actor = info.defender
	if kind == "hit" or kind == "held":
		Sfx.play_at("heavy" if info.heavy else "hit", at, 0.0 if info.heavy else -3.0, randf_range(0.92, 1.08))
		camera.add_shake(0.05 if info.heavy else 0.025)
		_flash(defender, Color(1, 1, 1), 0.55)
		_spark(at, Look.INK, 0.5 if info.heavy else 0.35)
	elif kind == "guarded":
		Sfx.play_at("guard", at, -4.0, randf_range(0.95, 1.1))
		camera.add_shake(0.015)
		_spark(at, Look.STONE_SHADE, 0.3)
	elif kind == "parried":
		Sfx.play_at("parry", at, 2.0, 1.25)
		camera.add_shake(0.04)
		_spark(at, Look.GOLD, 0.6)
	elif kind == "denied":
		Sfx.play_at("denied", at, 3.0, 0.9)
		camera.add_shake(0.03)
		_spark(at, Look.VERMILION, 0.55)
	elif kind == "perfect_dodge":
		Sfx.play_at("dodge", at, -6.0, 1.3)


func _on_spoke(text: String) -> void:
	if text != "" and hud != null:
		hud.announce(text, 4.2)


## The Arbiter has yielded. He offers his licence; the Witness answers.
func _on_yielded(actor: Actor) -> void:
	if actor != boss:
		return
	player.choosing = true
	player.choice_count = 2
	if hud != null:
		hud.set_choice(["1    Take his licence", "2    Refuse it"])


func _on_chose(option: int) -> void:
	if not player.choosing or boss == null:
		return
	player.choosing = false
	flags["voss"] = "licensed" if option == 1 else "refused"
	if option == 1:
		# Licensed: the Court recognises this Witness from now on.
		bridge.world.add_tag(player.entity_id, "licensed", 0)
		bridge.world.add_tag(player.entity_id, "recognised", 0)
	bridge.log_lines.append("%6d  %-12s  %-18s  %s" % [bridge.tick, "CHOSE", "", "the Witness is %s" % flags["voss"]])
	if hud != null:
		hud.set_choice([])
		hud.announce("Licensed. The Court will know your name." if option == 1 else "Refused. You are Crownless now.", 5.0)


## The first Revelation: the Instrument wakes, and the yard knows it.
func _on_unveiled(actor: Actor) -> void:
	var at := actor.global_position + Vector3.UP * 1.0
	Sfx.play_at("seal", at, 6.0, 0.6)
	Sfx.play_at("parry", at, 4.0, 0.7)
	camera.add_shake(0.12)
	for size: float in [2.2, 4.4, 6.5]:
		_spark(at, Look.GOLD, size)
	if hud != null and actor is Player:
		var def := bridge.registry.resolve((actor as Player).law_id, "UNVEILED")
		hud.announce("Unveiled: " + String(def.get("name", "")))


## A law's harm reaching someone: a mirrored strike, a twin's share, a debt.
func _on_consequence(info: Dictionary) -> void:
	var kind: String = info.kind
	var at: Vector3 = info.at
	var colours := {"mirrored": LawFx.SILVER, "copied": LawFx.SILVER, "returned": Look.GOLD,
		"paid_forward": Look.GOLD, "debt_due": Look.VERMILION, "sanction": Look.VERMILION, "forfeit": Look.VERMILION,
		"defaulted": Look.VERMILION}
	var colour: Color = colours.get(kind, Look.INK)
	_flash(info.target, colour, 0.5)
	_spark(at, colour, 0.75 if kind == "defaulted" else 0.42)
	Sfx.play_at("denied" if kind in ["debt_due", "sanction", "defaulted", "forfeit"] else "hit", at, -4.0, 1.25)


func _flash(actor: Actor, colour: Color, amount: float) -> void:
	if actor == null or actor.model == null:
		return
	actor.model.set_tint(colour, amount)
	get_tree().create_timer(0.07).timeout.connect(_unflash.bind(actor.get_instance_id()))


func _unflash(id: int) -> void:
	var actor := instance_from_id(id) as Actor
	if actor != null and actor.model != null:
		actor.model.set_tint(Color.WHITE, 0.0)


## A hard-edged ring at the point of contact. Effects have edges (docs/08).
func _spark(at: Vector3, colour: Color, size: float) -> void:
	if test_mode:
		return
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 6
	ring.mesh = mesh
	var mat := Look.flat(colour)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = at
	if camera != null:
		ring.look_at(camera.camera().global_position, Vector3.UP)
		ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * size * 0.3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * size, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14).set_delay(0.04)
	tw.chain().tween_callback(ring.queue_free)


# -------------------------------------------------------------------- world

func _build_world() -> void:
	_build_sky()
	_build_yard()


## Sky, ambient light, fog and the one sun. `fog` is density; `shadow_far`
## is how far from the camera shadows are drawn.
func _build_sky(fog: float = 0.004, shadow_far: float = 70.0) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	# First look (2026-11-10) was blown out to white: pale stone under a bright
	# sun, with fog painting the whole sky one colour. Everything here is set
	# so lit stone lands near 0.6 and shadow near 0.2.
	sky_mat.sky_top_color = Color(0.46, 0.52, 0.60)
	sky_mat.sky_horizon_color = Color(0.82, 0.74, 0.58)
	sky_mat.sky_curve = 0.09
	sky_mat.ground_bottom_color = Color(0.42, 0.41, 0.38)
	sky_mat.ground_horizon_color = Color(0.82, 0.74, 0.58)
	sky_mat.sun_angle_max = 6.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.80)   # shadows are ink, not black
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.74, 0.62)
	env.fog_density = fog
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 145.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = shadow_far
	add_child(sun)


func _build_yard() -> void:
	# The floor: a ruled page.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 120.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor_mesh.mesh = plane
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = load("res://presentation/shaders/ruled_floor.gdshader")
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	# A colonnade: columns as ruled lines, lintels across them.
	var stone := Look.stone(Look.STONE)
	var dark := Look.stone(Look.STONE_SHADE)
	var count := 12
	var radius := 19.0
	for i in count:
		var a := TAU * float(i) / float(count)
		var at := Vector3(sin(a) * radius, 0.0, cos(a) * radius)
		_column(at, stone, dark)
		var b := TAU * float(i + 1) / float(count)
		var next := Vector3(sin(b) * radius, 0.0, cos(b) * radius)
		if i % 3 != 2:      # leave gaps: blank space is part of the design
			_lintel(at, next, stone)

	# The yard's edge. Low, so the sky stays in frame.
	for i in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(60.0, 6.0, 1.0)
		ws.shape = wb
		wall.add_child(ws)
		var wm := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(60.0, 1.1, 1.0)
		wm.mesh = mesh
		wm.position.y = -2.45
		wm.material_override = dark
		wall.add_child(wm)
		wall.position = Vector3(0.0, 3.0, 29.5).rotated(Vector3.UP, PI * 0.5 * i)
		wall.rotation.y = PI * 0.5 * i
		add_child(wall)


func _column(at: Vector3, _stone: Material, _dark: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = at
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 10.0
	shape.shape = cyl
	shape.position.y = 5.0
	body.add_child(shape)
	# Ten metres: plinth, base, a shaft with a slight swell, capital, abacus.
	var scene := load("res://assets/models/props/column.glb") as PackedScene
	if scene != null:
		body.add_child(scene.instantiate())
	add_child(body)


func _lintel(from: Vector3, to: Vector3, stone: Material) -> void:
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.9, from.distance_to(to) + 1.9)
	beam.mesh = bm
	beam.material_override = stone
	add_child(beam)
	beam.position = (from + to) * 0.5 + Vector3.UP * 10.45
	beam.rotation.y = atan2(to.x - from.x, to.z - from.z)
