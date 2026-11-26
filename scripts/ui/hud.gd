extends CanvasLayer
## HUD: quest panel, interact prompt, dialog with subtitles/choices, toast, touch controls.

signal action_pressed
signal joystick_changed(v: Vector2)

const CREAM := Color("fffaf0")
const WOOD := Color("7a4b2a")
const DEEP := Color("0F5132")
const INK := Color("2b2418")

var quest_title: Label
var quest_steps: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var dialog_panel: PanelContainer
var who_label: Label
var text_label: Label
var btn_row: HBoxContainer
var toast_label: Label
var toast_timer := 0.0

var _lines: Array = []
var _idx := 0
var _choices: Array = []
var _on_done: Callable
var _open := false

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

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Quest panel (top-left)
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", _style(CREAM, WOOD))
	qp.position = Vector2(12, 12)
	qp.custom_minimum_size = Vector2(280, 0)
	root.add_child(qp)
	var qv := VBoxContainer.new()
	qp.add_child(qv)
	quest_title = _label("", 20, DEEP)
	qv.add_child(quest_title)
	quest_steps = _label("", 15, INK)
	quest_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qv.add_child(quest_steps)

	# Prompt (bottom-center)
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _style(DEEP, Color("22A061"), 24))
	_anchor_bottom_center(prompt_panel, 360, 50, 90)
	root.add_child(prompt_panel)
	prompt_label = _label("", 16, Color.WHITE)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false

	# Dialog (bottom-center)
	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", _style(CREAM, WOOD))
	_anchor_bottom_center(dialog_panel, 640, 170, 16)
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
	dv.add_child(btn_row)
	dialog_panel.visible = false

	# Toast (top-center)
	toast_label = _label("", 16, Color.WHITE)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", _style(DEEP, Color("F6B73C"), 24))
	tp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tp.position.y = 14
	tp.add_child(toast_label)
	tp.name = "Toast"
	root.add_child(tp)
	tp.visible = false

	# Touch controls
	if DisplayServer.is_touchscreen_available():
		var joy := preload("res://scripts/ui/virtual_joystick.gd").new()
		joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		joy.position = Vector2(24, -170)
		joy.changed.connect(func(v: Vector2): joystick_changed.emit(v))
		root.add_child(joy)
		var act := Button.new()
		act.text = "Aksi"
		act.add_theme_font_size_override("font_size", 20)
		act.custom_minimum_size = Vector2(96, 96)
		act.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		act.position = Vector2(-120, -130)
		act.pressed.connect(func(): action_pressed.emit())
		root.add_child(act)

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

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.get_parent().visible = false

func set_quest(title: String, steps: Array, current: int) -> void:
	quest_title.text = title
	var out := ""
	for i in steps.size():
		var mark := "[x] " if i < current else ("> " if i == current else "[ ] ")
		out += mark + str(steps[i]) + "\n"
	if current >= steps.size():
		out += "Misi selesai."
	quest_steps.text = out

func set_prompt(text: String) -> void:
	prompt_panel.visible = text != "" and not _open
	prompt_label.text = ("E  " if not DisplayServer.is_touchscreen_available() else "") + text

func toast(text: String) -> void:
	toast_label.text = text
	toast_label.get_parent().visible = true
	toast_timer = 2.2

func dialog_open() -> bool:
	return _open

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
			var b := Button.new()
			b.text = str(_choices[i].get("label", ""))
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_close.bind(i))
			btn_row.add_child(b)
	else:
		var b := Button.new()
		b.text = "Tutup" if last else "Lanjut"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(advance)
		btn_row.add_child(b)

func advance() -> void:
	if not _open:
		return
	var last := _idx == _lines.size() - 1
	if last and not _choices.is_empty():
		return
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
