extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	m.player.position = Vector3(-10, 0, 1); m.rig.snap()
	await shot("start")
	gd.set_quest("q.help_neighbor", 2); gd.add_item("rantang"); m._refresh_ui()
	m.player.position = Vector3(10, 0, 4.5); m.rig.snap()
	await shot("behind_house")
	m.hud.toggle_journal()
	await shot("journal")
	quit()
