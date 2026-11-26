extends SceneTree
## Headless smoke test: movement, collision, quests, learning card, settings, audio, save/load.
## Run: godot --headless --path . -s res://tests/smoke_test.gd

var main
var fails := 0

func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await process_frame

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	_run.call_deferred()

func goto(p: Vector3) -> void:
	main.player.position = p
	await frames(3)

func near_id() -> String:
	return main.near.instance_key if main.near != null else ""

func _run() -> void:
	var gd = root.get_node("GameData")
	gd.reset()
	gd.state["settings"] = gd.default_settings()
	gd.save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	var player = main.player
	var hud = main.hud

	# --- movement & collision ---
	player.position = Vector3(-4, 0, 2)
	player.joystick_vector = Vector2(1, 0)
	await ticks(60)
	player.joystick_vector = Vector2.ZERO
	check(player.position.x > -1.0, "player moves with joystick (x=%.2f)" % player.position.x)
	var start: Vector3 = player.position
	player.joystick_vector = Vector2(0.9, 0.8)
	await ticks(30)
	player.joystick_vector = Vector2.ZERO
	var d: Vector3 = player.position - start
	check(absf(absf(d.x) - absf(d.z)) < 0.05, "8-direction snap to diagonal")
	player.position = Vector3(10, 0, 4.0)
	player.joystick_vector = Vector2(0, 1)
	await frames(90)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z < 5.6, "house blocks player (z=%.2f)" % player.position.z)
	player.position = Vector3(0, 0, 17.5)
	player.joystick_vector = Vector2(0, 1)
	await frames(90)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z < 19.0, "map boundary holds (z=%.2f)" % player.position.z)
	# garden: fence blocks, gate lets you in
	player.position = Vector3(-10.2, 0, -10.6)
	player.joystick_vector = Vector2(0, -1)
	await frames(60)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z > -11.5, "garden fence blocks (z=%.2f)" % player.position.z)
	player.position = Vector3(-12.5, 0, -10.6)
	player.joystick_vector = Vector2(0, -1)
	await ticks(40)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z < -12.0, "garden gate is passable (z=%.2f)" % player.position.z)

	# --- side quest locked before main quest ---
	await goto(Vector3(-14.6, 0, -9.0))
	check(near_id() == "rahman", "Pak Rahman reachable")
	check(main.engine.resolve("rahman", "npcs").is_empty(), "Panen Tomat locked until main quest done")
	await goto(Vector3(-15.3, 0, -15.0))
	check(near_id() == "", "tomatoes not pickable before quest")

	# --- main quest ---
	await goto(Vector3(-8.3, 0, 14.0))
	check(near_id() == "aminah", "Bu Aminah is interactable")
	main._on_action()
	check(hud.dialog_open(), "dialog opens")
	for i in 3:
		main._on_action()
	hud._close(0)
	await frames(2)
	check(gd.quest("q.help_neighbor") == 1, "quest accepted -> state 1")
	hud.advance()
	await goto(Vector3(-12.3, 0, 13.2))
	check(near_id() == "table", "table interactable at state 1")
	main._on_action()
	check(gd.quest("q.help_neighbor") == 2 and gd.has_item("rantang"), "rantang picked -> state 2")
	check(not main.rantang.visible, "rantang hidden on table")
	await goto(Vector3(8.6, 0, 14.0))
	check(near_id() == "hasan", "Pak Hasan interactable")
	main._on_action()
	for i in 3:
		main._on_action()
	await frames(2)
	check(gd.quest("q.help_neighbor") == 3, "main quest complete -> state 3")
	check(hud.learn_open(), "learning card shown")
	check(player.input_locked == true or hud.is_blocking(), "learning card blocks movement")
	main._on_action()
	check(not hud.learn_open(), "learning card closes")
	check(int(gd.state["stickers"]) == 1 and gd.state["learned"].has("adab.tetangga"), "sticker + learning unlocked")

	# --- side quest: Panen Tomat ---
	await goto(Vector3(-14.6, 0, -9.0))
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	check(gd.quest("q.harvest_tomato") == 1, "Panen Tomat accepted")
	var picked := 0
	for key in ["tomato_0", "tomato_1", "tomato_2", "tomato_3", "tomato_4", "tomato_5"]:
		var t = null
		for it in main.interactables:
			if it.instance_key == key:
				t = it
		var side := 0.8 if t.position.z < -14.0 else -0.8
		await goto(t.position + Vector3(0, 0, side))
		if near_id() == key:
			main._on_action()
			picked += 1
	check(picked == 5, "exactly 5 tomatoes pickable (picked=%d)" % picked)
	check(gd.counter("q.harvest_tomato") == 5, "counter = 5")
	check(gd.state["hidden"].has("tomato_0") and not gd.state["hidden"].has("tomato_5"), "picked tomatoes hidden, 6th untouched")
	var panel: Array = main.engine.panel_data()
	check(panel.size() == 2 and panel[1]["steps"][0]["text"].contains("5/5"), "quest panel shows 5/5")
	await goto(Vector3(-14.6, 0, -9.0))
	for i in 3:
		main._on_action()
	await frames(2)
	check(gd.quest("q.harvest_tomato") == 2, "Panen Tomat complete")
	check(int(gd.state["stickers"]) == 2 and gd.state["learned"].has("adab.lingkungan"), "2nd sticker + learning")
	main._on_action()

	# --- occlusion fade ---
	player.position = Vector3(10, 0, 4.5)
	await frames(60)
	var hasan_house: Dictionary = WorldBuilder.fade_targets[2]
	check(hasan_house.cur < 0.5, "house fades when it hides the player (a=%.2f)" % hasan_house.cur)
	player.position = Vector3(0, 0, 2)
	await frames(90)
	check(hasan_house.cur > 0.99, "house restores when player leaves")
	player.position = Vector3(-10, 0, 1)
	await frames(60)
	check(WorldBuilder.fade_targets[1].cur > 0.99, "house in front but not hiding player stays solid")

	# --- settings ---
	hud.toggle_settings()
	check(hud.is_blocking(), "settings panel blocks gameplay")
	hud.s_pitch.value = 45
	hud.s_ortho.button_pressed = true
	hud.s_sfx.value = 0.0
	await frames(2)
	check(is_equal_approx(main.rig.pitch_deg, 45.0) and main.rig.use_orthographic, "camera follows settings")
	check(main.rig.cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "camera switched to orthographic")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX bus muted at volume 0")
	check(float(gd.repo.load_state()["settings"]["pitch"]) == 45.0, "settings saved")
	hud.toggle_settings()

	# --- audio buses ---
	for b in ["Voice", "Ambience", "SFX"]:
		check(AudioServer.get_bus_index(b) != -1, "audio bus %s exists" % b)

	# --- save / load ---
	var loaded: Dictionary = gd.repo.load_state()
	check(int(loaded["quests"]["q.help_neighbor"]) == 3 and int(loaded["quests"]["q.harvest_tomato"]) == 2, "quest states persisted")

	gd.reset()
	gd.state["settings"] = gd.default_settings()
	gd.save()
	print("RESULT: %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
