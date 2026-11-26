extends Node3D
## Elevated three-quarter camera. Fixed rotation and zoom for MVP; all values configurable.
## Owner-approved default: Perspective, pitch 60°.

@export_range(30.0, 75.0) var pitch_deg := 60.0
@export var distance := 24.0
@export var fov := 32.0
@export var use_orthographic := false
@export var ortho_size := 16.0
@export var follow_smooth := 6.0
@export var look_height := 0.6

var target: Node3D
var cam: Camera3D

func _ready() -> void:
	cam = Camera3D.new()
	add_child(cam)
	apply_config()

func apply_config() -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL if use_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.size = ortho_size
	cam.near = 0.5
	cam.far = 200.0
	cam.current = true
	_update_cam()

func snap() -> void:
	if target:
		global_position = target.global_position
	_update_cam()

func _process(delta: float) -> void:
	if target == null:
		return
	var t := 1.0 - exp(-follow_smooth * delta)
	global_position = global_position.lerp(target.global_position, t)
	_update_cam()

func _update_cam() -> void:
	if cam == null or not is_inside_tree():
		return
	var p := deg_to_rad(pitch_deg)
	var d := 40.0 if use_orthographic else distance
	cam.position = Vector3(0.0, sin(p) * d, cos(p) * d)
	cam.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
