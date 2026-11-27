extends SceneTree
## Renders the game and saves screenshots. Run under a display (Xvfb).
func _init(): _run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % name)
func _run():
	var gd = root.get_node("GameData"); gd.reset(); gd.state["settings"] = gd.default_settings()
	gd.set_quest("q.help_neighbor", 3); gd.set_quest("q.rukun_islam", 1)
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	var mode: String = "portrait" if OS.get_cmdline_user_args().has("--portrait") else "land"
	if mode == "portrait":
		m.player.position = Vector3(-6, 0, 2); m.rig.snap()
		await shot("portrait")
	else:
		m._teleport({"to": {"x": 100.0, "z": 31.5}, "place": "Masjid"})
		await shot("masjid")
	quit()
