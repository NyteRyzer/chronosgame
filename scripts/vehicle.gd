extends Node3D
## Avenue traffic: triceratops herds (Cretaceous), horse carts (1890), yellow cabs
## (2025), cargo drones (2150) and scrap crawlers (AD 30,000).
## One-way avenues like Manhattan; vehicles wrap at the end of the grid.
## Freezable with Stop Time.

const EraData = preload("res://scripts/era_data.gd")

const SIZE := Vector3(2.4, 2.0, 5.0)

var era := EraData.PRESENT
var speed := 12.0
var dir := 1.0
var label := ""
var frozen := 0.0
var _ice: MeshInstance3D
var _rotors: Array = []


func setup(new_era: int, x: float, z: float, direction: float, speed_scale: float) -> void:
	era = new_era
	var info := EraData.era_info(era)
	speed = info.vehicle_speed * speed_scale
	label = info.vehicle
	dir = direction
	position = Vector3(x, 0, z)
	rotation.y = 0.0 if dir > 0 else PI
	_build(info.vehicle_color)


func _build(color: Color) -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = color
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1a1a")
	match era:
		EraData.PREHISTORIC:
			# triceratops: body, head with frill and horns, legs, tail
			_part(BoxMesh.new(), Vector3(2.2, 1.8, 4.0), Vector3(0, 1.7, -0.3), body)
			_part(BoxMesh.new(), Vector3(1.2, 1.0, 1.4), Vector3(0, 1.6, 2.3), body)
			_part(BoxMesh.new(), Vector3(2.6, 1.8, 0.25), Vector3(0, 2.4, 1.7), _color_mat(Color("a06a3a")))
			var horn := _color_mat(Color("e8dcc0"))
			for hx in [-0.4, 0.4]:
				var h := _part(CylinderMesh.new(), Vector3(0.2, 1.1, 0.2), Vector3(hx, 2.2, 3.0), horn)
				h.rotation_degrees.x = 70
			for lz in [-1.6, 1.0]:
				for lx in [-0.8, 0.8]:
					_part(BoxMesh.new(), Vector3(0.5, 1.0, 0.5), Vector3(lx, 0.5, lz), body)
			var tail := _part(BoxMesh.new(), Vector3(0.5, 0.5, 2.2), Vector3(0, 1.4, -3.2), body)
			tail.rotation_degrees.x = -15
		EraData.WASTELAND:
			# scrap crawler: rusted hull, spikes, tracks
			_part(BoxMesh.new(), Vector3(2.4, 1.2, 4.6), Vector3(0, 1.0, 0), body)
			_part(BoxMesh.new(), Vector3(2.6, 0.6, 4.8), Vector3(0, 0.3, 0), dark)
			_part(BoxMesh.new(), Vector3(1.4, 0.8, 1.6), Vector3(0, 2.0, -0.6), _color_mat(Color("5a3a22")))
			var spike := _color_mat(Color("b0a090"))
			for sx in [-0.8, 0.0, 0.8]:
				var sp := _part(CylinderMesh.new(), Vector3(0.15, 1.0, 0.15), Vector3(sx, 1.0, 2.7), spike)
				sp.rotation_degrees.x = 90
			_part(BoxMesh.new(), Vector3(0.4, 0.3, 0.2), Vector3(0, 2.2, 0.3), _color_mat(Color("ff6a2a"), true))
		EraData.PAST:
			_part(BoxMesh.new(), Vector3(2.0, 1.2, 3.2), Vector3(0, 1.3, -0.8), body)
			_part(BoxMesh.new(), Vector3(0.8, 1.4, 2.2), Vector3(0, 1.4, 2.0), _color_mat(Color("5a3a22")))  # horse
			_part(BoxMesh.new(), Vector3(0.5, 0.6, 0.9), Vector3(0, 2.2, 3.1), _color_mat(Color("5a3a22")))
			for wz in [-2.0, 0.4]:
				for wx in [-1.1, 1.1]:
					var w := _part(CylinderMesh.new(), Vector3(0.7, 0.15, 0.7), Vector3(wx, 0.7, wz), dark)
					w.rotation_degrees.z = 90
		EraData.FUTURE:
			_part(BoxMesh.new(), Vector3(2.6, 0.6, 4.2), Vector3(0, 1.8, 0), body)
			for c in [Vector3(-1.5, 2.2, -2), Vector3(1.5, 2.2, -2), Vector3(-1.5, 2.2, 2), Vector3(1.5, 2.2, 2)]:
				var t := TorusMesh.new()
				t.inner_radius = 0.6
				t.outer_radius = 0.75
				var r := MeshInstance3D.new()
				r.mesh = t
				r.position = c
				r.material_override = _color_mat(Color.WHITE, true)
				add_child(r)
				_rotors.append(r)
		_:
			_part(BoxMesh.new(), Vector3(2.0, 0.9, 4.6), Vector3(0, 0.75, 0), body)
			_part(BoxMesh.new(), Vector3(1.8, 0.7, 2.4), Vector3(0, 1.5, -0.2), _color_mat(Color("2a3a4a")))
			_part(BoxMesh.new(), Vector3(0.6, 0.25, 0.3), Vector3(0, 2.0, -0.2), _color_mat(Color("fff2c0"), true))
	var ice_mesh := BoxMesh.new()
	ice_mesh.size = SIZE + Vector3(0.6, 0.8, 0.6)
	_ice = MeshInstance3D.new()
	_ice.mesh = ice_mesh
	_ice.position.y = SIZE.y / 2.0 + 0.3
	_ice.material_override = _color_mat(Color(0.5, 0.85, 1.0), true, 0.35)
	_ice.visible = false
	add_child(_ice)


func _color_mat(c: Color, emissive := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if emissive:
		m.emission_enabled = true
		m.emission = c
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _part(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is CylinderMesh:
		mesh.top_radius = size.x / 2.0
		mesh.bottom_radius = size.x / 2.0
		mesh.height = size.y
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func step(delta: float) -> void:
	_ice.visible = frozen > 0.0
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		return
	for r in _rotors:
		r.rotate_y(delta * 20.0)
	position.z += dir * speed * delta
	if position.z > EraData.CITY_MAX.y - 4.0:
		position.z = EraData.CITY_MIN.y + 4.0
	elif position.z < EraData.CITY_MIN.y + 4.0:
		position.z = EraData.CITY_MAX.y - 4.0


## Ground-plane hit test (x, z) with a margin.
func hits(p: Vector3, margin: float) -> bool:
	return absf(p.x - position.x) < SIZE.x / 2.0 + margin and absf(p.z - position.z) < SIZE.z / 2.0 + margin and p.y < 3.5
