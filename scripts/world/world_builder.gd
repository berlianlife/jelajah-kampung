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
		m.roughness = 0.9
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
	fade_targets.append({"mats": mats, "min_x": x - w / 2.0, "max_x": x + w / 2.0, "min_z": z - d / 2.0, "max_z": z + d / 2.0, "cur": 1.0})

## Call every frame with the player position.
static func update_fades(p: Vector3, delta: float) -> void:
	for b in fade_targets:
		var occ: bool = p.x > b.min_x - 0.8 and p.x < b.max_x + 0.8 and b.max_z > p.z and b.min_z - p.z < 5.5 and p.z < b.max_z
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
	flat(world, Vector2(120, 120), Vector3(0, 0, 0), "86c45e")
	flat(world, Vector2(2 * HALF + 1, 2 * HALF + 1), Vector3(0, 0.005, 0), "8fcd63")
	# paths
	for p in [[0, 4.5, 2.6, 29], [0, 2, 2 * HALF, 2.4], [-10, 6.8, 2, 9.6], [10, 6.8, 2, 9.6], [-10, -0.2, 2, 3], [0, -9.5, 5, 1.6]]:
		flat(world, Vector2(p[2], p[3]), Vector3(p[0], 0.02, p[1]), "e3c48f")
	# buildings
	house(world, -10, -4, 6, 5, "fff1d6", "c8553d")   # rumah pemain
	house(world, -10, 8, 6, 5, "f6e3c0", "d07a3a")    # Bu Aminah
	house(world, 10, 8, 6, 5, "f3ead8", "3f78b5")     # Pak Hasan (atap biru)
	house(world, -16, 9.5, 4, 4, "fbe8c8", "b8613b")
	house(world, 15.5, 9.5, 4, 4, "efe1c6", "7a9a3a")
	mosque(world, 0, -14)
	# market stall + garden blockout
	box(world, Vector3(4, 0.9, 1.2), Vector3(11, 0.45, -5.4), "a8743f", true)
	box(world, Vector3(4.2, 0.12, 2.4), Vector3(11, 2.45, -6), "d9473a")
	garden(world)
	# pond
	var pond := mesh_at(world, cyl_mesh(3.2, 3.2, 0.05, 16), "5aa9e6", Vector3(15, 0.03, -15))
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	solid_cylinder(world, 3.2, 1.0, Vector3(15, 0, -15))
	# trees
	var trees := [[-17, -3], [-16.5, 5], [-17, 16], [16.5, 16], [17, 3], [16.5, -4], [-4, 16.5], [13.5, 17], [-11, 17], [6.5, -11], [-5.5, -7], [5.5, -3.5], [17, -9], [-7.5, -18], [17.5, -18], [-17.5, -9]]
	for idx in trees.size():
		tree(world, trees[idx][0], trees[idx][1], 1.0 + (idx % 3) * 0.18)
	bounds(world)
