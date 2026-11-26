extends Node3D
## Bootstraps the vertical slice: world, player, camera, NPCs, data-driven quests, settings, audio.

const QUEST_FILES := [
	"res://data/quests/01_help_neighbor.json",
	"res://data/quests/02_harvest_tomato.json",
]
const NPC_FILE := "res://data/world/npcs.json"
const INTERACT_RANGE := 2.1

const PlayerScript := preload("res://scripts/player/player.gd")
const CameraRigScript := preload("res://scripts/camera/camera_rig.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const InteractableScript := preload("res://scripts/world/interactable.gd")

var player
var rig
var hud
var engine: QuestEngine
var npc_data: Dictionary = {}
var interactables: Array = []
var near = null
var rantang: Node3D
var save_timer := 0.0
var step_timer := 0.0

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

	hud = HudScript.new()
	add_child(hud)
	hud.action_pressed.connect(_on_action)
	hud.joystick_changed.connect(func(v: Vector2): player.joystick_vector = v)
	hud.settings_changed.connect(_on_settings_changed)
	hud.reset_requested.connect(_on_reset)

	engine = QuestEngine.new()
	engine.load_files(QUEST_FILES)
	engine.changed.connect(_refresh_ui)
	engine.toast_requested.connect(hud.toast)
	engine.learned.connect(hud.show_learn)
	engine.hide_requested.connect(_hide_instance)
	engine.sfx_requested.connect(AudioManager.play)

	npc_data = _load_json(NPC_FILE)
	_spawn_interactables(world)

	hud.load_settings(GameData.state["settings"])
	_apply_settings(GameData.state["settings"])
	rig.snap()
	_refresh_ui()

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

# ---------- spawning ----------
func _spawn_interactables(world: Node3D) -> void:
	for n in npc_data.get("npcs", []):
		var it = InteractableScript.new()
		it.setup(n["id"], n["name"], n["prompt"], true, n.get("look", {}))
		it.position = Vector3(float(n["x"]), 0.0, float(n["z"]))
		world.add_child(it)
		interactables.append(it)

	# Table with rantang (quest item for q.help_neighbor)
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
	table.pickup = rantang
	interactables.append(table)

	# Items declared by quest files (e.g. tomatoes)
	for q in engine.quests:
		for s in q.get("spawn_items", []):
			var item = InteractableScript.new()
			item.setup(s["id"], "Tomat", "Petik tomat", false)
			item.instance_key = s["key"]
			item.solid = false
			item.position = Vector3(float(s["x"]), 0, float(s["z"]))
			world.add_child(item)
			var tomato := SphereMesh.new()
			tomato.radius = 0.15
			tomato.height = 0.3
			tomato.radial_segments = 8
			tomato.rings = 4
			item.pickup = WorldBuilder.mesh_at(item, tomato, "e2463a", Vector3(0, 0.64, 0))
			interactables.append(item)

	for it in interactables:
		if GameData.state["hidden"].has(it.instance_key):
			it.set_hidden(true)

func _hide_instance(key: String) -> void:
	for it in interactables:
		if it.instance_key == key:
			it.set_hidden(true)

# ---------- loop ----------
func _process(delta: float) -> void:
	var blocked: bool = hud.is_blocking()
	player.input_locked = blocked
	WorldBuilder.update_fades(player.global_position, delta)
	near = null if blocked else _find_near()
	hud.set_prompt(near.prompt_label if near != null else "")
	if player.is_moving:
		step_timer -= delta
		if step_timer <= 0.0:
			AudioManager.play("step")
			step_timer = 0.32
	save_timer += delta
	if save_timer > 2.0:
		save_timer = 0.0
		GameData.state["player"] = {"x": snappedf(player.position.x, 0.01), "z": snappedf(player.position.z, 0.01)}
		GameData.save()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("interact"):
		_on_action()

func _on_action() -> void:
	if hud.learn_open():
		hud.close_learn()
	elif hud.dialog_open():
		hud.advance()
	elif near != null and not hud.is_blocking():
		_interact(near)

func _has_action(it) -> bool:
	if it.hidden:
		return false
	if it.is_npc:
		return true
	return not engine.resolve(it.interact_id, "items").is_empty()

func _find_near():
	var best = null
	var best_d := INTERACT_RANGE
	for it in interactables:
		var d: float = Vector2(it.global_position.x - player.global_position.x, it.global_position.z - player.global_position.z).length()
		if d < best_d and _has_action(it):
			best_d = d
			best = it
	return best

func _idle_lines(id: String) -> Array:
	for n in npc_data.get("npcs", []):
		if n["id"] == id:
			return n.get("idle", [])
	return []

func _interact(it) -> void:
	if it.is_npc:
		it.face(player.global_position)
		player.face_towards(it.global_position)
	var r := engine.resolve(it.interact_id, "npcs" if it.is_npc else "items")
	if r.is_empty():
		var idle := _idle_lines(it.interact_id)
		if not idle.is_empty():
			AudioManager.play("open")
			hud.show_dialog(idle, [], Callable())
		return
	_run_node(r["node"], r["quest"], it.instance_key)

func _format_lines(lines: Array, q: Dictionary) -> Array:
	var out: Array = []
	for l in lines:
		out.append({"who": l.get("who", ""), "text": engine.fmt(str(l.get("text", "")), q)})
	return out

func _run_node(node: Dictionary, q: Dictionary, key: String) -> void:
	var lines: Array = node.get("lines", [])
	var choices: Array = node.get("choices", [])
	if lines.is_empty():
		engine.apply(node, q, key)
		return
	AudioManager.play("open")
	hud.show_dialog(_format_lines(lines, q), choices, func(choice_idx: int):
		if choice_idx >= 0:
			var c: Dictionary = choices[choice_idx]
			engine.apply(c, q, key)
			if c.has("reply"):
				_run_node({"lines": c["reply"]}, q, key)
		else:
			engine.apply(node, q, key)
	)

# ---------- settings / UI ----------
func _apply_settings(s: Dictionary) -> void:
	rig.use_orthographic = bool(s.get("ortho", false))
	rig.pitch_deg = float(s.get("pitch", 60.0))
	rig.distance = float(s.get("distance", 24.0))
	rig.ortho_size = float(s.get("distance", 24.0)) * 0.66
	rig.apply_config()
	AudioManager.set_volume("Voice", float(s.get("vol_voice", 1.0)))
	AudioManager.set_volume("Ambience", float(s.get("vol_amb", 0.4)))
	AudioManager.set_volume("SFX", float(s.get("vol_sfx", 0.7)))

func _on_settings_changed(s: Dictionary) -> void:
	GameData.state["settings"] = s
	GameData.save()
	_apply_settings(s)

func _on_reset() -> void:
	GameData.reset()
	get_tree().reload_current_scene()

func _refresh_ui() -> void:
	hud.set_quests(engine.panel_data())
	hud.set_stickers(int(GameData.state["stickers"]))

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
