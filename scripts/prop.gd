extends RigidBody3D
## A rewindable physics object. Records a rolling state buffer every physics
## frame so the ChronoCore can reverse it (the "local rewind" system).

const EraData = preload("res://scripts/era_data.gd")

const BUFFER_MAX := 300  # 5 seconds at 60 Hz

var kind := "crate"
var sunk := false
var held := false
var was_thrown := false
var rewinding := false
var buffer: Array = []
var _pending_lin := Vector3.ZERO
var _pending_ang := Vector3.ZERO
var _mesh: MeshInstance3D
var _ring: MeshInstance3D
var _ghost: MeshInstance3D


func setup(k: String, pos: Vector3, is_sunk := false) -> void:
	kind = k
	position = pos
	sunk = is_sunk


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 8
	continuous_cd = true
	mass = 4.0 if EraData.is_block_kind(kind) else 0.5
	var shape := CollisionShape3D.new()
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	match kind:
		"crate", "rock", "scrap":
			var b := BoxShape3D.new()
			b.size = Vector3(0.9, 0.9, 0.9)
			shape.shape = b
			var bm := BoxMesh.new()
			bm.size = b.size
			_mesh.mesh = bm
			mat.albedo_color = {"crate": Color("a0703c"), "rock": Color("7a7468"), "scrap": Color("7a4a2a")}[kind]
		_:
			var s := SphereShape3D.new()
			s.radius = 0.25
			shape.shape = s
			var sm := SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.5
			_mesh.mesh = sm
			var c: Color = {"seed": Color("6fbf4a"), "cell": Color("2ee6d6"), "phone": Color("9fc8ff"), "egg": Color("f0e2b6"), "gear": Color("d8a640")}.get(kind, Color.WHITE)
			mat.albedo_color = c
			mat.emission_enabled = true
			mat.emission = c
			mat.emission_energy_multiplier = 1.5
	_mesh.material_override = mat
	add_child(shape)
	add_child(_mesh)
	_ring = _make_ring(Color(1, 1, 1, 0.5), 0.8)
	_ghost = _make_ring(Color("5fd4ff"), 0.9)
	_apply_sunk_state()


func _make_ring(c: Color, r: float) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r
	t.outer_radius = r + 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


func display_name() -> String:
	match kind:
		"seed":
			return "Oak seed"
		"cell":
			return "Plasma cell (2150 tech)"
		"rock":
			return "Rock"
		"phone", "egg", "gear":
			return "%s (aberration)" % EraData.ABERRATIONS[kind].name
		"scrap":
			return "Scrap"
	return "Crate"


func set_held(h: bool) -> void:
	held = h
	freeze = h
	collision_layer = 0 if h else 8
	collision_mask = 0 if h else (1 | 8)
	if h:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func record() -> void:
	buffer.append([global_transform, linear_velocity, angular_velocity, sunk])
	if buffer.size() > BUFFER_MAX:
		buffer.pop_front()


## Applies one recorded frame in reverse. Returns false when the buffer is empty.
func rewind_step() -> bool:
	if buffer.is_empty():
		return false
	var s: Array = buffer.pop_back()
	freeze = true
	global_transform = s[0]
	_pending_lin = s[1]
	_pending_ang = s[2]
	sunk = s[3]
	rewinding = true
	_apply_sunk_state()
	return true


## Called every physics frame when this prop is not being rewound.
func simulate() -> void:
	if rewinding:
		rewinding = false
		if not held and not sunk:
			freeze = false
			linear_velocity = _pending_lin
			angular_velocity = _pending_ang
	_ghost.visible = false
	if held or sunk:
		return
	if global_position.y < EraData.SINK_Y and global_position.x < EraData.RIVER_X:
		sunk = true
		_apply_sunk_state()


func _apply_sunk_state() -> void:
	if sunk:
		freeze = true
		_mesh.visible = false
		_ring.visible = true
		_ring.global_position = Vector3(global_position.x, -0.6, global_position.z)
	else:
		_mesh.visible = true
		_ring.visible = false
		if not held and not rewinding:
			freeze = false
	if rewinding:
		_ghost.visible = true
		_ghost.global_position = global_position


func clear_history() -> void:
	buffer.clear()
