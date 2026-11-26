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

func _process(delta: float) -> void:
	if model:
		CharacterMesh.animate(model, delta, false)
	elif pickup and not hidden and interact_id == "tomato":
		pickup.position.y = 0.64 + sin(Time.get_ticks_msec() / 400.0 + position.x) * 0.03
