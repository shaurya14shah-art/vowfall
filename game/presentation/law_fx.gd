class_name LawFx
extends Node3D
## Shows the laws that are standing. Placeholder effects, but they obey the
## rule in docs/08_art_direction.md: a law is drawn, with edges, and never a
## glow. Gold is the player's law, vermilion an enemy's.
##
##   line law      a ruled line on the floor between two end-marks, with a
##                 faint sheet above it so it reads as a boundary
##   ring law      the same line closed into a circle
##   pair law      a taut thread between the two that are bound
##   self law      a ruled circle at its author's feet
##   a loan        counting-beads above the one who owes
##   a debt        vermilion beads above the one who must pay
##
## It reads the Law Engine every frame and decides nothing.

const SILVER := Color(0.80, 0.83, 0.88)
const BEAD_VALUE := 5

var bridge: CombatBridge
var player: Player
var _nodes: Dictionary = {}     # key -> Node3D
var _bead_counts: Dictionary = {}


func visual_count() -> int:
	return _nodes.size()


func _process(_delta: float) -> void:
	if bridge == null:
		return
	var seen: Dictionary = {}
	for law: Dictionary in bridge.world.laws:
		if not law.active or not bridge.actors.has(law.owner):
			continue
		var def := bridge.registry.resolve(law.def_id, law.form)
		var shape: String = def.scope.shape
		if shape == "FIELD":
			continue
		var key := "law%d" % law.id
		seen[key] = true
		var owner: Actor = bridge.actors[law.owner]
		var colour := Look.GOLD if owner.team == player.team else Look.VERMILION
		if not _nodes.has(key):
			_nodes[key] = _make(shape, law, def, colour)
		_follow(_nodes[key], shape, law, owner)
	_beads(seen)
	_preview(seen)
	for key: String in _nodes.keys():
		if not seen.has(key):
			_nodes[key].queue_free()
			_nodes.erase(key)
			_bead_counts.erase(key)


# -------------------------------------------------------------------- laws

func _make(shape: String, law: Dictionary, def: Dictionary, colour: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	if shape == "LINE":
		var l: Array = law.args.line
		var a := Vector3(l[0] / 100.0, 0.0, l[1] / 100.0)
		var b := Vector3(l[2] / 100.0, 0.0, l[3] / 100.0)
		# A Divide cuts both ways: it is drawn in ink, with its author's marks.
		_line(root, a, b, Look.INK if def.operation == "DIVIDE" else colour, colour, 1.0)
	elif shape == "RING":
		var c: Array = law.args.centre
		var r: float = float(def.scope.radius) / 100.0
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.035
		torus.outer_radius = r + 0.035
		torus.rings = 72
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = Look.flat(Look.INK)
		ring.position = Vector3(c[0] / 100.0, 0.04, c[1] / 100.0)
		root.add_child(ring)
		for i in 12:
			var ang := TAU * i / 12.0
			root.add_child(_post(ring.position + Vector3(sin(ang) * r, 0.0, cos(ang) * r), colour))
	elif shape == "PAIR":
		var thread := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.03, 0.03)
		thread.mesh = box
		thread.material_override = Look.flat(SILVER if colour == Look.GOLD else colour)
		thread.name = "thread"
		root.add_child(thread)
		for n: String in ["mark_a", "mark_b"]:
			var mark := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(0.16, 0.16, 0.16)
			mark.mesh = cube
			mark.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
			mark.material_override = Look.flat(SILVER if colour == Look.GOLD else colour)
			mark.name = n
			root.add_child(mark)
	else:   # SELF, TARGET
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.62
		torus.outer_radius = 0.67
		torus.rings = 40
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = Look.flat(colour)
		ring.position.y = 0.04
		root.add_child(ring)
		if colour == Look.VERMILION:
			# An enemy's writ is worn where it can be read: a seal over the head.
			var seal := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.17
			disc.bottom_radius = 0.17
			disc.height = 0.04
			seal.mesh = disc
			seal.rotation.x = PI * 0.5
			seal.position.y = 2.45
			seal.material_override = Look.flat(colour)
			root.add_child(seal)
	return root


func _follow(node: Node3D, shape: String, law: Dictionary, owner: Actor) -> void:
	if shape == "PAIR":
		var pair: Array = law.args.pair
		if not bridge.actors.has(pair[0]) or not bridge.actors.has(pair[1]):
			return
		var a: Vector3 = bridge.actors[pair[0]].get_global_transform_interpolated().origin + Vector3.UP * 1.25
		var b: Vector3 = bridge.actors[pair[1]].get_global_transform_interpolated().origin + Vector3.UP * 1.25
		var thread: MeshInstance3D = node.get_node("thread")
		var d := b - a
		thread.position = (a + b) * 0.5
		thread.rotation = Vector3(0.0, atan2(-d.z, d.x), 0.0)
		thread.scale = Vector3(maxf(d.length(), 0.01), 1.0, 1.0)
		(node.get_node("mark_a") as Node3D).position = a + Vector3.UP * 0.95
		(node.get_node("mark_b") as Node3D).position = b + Vector3.UP * 0.95
	elif shape == "SELF" or shape == "TARGET":
		node.position = owner.get_global_transform_interpolated().origin


func _line(root: Node3D, a: Vector3, b: Vector3, colour: Color, marks: Color, alpha: float) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.01)
	var yaw := atan2(-d.z, d.x)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.035, 0.07)
	bar.mesh = box
	bar.position = (a + b) * 0.5 + Vector3.UP * 0.035
	bar.rotation.y = yaw
	bar.material_override = _flat(colour, alpha)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	var sheet := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(length, 1.7, 0.012)
	sheet.mesh = plane
	sheet.position = (a + b) * 0.5 + Vector3.UP * 0.87
	sheet.rotation.y = yaw
	sheet.material_override = _flat(colour, 0.13 * alpha)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sheet)
	var top := MeshInstance3D.new()
	var rule := BoxMesh.new()
	rule.size = Vector3(length, 0.018, 0.018)
	top.mesh = rule
	top.position = (a + b) * 0.5 + Vector3.UP * 1.72
	top.rotation.y = yaw
	top.material_override = _flat(colour, 0.8 * alpha)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(top)
	root.add_child(_post(a, marks, alpha))
	root.add_child(_post(b, marks, alpha))


func _post(at: Vector3, colour: Color, alpha: float = 1.0) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.07
	cyl.height = 0.5
	cyl.radial_segments = 10
	post.mesh = cyl
	post.position = Vector3(at.x, 0.25, at.z)
	post.material_override = _flat(colour, alpha)
	return post


static func _flat(colour: Color, alpha: float) -> StandardMaterial3D:
	var m := Look.flat(Color(colour.r, colour.g, colour.b, alpha))
	if alpha < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ------------------------------------------------------------------- beads

func _beads(seen: Dictionary) -> void:
	var loans: Dictionary = {}    # debtor id -> amount (not yet due: a Creditor's ledger)
	var debts: Dictionary = {}    # debtor id -> amount (coming due: a Debtor's own)
	for h: Dictionary in bridge.world.held:
		if h.release == "INVOKE":
			loans[h.target] = loans.get(h.target, 0) + h.amount
		else:
			debts[h.target] = debts.get(h.target, 0) + h.amount
	for id: int in loans:
		_bead_row("loan%d" % id, id, loans[id], Look.GOLD, 2.30, seen)
	for id: int in debts:
		_bead_row("debt%d" % id, id, debts[id], Look.VERMILION, 2.10, seen)


func _bead_row(key: String, id: int, amount: int, colour: Color, height: float, seen: Dictionary) -> void:
	if not bridge.actors.has(id):
		return
	seen[key] = true
	var count := clampi((amount + BEAD_VALUE - 1) / BEAD_VALUE, 1, 14)
	if _bead_counts.get(key, -1) != count:
		if _nodes.has(key):
			_nodes[key].queue_free()
		var root := Node3D.new()
		add_child(root)
		for i in count:
			var bead := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.055
			sphere.height = 0.11
			sphere.radial_segments = 10
			sphere.rings = 5
			bead.mesh = sphere
			bead.material_override = Look.flat(colour)
			bead.position = Vector3((float(i) - float(count - 1) * 0.5) * 0.13, 0.0, 0.0)
			root.add_child(bead)
		_nodes[key] = root
		_bead_counts[key] = count
	var node: Node3D = _nodes[key]
	node.position = bridge.actors[id].get_global_transform_interpolated().origin + Vector3.UP * height
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		node.rotation.y = cam.global_rotation.y   # the row faces the camera


# ----------------------------------------------------------------- preview

func _preview(seen: Dictionary) -> void:
	if player == null or not player.imposing:
		return
	var def := bridge.registry.resolve(player.law_id, bridge.form(player))
	if def.scope.shape != "LINE":
		return
	# Rebuilt each frame while drawing: it is one short-lived thing.
	if _nodes.has("preview"):
		_nodes["preview"].queue_free()
	var root := Node3D.new()
	add_child(root)
	var ends := player.line_preview()
	_line(root, ends[0], ends[1], Look.GOLD, Look.GOLD, 0.45)
	_nodes["preview"] = root
	seen["preview"] = true
