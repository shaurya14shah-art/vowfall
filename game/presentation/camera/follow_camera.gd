class_name FollowCamera
extends Node3D
## Third-person camera. Orbits the player on the mouse or the right stick;
## when a target is locked it swings to keep the player and the target on
## one line. `yaw` is what the player's movement is relative to: 0 looks
## along +Z, and turning right decreases it.

# Set for the game's own 1.86 m figures. The first capture with them, at 5.8 m
# and looking down, made them small against the yard.
const DISTANCE := 4.8
const HEIGHT := 1.60
const SHOULDER := 0.55      # metres to the camera's right, so the player is not dead centre
const MOUSE_SENS := 0.0028
const STICK_SENS := 2.8
const PITCH_MIN := -0.25
const PITCH_MAX := 1.05
const LOCK_PITCH := 0.30    # a slim figure hides far less of a target than the old one did
const SHAKE_CAP := 0.12

var target: Player
var yaw: float = 0.0
var pitch: float = 0.26
var shake_enabled: bool = true

var _pitch_node: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _shake: float = 0.0
var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
	top_level = true
	# The camera moves every rendered frame, following the player's smoothed
	# position, so the engine must not also interpolate it between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.spring_length = DISTANCE
	_arm.margin = 0.2
	_arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_arm.shape = probe
	_pitch_node.add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.near = 0.1
	_cam.far = 400.0
	_arm.add_child(_cam)
	_cam.make_current()


func camera() -> Camera3D:
	return _cam


func add_shake(amount: float) -> void:
	if shake_enabled:
		_shake = minf(SHAKE_CAP, _shake + amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * MOUSE_SENS
		pitch = clampf(pitch + motion.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * STICK_SENS * delta
	pitch = clampf(pitch + look.y * STICK_SENS * 0.7 * delta, PITCH_MIN, PITCH_MAX)

	var here := target.get_global_transform_interpolated().origin
	var want := here + Vector3.UP * HEIGHT + Vector3(-cos(yaw), 0.0, sin(yaw)) * SHOULDER
	var locked: Actor = target.lock_target
	if locked != null and is_instance_valid(locked):
		var to := locked.get_global_transform_interpolated().origin - here
		to.y = 0.0
		if to.length() > 0.3:
			yaw = lerp_angle(yaw, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
		pitch = lerpf(pitch, LOCK_PITCH, 1.0 - exp(-3.0 * delta))
		# Look a little past the player toward the target so both stay framed.
		want += to.limit_length(6.0) * 0.18
	_focus = _focus.lerp(want, 1.0 - exp(-14.0 * delta))
	global_position = _focus
	rotation = Vector3(0.0, yaw + PI, 0.0)
	_pitch_node.rotation = Vector3(-pitch, 0.0, 0.0)

	if _shake > 0.001:
		_cam.h_offset = randf_range(-_shake, _shake)
		_cam.v_offset = randf_range(-_shake, _shake)
		_shake *= exp(-14.0 * delta)
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


## Place the camera at once, with no easing. Used on spawn.
func snap() -> void:
	if target != null:
		_focus = target.global_position + Vector3.UP * HEIGHT
		global_position = _focus
