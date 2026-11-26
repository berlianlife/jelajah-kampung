extends StaticBody3D
## Anything the player can talk to or use. NPCs get a faceless model.

var interact_id := ""
var display_name := ""
var prompt_label := ""
var is_npc := true
var look: Dictionary = {}
var model: Node3D
var radius := 0.4

func setup(id: String, name_: String, prompt: String, npc: bool, look_: Dictionary = {}) -> void:
	interact_id = id
	display_name = name_
	prompt_label = prompt
	is_npc = npc
	look = look_

func _ready() -> void:
	add_to_group("interactable")
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

func face(p: Vector3) -> void:
	if model:
		model.rotation.y = atan2(p.x - global_position.x, p.z - global_position.z)
		model.set_meta("wave", 1.2)

func _process(delta: float) -> void:
	if model:
		CharacterMesh.animate(model, delta, false)
