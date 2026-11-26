extends CanvasLayer
## HUD: quest panel, sticker count, interact prompt, dialog with subtitles/choices, toast,
## learning card, settings (camera + 3 volume buses + reset), touch controls.

signal action_pressed
signal joystick_changed(v: Vector2)
signal settings_changed(s: Dictionary)
signal reset_requested

const CREAM := Color("fffaf0")
const WOOD := Color("7a4b2a")
const DEEP := Color("0F5132")
const SUN := Color("F6B73C")
const INK := Color("2b2418")

var quest_text: RichTextLabel
var sticker_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var dialog_panel: PanelContainer
var who_label: Label
var text_label: Label
var btn_row: HBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0
var learn_panel: PanelContainer
var learn_title: Label
var learn_text: Label
var settings_panel: PanelContainer
var s_ortho: CheckButton
var s_pitch: HSlider
var s_dist: HSlider
var s_voice: HSlider
var s_amb: HSlider
var s_sfx: HSlider
var s_reset: Button
var reset_armed := false

var _lines: Array = []
var _idx := 0
var _choices: Array = []
var _on_done: Callable
var _open := false

# ---------- helpers ----------
func _style(bg: Color, border: Color, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _panel(bg: Color, border: Color, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(bg, border, radius))
	return p

func _button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	var bg := Color("22A061") if primary else Color("FFF4E1")
	var n := _style(bg, DEEP if primary else WOOD, 10)
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	return b

func _center(c: Control, w: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -w / 2.0
	c.offset_right = w / 2.0
	c.offset_top = -h / 2.0
	c.offset_bottom = h / 2.0

func _anchor_bottom_center(c: Control, w: float, h: float, bottom: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -w / 2.0
	c.offset_right = w / 2.0
	c.offset_top = -h - bottom
	c.offset_bottom = -bottom
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _slider(min_v: float, max_v: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(180, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(_v): _emit_settings())
	return s

func _row(parent: Control, text: String, control: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := _label(text, 15, INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(control)
	parent.add_child(h)

# ---------- build ----------
func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Quest panel + stickers (top-left)
	var left := VBoxContainer.new()
	left.position = Vector2(12, 12)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var sp := _panel(WOOD, Color("5b3519"), 24)
	sticker_label = _label("Ahmad  ·  Stiker Kebaikan: 0", 15, Color("FFF4E1"))
	sp.add_child(sticker_label)
	left.add_child(sp)
	var qp := _panel(CREAM, WOOD)
	qp.custom_minimum_size = Vector2(300, 0)
	left.add_child(qp)
	quest_text = RichTextLabel.new()
	quest_text.bbcode_enabled = true
	quest_text.fit_content = true
	quest_text.scroll_active = false
	quest_text.custom_minimum_size = Vector2(280, 0)
	quest_text.add_theme_font_size_override("normal_font_size", 15)
	quest_text.add_theme_font_size_override("bold_font_size", 17)
	quest_text.add_theme_color_override("default_color", INK)
	qp.add_child(quest_text)

	# Settings button (top-right)
	var gear := _button("Pengaturan")
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.position = Vector2(-150, 12)
	gear.pressed.connect(toggle_settings)
	root.add_child(gear)

	# Prompt
	prompt_panel = _panel(DEEP, Color("22A061"), 24)
	_anchor_bottom_center(prompt_panel, 380, 50, 90)
	root.add_child(prompt_panel)
	prompt_label = _label("", 16, Color.WHITE)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false

	# Dialog
	dialog_panel = _panel(CREAM, WOOD)
	_anchor_bottom_center(dialog_panel, 660, 180, 16)
	root.add_child(dialog_panel)
	var dv := VBoxContainer.new()
	dialog_panel.add_child(dv)
	who_label = _label("", 18, DEEP)
	dv.add_child(who_label)
	text_label = _label("", 19, INK)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(text_label)
	btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	dv.add_child(btn_row)
	dialog_panel.visible = false

	# Toast
	toast_panel = _panel(DEEP, SUN, 24)
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.position.y = 14
	toast_label = _label("", 16, Color.WHITE)
	toast_panel.add_child(toast_label)
	root.add_child(toast_panel)
	toast_panel.visible = false

	# Learning card
	learn_panel = _panel(CREAM, SUN)
	_center(learn_panel, 460, 300)
	root.add_child(learn_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	learn_panel.add_child(lv)
	lv.add_child(_label("Misi selesai!  +1 Stiker Kebaikan", 20, DEEP))
	learn_title = _label("", 18, WOOD)
	lv.add_child(learn_title)
	lv.add_child(_label("Draf · menunggu review", 12, Color("7a4b00")))
	learn_text = _label("", 16, INK)
	learn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learn_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(learn_text)
	lv.add_child(_label("Stiker hanya koleksi bermain, bukan nilai ibadah.", 12, Color("7a6a4c")))
	var lb := _button("Lanjut jelajah", true)
	lb.pressed.connect(close_learn)
	lv.add_child(lb)
	learn_panel.visible = false

	# Settings
	settings_panel = _panel(CREAM, WOOD)
	_center(settings_panel, 480, 440)
	root.add_child(settings_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	settings_panel.add_child(sv)
	sv.add_child(_label("Pengaturan", 22, DEEP))
	sv.add_child(_label("Kamera", 16, WOOD))
	s_ortho = CheckButton.new()
	s_ortho.focus_mode = Control.FOCUS_NONE
	s_ortho.toggled.connect(func(_v): _emit_settings())
	_row(sv, "Orthographic", s_ortho)
	s_pitch = _slider(30, 70, 1)
	_row(sv, "Sudut", s_pitch)
	s_dist = _slider(16, 34, 1)
	_row(sv, "Jarak", s_dist)
	sv.add_child(_label("Suara", 16, WOOD))
	s_voice = _slider(0, 1, 0.05)
	_row(sv, "Suara NPC", s_voice)
	s_amb = _slider(0, 1, 0.05)
	_row(sv, "Suasana", s_amb)
	s_sfx = _slider(0, 1, 0.05)
	_row(sv, "Efek suara", s_sfx)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	s_reset = _button("Ulang dari awal")
	s_reset.pressed.connect(_on_reset)
	bottom.add_child(s_reset)
	var close := _button("Tutup", true)
	close.pressed.connect(toggle_settings)
	bottom.add_child(close)
	sv.add_child(bottom)
	settings_panel.visible = false

	# Touch controls
	if DisplayServer.is_touchscreen_available():
		var joy := preload("res://scripts/ui/virtual_joystick.gd").new()
		joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		joy.position = Vector2(24, -170)
		joy.changed.connect(func(v: Vector2): joystick_changed.emit(v))
		root.add_child(joy)
		var act := _button("Aksi", true)
		act.add_theme_font_size_override("font_size", 22)
		act.custom_minimum_size = Vector2(100, 100)
		act.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		act.position = Vector2(-124, -134)
		act.pressed.connect(func(): action_pressed.emit())
		root.add_child(act)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_panel.visible = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("settings"):
		if learn_panel.visible:
			close_learn()
		else:
			toggle_settings()
		get_viewport().set_input_as_handled()

# ---------- public API ----------
func is_blocking() -> bool:
	return _open or learn_panel.visible or settings_panel.visible

func dialog_open() -> bool:
	return _open

func learn_open() -> bool:
	return learn_panel.visible

func set_quests(rows: Array) -> void:
	var out := ""
	for q in rows:
		var tag := "Misi Utama" if q["type"] == "main" else "Misi Sampingan"
		out += "[b]%s: %s[/b]\n" % [tag, q["title"]]
		var current_marked := false
		for s in q["steps"]:
			if s["done"]:
				out += "[color=#8a7a5c][s]✓ %s[/s][/color]\n" % s["text"]
			elif not current_marked:
				out += "[color=#0F5132]▶ %s[/color]\n" % s["text"]
				current_marked = true
			else:
				out += "○ %s\n" % s["text"]
	quest_text.text = out.strip_edges()

func set_stickers(n: int) -> void:
	sticker_label.text = "Ahmad  ·  Stiker Kebaikan: %d" % n

func set_prompt(text: String) -> void:
	prompt_panel.visible = text != "" and not is_blocking()
	prompt_label.text = ("E  " if not DisplayServer.is_touchscreen_available() else "") + text

func toast(text: String) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_timer = 2.4

func show_learn(title: String, text: String) -> void:
	learn_title.text = title
	learn_text.text = text
	learn_panel.visible = true

func close_learn() -> void:
	learn_panel.visible = false

func toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	reset_armed = false
	s_reset.text = "Ulang dari awal"

func load_settings(s: Dictionary) -> void:
	s_ortho.set_pressed_no_signal(bool(s.get("ortho", false)))
	s_pitch.set_value_no_signal(float(s.get("pitch", 60)))
	s_dist.set_value_no_signal(float(s.get("distance", 24)))
	s_voice.set_value_no_signal(float(s.get("vol_voice", 1.0)))
	s_amb.set_value_no_signal(float(s.get("vol_amb", 0.4)))
	s_sfx.set_value_no_signal(float(s.get("vol_sfx", 0.7)))

func current_settings() -> Dictionary:
	return {
		"ortho": s_ortho.button_pressed,
		"pitch": s_pitch.value,
		"distance": s_dist.value,
		"vol_voice": s_voice.value,
		"vol_amb": s_amb.value,
		"vol_sfx": s_sfx.value,
	}

func _emit_settings() -> void:
	settings_changed.emit(current_settings())

func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		s_reset.text = "Yakin? Klik lagi"
		return
	reset_armed = false
	settings_panel.visible = false
	reset_requested.emit()

func show_dialog(lines: Array, choices: Array, on_done: Callable) -> void:
	_lines = lines
	_choices = choices
	_on_done = on_done
	_idx = 0
	_open = true
	dialog_panel.visible = true
	prompt_panel.visible = false
	_render()

func _render() -> void:
	var line: Dictionary = _lines[_idx]
	who_label.text = str(line.get("who", ""))
	text_label.text = str(line.get("text", ""))
	for ch in btn_row.get_children():
		ch.queue_free()
	var last := _idx == _lines.size() - 1
	if last and not _choices.is_empty():
		for i in _choices.size():
			var b := _button(str(_choices[i].get("label", "")), i == 0)
			b.pressed.connect(_close.bind(i))
			btn_row.add_child(b)
	else:
		var b := _button("Tutup" if last else "Lanjut", true)
		b.pressed.connect(advance)
		btn_row.add_child(b)

func advance() -> void:
	if not _open:
		return
	var last := _idx == _lines.size() - 1
	if last and not _choices.is_empty():
		return
	AudioManager.play("blip")
	if last:
		_close(-1)
	else:
		_idx += 1
		_render()

func _close(choice_idx: int) -> void:
	_open = false
	dialog_panel.visible = false
	var cb := _on_done
	if cb.is_valid():
		cb.call(choice_idx)
