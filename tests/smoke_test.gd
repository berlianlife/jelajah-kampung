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

	# wallet is invisible and unusable before the main quest
	var wallet = null
	for it in main.interactables:
		if it.instance_key == "dompet_0":
			wallet = it
	await frames(2)
	check(wallet != null and not wallet.pickup.visible, "dompet hidden before main quest")
	# kids wander inside the playground
	var kid = null
	for it in main.interactables:
		if it.interact_id == "kid_umar":
			kid = it
	var kp: Vector3 = kid.position
	var max_d := 0.0
	for i in 16:
		await create_timer(0.25).timeout
		max_d = maxf(max_d, kid.position.distance_to(kp))
	check(max_d > 0.3 and kid.position.x >= 1.1 and kid.position.x <= 6.1 and kid.position.z >= 12.9 and kid.position.z <= 17.7, "kid wanders inside playground")
	var j0: Array = main.engine.journal_data()
	check(j0[0]["status"] == "Belum dimulai" and j0[1]["status"] == "Terkunci", "journal initial statuses")
	check(main.engine.current_target() == "aminah", "first objective target = Bu Aminah")
	var tp = main.target_position()
	check(tp != null and tp.distance_to(Vector3(-8.3, 0, 12.6)) < 0.1, "objective position = Bu Aminah")

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
	check(main.inventory_view().size() == 1 and main.inventory_view()[0]["name"] == "Rantang Lodeh", "hotbar shows Rantang Lodeh")
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
	check(main.engine.current_target() == "rahman", "after main quest, arrow points to next offer (Pak Rahman)")

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
	var inv: Array = main.inventory_view()
	check(inv.size() == 1 and inv[0]["id"] == "tomat" and int(inv[0]["count"]) == 5, "hotbar shows Tomat x5")
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

	# --- Dompet yang Tercecer (jujur & amanah) ---
	await frames(2)
	check(wallet.pickup.visible, "dompet visible after main quest")
	await goto(Vector3(6.8, 0, 3.2))
	check(near_id() == "dompet_0", "dompet interactable")
	main._on_action()
	await frames(2)
	check(gd.quest("q.lost_wallet") == 1 and gd.has_item("dompet") and not wallet.pickup.visible, "dompet picked -> state 1")
	check(main.engine.current_target() == "sari", "objective = Bu Sari")
	await goto(Vector3(11, 0, -2.6))
	check(near_id() == "sari", "Bu Sari interactable")
	for i in 4:
		main._on_action()
	await frames(2)
	check(gd.quest("q.lost_wallet") == 2, "Bu Sari names the owner -> state 2")
	var rr: Dictionary = main.engine.resolve("rahman", "npcs")
	check(rr["quest"]["quest_id"] == "q.lost_wallet", "active wallet quest wins over finished tomato quest for Pak Rahman")
	await goto(Vector3(-14.6, 0, -9.0))
	for i in 4:
		main._on_action()
	await frames(2)
	check(gd.quest("q.lost_wallet") == 3 and not gd.has_item("dompet") and gd.state["learned"].has("adab.amanah"), "dompet returned + lesson Jujur dan Amanah")
	check(int(gd.state["stickers"]) == 3, "3rd sticker")
	main._on_action()

	# --- day cycle ---
	main.apply_time(22.0)
	check(main.sun.light_energy < 0.2 and main.env.background_color.v < 0.35, "night is dark")
	main.apply_time(12.0)
	check(main.sun.light_energy > 0.5 and main.env.background_color.v > 0.7, "noon is bright")
	check(main._phase_name(7.5) == "Pagi" and main._phase_name(13) == "Siang" and main._phase_name(16.5) == "Sore" and main._phase_name(21) == "Malam", "phase names")
	var h0: float = gd.state["time"]["hour"]
	await frames(30)
	check(float(gd.state["time"]["hour"]) > h0, "time advances")
	check(hud.clock_label.text.begins_with("Hari 1 ·"), "clock shows day + phase")

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

	# --- journal ---
	var j: Array = main.engine.journal_data()
	check(j.size() == 7 and j[6]["status"] == "Belum dimulai" and j[5]["status"] == "Terkunci" and j[4]["status"] == "Belum dimulai" and j[0]["status"] == "Selesai" and j[1]["status"] == "Selesai" and j[2]["status"] == "Belum dimulai" and j[3]["status"] == "Selesai", "journal statuses after 3 quests")
	check(j[0]["lessons"][0]["unlocked"] and j[0]["lessons"][0]["title"] == "Adab Bertetangga", "journal: lesson unlocked")
	check(main.inventory_view().is_empty(), "inventory empty after handing in items")
	hud.toggle_journal()
	check(hud.is_blocking() and hud.journal_text.text.contains("Menjaga Kebun Bersama"), "journal panel opens with lessons")
	hud.toggle_journal()

	# --- enter / exit Ahmad's house ---
	await goto(Vector3(-10, 0, -0.2))
	check(near_id() == "door_home", "front door interactable")
	main._on_action()
	await frames(3)
	check(not main.in_village() and main.player.position.x > 90.0, "entered house interior")
	check(not hud.minimap.visible, "minimap hidden indoors")
	await goto(Vector3(102.8, 0, -0.6))
	check(near_id() == "bed", "bed prop interactable")
	main._on_action()
	check(hud.dialog_open(), "bed shows a line")
	main._on_action()
	await goto(Vector3(100.0, 0, 2.6))
	check(near_id() == "door_home_out", "exit door interactable")
	main._on_action()
	await frames(3)
	check(main.in_village() and hud.minimap.visible, "back in village with minimap")
	# walls keep you inside the room
	await goto(Vector3(100, 0, 0))
	main.player.joystick_vector = Vector2(1, 0)
	await ticks(120)
	main.player.joystick_vector = Vector2.ZERO
	check(main.player.position.x < 104.5, "interior wall blocks (x=%.2f)" % main.player.position.x)
	await goto(Vector3(-10, 0, 0.4))

	# --- Belajar Wudhu ---
	await goto(Vector3(2.2, 0, -8.0))
	check(near_id() == "ustadz", "Ustadz Ali interactable")
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	hud.advance()
	check(gd.quest("q.learn_wudhu") == 1, "Belajar Wudhu accepted")
	check(main.engine.current_target() == "wudhu_station", "objective = tempat wudhu")
	await goto(Vector3(-4.3, 0, -6.8))
	check(near_id() == "wudhu_station", "tempat wudhu interactable")
	# a wrong answer gives a gentle hint, no progress
	main._on_action()
	var node: Dictionary = main.engine.resolve("wudhu_station", "items")["node"]
	var wrong := -1
	for i in node["choices"].size():
		if not node["choices"][i].has("counter_add"):
			wrong = i
	hud._close(wrong)
	await frames(2)
	check(hud.dialog_open() and gd.counter("q.learn_wudhu") == 0, "wrong choice -> hint, counter stays 0")
	hud.advance()
	await frames(2)
	for k in 7:
		main._on_action()
		var nd: Dictionary = main.engine.resolve("wudhu_station", "items")["node"]
		var right := -1
		for i in nd["choices"].size():
			if nd["choices"][i].has("counter_add"):
				right = i
		hud._close(right)
		await frames(2)
	check(gd.counter("q.learn_wudhu") == 7 and gd.quest("q.learn_wudhu") == 2, "7 wudhu steps ordered -> state 2")
	check(main.engine.resolve("wudhu_station", "items").is_empty(), "station done after all steps")
	await goto(Vector3(2.2, 0, -8.0))
	for i in 3:
		main._on_action()
	await frames(2)
	check(gd.quest("q.learn_wudhu") == 3 and gd.state["learned"].has("ibadah.wudhu"), "Belajar Wudhu complete + lesson")
	check(hud.learn_open(), "wudhu learning card shown")
	main._on_action()
	check(main.engine.current_target() == "imam", "next offer = Pak Imam (inside masjid)")
	await goto(Vector3(4, 0, -6))
	var door_pos = main.target_position()
	check(door_pos != null and door_pos.distance_to(Vector3(0, 0, -9.4)) < 0.1, "arrow routes to masjid door when target is inside")

	# --- masjid + Mengenal Rukun Islam ---
	await goto(Vector3(0, 0, -8.6))
	check(near_id() == "door_masjid", "masjid door interactable")
	main._on_action()
	await frames(2)
	check(main.area_of(main.player.position) == "Masjid" and hud.dialog_open(), "entered masjid with adab line")
	main._on_action()
	await frames(2)
	check(not hud.minimap.visible and hud.place_label.text == "Masjid", "place label = Masjid, minimap hidden")
	await goto(Vector3(101.8, 0, 28.8))
	check(near_id() == "imam", "Pak Imam interactable")
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	hud.advance()
	await frames(2)
	check(gd.quest("q.rukun_islam") == 1, "Rukun Islam accepted")
	var card_keys := ["kartu_rukun_1", "kartu_rukun_2", "kartu_rukun_3", "kartu_rukun_4", "kartu_rukun_5"]
	var read := 0
	for key in card_keys:
		var card = null
		for it in main.interactables:
			if it.instance_key == key:
				card = it
		await goto(card.position + Vector3(0, 0, 0.9))
		if near_id() == key:
			main._on_action()
			var shown: bool = hud.dialog_open() and hud.text_label.text.begins_with("Rukun Islam")
			main._on_action()
			await frames(2)
			if shown:
				read += 1
	check(read == 5 and gd.counter("q.rukun_islam") == 5, "5 Rukun Islam cards read (read=%d)" % read)
	await goto(Vector3(101.8, 0, 28.8))
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	check(hud.dialog_open() and gd.quest("q.rukun_islam") == 1, "wrong quiz answer -> hint, still state 1")
	hud.advance()
	await frames(2)
	main._on_action()
	main._on_action()
	hud._close(1)
	await frames(2)
	check(gd.quest("q.rukun_islam") == 2 and gd.state["learned"].has("aqidah.rukun_islam"), "correct answer -> quest done + lesson")
	hud.advance()
	await frames(2)
	if hud.learn_open():
		main._on_action()
	await goto(Vector3(100, 0, 33.9))
	check(near_id() == "door_masjid_out", "masjid exit door")
	main._on_action()
	await frames(2)
	check(main.in_village(), "back in village")
	check(main.engine.current_target() == "ustadz", "next offer = Ustadz Ali (Rukun Iman)")

	# --- Mengenal Rukun Iman (explore 6 boards) ---
	await goto(Vector3(2.2, 0, -8.0))
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	hud.advance()
	await frames(2)
	check(gd.quest("q.rukun_iman") == 1, "Rukun Iman accepted")
	var boards_read := 0
	for i in 6:
		var key := "papan_iman_%d" % (i + 1)
		var bd = null
		for it in main.interactables:
			if it.instance_key == key:
				bd = it
		await goto(bd.position + Vector3(0, 0, 1.0))
		if near_id() == key:
			main._on_action()
			var ok: bool = hud.dialog_open() and hud.text_label.text.begins_with("Rukun Iman")
			main._on_action()
			await frames(2)
			if ok:
				boards_read += 1
	check(boards_read == 6 and gd.counter("q.rukun_iman") == 6, "6 Rukun Iman boards read (read=%d)" % boards_read)
	await goto(Vector3(2.2, 0, -8.0))
	main._on_action()
	main._on_action()
	hud._close(2)
	await frames(2)
	check(hud.dialog_open() and gd.quest("q.rukun_iman") == 1, "wrong answer (Tujuh) -> hint")
	hud.advance()
	await frames(2)
	main._on_action()
	main._on_action()
	hud._close(1)
	await frames(2)
	check(gd.quest("q.rukun_iman") == 2 and gd.state["learned"].has("aqidah.rukun_iman"), "Rukun Iman complete + lesson")
	hud.advance()
	await frames(2)
	if hud.learn_open():
		main._on_action()
	check(main.engine.current_target() == "aminah", "next offer = Bu Aminah (adab makan)")

	# --- Bertamu dan Adab Makan ---
	await goto(Vector3(-8.3, 0, 14.0))
	main._on_action()
	main._on_action()
	hud._close(0)
	await frames(2)
	hud.advance()
	await frames(2)
	check(gd.quest("q.adab_makan") == 1, "adab makan invitation accepted")
	await goto(Vector3(-10.0, 0, 11.8))
	check(near_id() == "pintu_aminah", "Bu Aminah's door interactable")
	main._on_action()
	hud._close(0)
	await frames(2)
	check(hud.dialog_open() and gd.quest("q.adab_makan") == 1 and main.in_village(), "barging in -> reminder, stays outside")
	hud.advance()
	await frames(2)
	main._on_action()
	hud._close(1)
	await frames(3)
	check(gd.quest("q.adab_makan") == 2 and main.area_of(main.player.position) == "Rumah Bu Aminah", "knock + salam -> inside Bu Aminah's house")
	await goto(Vector3(101.4, 0, -29.8))
	check(near_id() == "aminah_home", "Bu Aminah inside interactable")
	main._on_action()
	var nd0: Dictionary = main.engine.resolve("aminah_home", "npcs")["node"]
	var bad := -1
	for i in nd0["choices"].size():
		if not nd0["choices"][i].has("counter_add"):
			bad = i
	hud._close(bad)
	await frames(2)
	check(hud.dialog_open() and gd.counter("q.adab_makan") == 0, "wrong adab answer -> gentle hint")
	hud.advance()
	await frames(2)
	main._on_action()
	var chained := 0
	for k in 6:
		var nd: Dictionary = main.engine.resolve("aminah_home", "npcs")["node"]
		var good := -1
		for i in nd["choices"].size():
			if nd["choices"][i].has("counter_add"):
				good = i
		hud._close(good)
		await frames(2)
		if k < 5 and hud.dialog_open():
			chained += 1
	check(chained == 5, "questions chain automatically after correct answers (%d/5)" % chained)
	check(gd.quest("q.adab_makan") == 3 and gd.state["learned"].has("adab.makan_bertamu"), "adab makan complete + lesson")
	hud.advance()
	await frames(2)
	if hud.learn_open():
		main._on_action()
	await goto(Vector3(100.0, 0, -27.0))
	check(near_id() == "door_aminah_out", "exit door in Bu Aminah's house")
	main._on_action()
	await frames(2)
	main._on_action()
	await frames(2)
	check(main.in_village() and not hud.is_blocking(), "back in village after pamit")
	check(main.engine.current_target() == "", "no objective left")

	# --- night behaviour ---
	gd.state["time"]["hour"] = 21.0
	await frames(3)
	var umar = null
	for it in main.interactables:
		if it.interact_id == "kid_umar":
			umar = it
	check(umar.asleep and not umar.visible and not main.ball.visible, "kids go home at night")
	check(WorldBuilder.lamp_mats[0].emission_energy_multiplier > 1.0, "street lamps on at night")
	check(main._idle_lines("sari")[0]["text"].contains("tutup"), "Bu Sari: pasar tutup at night")
	gd.state["time"]["hour"] = 9.0
	await frames(3)
	check(umar.visible and WorldBuilder.lamp_mats[0].emission_energy_multiplier == 0.0, "morning: kids back, lamps off")

	# --- portrait phone layout ---
	main.get_window().size = Vector2i(400, 800)
	main._fit_ui()
	check(main.get_window().content_scale_size == Vector2i(720, 1280), "portrait uses 720x1280 UI base")
	main.get_window().size = Vector2i(1280, 720)
	main._fit_ui()
	check(main.get_window().content_scale_size == Vector2i(1280, 720), "landscape uses 1280x720 UI base")

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
