class_name Massing
extends RefCounted
## Architecture as typography (docs/08): a district's walls, floors, stairs
## and lintels are plain blocks of stone. This builds them, merges every
## block of one material into one mesh, and gives them one static body, so
## a whole quarter costs a handful of draw calls.
##
##   var m := Massing.new()
##   m.material("stone", Look.stone(Look.STONE))
##   m.box("stone", Vector3(0, 6, 18), Vector3(40, 12, 1))
##   m.stair("stone", Vector3(0, 0, 18), Vector3(0, 4, 34), 12.0, 16)
##   m.commit(self)

var boxes: int = 0
var solids: int = 0

var _tools: Dictionary = {}    # material key -> SurfaceTool
var _mats: Dictionary = {}     # material key -> Material
var _order: Array = []
var _shapes: Array = []        # [Transform3D, Vector3 size]


func material(key: String, mat: Material) -> void:
	_mats[key] = mat
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
		_order.append(key)


## A block. `solid` gives it collision; `drawn` gives it a surface.
func box(key: String, centre: Vector3, size: Vector3, solid: bool = true, basis: Basis = Basis.IDENTITY, drawn: bool = true) -> void:
	boxes += 1
	if solid:
		solids += 1
		_shapes.append([Transform3D(basis, centre), size])
	if not drawn:
		return
	var st: SurfaceTool = _tools[key]
	var h := size * 0.5
	var corners: Array = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				corners.append(centre + basis * Vector3(sx * h.x, sy * h.y, sz * h.z))
	# corner index = 4 * (x side) + 2 * (y side) + (z side)
	var faces := [
		[[0, 1, 3, 2], Vector3.LEFT], [[4, 6, 7, 5], Vector3.RIGHT],
		[[0, 4, 5, 1], Vector3.DOWN], [[2, 3, 7, 6], Vector3.UP],
		[[0, 2, 6, 4], Vector3.FORWARD], [[1, 5, 7, 3], Vector3.BACK],
	]
	for f: Array in faces:
		var idx: Array = f[0]
		_quad(st, corners[idx[0]], corners[idx[1]], corners[idx[2]], corners[idx[3]], basis * (f[1] as Vector3))


## A sloping slab whose top surface runs from `from` to `to` (points on its
## centre line). What a body walks on where the ground changes height.
func ramp(key: String, from: Vector3, to: Vector3, width: float, thickness: float = 1.0, solid: bool = true, drawn: bool = true) -> void:
	var along := (to - from)
	var z := along.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x).normalized()
	var basis := Basis(x, y, z)
	box(key, (from + to) * 0.5 - y * thickness * 0.5, Vector3(width, thickness, along.length()), solid, basis, drawn)


## A flight of steps from `from` up to `to`: the steps are what is seen, a
## hidden ramp is what is walked on.
func stair(key: String, from: Vector3, to: Vector3, width: float, count: int) -> void:
	ramp(key, from, to, width, 1.0, true, false)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var run := flat.length() / float(count)
	var rise := (to.y - from.y) / float(count)
	var dir := flat.normalized()
	var basis := Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP, dir)
	for i in count:
		var top := from.y + rise * (float(i) + 0.5)
		var height := absf(rise) * 2.0 + 0.6
		var centre := from + dir * run * (float(i) + 0.5)
		centre.y = top - height * 0.5
		box(key, centre, Vector3(width, height, run), false, basis)


## Turn everything added so far into nodes under `parent`.
func commit(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Massing"
	body.collision_layer = 1
	body.collision_mask = 0
	for s: Array in _shapes:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = s[1]
		shape.shape = b
		shape.transform = s[0]
		body.add_child(shape)
	var mesh := ArrayMesh.new()
	var used: Array = []
	for key: String in _order:
		var st: SurfaceTool = _tools[key]
		var arrays := st.commit_to_arrays()
		if arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		used.append(key)
	var inst := MeshInstance3D.new()
	inst.name = "Stone"
	inst.mesh = mesh
	for i in used.size():
		inst.set_surface_override_material(i, _mats[used[i]])
	body.add_child(inst)
	parent.add_child(body)
	return body


## Godot's front faces wind clockwise. Rather than trust six hand-written
## orders, each quad is checked against the way it is meant to face.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = d
		d = t
	st.set_normal(normal)
	for p: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(p)
