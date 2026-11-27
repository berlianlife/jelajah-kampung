extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	gd.set_quest("q.help_neighbor", 3); gd.set_quest("q.clean_village", 1); gd.set_quest("q.help_mother", 1); gd.state["time"]["hour"] = 10.0
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	m.player.position = Vector3(-2.0, 0, 9.6); m.rig.snap()
	await shot("rt")
	m._teleport({"to": {"x": 100.0, "z": 1.8}, "place": "Rumah Ahmad"})
	for i in 3: await process_frame
	m.hud.advance()
	await shot("ibu")
	quit()
