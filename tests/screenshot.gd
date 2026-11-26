extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	m.player.position = Vector3(-6, 0, 2); m.rig.snap()
	await shot("village")
	m._teleport({"to": {"x": 100.0, "z": 1.5}, "place": "Rumah Ahmad"})
	await shot("interior")
	m._teleport({"to": {"x": -4.3, "z": -6.8}, "place": "Kampung Muslim"})
	gd.set_quest("q.learn_wudhu", 1); gd.add_counter("q.learn_wudhu", 3); m._refresh_ui()
	m.player.position = Vector3(-4.3, 0, -6.8); m.rig.snap()
	for i in 3: await process_frame
	m._on_action()
	await shot("wudhu")
	quit()
