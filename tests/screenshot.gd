extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func at_hour(m, gd, h: float) -> void:
	gd.state["time"]["hour"] = h
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	gd.set_quest("q.help_neighbor", 3)
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	m.player.position = Vector3(5, 0, 8.5); m.rig.snap()
	at_hour(m, gd, 8.0); await shot("pagi")
	at_hour(m, gd, 17.6); await shot("sore")
	at_hour(m, gd, 21.0); await shot("malam")
	quit()
