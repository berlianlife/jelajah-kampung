extends SceneTree
## Headless smoke test: movement, collision, full quest flow, save/load.
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

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var gd = root.get_node("GameData")
	gd.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	var player = main.player
	var hud = main.hud

	# Movement: walk right on open road for ~1s
	player.position = Vector3(-4, 0, 2)
	player.joystick_vector = Vector2(1, 0)
	await frames(60)
	player.joystick_vector = Vector2.ZERO
	check(player.position.x > -3.0, "player moves with joystick (x=%.2f)" % player.position.x)

	# 8-direction snapping: slightly off-axis input becomes pure diagonal
	var start: Vector3 = player.position
	player.joystick_vector = Vector2(0.9, 0.8)
	await frames(30)
	player.joystick_vector = Vector2.ZERO
	var d: Vector3 = player.position - start
	check(absf(absf(d.x) - absf(d.z)) < 0.05, "8-direction snap to diagonal")

	# Collision: push up into Pak Hasan's house front wall (house z 5.5..10.5 at x 10)
	player.position = Vector3(10, 0, 4.0)
	player.joystick_vector = Vector2(0, 1)
	await frames(90)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z < 5.6, "house blocks player (z=%.2f)" % player.position.z)

	# Map bounds
	player.position = Vector3(0, 0, 17.5)
	player.joystick_vector = Vector2(0, 1)
	await frames(90)
	player.joystick_vector = Vector2.ZERO
	check(player.position.z < 19.0, "map boundary holds (z=%.2f)" % player.position.z)

	# Quest: talk to Bu Aminah, accept
	player.position = Vector3(-8.3, 0, 14.0)
	await frames(3)
	check(main.near != null and main.near.interact_id == "aminah", "Bu Aminah is interactable")
	main._on_action()
	check(hud.dialog_open(), "dialog opens")
	for i in 3:
		main._on_action()
	hud._close(0)  # choose "Baik, Bu!"
	await frames(2)
	check(gd.quest("q.help_neighbor") == 1, "quest accepted -> state 1")
	hud.advance()  # close reply

	# Table not usable before; now take rantang
	player.position = Vector3(-12.3, 0, 13.2)
	await frames(3)
	check(main.near != null and main.near.interact_id == "table", "table interactable at state 1")
	main._on_action()
	check(gd.quest("q.help_neighbor") == 2 and gd.has_item("rantang"), "rantang picked -> state 2")
	check(not main.rantang.visible, "rantang hidden on table")

	# Deliver to Pak Hasan
	player.position = Vector3(8.6, 0, 14.0)
	await frames(3)
	check(main.near != null and main.near.interact_id == "hasan", "Pak Hasan interactable")
	main._on_action()
	for i in 3:
		main._on_action()
	await frames(2)
	check(gd.quest("q.help_neighbor") == 3, "quest complete -> state 3")
	check(not gd.has_item("rantang"), "rantang removed from inventory")
	check(int(gd.state["stickers"]) == 1, "sticker awarded")
	check(gd.state["learned"].has("adab.tetangga"), "learning entry unlocked")

	# Occlusion fade: stand behind Pak Hasan's house (camera looks from +z)
	player.position = Vector3(10, 0, 4.5)
	await frames(60)
	var hasan_house: Dictionary = WorldBuilder.fade_targets[2]
	check(hasan_house.cur < 0.5, "house fades when it hides the player (a=%.2f)" % hasan_house.cur)
	player.position = Vector3(0, 0, 2)
	await frames(90)
	check(hasan_house.cur > 0.99, "house restores when player leaves (a=%.2f)" % hasan_house.cur)

	# Save / load roundtrip
	gd.save()
	var loaded: Dictionary = gd.repo.load_state()
	check(int(loaded["quests"]["q.help_neighbor"]) == 3, "save file persists quest state")

	gd.reset()
	print("RESULT: %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
