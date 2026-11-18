class_name Gate
extends StaticBody3D
## A bronze grille across a way. Closed, it is a wall. Opened, it sinks into
## the floor. Some open only from one side; some are not opened by hand.

const HEIGHT := 5.0
const SPEED := 0.07          # metres per tick: down in a little over a second
const PANEL := 2.0           # width of one grille panel of the model

var gate_id: String = ""
var gate_name: String = "Gate"
var width: float = 6.0
var spans_z: bool = true     # true: the grille runs along Z and bars travel along X
var opens_from: int = 0      # +1 or -1: the side (along the barred axis) it opens from; 0: not by hand
var locked_text: String = "It does not open."
var is_open: bool = false

var _shape: CollisionShape3D
var _visual: Node3D
var _drop: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, HEIGHT, width) if spans_z else Vector3(width, HEIGHT, 0.6)
	_shape.shape = box
	_shape.position.y = HEIGHT * 0.5
	add_child(_shape)
	_visual = Node3D.new()
	add_child(_visual)
	_visual.rotation.y = PI * 0.5 if spans_z else 0.0
	var path := "res://assets/models/world/gate.glb"
	var count := maxi(1, roundi(width / PANEL))
	for i in count:
		var panel: Node3D
		if ResourceLoader.exists(path):
			panel = (load(path) as PackedScene).instantiate()
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(PANEL - 0.1, HEIGHT, 0.2)
			mi.mesh = bm
			mi.position.y = HEIGHT * 0.5
			mi.material_override = Look.stone(Look.STONE_SHADE)
			panel = mi
		panel.position.x += (float(i) - float(count - 1) * 0.5) * PANEL
		_visual.add_child(panel)
	if is_open:
		_drop = HEIGHT
		_apply()


## Which side of the grille a point is on, along the axis it bars.
func side_of(point: Vector3) -> int:
	var d := (point.x - global_position.x) if spans_z else (point.z - global_position.z)
	return 1 if d > 0.0 else -1


## Can someone standing at `point` open it by hand?
func can_open_from(point: Vector3) -> bool:
	return not is_open and opens_from != 0 and side_of(point) == opens_from


func open() -> void:
	is_open = true


func close() -> void:
	is_open = false


func _physics_process(_delta: float) -> void:
	var want := HEIGHT if is_open else 0.0
	if is_equal_approx(_drop, want):
		return
	# It sinks slowly and comes up fast: a bar across a hall is slammed.
	_drop = move_toward(_drop, want, SPEED if is_open else SPEED * 4.0)
	_apply()


func _apply() -> void:
	_visual.position.y = -_drop
	_shape.disabled = _drop > HEIGHT * 0.7
