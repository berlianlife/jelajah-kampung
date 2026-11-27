class_name WorldBuilder
extends RefCounted
## Procedural blockout of Kampung Muslim (low-poly). Replace pieces with modelled assets later;
## keep positions in sync with data/world/kampung_muslim.json.

const HALF := 19.0
static var _mats := {}

static func mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_mats[hex] = m
	return _mats[hex]

static func mesh_at(parent: Node3D, mesh: Mesh, hex: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(hex)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, hex: String, collide := false) -> Node3D:
	var bm := BoxMesh.new()
	bm.size = size
	if not collide:
		return mesh_at(parent, bm, hex, pos)
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	mesh_at(body, bm, hex, Vector3.ZERO)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body

static func cyl_mesh(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func solid_cylinder(parent: Node3D, r: float, h: float, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position.y = h / 2.0
	body.add_child(cs)

static func flat(parent: Node3D, size: Vector2, pos: Vector3, hex: String) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := mesh_at(parent, pm, hex, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Buildings that fade when they stand between the camera and the player.
static var fade_targets: Array = []
## Shapes for the minimap: {"x","z","w","d","color","round"} in world units (centre + size).
static var map_shapes: Array = []
## Emissive bulb materials of the street lamps (brightened at night by main).
static var lamp_mats: Array = []
static var lamp_pools: Array = []
## Interior origin (Ahmad's room) — far outside the village bounds.
const INTERIOR := Vector3(100, 0, 0)
const MASJID_IN := Vector3(100, 0, 30)
const AMINAH_IN := Vector3(100, 0, -30)

static func _map(x: float, z: float, w: float, d: float, color: String, round := false) -> void:
	map_shapes.append({"x": x, "z": z, "w": w, "d": d, "color": color, "round": round})

static func _collect_unique_mats(node: Node, out: Array) -> void:
	if node is MeshInstance3D and node.material_override:
		var m: StandardMaterial3D = node.material_override.duplicate()
		node.material_override = m
		out.append(m)
	for ch in node.get_children():
		_collect_unique_mats(ch, out)

static func house(parent: Node3D, x: float, z: float, w: float, d: float, wall: String, roof: String) -> void:
	var g := Node3D.new()
	g.name = "House"
	parent.add_child(g)
	_house_parts(g, x, z, w, d, wall, roof)
	var mats: Array = []
	_collect_unique_mats(g, mats)
	_map(x, z, w, d, roof)
	fade_targets.append({"mats": mats, "min_x": x - w / 2.0, "max_x": x + w / 2.0, "min_z": z - d / 2.0, "max_z": z + d / 2.0, "cur": 1.0})

## Segment vs axis-aligned box (slab test). True when a..b passes through the box.
static func _segment_hits_box(a: Vector3, b: Vector3, bmin: Vector3, bmax: Vector3) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if absf(d[i]) < 1e-6:
			if a[i] < bmin[i] or a[i] > bmax[i]:
				return false
		else:
			var ta := (bmin[i] - a[i]) / d[i]
			var tb := (bmax[i] - a[i]) / d[i]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return false
	return true

## Call every frame. A house fades only when it actually blocks the camera's line of sight
## to the player (works for any pitch, distance or projection).
static func update_fades(p: Vector3, delta: float, cam_pos: Vector3) -> void:
	var head := p + Vector3(0, 1.3, 0)
	var body := p + Vector3(0, 0.7, 0)
	for b in fade_targets:
		var bmin := Vector3(b.min_x - 0.15, 0.0, b.min_z - 0.15)
		var bmax := Vector3(b.max_x + 0.15, 4.0, b.max_z + 0.15)
		var occ: bool = _segment_hits_box(head, cam_pos, bmin, bmax) or _segment_hits_box(body, cam_pos, bmin, bmax)
		var goal := 0.3 if occ else 1.0
		var cur: float = b.cur
		if absf(cur - goal) < 0.002:
			continue
		cur = lerpf(cur, goal, 1.0 - exp(-10.0 * delta))
		if absf(cur - goal) < 0.01:
			cur = goal
		b.cur = cur
		for m in b.mats:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if cur >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = cur

static func _house_parts(parent: Node3D, x: float, z: float, w: float, d: float, wall: String, roof: String) -> void:
	box(parent, Vector3(w, 2.6, d), Vector3(x, 1.3, z), wall, true)
	box(parent, Vector3(w + 0.3, 0.25, d + 0.3), Vector3(x, 0.12, z), "7a4b2a")
	var r := mesh_at(parent, cyl_mesh(0.0, sqrt(2.0) * w / 2.0 + 0.35, 1.9, 4), roof, Vector3(x, 3.55, z))
	r.rotation.y = PI / 4.0
	r.scale.z = (d + 0.6) / (w + 0.6)
	box(parent, Vector3(1.1, 1.7, 0.12), Vector3(x, 0.95, z + d / 2.0 + 0.02), "5b3519")
	box(parent, Vector3(0.9, 0.8, 0.1), Vector3(x - w / 2.0 + 1.1, 1.6, z + d / 2.0 + 0.03), "3d6f8f")
	box(parent, Vector3(0.9, 0.8, 0.1), Vector3(x + w / 2.0 - 1.1, 1.6, z + d / 2.0 + 0.03), "3d6f8f")

static func tree(parent: Node3D, x: float, z: float, s: float) -> void:
	mesh_at(parent, cyl_mesh(0.18, 0.28, 1.4, 6), "7a4b2a", Vector3(x, 0.7, z))
	var crown := SphereMesh.new()
	crown.radius = 1.25 * s
	crown.height = 2.4 * s
	crown.radial_segments = 6
	crown.rings = 3
	mesh_at(parent, crown, "3fae55", Vector3(x, 2.2 * s, z))
	solid_cylinder(parent, 0.5, 2.0, Vector3(x, 0, z))

static func mosque(parent: Node3D, x: float, z: float) -> void:
	box(parent, Vector3(10.4, 0.4, 8.4), Vector3(x, 0.2, z), "d9cdb3")
	box(parent, Vector3(10, 3.4, 8), Vector3(x, 2.1, z), "f6efdf", true)
	box(parent, Vector3(10.6, 0.35, 8.6), Vector3(x, 3.95, z), "1e7a4f")
	mesh_at(parent, cyl_mesh(2.4, 2.6, 1.0, 12), "f6efdf", Vector3(x, 4.6, z))
	var dome := SphereMesh.new()
	dome.radius = 2.5
	dome.height = 2.5
	dome.is_hemisphere = true
	dome.radial_segments = 14
	dome.rings = 5
	mesh_at(parent, dome, "1f8a57", Vector3(x, 5.1, z))
	box(parent, Vector3(1.6, 2.4, 0.14), Vector3(x, 1.6, z + 4.05), "6b4220")
	mesh_at(parent, cyl_mesh(0.7, 0.85, 8.0, 10), "f6efdf", Vector3(x + 6.4, 4.0, z - 2.6))
	mesh_at(parent, cyl_mesh(1.0, 1.0, 0.3, 10), "1e7a4f", Vector3(x + 6.4, 6.4, z - 2.6))
	solid_cylinder(parent, 1.0, 8.0, Vector3(x + 6.4, 0, z - 2.6))

## Fenced garden (x -16.4..-8.6, z -17.4..-11.6) with a gate on the south side (x -13.2..-11.8).
static func garden(parent: Node3D) -> void:
	var fence := "a8743f"
	# solid fence lines (thin colliders)
	box(parent, Vector3(7.8, 0.1, 0.1), Vector3(-12.5, 0.5, -17.4), fence, false)
	_wall(parent, Vector3(7.8, 1.2, 0.3), Vector3(-12.5, 0.6, -17.4))
	_wall(parent, Vector3(0.3, 1.2, 5.8), Vector3(-16.4, 0.6, -14.5))
	_wall(parent, Vector3(0.3, 1.2, 5.8), Vector3(-8.6, 0.6, -14.5))
	_wall(parent, Vector3(3.2, 1.2, 0.3), Vector3(-14.8, 0.6, -11.6))
	_wall(parent, Vector3(3.2, 1.2, 0.3), Vector3(-10.2, 0.6, -11.6))
	box(parent, Vector3(0.1, 0.1, 5.8), Vector3(-16.4, 0.5, -14.5), fence)
	box(parent, Vector3(0.1, 0.1, 5.8), Vector3(-8.6, 0.5, -14.5), fence)
	box(parent, Vector3(3.2, 0.1, 0.1), Vector3(-14.8, 0.5, -11.6), fence)
	box(parent, Vector3(3.2, 0.1, 0.1), Vector3(-10.2, 0.5, -11.6), fence)
	var x := -16.4
	while x <= -8.5:
		box(parent, Vector3(0.15, 0.7, 0.15), Vector3(x, 0.35, -17.4), fence)
		if absf(x + 12.5) > 0.3:
			box(parent, Vector3(0.15, 0.7, 0.15), Vector3(x, 0.35, -11.6), fence)
		x += 1.3
	box(parent, Vector3(0.15, 1.1, 0.15), Vector3(-13.2, 0.55, -11.6), fence)
	box(parent, Vector3(0.15, 1.1, 0.15), Vector3(-11.8, 0.55, -11.6), fence)
	# soil rows + plants (walkable)
	for r in 3:
		var z := -16.2 + r * 1.8
		box(parent, Vector3(7, 0.25, 1), Vector3(-12.5, 0.12, z), "7a5233")
		for i in 6:
			var leaf := SphereMesh.new()
			leaf.radius = 0.38
			leaf.height = 0.7
			leaf.radial_segments = 5
			leaf.rings = 2
			mesh_at(parent, leaf, "5fae3b" if r == 1 else "3f9a3a", Vector3(-15.5 + i * 1.2, 0.55, z))

static func _wall(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)

## Tempat wudhu: low wall with three taps, facing south (toward the road).
static func wudhu_station(parent: Node3D, x: float, z: float) -> void:
	box(parent, Vector3(3.2, 0.9, 0.6), Vector3(x, 0.45, z), "d9cdb3", true)
	box(parent, Vector3(3.4, 0.12, 0.8), Vector3(x, 0.96, z), "c7b998")
	box(parent, Vector3(3.2, 0.06, 0.9), Vector3(x, 0.03, z + 0.7), "9fc6d8")
	for i in 3:
		var tx := x - 1.0 + i * 1.0
		mesh_at(parent, cyl_mesh(0.05, 0.05, 0.4, 6), "9aa7ad", Vector3(tx, 1.2, z + 0.15))
		box(parent, Vector3(0.08, 0.08, 0.3), Vector3(tx, 1.38, z + 0.3), "9aa7ad")
	_map(x, z, 3.2, 0.8, "9fc6d8")

## Ahmad's room, built at INTERIOR. South wall is low so the camera can see in.
static func interior(parent: Node3D) -> void:
	var o := INTERIOR
	flat(parent, Vector2(9, 7), o + Vector3(0, 0.01, 0), "d8b98c")
	flat(parent, Vector2(3, 2), o + Vector3(-1.2, 0.02, 0.6), "b0473a")
	box(parent, Vector3(9, 3, 0.3), o + Vector3(0, 1.5, -3.5), "fbe9cc", true)
	box(parent, Vector3(0.3, 3, 7), o + Vector3(-4.5, 1.5, 0), "f6e0bd", true)
	box(parent, Vector3(0.3, 3, 7), o + Vector3(4.5, 1.5, 0), "f6e0bd", true)
	box(parent, Vector3(3.6, 0.4, 0.3), o + Vector3(-2.7, 0.2, 3.5), "e8cfa6", true)
	box(parent, Vector3(3.6, 0.4, 0.3), o + Vector3(2.7, 0.2, 3.5), "e8cfa6", true)
	_wall(parent, Vector3(9, 3, 0.3), o + Vector3(0, 1.5, 3.9))
	# bed, shelf, small table with a green book
	box(parent, Vector3(2.0, 0.5, 1.2), o + Vector3(2.8, 0.25, -2.4), "8a5a30", true)
	box(parent, Vector3(1.8, 0.2, 1.1), o + Vector3(2.8, 0.6, -2.4), "fff4e1")
	box(parent, Vector3(0.6, 0.15, 0.9), o + Vector3(3.4, 0.75, -2.4), "8ec9ff")
	box(parent, Vector3(2.2, 2.2, 0.5), o + Vector3(-2.6, 1.1, -3.1), "7a4b2a", true)
	for r in 3:
		box(parent, Vector3(2.0, 0.06, 0.45), o + Vector3(-2.6, 0.5 + r * 0.6, -2.9), "a8743f")
	box(parent, Vector3(1.0, 0.5, 0.7), o + Vector3(-1.2, 0.25, 0.6), "a8743f", true)
	box(parent, Vector3(0.4, 0.08, 0.3), o + Vector3(-1.2, 0.54, 0.6), "1e7a4f")
	# doorway frame on the south side
	box(parent, Vector3(0.15, 2.2, 0.15), o + Vector3(-0.8, 1.1, 3.5), "5b3519")
	box(parent, Vector3(0.15, 2.2, 0.15), o + Vector3(0.8, 1.1, 3.5), "5b3519")

## Prayer hall, built at MASJID_IN (14 x 10). Mihrab on the north wall, saf lines on the carpet.
static func masjid_interior(parent: Node3D) -> void:
	var o := MASJID_IN
	flat(parent, Vector2(14, 10), o + Vector3(0, 0.01, 0), "1f7a52")
	for i in 5:
		flat(parent, Vector2(13, 0.08), o + Vector3(0, 0.015, -3.2 + i * 1.5), "e8d9a8")
	box(parent, Vector3(14, 4, 0.3), o + Vector3(0, 2, -5), "f6efdf", true)
	box(parent, Vector3(0.3, 4, 10), o + Vector3(-7, 2, 0), "f1e8d4", true)
	box(parent, Vector3(0.3, 4, 10), o + Vector3(7, 2, 0), "f1e8d4", true)
	box(parent, Vector3(5.8, 0.4, 0.3), o + Vector3(-4.1, 0.2, 5), "e3d7bd", true)
	box(parent, Vector3(5.8, 0.4, 0.3), o + Vector3(4.1, 0.2, 5), "e3d7bd", true)
	_wall(parent, Vector3(14, 4, 0.3), o + Vector3(0, 2, 5.4))
	# mihrab niche + arch, minbar steps
	box(parent, Vector3(1.8, 2.8, 0.2), o + Vector3(0, 1.4, -4.8), "1e7a4f")
	mesh_at(parent, cyl_mesh(0.9, 0.9, 0.2, 12), "1e7a4f", o + Vector3(0, 2.8, -4.8)).rotation.x = PI / 2.0
	box(parent, Vector3(1.3, 2.4, 0.22), o + Vector3(0, 1.2, -4.75), "0f5132")
	for st in 3:
		box(parent, Vector3(0.9, 0.3 * (st + 1), 0.7), o + Vector3(2.2 + st * 0.5, 0.15 * (st + 1), -4.4), "8a5a30", st == 0)
	# windows, pillars, mushaf shelf, sandal rack by the door
	for wx in [-5.0, -2.8, 2.8, 5.0]:
		box(parent, Vector3(1.0, 1.6, 0.1), o + Vector3(wx, 2.2, -4.82), "8ec9ff")
	for px in [-3.5, 3.5]:
		for pz in [-1.5, 2.0]:
			mesh_at(parent, cyl_mesh(0.25, 0.25, 4.0, 10), "fbf6ea", o + Vector3(px, 2.0, pz))
			solid_cylinder(parent, 0.3, 4.0, o + Vector3(px, 0, pz))
	box(parent, Vector3(0.5, 1.6, 2.2), o + Vector3(-6.6, 0.8, -2.0), "7a4b2a", true)
	for r in 3:
		box(parent, Vector3(0.45, 0.06, 2.0), o + Vector3(-6.5, 0.4 + r * 0.45, -2.0), "a8743f")
		box(parent, Vector3(0.25, 0.3, 1.6), o + Vector3(-6.5, 0.6 + r * 0.45, -2.0), "1e7a4f")
	box(parent, Vector3(1.6, 0.5, 0.5), o + Vector3(-2.6, 0.25, 4.5), "8a5a30", true)

## Street lamps along the roads. Bulbs use one shared emissive material per lamp.
static func street_lamps(parent: Node3D) -> void:
	for p in [[-6.0, 3.6], [6.0, 3.6], [-14.0, 3.6], [14.0, 3.6], [1.9, 9.0], [1.9, -6.0], [-1.9, 14.0]]:
		var x: float = p[0]
		var z: float = p[1]
		mesh_at(parent, cyl_mesh(0.07, 0.09, 2.6, 6), "3b3b3b", Vector3(x, 1.3, z))
		box(parent, Vector3(0.5, 0.06, 0.06), Vector3(x, 2.6, z), "3b3b3b")
		var bulb := SphereMesh.new()
		bulb.radius = 0.16
		bulb.height = 0.32
		bulb.radial_segments = 8
		bulb.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("fff1c4")
		m.emission_enabled = true
		m.emission = Color("ffd36b")
		m.emission_energy_multiplier = 0.0
		var b := MeshInstance3D.new()
		b.mesh = bulb
		b.material_override = m
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = Vector3(x + 0.22, 2.45, z)
		parent.add_child(b)
		lamp_mats.append(m)
		solid_cylinder(parent, 0.15, 2.6, Vector3(x, 0, z))
		# light pool on the ground (alpha raised at night)
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 2.2
		disc.bottom_radius = 2.2
		disc.height = 0.01
		disc.radial_segments = 20
		pool.mesh = disc
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_color = Color(1.0, 0.85, 0.45, 0.0)
		pool.material_override = pm
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position = Vector3(x + 0.22, 0.03, z)
		parent.add_child(pool)
		lamp_pools.append(pm)

## Bu Aminah's living room at AMINAH_IN (10 x 8): mat, low table with dishes, cupboard.
static func aminah_interior(parent: Node3D) -> void:
	var o := AMINAH_IN
	flat(parent, Vector2(10, 8), o + Vector3(0, 0.01, 0), "d9b98a")
	box(parent, Vector3(10, 3, 0.3), o + Vector3(0, 1.5, -4), "f6e3c0", true)
	box(parent, Vector3(0.3, 3, 8), o + Vector3(-5, 1.5, 0), "f1dcb6", true)
	box(parent, Vector3(0.3, 3, 8), o + Vector3(5, 1.5, 0), "f1dcb6", true)
	box(parent, Vector3(4.0, 0.4, 0.3), o + Vector3(-3.0, 0.2, 4), "e8cfa6", true)
	box(parent, Vector3(4.0, 0.4, 0.3), o + Vector3(3.0, 0.2, 4), "e8cfa6", true)
	_wall(parent, Vector3(10, 3, 0.3), o + Vector3(0, 1.5, 4.4))
	flat(parent, Vector2(4.2, 2.8), o + Vector3(0.4, 0.02, -1.4), "b0473a")
	box(parent, Vector3(2.4, 0.35, 1.2), o + Vector3(0.4, 0.18, -1.4), "8a5a30", true)
	for i in 4:
		var px := -0.4 + i * 0.55
		mesh_at(parent, cyl_mesh(0.2, 0.18, 0.06, 10), "fff4e1", o + Vector3(px, 0.39, -1.4))
	mesh_at(parent, cyl_mesh(0.28, 0.22, 0.2, 10), "f6b73c", o + Vector3(0.4, 0.46, -1.4))
	box(parent, Vector3(1.6, 2.0, 0.5), o + Vector3(-4.0, 1.0, -3.4), "7a4b2a", true)
	for r in 3:
		box(parent, Vector3(1.4, 0.05, 0.42), o + Vector3(-4.0, 0.6 + r * 0.5, -3.2), "a8743f")
	box(parent, Vector3(1.2, 1.0, 0.1), o + Vector3(2.6, 1.8, -3.82), "8ec9ff")
	box(parent, Vector3(0.15, 2.2, 0.15), o + Vector3(-0.8, 1.1, 4.0), "5b3519")
	box(parent, Vector3(0.15, 2.2, 0.15), o + Vector3(0.8, 1.1, 4.0), "5b3519")

static func bounds(parent: Node3D) -> void:
	var h := HALF
	for spec in [
		[Vector3(2 * h + 2, 2, 0.5), Vector3(0, 1, -h - 0.25)],
		[Vector3(2 * h + 2, 2, 0.5), Vector3(0, 1, h + 0.25)],
		[Vector3(0.5, 2, 2 * h + 2), Vector3(-h - 0.25, 1, 0)],
		[Vector3(0.5, 2, 2 * h + 2), Vector3(h + 0.25, 1, 0)],
	]:
		var body := StaticBody3D.new()
		body.position = spec[1]
		parent.add_child(body)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = spec[0]
		cs.shape = sh
		body.add_child(cs)
	var i := -h
	while i <= h:
		for p in [Vector3(i, 0.45, -h - 0.3), Vector3(i, 0.45, h + 0.3), Vector3(-h - 0.3, 0.45, i), Vector3(h + 0.3, 0.45, i)]:
			box(parent, Vector3(0.22, 0.9, 0.22), p, "a8743f")
		i += 2.0

static func build_kampung(world: Node3D) -> void:
	fade_targets.clear()
	map_shapes.clear()
	lamp_mats.clear()
	lamp_pools.clear()
	flat(world, Vector2(90, 90), Vector3(0, 0, 0), "86c45e")
	flat(world, Vector2(2 * HALF + 1, 2 * HALF + 1), Vector3(0, 0.005, 0), "8fcd63")
	# paths
	for p in [[0, 4.5, 2.6, 29], [0, 2, 2 * HALF, 2.4], [-10, 6.8, 2, 9.6], [10, 6.8, 2, 9.6], [-10, -0.2, 2, 3], [0, -9.5, 5, 1.6]]:
		flat(world, Vector2(p[2], p[3]), Vector3(p[0], 0.02, p[1]), "e3c48f")
		_map(p[0], p[1], p[2], p[3], "e9cf9c")
	# buildings
	house(world, -10, -4, 6, 5, "fff1d6", "c8553d")   # rumah pemain
	house(world, -10, 8, 6, 5, "f6e3c0", "d07a3a")    # Bu Aminah
	house(world, 10, 8, 6, 5, "f3ead8", "3f78b5")     # Pak Hasan (atap biru)
	house(world, -16, 9.5, 4, 4, "fbe8c8", "b8613b")
	house(world, 15.5, 9.5, 4, 4, "efe1c6", "7a9a3a")
	mosque(world, 0, -14)
	_map(0, -14, 10, 8, "1f8a57")
	wudhu_station(world, -4.3, -8.5)
	# market stall + garden blockout
	box(world, Vector3(4, 0.9, 1.2), Vector3(11, 0.45, -5.4), "a8743f", true)
	box(world, Vector3(4.2, 0.12, 2.4), Vector3(11, 2.45, -6), "d9473a")
	garden(world)
	_map(11, -6, 4, 2, "d9473a")
	_map(-12.5, -14.5, 7.8, 5.8, "7a5233")
	# pond
	var pond := mesh_at(world, cyl_mesh(3.2, 3.2, 0.05, 16), "5aa9e6", Vector3(15, 0.03, -15))
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	solid_cylinder(world, 3.2, 1.0, Vector3(15, 0, -15))
	# trees
	var trees := [[-17, -3], [-16.5, 5], [-17, 16], [16.5, 16], [17, 3], [16.5, -4], [-4, 16.5], [13.5, 17], [-11, 17], [6.5, -11], [5.5, -3.5], [17, -9], [-7.5, -18], [17.5, -18], [-17.5, -9]]
	for idx in trees.size():
		tree(world, trees[idx][0], trees[idx][1], 1.0 + (idx % 3) * 0.18)
		_map(trees[idx][0], trees[idx][1], 1.6, 1.6, "2f8a45", true)
	_map(15, -15, 6.4, 6.4, "5aa9e6", true)
	interior(world)
	masjid_interior(world)
	aminah_interior(world)
	street_lamps(world)
	bounds(world)
