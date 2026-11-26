extends Node3D
## Bootstraps the Phase 1 vertical slice: world, player, camera, NPCs, data-driven quest.

const QUEST_ID := "q.help_neighbor"
const DIALOGUE_PATH := "res://data/dialogues/help_neighbor.json"
const INTERACT_RANGE := 2.1

const PlayerScript := preload("res://scripts/player/player.gd")
const CameraRigScript := preload("res://scripts/camera/camera_rig.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const InteractableScript := preload("res://scripts/world/interactable.gd")

var player
var rig
var hud
var dialogue: Dictionary = {}
var interactables: Array = []
var near = null
var rantang: Node3D
var save_timer := 0.0

func _ready() -> void:
	_setup_environment()
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	WorldBuilder.build_kampung(world)

	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	var p: Dictionary = GameData.state["player"]
	player.position = Vector3(float(p.get("x", -10.0)), 0.0, float(p.get("z", 1.0)))

	rig = CameraRigScript.new()
	add_child(rig)
	rig.target = player
	rig.snap()

	hud = HudScript.new()
	add_child(hud)
	hud.action_pressed.connect(_on_action)
	hud.joystick_changed.connect(func(v: Vector2): player.joystick_vector = v)

	dialogue = _load_json(DIALOGUE_PATH)
	_spawn_interactables(world)
	_refresh_quest_ui()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff6dc")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

func _spawn_interactables(world: Node3D) -> void:
	for n in dialogue.get("npcs_spawn", []):
		var it = InteractableScript.new()
		it.setup(n["id"], n["name"], n["prompt"], true, n.get("look", {}))
		it.position = Vector3(float(n["x"]), 0.0, float(n["z"]))
		world.add_child(it)
		interactables.append(it)
	# Table with rantang (quest item)
	var table = InteractableScript.new()
	table.setup("table", "Meja", "Ambil rantang", false)
	table.radius = 0.6
	table.position = Vector3(-12.3, 0, 12)
	world.add_child(table)
	WorldBuilder.box(table, Vector3(1.2, 0.08, 0.8), Vector3(0, 0.8, 0), "a8743f")
	rantang = Node3D.new()
	rantang.position = Vector3(0, 0.84, 0)
	table.add_child(rantang)
	for i in 3:
		WorldBuilder.mesh_at(rantang, WorldBuilder.cyl_mesh(0.22, 0.22, 0.16), "2fa36b" if i == 1 else "e8eef0", Vector3(0, 0.08 + i * 0.17, 0))
	rantang.visible = GameData.quest(QUEST_ID) < 2
	interactables.append(table)

func _process(delta: float) -> void:
	player.input_locked = hud.dialog_open()
	WorldBuilder.update_fades(player.global_position, delta)
	near = null if hud.dialog_open() else _find_near()
	hud.set_prompt(_prompt_for(near))
	save_timer += delta
	if save_timer > 2.0:
		save_timer = 0.0
		GameData.state["player"] = {"x": snappedf(player.position.x, 0.01), "z": snappedf(player.position.z, 0.01)}
		GameData.save()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("interact"):
		_on_action()

func _on_action() -> void:
	if hud.dialog_open():
		hud.advance()
	elif near != null:
		_interact(near)

func _find_near():
	var best = null
	var best_d := INTERACT_RANGE
	for it in interactables:
		if _node_for(it) == null:
			continue
		var d: float = Vector2(it.global_position.x - player.global_position.x, it.global_position.z - player.global_position.z).length()
		if d < best_d:
			best_d = d
			best = it
	return best

func _prompt_for(it) -> String:
	if it == null:
		return ""
	return it.prompt_label

func _node_for(it):
	var group: Dictionary = dialogue.get("npcs" if it.is_npc else "items", {})
	var entry: Dictionary = group.get(it.interact_id, {})
	var q := str(GameData.quest(QUEST_ID))
	if entry.has(q):
		return entry[q]
	return entry.get("default", null)

func _interact(it) -> void:
	var node = _node_for(it)
	if node == null:
		return
	if it.is_npc:
		it.face(player.global_position)
		player.face_towards(it.global_position)
	_run_node(node)

func _run_node(node: Dictionary) -> void:
	var lines: Array = node.get("lines", [])
	var choices: Array = node.get("choices", [])
	if lines.is_empty():
		_apply(node)
		return
	hud.show_dialog(lines, choices, func(choice_idx: int):
		if choice_idx >= 0:
			var c: Dictionary = choices[choice_idx]
			_apply(c)
			if c.has("reply"):
				_run_node({"lines": c["reply"]})
		else:
			_apply(node)
	)

func _apply(fx: Dictionary) -> void:
	var changed := false
	if fx.has("set_state"):
		GameData.set_quest(QUEST_ID, int(fx["set_state"]))
		changed = true
	if fx.has("give_item"):
		GameData.add_item(str(fx["give_item"]))
		if fx["give_item"] == "rantang":
			rantang.visible = false
		changed = true
	if fx.has("remove_item"):
		GameData.remove_item(str(fx["remove_item"]))
		changed = true
	if fx.has("add_sticker"):
		GameData.state["stickers"] = int(GameData.state["stickers"]) + int(fx["add_sticker"])
		changed = true
	if fx.has("learn") and not GameData.state["learned"].has(fx["learn"]):
		GameData.state["learned"].append(fx["learn"])
		changed = true
	if fx.has("toast"):
		hud.toast(str(fx["toast"]))
	if changed:
		GameData.save()
		_refresh_quest_ui()

func _refresh_quest_ui() -> void:
	hud.set_quest(str(dialogue.get("title", "")), dialogue.get("steps", []), GameData.quest(QUEST_ID))

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
