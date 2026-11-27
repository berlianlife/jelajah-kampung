extends Node3D
## Bootstraps the vertical slice: world, player, camera, NPCs, data-driven quests, settings, audio.

const QUEST_FILES := [
	"res://data/quests/01_help_neighbor.json",
	"res://data/quests/02_harvest_tomato.json",
	"res://data/quests/03_learn_wudhu.json",
	"res://data/quests/04_lost_wallet.json",
]
const NPC_FILE := "res://data/world/npcs.json"
const ITEM_FILE := "res://data/world/items.json"
const PLACES_FILE := "res://data/world/places.json"
const VILLAGE_LIMIT := 40.0
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
var item_data: Dictionary = {}
var places: Dictionary = {}
var marker: MeshInstance3D
var place_name := "Kampung Muslim"
var env: Environment
var sun: DirectionalLight3D
var safari := false
var ball: MeshInstance3D
var kids: Array = []

## Day cycle keyframes: hour -> lighting. 1 real second = 1 game minute when running.
const DAY_KEYS := [
	[0.0, 0.12, "9fb4ff", 0.15, "7080b0", "141f3a"],
	[5.0, 0.15, "ffb27a", 0.16, "8090c0", "2b3a66"],
	[7.0, 0.50, "fff0d6", 0.22, "d9ecff", "9fd3ff"],
	[12.0, 0.55, "ffffff", 0.24, "e6f2ff", "8ec9ff"],
	[16.0, 0.47, "ffe6c0", 0.22, "f3ecdf", "a8cdef"],
	[18.0, 0.30, "ffc8a0", 0.19, "eadbc8", "e9b48a"],
	[19.5, 0.12, "9fb4ff", 0.15, "7080b0", "1b2a4a"],
	[24.0, 0.12, "9fb4ff", 0.15, "7080b0", "141f3a"],
]
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
	item_data = _load_json(ITEM_FILE).get("items", {})
	places = _load_json(PLACES_FILE)
	hud.journal_opened.connect(_refresh_ui)
	_spawn_interactables(world)

	hud.minimap.shapes = WorldBuilder.map_shapes
	hud.load_settings(GameData.state["settings"])
	_apply_settings(GameData.state["settings"])
	rig.snap()
	_refresh_ui()

func _setup_environment() -> void:
	safari = _is_safari()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9ecff")
	env.ambient_light_energy = 0.3 if safari else 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 0.5
	# Safari's WebGL is the weak spot for shadow maps; skip them there.
	sun.shadow_enabled = not safari
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	if safari:
		print("Jelajah-Kampung: Safari detected, shadows off")

func _is_safari() -> bool:
	if not OS.has_feature("web"):
		return false
	var ua := str(JavaScriptBridge.eval("navigator.userAgent", true))
	return ua.contains("Safari") and not ua.contains("Chrome") and not ua.contains("Chromium") and not ua.contains("Android")

# ---------- spawning ----------
func _spawn_interactables(world: Node3D) -> void:
	for n in npc_data.get("npcs", []):
		var it = InteractableScript.new()
		it.setup(n["id"], n["name"], n["prompt"], true, n.get("look", {}))
		it.position = Vector3(float(n["x"]), 0.0, float(n["z"]))
		it.wander = n.get("wander", [])
		world.add_child(it)
		interactables.append(it)
		if not it.wander.is_empty():
			kids.append(it)
	# Playground ball, passed between the kids
	var bm := SphereMesh.new()
	bm.radius = 0.2
	bm.height = 0.4
	bm.radial_segments = 8
	bm.rings = 4
	ball = WorldBuilder.mesh_at(world, bm, "ffffff", Vector3(3, 0.2, 15))

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
			item.setup(s["id"], s.get("name", "Tomat"), s.get("prompt", "Petik tomat"), false)
			item.instance_key = s["key"]
			item.solid = false
			item.hide_until_available = s.get("hide_until_available", false)
			item.position = Vector3(float(s["x"]), 0, float(s["z"]))
			world.add_child(item)
			if s.get("model", "tomato") == "wallet":
				var wb := BoxMesh.new()
				wb.size = Vector3(0.36, 0.08, 0.26)
				item.pickup = WorldBuilder.mesh_at(item, wb, "8a5a30", Vector3(0, 0.06, 0))
				WorldBuilder.box(item.pickup, Vector3(0.38, 0.03, 0.06), Vector3(0, 0.03, 0.04), "F6B73C")
			else:
				var tomato := SphereMesh.new()
				tomato.radius = 0.15
				tomato.height = 0.3
				tomato.radial_segments = 8
				tomato.rings = 4
				item.pickup = WorldBuilder.mesh_at(item, tomato, "e2463a", Vector3(0, 0.64, 0))
			interactables.append(item)

	# Doors, room props and quest spots from places.json
	for d in places.get("portals", []):
		var door = InteractableScript.new()
		door.setup(d["id"], d.get("place", ""), d["prompt"], false)
		door.solid = false
		door.portal_to = d
		door.position = Vector3(float(d["x"]), 0, float(d["z"]))
		world.add_child(door)
		interactables.append(door)
	for pr in places.get("props", []):
		var prop = InteractableScript.new()
		prop.setup(pr["id"], "", pr["prompt"], false)
		prop.solid = false
		prop.lines = pr.get("lines", [])
		prop.position = Vector3(float(pr["x"]), 0, float(pr["z"]))
		world.add_child(prop)
		interactables.append(prop)
	for sp in places.get("spots", []):
		var spot = InteractableScript.new()
		spot.setup(sp["id"], "", sp["prompt"], false)
		spot.solid = false
		spot.position = Vector3(float(sp["x"]), 0, float(sp["z"]))
		world.add_child(spot)
		interactables.append(spot)

	for it in interactables:
		if GameData.state["hidden"].has(it.instance_key):
			it.set_hidden(true)

	# Objective marker (bobbing arrow above the next target)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.34
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	marker = MeshInstance3D.new()
	marker.mesh = cone
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("F6B73C")
	mm.emission_enabled = true
	mm.emission = Color("a86b00")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mm
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)

func _hide_instance(key: String) -> void:
	for it in interactables:
		if it.instance_key == key:
			it.set_hidden(true)

# ---------- loop ----------
func _teleport(d: Dictionary) -> void:
	var to: Dictionary = d["to"]
	player.position = Vector3(float(to["x"]), 0, float(to["z"]))
	player.velocity = Vector3.ZERO
	rig.snap()
	AudioManager.play("open")
	place_name = "Rumah Ahmad" if player.position.x > VILLAGE_LIMIT else "Kampung Muslim"
	hud.toast(str(d.get("place", place_name)))

func in_village() -> bool:
	return player.position.x < VILLAGE_LIMIT

## World position of the next target, or null.
func target_position() -> Variant:
	var id := engine.current_target()
	if id == "":
		return null
	var best = null
	var best_d := INF
	for it in interactables:
		if it.interact_id != id or it.hidden:
			continue
		if not it.is_npc and engine.resolve(it.interact_id, "items").is_empty():
			continue
		var dd: float = it.global_position.distance_to(player.global_position)
		if dd < best_d:
			best_d = dd
			best = it
	return best.global_position if best != null else null

func _phase_name(h: float) -> String:
	if h >= 4.0 and h < 10.0:
		return "Pagi"
	if h >= 10.0 and h < 15.0:
		return "Siang"
	if h >= 15.0 and h < 18.0:
		return "Sore"
	return "Malam"

func apply_time(h: float) -> void:
	var a: Array = DAY_KEYS[0]
	var b: Array = DAY_KEYS[1]
	for i in DAY_KEYS.size() - 1:
		if h >= DAY_KEYS[i][0] and h <= DAY_KEYS[i + 1][0]:
			a = DAY_KEYS[i]
			b = DAY_KEYS[i + 1]
			break
	var t := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
	sun.light_energy = lerpf(a[1], b[1], t)
	sun.light_color = Color(str(a[2])).lerp(Color(str(b[2])), t)
	env.ambient_light_energy = lerpf(a[3], b[3], t) * (1.35 if safari else 1.0)
	env.ambient_light_color = Color(str(a[4])).lerp(Color(str(b[4])), t)
	if in_village():
		env.background_color = Color(str(a[5])).lerp(Color(str(b[5])), t)
	var day_t := clampf((h - 5.0) / 14.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-20.0 - 50.0 * sin(PI * day_t), -35.0 + 70.0 * (day_t - 0.5), 0.0) if h > 5.0 and h < 19.0 else Vector3(-55, 20, 0)

func _tick_time(delta: float) -> void:
	var tm: Dictionary = GameData.state["time"]
	if bool(GameData.state["settings"].get("day_cycle", true)):
		tm["hour"] = float(tm["hour"]) + delta / 60.0
		if float(tm["hour"]) >= 24.0:
			tm["hour"] = float(tm["hour"]) - 24.0
			tm["day"] = int(tm["day"]) + 1
	var h := float(tm["hour"]) if bool(GameData.state["settings"].get("day_cycle", true)) else 8.0
	apply_time(h)
	hud.set_clock(int(tm["day"]), _phase_name(h), "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)])

func _update_ball() -> void:
	if kids.size() < 2:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var k: int = int(t / 1.6) % 2
	var f := fmod(t, 1.6) / 1.6
	var a: Vector3 = kids[k].position
	var b: Vector3 = kids[(k + 1) % 2].position
	ball.position = a.lerp(b, f) + Vector3(0, 0.2 + sin(f * PI) * 1.0, 0.3)

func _process(delta: float) -> void:
	_tick_time(delta)
	_update_ball()
	for it in interactables:
		if it.hide_until_available and not it.hidden and it.pickup:
			it.pickup.visible = not engine.resolve(it.interact_id, "items").is_empty()
	var blocked: bool = hud.is_blocking()
	player.input_locked = blocked
	WorldBuilder.update_fades(player.global_position, delta, rig.cam.global_position)
	near = null if blocked else _find_near()
	hud.set_prompt(near.prompt_label if near != null else "")
	var village := in_village()
	place_name = "Kampung Muslim" if village else "Rumah Ahmad"
	hud.set_place(place_name, village)
	if not village:
		env.background_color = Color("3b2a1c")
	var tgt: Variant = target_position() if village else null
	hud.minimap.update_state(player.position, player.model.rotation.y, tgt)
	marker.visible = tgt != null and not blocked
	if marker.visible:
		var t := Time.get_ticks_msec() / 1000.0
		marker.position = tgt + Vector3(0, 2.7 + sin(t * 4.0) * 0.15, 0)
		marker.rotation.y = t * 2.0
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
	if it.is_npc or it.portal_to != null or not it.lines.is_empty():
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
	if it.portal_to != null:
		_teleport(it.portal_to)
		return
	if not it.lines.is_empty():
		AudioManager.play("open")
		hud.show_dialog(it.lines, [], Callable())
		return
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
	hud.set_inventory(inventory_view())
	hud.set_journal(engine.journal_data())

func inventory_view() -> Array:
	var out: Array = []
	for id in GameData.state["inventory"]:
		var def: Dictionary = item_data.get(id, {"name": id, "short": id, "color": "888888"})
		var row := def.duplicate()
		row["id"] = id
		row["count"] = GameData.counter(def["count_from"]) if def.has("count_from") else 1
		out.append(row)
	return out

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
