extends Control
## Round minimap of the village. Shapes come from WorldBuilder.map_shapes (world units).

const HALF := 20.0
var shapes: Array = []
var player_pos := Vector3.ZERO
var player_yaw := 0.0
var target_pos: Variant = null
var pulse := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_state(p: Vector3, yaw: float, target: Variant) -> void:
	player_pos = p
	player_yaw = yaw
	target_pos = target
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	if visible and target_pos != null:
		queue_redraw()

func _to_map(x: float, z: float) -> Vector2:
	var r := size.x / 2.0
	return Vector2(r + x / HALF * (r - 8.0), r + z / HALF * (r - 8.0))

func _draw() -> void:
	var r := size.x / 2.0
	var c := Vector2(r, r)
	draw_circle(c, r, Color("7a4b2a"))
	draw_circle(c, r - 4.0, Color("8fcd63"))
	var scale := (r - 8.0) / HALF
	for s in shapes:
		var col := Color(str(s["color"]))
		var p := _to_map(float(s["x"]), float(s["z"]))
		if s.get("round", false):
			draw_circle(p, maxf(1.5, float(s["w"]) * 0.5 * scale), col)
		else:
			var w := float(s["w"]) * scale
			var h := float(s["d"]) * scale
			draw_rect(Rect2(p - Vector2(w, h) / 2.0, Vector2(w, h)), col)
	if target_pos != null:
		var tp := _to_map(target_pos.x, target_pos.z)
		draw_circle(tp, 6.0 + sin(pulse * 5.0) * 1.5, Color("7a4b2a"))
		draw_circle(tp, 4.5 + sin(pulse * 5.0) * 1.5, Color("F6B73C"))
	# player arrow (model faces +Z when yaw = 0, i.e. "down" on the map)
	var pp := _to_map(player_pos.x, player_pos.z)
	var fwd := Vector2(sin(player_yaw), cos(player_yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([pp + fwd * 8.0, pp - fwd * 5.0 + side * 5.0, pp - fwd * 2.0, pp - fwd * 5.0 - side * 5.0])
	draw_colored_polygon(pts, Color.WHITE)
	pts.append(pts[0])
	draw_polyline(pts, Color("0F5132"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(r - 4.0, 16.0), "U", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
