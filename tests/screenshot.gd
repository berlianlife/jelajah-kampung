extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	gd.set_quest("q.help_neighbor", 3); gd.set_quest("q.learn_wudhu", 3); gd.set_quest("q.rukun_iman", 1)
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	m.player.position = Vector3(-4.6, 0, 6.2); m.rig.snap()
	gd.state["time"]["hour"] = 10.0
	await shot("board_day")
	gd.state["time"]["hour"] = 21.0
	m.player.position = Vector3(0, 0, 5.5); m.rig.snap()
	await shot("night_lamps")
	quit()
