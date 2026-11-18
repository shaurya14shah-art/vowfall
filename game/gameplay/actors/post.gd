class_name Post
extends Actor
## A training post. It does not move or strike. A plain post is something to
## hit. A sealed post keeps laws standing, so that the first rules a player
## meets are met on something that cannot hurt them back, except by sanction.

const RESTORE_AFTER := 180
const CHECK_EVERY := 30

var standing_laws: Array = []      # law ids this post keeps imposed
var sealed: bool = false
var _mesh_root: Node3D
var _wobble: float = 0.0
var _wobble_dir: Vector3 = Vector3.ZERO
var _idle: int = 0


func _init() -> void:
	display_name = "Practice post"
	team = 2
	max_hp = 300
	max_poise = 0
	immovable = true
	hurt_radius = 0.4
	tags = ["construct"]
	start_resonance = 100
	collision_layer = 2
	collision_mask = 0


func _build_model() -> void:
	# The stele is modelled in tools/blender/props.py. Its face looks along
	# +Z: strikes from the other side are "from behind".
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var path := "res://assets/models/props/post_sealed.glb" if sealed else "res://assets/models/props/post_plain.glb"
	var scene := load(path) as PackedScene
	if scene != null:
		_mesh_root.add_child(scene.instantiate())
	if sealed:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.52
		torus.outer_radius = 1.56
		torus.rings = 48
		ring.mesh = torus
		ring.position.y = 0.02
		ring.material_override = Look.flat(Look.VERMILION)
		add_child(ring)
	_mesh_root.rotation.y = facing


func _physics_process(_delta: float) -> void:
	if bridge == null:
		return
	machine.tick(false, false, false, false)
	_idle += 1
	if _idle >= RESTORE_AFTER and hp() < max_hp:
		bridge.world.restore(entity_id)
	if sealed and bridge.tick % CHECK_EVERY == 1:
		for def_id: String in standing_laws:
			if bridge.world.find_law(entity_id, def_id).is_empty():
				bridge.grant(self, 100)
				bridge.impose(self, def_id)
	if _wobble > 0.001:
		_wobble *= 0.86
		_mesh_root.rotation.x = _wobble_dir.z * _wobble
		_mesh_root.rotation.z = -_wobble_dir.x * _wobble


func on_hit(from: Actor, m: Dictionary) -> void:
	_idle = 0
	var away := global_position - from.global_position
	away.y = 0.0
	_wobble_dir = away.normalized()
	_wobble = 0.10 if int(m.get("poise", 10)) < 25 else 0.18


func on_death() -> void:
	# A post is never out of the fight: it is put back together.
	bridge.world.restore(entity_id)
	_idle = 0
