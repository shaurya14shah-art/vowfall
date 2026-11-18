class_name CharacterModel
extends Node3D
## A VOWFALL figure and its animation player. The figures are modelled from
## scratch (tools/blender/); they stand on a re-proportioned rig that keeps a
## CC0 pack's motion clips. Faces +Z at rotation 0.
## Pure presentation: nothing here decides anything.

const LOOPS := ["Idle", "Running_A", "Walking_A", "Walking_Backwards", "Running_Strafe_Left",
	"Running_Strafe_Right", "Blocking", "2H_Melee_Idle", "Unarmed_Idle", "Sit_Floor_Idle"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _current: String = ""
var _paused: bool = false
var _speed: float = 1.0


## right, left: scenes to put in the hands (a blade, a shield, a ledger).
func setup(scene_path: String, right: String = "", left: String = "", body_scale: float = 1.0) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("CharacterModel: cannot load " + scene_path)
		return
	var root := packed.instantiate()
	add_child(root)
	scale = Vector3.ONE * body_scale
	anim = root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hold("handslot.r", right)
	_hold("handslot.l", left)
	for clip: String in LOOPS:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.playback_default_blend_time = 0.12
	play("Idle")


## Change what is in the hands (another Instrument, or its awakened form).
func set_held(right: String, left: String) -> void:
	if skeleton == null:
		return
	for slot_name: String in ["handslot_r", "handslot_l"]:
		var old := skeleton.get_node_or_null(slot_name)
		if old != null:
			skeleton.remove_child(old)
			old.queue_free()
	_hold("handslot.r", right)
	_hold("handslot.l", left)


func _hold(bone: String, scene_path: String) -> void:
	if scene_path == "" or skeleton.find_bone(bone) < 0:
		return
	var item := load(scene_path) as PackedScene
	if item == null:
		push_error("CharacterModel: cannot load " + scene_path)
		return
	var slot := BoneAttachment3D.new()
	slot.name = bone.replace(".", "_")
	skeleton.add_child(slot)
	slot.bone_name = bone
	slot.add_child(item.instantiate())


func play(clip: String, blend: float = 0.12, speed: float = 1.0, restart: bool = false) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if clip == _current and not restart:
		_speed = speed
		if not _paused:
			anim.speed_scale = speed
		return
	_current = clip
	_speed = speed
	anim.play(clip, blend, 1.0)
	if restart:
		anim.seek(0.0, false)
	anim.speed_scale = 0.0 if _paused else speed


## Hit-stop: freeze the pose without losing the place in the clip.
func set_paused(paused: bool) -> void:
	if anim == null or paused == _paused:
		return
	_paused = paused
	anim.speed_scale = 0.0 if paused else _speed


func current() -> String:
	return _current


func set_tint(colour: Color, amount: float) -> void:
	if skeleton == null:
		return
	for child: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if amount <= 0.0:
			mesh.material_overlay = null
		else:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(colour.r, colour.g, colour.b, amount)
			mesh.material_overlay = mat
