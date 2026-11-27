extends StaticBody3D
## Anything the player can talk to or use. NPCs get a faceless model; items get a "pickup" visual.

var interact_id := ""
var instance_key := ""
var display_name := ""
var prompt_label := ""
var is_npc := true
var solid := true
var look: Dictionary = {}
var model: Node3D
var pickup: Node3D
var radius := 0.4
var hidden := false
var portal_to: Variant = null
var lines: Array = []
## Optional wandering inside [x0, z0, x1, z1] (kids at the playground).
var wander: Array = []
var wander_target := Vector3.ZERO
var wander_wait := 0.0
var talk_timer := 0.0
var hide_until_available := false

func setup(id: String, name_: String, prompt: String, npc: bool, look_: Dictionary = {}) -> void:
	interact_id = id
	instance_key = id
	display_name = name_
	prompt_label = prompt
	is_npc = npc
	look = look_

func _ready() -> void:
	add_to_group("interactable")
	if solid:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = 1.8
		cs.shape = sh
		cs.position.y = 0.9
		add_child(cs)
	if is_npc:
		model = CharacterMesh.build(look)
		add_child(model)

## Hide the pickup visual (rantang taken, tomato picked) and stop offering the interaction.
func set_hidden(v: bool) -> void:
	hidden = v
	if pickup:
		pickup.visible = not v

func face(p: Vector3) -> void:
	if model:
		model.rotation.y = atan2(p.x - global_position.x, p.z - global_position.z)
		model.set_meta("wave", 1.2)
	talk_timer = 4.0

func _process(delta: float) -> void:
	if model:
		var moving := false
		if talk_timer > 0.0:
			talk_timer -= delta
		elif not wander.is_empty():
			moving = _wander_step(delta)
		CharacterMesh.animate(model, delta, moving)
	elif pickup and not hidden and interact_id == "tomato":
		pickup.position.y = 0.64 + sin(Time.get_ticks_msec() / 400.0 + position.x) * 0.03

func _wander_step(delta: float) -> bool:
	if wander_wait > 0.0:
		wander_wait -= delta
		return false
	if wander_target == Vector3.ZERO:
		wander_target = position
	var to := wander_target - position
	to.y = 0.0
	if to.length() < 0.2:
		wander_target = Vector3(randf_range(wander[0], wander[2]), 0.0, randf_range(wander[1], wander[3]))
		wander_wait = randf_range(0.4, 1.6)
		return false
	var step := to.normalized() * 2.2 * delta
	position += step if step.length() < to.length() else to
	model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 0.2)
	return true
