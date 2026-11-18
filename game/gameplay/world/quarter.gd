class_name Quarter
extends Arena
## The Assize Quarter of Veyr (milestone M5): one connected district.
##
##   The Oath-Market        where the Witness starts. A vow broke here.
##   The Scriveners' Stair  two flights and a landing, up to the forecourt.
##   The Drowned Docket     a flooded archive below the market. Its far end
##                          climbs to a gate on the landing that opens only
##                          from the Docket's side.
##   The Hall of Standing   Aurel Voss.
##
## It is the practice yard's fight wiring (Arena) in a real place: who
## stands where, what can be read and where a Witness may rest come from
## data/world/assize_quarter.json. The stone is built here, from blocks
## (Massing) and from the game's own models.

const DATA := "res://data/world/assize_quarter.json"
const REACH := 2.4               # how near a thing must be to read, rest or open it
const FALL_Y := -30.0

## Tests leave enemies asleep (Arena.test_mode); one that wants them to fight sets this.
var force_ai: bool = false
## A capture that wants keepers to notice the Witness and still stand there sets this.
var pacified: bool = false

var data: Dictionary = {}
var groups: Dictionary = {}      # encounter id -> {spec, enemies, awake, cleared}
var gates: Dictionary = {}       # gate id -> Gate
var stone_id: String = ""        # the vow-stone last rested at
var area_id: String = ""
var reading: String = ""         # id of the record open on screen
var prompt: String = ""          # what the interact button would do now
var rests: int = 0
var menu: String = ""            # "stone" while a vow-stone's choices are open
var menu_stone: String = ""
var menu_lines: Array = []       # what the open menu offers (tests read this; the HUD shows it)
var vows_kept: int = 0
var vows_fallen: int = 0
var missing_props: Array = []

var _decor: Massing
var _said: String = ""


# ------------------------------------------------------------------ set-up

func _build_world() -> void:
	data = LawRegistry.read_json(DATA)
	stone_id = data.start.stone
	respawn_at = _v(data.start.at)
	_build_sky(0.0026, 95.0)
	# Out of the sun everything was one flat grey-violet (first capture). A
	# weak cool light from the other side of the sky, casting no shadow,
	# gives shaded stone a lit face and a turned one.
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	fill.light_color = Color(0.66, 0.76, 1.0)
	fill.light_energy = 0.20
	fill.light_specular = 0.0
	fill.shadow_enabled = false
	add_child(fill)
	_build_stone()
	_build_courts()
	_build_props()


func _place_fixtures() -> void:
	for g: Dictionary in data.gates:
		var gate := Gate.new()
		gate.gate_id = g.id
		gate.gate_name = g.name
		gate.width = float(g.width)
		gate.spans_z = g.axis == "x"
		gate.opens_from = int(g.opens_from)
		gate.locked_text = g.locked
		gate.is_open = g.get("starts_open", false)
		gate.position = _v(g.at)
		add_child(gate)
		gates[g.id] = gate


func _populate() -> void:
	enemies = []
	for spec: Dictionary in data.encounters:
		groups[spec.id] = {"spec": spec, "enemies": [], "awake": false, "cleared": false}
		_spawn_group(spec.id)
	bailiff = groups["bailiff"].enemies[0]


func _after_ready() -> void:
	player.free_rest = false
	area_id = area_at(respawn_at).get("id", "")      # the Quarter's own name is the first thing said
	player.interacted.connect(_on_interact)
	bridge.struck.connect(_on_struck_wake)
	bridge.vow_changed.connect(_on_vow)
	if hud != null:
		hud.set_help([
			"WASD move   ·   mouse look   ·   Tab lock on   ·   LMB light   ·   RMB heavy",
			"Space dodge   ·   Shift guard (tap to parry)   ·   1 to 6 choose your law",
			"Q impose (hold to commit; walk to draw a line)   ·   Q + strike inscribes",
			"E read, rest at a vow-stone, open   ·   L save the verdict log   ·   T the practice yard",
			"Esc free the mouse   ·   Backspace start again   ·   H hide this",
		], false)
		hud.announce(String(data.name), 3.4)


func _travel_to() -> String:
	return "res://scenes/Arena.tscn"


func _has_encounter_list() -> bool:
	return false


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


# -------------------------------------------------------------- encounters

func _spawn_group(id: String) -> void:
	var g: Dictionary = groups[id]
	var spec: Dictionary = g.spec
	g.enemies = []
	g.awake = false
	g.cleared = false
	for entry: Array in spec.spawn:
		var e := _make_enemy(entry[0], _v(entry[1]))
		e.ai_enabled = false
		if e is Voss:
			(e as Voss).hearing_open = false
		e.has_home = true
		e.home = _v(entry[1])
		g.enemies.append(e)
		enemies.append(e)
	if spec.get("escort", false) and g.enemies.size() >= 2:
		g.enemies[0].partner = g.enemies[1]
		g.enemies[1].partner = g.enemies[0]


func _live_ai() -> bool:
	return not pacified and (force_ai or not test_mode)


## Those who keep a place notice the Witness.
func wake(id: String) -> void:
	var g: Dictionary = groups[id]
	if g.awake or g.cleared:
		return
	g.awake = true
	for e: Variant in g.enemies:
		if is_instance_valid(e) and not e.machine.dead():
			e.ai_enabled = _live_ai()
	_announce(String(g.spec.name))
	if g.spec.get("boss", false) and boss != null:
		boss.hearing_open = true
		(gates["hall_gate"] as Gate).close()
		if hud != null:
			hud.set_boss(boss)


## The Witness has gone too far to follow: they walk back to their posts.
func sleep(id: String) -> void:
	var g: Dictionary = groups[id]
	g.awake = false
	for e: Variant in g.enemies:
		if is_instance_valid(e):
			e.ai_enabled = false


## Everyone the Quarter keeps is back at their post, whole. The Arbiter is
## not, once he has yielded: that happened.
func reset_encounters() -> void:
	player.lock_target = null
	for c: Array in _corpses:
		if is_instance_valid(c[0]):
			bridge.unregister(c[0])
			c[0].queue_free()
	_corpses.clear()
	var kept: Array = []
	for id: String in groups:
		var g: Dictionary = groups[id]
		if g.spec.get("boss", false) and boss != null and is_instance_valid(boss) and boss.yielded:
			kept.append_array(g.enemies)
			continue
		for e: Variant in g.enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if e is Voss:
					(e as Voss).clear_seals()
				bridge.retire(e)
				e.queue_free()
	enemies = kept
	for id: String in groups:
		var g: Dictionary = groups[id]
		if g.spec.get("boss", false):
			if boss != null and is_instance_valid(boss) and boss.yielded:
				continue
			boss = null
			player.choosing = false
			if hud != null:
				hud.set_boss(null)
				hud.set_choice([])
			(gates["hall_gate"] as Gate).open()
		_spawn_group(id)
	bailiff = groups["bailiff"].enemies[0]


func _tick_encounters() -> void:
	if player.machine.dead():
		return
	var here := player.global_position
	for id: String in groups:
		var g: Dictionary = groups[id]
		if g.cleared:
			continue
		var at := _v(g.spec.at)
		var flat := Vector2(here.x - at.x, here.z - at.z).length()
		var level := absf(here.y - at.y) < 3.0
		if not g.awake:
			if level and flat < float(g.spec.radius):
				wake(id)
		elif not g.spec.get("boss", false) and (flat > float(g.spec.leash) or not level):
			sleep(id)


func _on_struck_wake(info: Dictionary) -> void:
	# Striking a sleeper wakes the whole post.
	for id: String in groups:
		var g: Dictionary = groups[id]
		if not g.awake and not g.cleared and g.enemies.has(info.defender) and info.attacker == player:
			wake.call_deferred(id)


func _on_died(actor: Actor) -> void:
	if actor is Player:
		_player_timer = PLAYER_RESPAWN_TICKS
		reading = ""
		return
	if actor is Enemy:
		_corpses.append([actor, 240])
		for id: String in groups:
			var g: Dictionary = groups[id]
			if not g.enemies.has(actor):
				continue
			var all_down := true
			for e: Variant in g.enemies:
				if is_instance_valid(e) and not e.machine.dead():
					all_down = false
			if all_down:
				g.cleared = true
				g.awake = false
				_keep_vows.call_deferred()      # a post cleared under a Vow is the Vow kept


func _on_player_stood() -> void:
	bridge.forget_standing(player)       # a Vow ends unkept with its author; what their word weighed goes too
	reset_encounters()


func _on_yielded(actor: Actor) -> void:
	super._on_yielded(actor)
	if actor == boss:
		groups["voss"].cleared = true
		groups["voss"].awake = false
		(gates["hall_gate"] as Gate).open()
		_keep_vows.call_deferred()


# ------------------------------------------------------- reading, resting

## The nearest thing in reach: {kind, id, text} or {}.
func nearest_interactable() -> Dictionary:
	var here := player.global_position
	var best := {}
	var best_d := REACH
	for s: Dictionary in data.stones:
		var d := here.distance_to(_v(s.at))
		if d < best_d:
			best_d = d
			best = {"kind": "stone", "id": s.id, "text": "The vow-stone: rest, or swear"}
	for r: Dictionary in data.records:
		var d := here.distance_to(_v(r.at))
		if d < best_d:
			best_d = d
			best = {"kind": "record", "id": r.id, "text": "Read: " + String(r.title)}
	for id: String in gates:
		var gate: Gate = gates[id]
		if gate.is_open or gate.opens_from == 0:
			continue
		var d := here.distance_to(gate.global_position)
		if d < 3.4 and (best.is_empty() or d < best_d):
			best_d = d
			best = {"kind": "gate", "id": id,
				"text": "Open the gate" if gate.can_open_from(here) else gate.locked_text}
	return best


func _on_interact() -> void:
	if player.machine.dead():
		return
	if menu != "":
		_close_menu()
		return
	if player.choosing:
		return
	if reading != "":
		reading = ""
		_show_record()
		return
	var it := nearest_interactable()
	if it.is_empty():
		return
	if it.kind == "stone":
		open_stone(it.id)
	elif it.kind == "record":
		reading = it.id
		_show_record()
	elif it.kind == "gate":
		var gate: Gate = gates[it.id]
		if gate.can_open_from(player.global_position):
			gate.open()
			Sfx.play_at("seal", gate.global_position, 2.0, 0.8)
			_announce(gate.gate_name + " is open")
		else:
			_announce(gate.locked_text)


# -------------------------------------------------------------------- vows

## A vow-stone's choices: rest, or swear one of the Vows before going on.
## One Vow at a time; a stone will not take a second while the first stands.
func open_stone(id: String) -> bool:
	if _fighting():
		_announce("Not while they are upon you")
		return false
	menu = "stone"
	menu_stone = id
	menu_lines = ["1    Rest"]
	var sworn := bridge.vow_of(player)
	if sworn.is_empty():
		var n := 2
		for def: Dictionary in bridge.vows():
			menu_lines.append("%d    Swear: %s   (stake %d, weight +%d)" % [n, def.thesis, int(def.forfeit.harm), int(def.reward.standing)])
			n += 1
		player.choice_count = n - 1
	else:
		menu_lines.append("Sworn: " + String(sworn.thesis))
		player.choice_count = 1
	menu_lines.append("E    Step away")
	player.choosing = true
	if hud != null:
		hud.set_choice(menu_lines)
	return true


func _close_menu() -> void:
	if menu == "":
		return
	menu = ""
	menu_lines = []
	player.choosing = false
	player.choice_count = 2
	if hud != null:
		hud.set_choice([])


func _on_chose(option: int) -> void:
	if menu != "stone":
		super._on_chose(option)      # the Arbiter's offer
		return
	var stone := menu_stone
	_close_menu()
	if option == 1:
		rest_at(stone)
	else:
		var all := bridge.vows()
		if option - 2 < all.size():
			swear(String(all[option - 2].id))


## Swear a Vow. It stands until a post is cleared under it (kept) or the
## thing it names happens (it falls).
func swear(def_id: String) -> bool:
	if not bridge.swear(player, def_id):
		_announce("You are already sworn" if not bridge.vow_of(player).is_empty() else "The vow would not take")
		return false
	return true


func _keep_vows() -> void:
	if not player.machine.dead():
		bridge.keep_vows(player)


func _on_vow(actor: Actor, what: String, def_id: String) -> void:
	if actor != player:
		return
	var def := bridge.registry.resolve(def_id)
	var at := player.global_position + Vector3.UP * 1.0
	if what == "sworn":
		Sfx.play_at("seal", at, 2.0, 0.9)
		_announce("Sworn: " + String(def.thesis))
	elif what == "kept":
		vows_kept += 1
		Sfx.play_at("parry", at, 2.0, 0.8)
		_spark(at, Look.GOLD, 2.4)
		_announce("The vow is kept. Your word weighs %d." % bridge.standing(player))
	elif what == "fell":
		vows_fallen += 1
		Sfx.play_at("denied", at, 5.0, 0.7)
		camera.add_shake(0.08)
		_spark(at, Look.VERMILION, 2.4)
		_announce("The vow fell")


## Rest at a vow-stone: whole again, this is where you stand if you fall,
## and everyone you put down is back at their post. What your word weighed
## is forgotten; a Vow still standing still stands.
func rest_at(id: String) -> bool:
	if _fighting():
		_announce("Not while they are upon you")
		return false
	for s: Dictionary in data.stones:
		if s.id == id:
			stone_id = id
			respawn_at = _v(s.stand)
			bridge.rest(player)
			bridge.forget_standing(player)
			reset_encounters()
			rests += 1
			Sfx.play_at("seal", _v(s.at), 0.0, 1.1)
			_announce(String(s.name))
			return true
	return false


func _fighting() -> bool:
	for id: String in groups:
		if groups[id].awake and not groups[id].cleared:
			return true
	return false


func record(id: String) -> Dictionary:
	for r: Dictionary in data.records:
		if r.id == id:
			return r
	return {}


func _show_record() -> void:
	if hud == null:
		return
	var r := record(reading)
	if r.is_empty():
		hud.set_record("", "")
	else:
		hud.set_record(String(r.title), String(r.text))


func _announce(text: String) -> void:
	_said = text
	if hud != null:
		hud.announce(text)


## What was last announced (tests read this; the HUD shows it).
func said() -> String:
	return _said


func area_at(p: Vector3) -> Dictionary:
	for a: Dictionary in data.areas:
		if p.x >= float(a.min[0]) and p.x <= float(a.max[0]) and p.z >= float(a.min[1]) and p.z <= float(a.max[1]):
			return a
	return {}


func _physics_process(_delta: float) -> void:
	_tick_fallen()
	_tick_encounters()
	var here := player.global_position
	if here.y < FALL_Y:
		player.global_position = respawn_at
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
	var a := area_at(here)
	if not a.is_empty() and a.id != area_id:
		area_id = a.id
		if not _fighting():
			_announce(String(a.name))
	if reading != "" and here.distance_to(_v(record(reading).at)) > REACH + 1.2:
		reading = ""
		_show_record()
	if menu == "stone":
		var away := true
		for s: Dictionary in data.stones:
			if s.id == menu_stone and here.distance_to(_v(s.at)) <= REACH + 1.2:
				away = false
		if away or player.machine.dead() or _fighting():
			_close_menu()
	var it := {} if (player.machine.dead() or reading != "" or menu != "") else nearest_interactable()
	var text: String = it.get("text", "")
	if text != prompt:
		prompt = text
		if hud != null:
			var by_hand: bool = it.get("kind", "") != "gate" or (gates[it.id] as Gate).can_open_from(here)
			hud.set_prompt(("E    " + text) if (text != "" and by_hand) else text)


# -------------------------------------------------------------------- stone
# Architecture as typography: wide margins of blank stone, dense ornament
# only where authority sits, lintels where a lesser city would have arches.

func _block(m: Massing, key: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, solid: bool = true) -> void:
	m.box(key, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
		Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)), solid)


func _materials(m: Massing) -> void:
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = load("res://presentation/shaders/ruled_floor.gdshader")
	m.material("floor", floor_mat)
	m.material("stone", Look.masonry(Look.STONE))
	m.material("pale", Look.masonry(Look.STONE.lightened(0.10)))
	m.material("dark", Look.stone(Look.STONE_SHADE))
	m.material("bronze", Look.metal(Look.VERDIGRIS.darkened(0.35)))
	m.material("gold", Look.metal(Look.GOLD))
	m.material("struck", Look.flat(Look.STRUCK))
	m.material("vow", Look.flat(Look.GOLD))
	m.material("fallen", Look.flat(Look.VERMILION))


func _build_stone() -> void:
	var m := Massing.new()
	_materials(m)

	# ---- floors
	_block(m, "floor", -21.5, 21.5, -1, 0, -19.5, 19.5)                 # the Oath-Market
	m.stair("pale", Vector3(0, 0, 18), Vector3(0, 4, 34), 12.0, 16)     # first flight
	_block(m, "floor", -12, 12, 3, 4, 34, 50)                           # the landing
	m.stair("pale", Vector3(0, 4, 50), Vector3(0, 8, 66), 12.0, 16)     # second flight
	_block(m, "floor", -14, 14, 7, 8, 66, 83)                           # the forecourt
	_block(m, "floor", -18.5, 18.5, 7, 8, 83, 119.5)                    # the Hall of Standing
	m.ramp("pale", Vector3(20, 0, 0), Vector3(36, -4, 0), 6.0)          # down to the Docket
	_block(m, "dark", 34.5, 55.5, -5, -4, -11.5, 53.5)                  # the Docket's bed
	m.ramp("pale", Vector3(36, -4, 45), Vector3(12, 4, 45), 6.0)        # up to the gate

	# ---- the Oath-Market's walls
	_block(m, "stone", -21.5, 21.5, 0, 12, -19.5, -18)                  # south, with the Witness Gate
	_block(m, "stone", 6, 21.5, 0, 12, 18, 19.5)
	_block(m, "stone", -21.5, -6, 0, 12, 18, 19.5)
	_block(m, "stone", -6, 6, 9, 12, 18, 19.5)                          # lintel over the Stair
	_block(m, "dark", -6.3, 6.3, 8.6, 9.0, 17.9, 19.6, false)
	_block(m, "stone", 20, 21.5, 0, 12, -19.5, -3)
	_block(m, "stone", 20, 21.5, 0, 12, 3, 19.5)
	_block(m, "stone", 20, 21.5, 6, 12, -3, 3)                          # lintel over the way down
	_block(m, "dark", 19.9, 21.6, 5.6, 6.0, -3.3, 3.3, false)
	# The west side: the Oath Hall, where the vow broke. What is left of its
	# front, the dark of what fell in behind, and the Court's answer to it:
	# a bar struck across the gap.
	_block(m, "stone", -21.5, -20, 0, 12, -19.5, -8)
	_block(m, "stone", -21.5, -20, 0, 12, 10, 19.5)
	# (The ruin itself is a model, placed in _build_props. Here: what stops
	# the Witness walking into it. The stumps and drums of its porch are
	# solid; the gap in the wall is closed by a wall that is not drawn.)
	m.box("stone", Vector3(-20.75, 6, 1), Vector3(1.5, 12, 18), true, Basis.IDENTITY, false)
	for stump: Array in [[7.0, 1.5], [3.0, 3.4], [-1.0, 0.9], [-5.0, 2.3]]:
		var sz: float = stump[0]
		var sh: float = stump[1]
		m.box("stone", Vector3(-16.8, sh * 0.5, sz), Vector3(1.9, sh, 1.9), true, Basis.IDENTITY, false)
		m.box("stone", Vector3(-13.4, 0.65, sz), Vector3(4.6, 1.3, 1.6), true, Basis.IDENTITY, false)
	# String courses: one ruled line round the square.
	for z: float in [-17.95, 17.95]:
		_block(m, "dark", -20, 20, 4.0, 4.25, z - 0.06, z + 0.06, false)

	# ---- the way down to the Docket
	_block(m, "stone", 21.5, 34.5, -5, 12, -4.5, -3)
	_block(m, "stone", 21.5, 34.5, -5, 12, 3, 4.5)

	# ---- the Drowned Docket: a sunk court, open to the sky, ribbed over
	_block(m, "stone", 34.5, 36, -5, 10, -11.5, -3)
	_block(m, "stone", 34.5, 36, -5, 10, 3, 42)
	_block(m, "stone", 34.5, 36, -5, 10, 48, 53.5)
	_block(m, "stone", 34.5, 36, 6, 10, -3, 3)
	_block(m, "stone", 34.5, 36, 6, 10, 42, 48)
	_block(m, "stone", 54, 55.5, -5, 10, -11.5, 53.5)
	_block(m, "stone", 34.5, 55.5, -5, 10, -11.5, -10)
	_block(m, "stone", 34.5, 55.5, -5, 10, 52, 53.5)
	for z: float in [0.0, 12.0, 24.0, 36.0]:
		if z > 6.0:      # the first pier on the west would stand in the way down
			_block(m, "dark", 36, 37.1, -5, 7, z - 0.6, z + 0.6)
		_block(m, "dark", 52.9, 54, -5, 7, z - 0.6, z + 0.6)
		_block(m, "dark", 36, 54, 7, 7.9, z - 0.5, z + 0.5, false)
	_block(m, "bronze", 36, 54, -3.3, -3.15, -10, -9.85, false)           # a tide line the water has left

	# ---- the way up to the gate
	_block(m, "stone", 13.5, 34.5, -5, 12, 40.5, 42)
	_block(m, "stone", 13.5, 34.5, -5, 12, 48, 49.5)

	# ---- the Scriveners' Stair
	_block(m, "stone", 6, 7.5, 0, 14, 19.5, 34)
	_block(m, "stone", -7.5, -6, 0, 14, 19.5, 34)
	_block(m, "stone", 7.5, 13.5, 0, 14, 32.5, 34)
	_block(m, "stone", -13.5, -7.5, 0, 14, 32.5, 34)
	_block(m, "stone", 12, 13.5, 0, 14, 34, 42)
	_block(m, "stone", 12, 13.5, 0, 14, 48, 51.5)
	_block(m, "stone", 12, 13.5, 9, 14, 42, 48)                         # lintel over the Docket Gate
	_block(m, "dark", 11.9, 13.6, 8.6, 9.0, 41.7, 48.3, false)
	_block(m, "stone", -13.5, -12, 0, 14, 34, 51.5)
	_block(m, "stone", 6, 12, 0, 18, 50, 51.5)
	_block(m, "stone", -12, -6, 0, 18, 50, 51.5)
	_block(m, "stone", 6, 7.5, 4, 18, 51.5, 66)
	_block(m, "stone", -7.5, -6, 4, 18, 51.5, 66)
	# Each flight is ruled down both sides.
	for x: float in [5.94, -5.94]:
		_block(m, "dark", x - 0.06, x + 0.06, 6.0, 6.25, 19.5, 34, false)
		_block(m, "dark", x - 0.06, x + 0.06, 10.0, 10.25, 51.5, 66, false)

	# ---- the forecourt, and the portal of the Hall
	_block(m, "stone", 7.5, 15.5, 4, 20, 64.5, 66)
	_block(m, "stone", -15.5, -7.5, 4, 20, 64.5, 66)
	_block(m, "stone", 14, 15.5, 4, 20, 66, 85.5)
	_block(m, "stone", -15.5, -14, 4, 20, 66, 85.5)
	_block(m, "pale", 4, 14, 8, 24, 83, 85.5)
	_block(m, "pale", -14, -4, 8, 24, 83, 85.5)
	_block(m, "pale", -4, 4, 15, 24, 83, 85.5)                          # the lintel of Standing
	_block(m, "gold", -4.5, 4.5, 14.55, 15.0, 82.9, 83.1, false)        # gold only where law sits
	_block(m, "dark", -14, 14, 20.0, 20.5, 82.9, 83.0, false)
	for x: float in [-4.6, 4.6]:                                        # jambs
		_block(m, "dark", x - 0.6, x + 0.6, 8, 15, 82.6, 83.0, false)

	# ---- the Hall of Standing: a round court open to the sky
	var centre := Vector3(0, 8, 101)
	var radius := 17.0
	var segments := 28
	var chord := 2.0 * (radius + 1.5) * tan(PI / float(segments)) + 0.1
	for i in segments:
		var a := TAU * float(i) / float(segments)
		if i == 0 or i == 1 or i == segments - 1:
			continue                                                    # the three bays of the portal
		# angle 0 looks south, toward the forecourt
		var out := Vector3(sin(a), 0.0, -cos(a))
		var basis := Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)
		m.box("pale", centre + out * (radius + 0.75) + Vector3.UP * 8.0, Vector3(chord, 16.0, 1.5), true, basis)
		m.box("dark", centre + out * (radius - 0.03) + Vector3.UP * 5.0, Vector3(chord, 0.25, 0.1), false, basis)
	_dress(m)
	# The Court's mark, inlaid in gold in the floor of its Hall: a circle
	# with a line through it, twenty-four metres across. Gold only where
	# law sits.
	for i in 64:
		var a := TAU * float(i) / 64.0
		var out := Vector3(sin(a), 0.0, cos(a))
		m.box("gold", centre + out * 12.2 + Vector3.UP * 0.012, Vector3(1.24, 0.03, 0.24), false,
			Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out))
	m.box("gold", centre + Vector3.UP * 0.012, Vector3(0.24, 0.03, 30.4), false)
	m.commit(self)

	# Water in the Docket: ankle deep, still, the green of old bronze.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.0, 62.0)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(Look.VERDIGRIS.darkened(0.45), 0.62)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.06
	wm.metallic = 0.35
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(45.0, -3.8, 21.0)
	water.name = "Water"
	add_child(water)
	# The Docket is in shadow most of the day: three lamps' worth of green light.
	for z: float in [6.0, 24.0, 42.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.62, 0.86, 0.78)
		lamp.light_energy = 1.6
		lamp.omni_range = 15.0
		lamp.shadow_enabled = false
		lamp.light_specular = 0.0          # on still water a lamp's highlight was a bright blob that followed the camera
		lamp.position = Vector3(45.0, 1.5, z)
		add_child(lamp)


## One face of a wall, dressed: a dark plinth at its foot, a cornice at its
## head, and pilasters between, so that a blank wall is a composed blank
## and not an unfinished one. `a` to `b` is the foot of the face; `inward`
## points into the place it faces. None of it is solid.
func _face(m: Massing, a: Vector3, b: Vector3, top: float, inward: Vector3, plinth: bool = true, pilasters: bool = true, skip: Array = []) -> void:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var n := inward.normalized()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	var mid := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	var foot := minf(a.y, b.y)
	if plinth:
		m.box("dark", mid + n * 0.10 + Vector3.UP * (foot + 0.36), Vector3(length, 0.72, 0.20), false, basis)
		m.box("dark", mid + n * 0.05 + Vector3.UP * (foot + 0.80), Vector3(length, 0.10, 0.12), false, basis)
	m.box("pale", mid + n * 0.20 + Vector3.UP * (top - 0.28), Vector3(length + 0.4, 0.56, 0.44), false, basis)
	m.box("dark", mid + n * 0.11 + Vector3.UP * (top - 0.68), Vector3(length, 0.14, 0.22), false, basis)
	if not pilasters:
		return
	var count := maxi(0, roundi(length / 6.5) - 1)
	for i in count:
		var along := length * float(i + 1) / float(count + 1)
		var skipped := false
		for gap: Array in skip:
			if along > float(gap[0]) and along < float(gap[1]):
				skipped = true
		if skipped:
			continue
		var at := Vector3(a.x, 0.0, a.z) + dir * along
		var low := foot - 1.0
		m.box("pale", at + n * 0.08 + Vector3.UP * ((low + top - 0.75) * 0.5), Vector3(0.95, top - 0.75 - low, 0.16), false, basis)
		m.box("dark", at + n * 0.10 + Vector3.UP * (top - 1.02), Vector3(1.15, 0.22, 0.22), false, basis)


func _dress(m: Massing) -> void:
	var px := Vector3.RIGHT
	var pz := Vector3.BACK
	# The Oath-Market (walls 12 m).
	_face(m, Vector3(-20, 0, -18), Vector3(20, 0, -18), 12, pz, true, true, [[15.0, 25.0]])     # round the Witness Gate
	_face(m, Vector3(-20, 0, 18), Vector3(-6, 0, 18), 12, -pz)
	_face(m, Vector3(6, 0, 18), Vector3(20, 0, 18), 12, -pz)
	_face(m, Vector3(20, 0, -18), Vector3(20, 0, -3), 12, -px)
	_face(m, Vector3(20, 0, 3), Vector3(20, 0, 18), 12, -px)
	_face(m, Vector3(-20, 0, -18), Vector3(-20, 0, -8), 12, px)
	_face(m, Vector3(-20, 0, 10), Vector3(-20, 0, 18), 12, px)
	# The Stair: its flights have no plinth (the floor climbs), its landing and forecourt do.
	for sx: float in [1.0, -1.0]:
		_face(m, Vector3(6 * sx, 0, 19.5), Vector3(6 * sx, 0, 34), 14, -px * sx, false)
		_face(m, Vector3(6 * sx, 4, 51.5), Vector3(6 * sx, 4, 66), 18, -px * sx, false)
		_face(m, Vector3(6 * sx, 4, 34), Vector3(12 * sx, 4, 34), 14, pz, true, false)
		_face(m, Vector3(6 * sx, 4, 50), Vector3(12 * sx, 4, 50), 18, -pz, true, false)
		_face(m, Vector3(7.5 * sx, 8, 66), Vector3(14 * sx, 8, 66), 20, pz, true, false)
		_face(m, Vector3(14 * sx, 8, 66), Vector3(14 * sx, 8, 83), 20, -px * sx)
		_face(m, Vector3(4 * sx, 8, 83), Vector3(14 * sx, 8, 83), 24, -pz, true, false)
	_face(m, Vector3(-12, 4, 34), Vector3(-12, 4, 50), 14, px)
	_face(m, Vector3(12, 4, 34), Vector3(12, 4, 42), 14, -px, true, false)
	_face(m, Vector3(12, 4, 48), Vector3(12, 4, 50), 14, -px, true, false)
	# The ways down and up: cornices only.
	_face(m, Vector3(21.5, 0, -3), Vector3(34.5, 0, -3), 12, pz, false, false)
	_face(m, Vector3(21.5, 0, 3), Vector3(34.5, 0, 3), 12, -pz, false, false)
	_face(m, Vector3(13.5, 0, 42), Vector3(34.5, 0, 42), 12, pz, false, false)
	_face(m, Vector3(13.5, 0, 48), Vector3(34.5, 0, 48), 12, -pz, false, false)
	# The Docket (shelves and piers stand where pilasters would).
	_face(m, Vector3(36, -4, -10), Vector3(36, -4, -3), 10, px, true, false)
	_face(m, Vector3(36, -4, 3), Vector3(36, -4, 42), 10, px, true, false)
	_face(m, Vector3(36, -4, 48), Vector3(36, -4, 52), 10, px, true, false)
	_face(m, Vector3(54, -4, -10), Vector3(54, -4, 52), 10, -px, true, false)
	_face(m, Vector3(36, -4, -10), Vector3(54, -4, -10), 10, pz, true, false)
	_face(m, Vector3(36, -4, 52), Vector3(54, -4, 52), 10, -pz, true, false)
	# The Hall: each bay of its round wall.
	var centre := Vector3(0, 8, 101)
	for i in 28:
		if i == 0 or i == 1 or i == 27:
			continue
		var ang := TAU * float(i) / 28.0
		var out := Vector3(sin(ang), 0.0, -cos(ang))
		var tangent := Vector3.UP.cross(out).normalized()
		var half := 17.0 * tan(PI / 28.0)
		_face(m, centre + out * 17.0 - tangent * half, centre + out * 17.0 + tangent * half, 24, -out, true, false)


## A line of writing hung in the air: words made of upright strokes, some
## tall, some hanging below the line, all leaning the way a hand leans.
## `along` is the way it reads, `up` the way its strokes stand.
func _script(m: Massing, key: String, from: Vector3, along: Vector3, up: Vector3, length: float, rng: RandomNumberGenerator, size: float = 1.0, depth: float = 0.03) -> void:
	var a := along.normalized()
	var u := (up - a * up.dot(a)).normalized()
	var face := a.cross(u).normalized()
	var basis := Basis(face, -0.21) * Basis(a, u, face)
	var x := 0.0
	while x < length:
		for s in rng.randi_range(2, 7):
			if x >= length:
				break
			var roll := rng.randf()
			var h := 0.24
			var lift := 0.0
			if roll < 0.20:
				h = 0.44
				lift = 0.10
			elif roll < 0.33:
				h = 0.40
				lift = -0.08
			elif roll < 0.46:
				h = 0.15
				lift = -0.045
			m.box(key, from + a * x + u * (lift * size), Vector3(0.05 * size, h * size, depth), false, basis)
			x += 0.115 * size
		x += 0.27 * size


## What is seen and never touched: the city beyond the walls, the vows that
## hang over the market, and the Hanging Courts, chained to nothing.
func _build_courts() -> void:
	var m := Massing.new()
	_materials(m)
	# The city beyond the walls.
	for b: Array in [[-44.0, -34.0, 26.0, -14.0, 16.0], [22.0, 34.0, 22.0, 6.0, 38.0], [-36.0, -15.5, 25.0, 22.0, 60.0],
			[17.0, 34.0, 31.0, 52.0, 82.0], [-42.0, -17.0, 35.0, 64.0, 100.0], [21.0, 46.0, 29.0, 86.0, 114.0],
			[-32.0, 32.0, 19.0, -36.0, -21.0], [58.0, 74.0, 24.0, -6.0, 40.0], [-12.0, 12.0, 30.0, 122.0, 140.0]]:
		var x0: float = b[0]
		var x1: float = b[1]
		var top: float = b[2]
		var z0: float = b[3]
		var z1: float = b[4]
		_block(m, "stone", x0, x1, 0.0, top, z0, z1, false)
		_block(m, "dark", x0 - 0.4, x1 + 0.4, top, top + 0.7, z0 - 0.4, z1 + 0.4, false)
		# A second storey set back from the first, so the skyline is not a row of lids.
		var ix := (x1 - x0) * 0.2
		var iz := (z1 - z0) * 0.24
		var rise := 5.0 + fmod(absf(x0) + absf(z0), 7.0)
		_block(m, "stone", x0 + ix, x1 - ix, top + 0.7, top + rise, z0 + iz, z1 - iz, false)
		_block(m, "dark", x0 + ix - 0.3, x1 - ix + 0.3, top + rise, top + rise + 0.5, z0 + iz - 0.3, z1 - iz + 0.3, false)
	# Vows hang over the market as written lines until they are kept: eleven
	# of them, in gold, each a line of someone's hand. (The first captures had
	# them as rows of dashes, and they read as a dashed border.)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	for line in 11:
		var y := 4.6 + rng.randf() * 3.6
		var z := -13.0 + float(line) * 2.5 + rng.randf_range(-0.5, 0.5)
		var length := 15.0 + rng.randf() * 7.0
		_script(m, "vow", Vector3(11.5 - rng.randf() * 3.0, y, z), Vector3.LEFT, Vector3.UP, length, rng, 1.25)
	# One fell. It lies in pieces before the Oath Hall, in the colour of an act.
	_script(m, "fallen", Vector3(-10.4, 0.22, 5.4), Vector3(-0.72, 0.52, -0.30), Vector3.UP, 6.4, rng, 2.0, 0.06)
	_script(m, "fallen", Vector3(-11.6, 0.07, -3.4), Vector3(0.80, 0.0, 0.60), Vector3(-0.6, 0.0, 0.8), 3.8, rng, 2.0, 0.10)
	_script(m, "fallen", Vector3(-9.2, 0.07, 1.6), Vector3(0.30, 0.0, -0.95), Vector3(0.95, 0.0, 0.3), 2.2, rng, 2.0, 0.10)
	var body := m.commit(self)
	body.name = "Beyond"
	(body.get_node("Stone") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# -------------------------------------------------------------------- props

func _scene(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	if not missing_props.has(path):
		missing_props.append(path)
	return null


## One of the game's own models, standing at `at`, its front toward `yaw`
## (0 looks along +Z). `solid` gives it a box to walk into.
func _prop(model: String, at: Vector3, yaw: float = 0.0, solid: Vector3 = Vector3.ZERO, size: float = 1.0) -> Node3D:
	var path := "res://assets/models/%s.glb" % (model if model.contains("/") else "world/" + model)
	var scene := _scene(path)
	var root := StaticBody3D.new()
	root.collision_layer = 1 if solid != Vector3.ZERO else 0
	root.collision_mask = 0
	root.position = at
	root.rotation.y = yaw
	if scene != null:
		var inst: Node3D = scene.instantiate()
		inst.scale = Vector3.ONE * size
		root.add_child(inst)
	if solid != Vector3.ZERO:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = solid
		shape.shape = box
		shape.position.y = solid.y * 0.5
		root.add_child(shape)
	add_child(root)
	return root


func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_no_shadow(child)


func _build_props() -> void:
	var half := PI * 0.5
	# The market: a colonnade down each side, lintels across it. On the west
	# two columns went down with the Hall.
	var beams := Massing.new()
	_materials(beams)
	for z: float in [-12.0, -4.0, 4.0, 12.0]:
		_prop("props/column", Vector3(15, 0, z), 0.0, Vector3(1.6, 10, 1.6))
		if absf(z) > 6.0:
			_prop("props/column", Vector3(-15, 0, z), 0.0, Vector3(1.6, 10, 1.6))
	_block(beams, "stone", 14.3, 15.7, 10.0, 10.9, -13.2, 13.2, false)
	_block(beams, "stone", -15.7, -14.3, 10.0, 10.9, -13.2, -10.6, false)
	_block(beams, "stone", -15.7, -14.3, 10.0, 10.9, 10.6, 13.2, false)
	# Where the Oath Hall stood (its solid parts are in _build_stone).
	_prop("oath_hall_ruin", Vector3(-20.0, 0, 1.0), half)
	# The Hanging Courts, over the Hall. Its lowest point, the tip of its
	# keel, is thirty-eight metres above the Arbiter's floor. It casts no
	# shadow: the Quarter is lit as if it were not there, which is how the
	# Quarter prefers to think of it.
	_no_shadow(_prop("hanging_courts", Vector3(0, 46, 112)))
	_prop("door", Vector3(0, 0, -17.95), 0.0)                              # the Witness Gate, shut behind you
	for s: Array in [[11.6, -12.0, -half], [11.6, -4.6, -half], [-11.6, -13.0, half]]:
		_prop("stall", Vector3(float(s[0]), 0.0, float(s[1])), float(s[2]), Vector3(2.8, 2.3, 1.5))
	# Either side of the Stair: an Arbiter in stone, and a plinth with the
	# feet of someone the Court would rather not name.
	_prop("statue", Vector3(9.5, 0, 15.6), PI, Vector3(1.8, 6.0, 1.8))
	_prop("plinth_struck", Vector3(-9.5, 0, 15.6), PI, Vector3(1.8, 2.2, 1.8))
	for l: Array in [[17.5, -16.0], [-17.5, -16.0], [4.2, 16.4], [-4.2, 16.4]]:
		_prop("lamp", Vector3(float(l[0]), 0.0, float(l[1])), 0.0, Vector3(0.5, 3.4, 0.5))

	# The landing: copyists' desks under the north wall.
	for x: float in [-9.6, -6.9, 6.9, 9.6]:
		_prop("desk", Vector3(x, 4, 48.9), PI, Vector3(1.5, 1.2, 1.0))
	for x: float in [-11.0, 11.0]:
		_prop("lamp", Vector3(x, 4, 34.9), 0.0, Vector3(0.5, 3.4, 0.5))

	# The forecourt: the Court's banners, and its lamps.
	for b: Array in [[13.9, 70.0, -half], [13.9, 76.0, -half], [-13.9, 70.0, half], [-13.9, 76.0, half],
			[8.5, 82.9, PI], [-8.5, 82.9, PI]]:
		_prop("banner", Vector3(float(b[0]), 19.0, float(b[1])), float(b[2]))
	for x: float in [-6.2, 6.2]:
		_prop("lamp", Vector3(x, 8, 81.8), 0.0, Vector3(0.5, 3.4, 0.5))

	# The Hall: twelve columns at the wall, a ring of lintels on them.
	var centre := Vector3(0, 8, 101)
	var ring: Array = []
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		var at := centre + Vector3(sin(a), 0.0, -cos(a)) * 15.3
		ring.append(at)
		_prop("props/column", at, 0.0, Vector3(1.6, 10, 1.6))
	for i in 12:
		var from: Vector3 = ring[i]
		var to: Vector3 = ring[(i + 1) % 12]
		if i == 11:
			continue                                                       # the bay above the portal stays open
		var dir := (to - from).normalized()
		var basis := Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP, dir)
		beams.box("pale", (from + to) * 0.5 + Vector3.UP * 10.45, Vector3(1.3, 0.9, from.distance_to(to) + 1.9), false, basis)
	var lintels := beams.commit(self)
	lintels.name = "Lintels"

	# The Docket: shelves of rolled dockets down both walls, green lamps.
	for z: float in [-6.0, 6.0, 18.0, 30.0]:
		_prop("shelf", Vector3(53.3, -4, z), -half, Vector3(3.4, 3.2, 0.9))
	for z: float in [18.0, 30.0]:
		_prop("shelf", Vector3(36.7, -4, z), half, Vector3(3.4, 3.2, 0.9))
	for l: Array in [[37.6, -8.5], [52.4, -8.5], [37.6, 50.6], [52.4, 39.5]]:
		_prop("lamp", Vector3(float(l[0]), -4.0, float(l[1])), 0.0, Vector3(0.5, 3.4, 0.5))

	# Vow-stones, and what can be read.
	for s: Dictionary in data.stones:
		var at := _v(s.at)
		var toward := _v(s.stand) - at
		_prop("vow_stone", at, atan2(toward.x, toward.z), Vector3(0.9, 1.8, 0.9))
	for r: Dictionary in data.records:
		if r.get("prop", "lectern") == "lectern":
			_prop("lectern", _v(r.at), float(r.get("facing", 0.0)), Vector3(0.7, 1.2, 0.7))
