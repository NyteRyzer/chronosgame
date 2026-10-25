extends RefCounted
## Small procedural-mesh helpers for vehicles and props.

## Extrudes a convex side-view profile (points as (z, y), counter-clockwise when
## viewed from +X) across the X axis. Gives car bodies real silhouettes.
static func extrude(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var hw := width / 2.0
	var n := profile.size()
	# side caps (triangle fans)
	for i in range(1, n - 1):
		_tri(st, Vector3(hw, profile[0].y, profile[0].x), Vector3(hw, profile[i + 1].y, profile[i + 1].x), Vector3(hw, profile[i].y, profile[i].x))
		_tri(st, Vector3(-hw, profile[0].y, profile[0].x), Vector3(-hw, profile[i].y, profile[i].x), Vector3(-hw, profile[i + 1].y, profile[i + 1].x))
	# band around the outline
	for i in range(n):
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var a0 := Vector3(-hw, a.y, a.x)
		var a1 := Vector3(hw, a.y, a.x)
		var b0 := Vector3(-hw, b.y, b.x)
		var b1 := Vector3(hw, b.y, b.x)
		_tri(st, a0, a1, b1)
		_tri(st, a0, b1, b0)
	st.generate_normals()
	return st.commit()


## Godot treats clockwise triangles as front faces, so emit in reverse.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func mat(c: Color, metallic := 0.0, rough := 0.7, emissive := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.metallic = metallic
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.2
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func add(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(r: float, segments := 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segments
	m.rings = segments / 2
	return m


static func cylinder(r_top: float, r_bottom: float, h: float, segments := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segments
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m


## A wheel on an axle pivot (rotate the returned node around X to spin it).
static func wheel(parent: Node3D, pos: Vector3, radius: float, width: float, tyre: Material, hub: Material, spokes := 0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	add(pivot, cylinder(radius, radius, width, 20), Vector3.ZERO, tyre, Vector3(0, 0, 90))
	add(pivot, cylinder(radius * 0.55, radius * 0.55, width + 0.02, 16), Vector3.ZERO, hub, Vector3(0, 0, 90))
	for k in range(spokes):
		var s := add(pivot, box(Vector3(width * 0.6, radius * 1.8, 0.05)), Vector3.ZERO, hub)
		s.rotation.x = PI * k / spokes
	return pivot


static func capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 16
	m.rings = 6
	return m
