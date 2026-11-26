extends Control
## Touch joystick for mobile browsers.

signal changed(v: Vector2)

var radius := 65.0
var knob := Vector2.ZERO
var touch_idx := -1

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and touch_idx == -1:
			touch_idx = e.index
			_update(e.position)
		elif not e.pressed and e.index == touch_idx:
			touch_idx = -1
			knob = Vector2.ZERO
			changed.emit(Vector2.ZERO)
			queue_redraw()
	elif e is InputEventScreenDrag and e.index == touch_idx:
		_update(e.position)

func _update(p: Vector2) -> void:
	var m := radius - 14.0
	var d := p - size / 2.0
	if d.length() > m:
		d = d.normalized() * m
	knob = d
	changed.emit(d / m)
	queue_redraw()

func _draw() -> void:
	draw_circle(size / 2.0, radius, Color(1, 0.98, 0.94, 0.35))
	draw_circle(size / 2.0 + knob, 28.0, Color("fffaf0"))
