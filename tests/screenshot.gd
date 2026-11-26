extends SceneTree
## Renders the game and saves screenshots. Run under a display (xvfb-run).
func _init(): _run.call_deferred()
func _run():
	var gd = root.get_node("GameData"); gd.reset()
	var m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_start.png")
	m.player.position = Vector3(-8.5, 0, 9.8)
	m.rig.snap()
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_aminah.png")
	quit()
