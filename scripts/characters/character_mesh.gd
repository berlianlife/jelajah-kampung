class_name CharacterMesh
extends RefCounted
## Builds faceless low-poly characters from a look dictionary.
## No eyes, nose, mouth or lip-sync. Emotion only through body animation.
## Look keys: robe, pants, dress(bool), hijab, cap, peci, bag(bool). Colors as hex strings.

const SKIN := Color("e6b48a")

static func _c(v: Variant, fallback: String) -> Color:
	if v is Color:
		return v
	return Color(str(v)) if v != null else Color(fallback)

static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m

static func cyl(top: float, bottom: float, h: float, seg: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func sph(r: float, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 12
	s.rings = 6
	return s

static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func build(o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var robe := _c(o.get("robe"), "22A061")
	var pants := _c(o.get("pants"), "efe6d4")
	var dress: bool = o.get("dress", false)

	if not dress:
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.name = "LegL" if side < 0 else "LegR"
			leg.position = Vector3(0.13 * side, 0.62, 0)
			root.add_child(leg)
			part(leg, cyl(0.1, 0.1, 0.6), pants, Vector3(0, -0.3, 0))
		part(root, cyl(0.27, 0.36, 0.82), robe, Vector3(0, 1.0, 0))
	else:
		part(root, cyl(0.27, 0.5, 1.35, 10), robe, Vector3(0, 0.68, 0))

	var arm_color := _c(o.get("hijab"), "22A061") if dress else robe
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(0.33 * side, 1.3, 0)
		root.add_child(arm)
		part(arm, cyl(0.08, 0.08, 0.58), arm_color, Vector3(0, -0.29, 0))
		part(arm, sph(0.08), SKIN, Vector3(0, -0.6, 0))

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.66
	root.add_child(head)
	if o.has("hijab"):
		var hc := _c(o["hijab"], "7B61FF")
		part(head, sph(0.34), hc, Vector3.ZERO)
		part(head, cyl(0.0, 0.5, 0.62, 12), hc, Vector3(0, -0.38, 0))
		var face := part(head, sph(0.23), SKIN, Vector3(0, -0.02, 0.22))
		face.scale = Vector3(1, 1.18, 0.55)
	else:
		part(head, sph(0.3), SKIN, Vector3.ZERO)
		if o.has("cap"):
			part(head, sph(0.31, true), _c(o["cap"], "ffffff"), Vector3(0, 0.04, 0))
		if o.has("peci"):
			part(head, cyl(0.27, 0.3, 0.2, 10), _c(o["peci"], "2b2418"), Vector3(0, 0.22, 0))

	if o.has("scale"):
		root.scale = Vector3.ONE * float(o["scale"])
	if o.get("bag", false):
		var bag := BoxMesh.new()
		bag.size = Vector3(0.42, 0.48, 0.2)
		part(root, bag, Color("8a5a30"), Vector3(0, 1.08, -0.33))
	return root

## Walk cycle / idle. Model faces +Z.
static func animate(model: Node3D, delta: float, moving: bool) -> void:
	var phase: float = model.get_meta("phase", 0.0)
	phase = phase + delta * 11.0 if moving else phase * 0.85
	model.set_meta("phase", phase)
	var s := sin(phase) * (0.65 if moving else 0.0)
	var leg_l := model.get_node_or_null("LegL") as Node3D
	if leg_l:
		leg_l.rotation.x = s
		(model.get_node("LegR") as Node3D).rotation.x = -s
	(model.get_node("ArmL") as Node3D).rotation.x = -s * 0.8
	var wave: float = model.get_meta("wave", 0.0)
	var arm_r := model.get_node("ArmR") as Node3D
	if wave > 0.0:
		wave -= delta
		arm_r.rotation.x = -2.6 + sin(wave * 14.0) * 0.25
	else:
		arm_r.rotation.x = s * 0.8
	model.set_meta("wave", wave)
	(model.get_node("Head") as Node3D).position.y =1.66 + (absf(sin(phase)) * 0.05 if moving else 0.0)
