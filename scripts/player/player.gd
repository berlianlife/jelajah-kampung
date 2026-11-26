extends CharacterBody3D
## Player: 8-direction movement, collision, faceless model.

@export var speed := 4.6
@export var snap_8_dir := true

var model: Node3D
var input_locked := false
var joystick_vector := Vector2.ZERO

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	add_child(col)
	model = CharacterMesh.build({"robe": "22A061", "pants": "efe6d4", "cap": "ffffff", "bag": true})
	model.scale = Vector3.ONE * 0.9
	add_child(model)

func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if not input_locked:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if joystick_vector.length() > 0.25:
			v = joystick_vector
	if v.length() > 0.1:
		var a := atan2(v.y, v.x)
		if snap_8_dir:
			a = roundf(a / (PI / 4.0)) * (PI / 4.0)
		v = Vector2(cos(a), sin(a))
	else:
		v = Vector2.ZERO

	velocity = Vector3(v.x * speed, 0.0, v.y * speed)
	move_and_slide()
	position.y = 0.0

	var moving := v != Vector2.ZERO
	if moving:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(v.x, v.y), 0.25)
	CharacterMesh.animate(model, delta, moving)

func face_towards(p: Vector3) -> void:
	model.rotation.y = atan2(p.x - global_position.x, p.z - global_position.z)
