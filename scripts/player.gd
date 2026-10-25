extends CharacterBody3D
## The independent time traveller: third-person movement and camera, the
## Time Pad bracer on the left forearm, and the equipped weapon in the right
## hand. Powers and weapon logic live in main.gd.

const WALK := 6.0
const SPRINT := 10.0
const JUMP := 6.5
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025

var stun := 0.0
var knock := Vector3.ZERO
var held = null  # the prop being carried (prop.gd)
var yaw := 0.0
var pitch := -0.25
var rig: Node3D
var spring: SpringArm3D
var camera: Camera3D
var _model: Node3D
var _core: MeshInstance3D
var _weapon_pivot: Node3D
var _weapons: Array = []
var _swing := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_model = Node3D.new()
	add_child(_model)
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.75
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color("e8e8ee")
	_add_mesh(_model, body, Vector3(0, 0.88, 0), coat)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.5, 0.12, 0.2)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color("5fd4ff")
	vm.emission_enabled = true
	vm.emission = Color("5fd4ff")
	_add_mesh(_model, visor, Vector3(0, 1.45, 0.3), vm)
	# arms
	var arm := CapsuleMesh.new()
	arm.radius = 0.11
	arm.height = 0.75
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color("c8c8d2")
	for side in [-1.0, 1.0]:
		var a := _add_mesh(_model, arm, Vector3(side * 0.5, 1.1, 0.12), sleeve)
		a.rotation_degrees.x = 60
	# Time Pad bracer on the left forearm: housing + glowing screen
	var housing := BoxMesh.new()
	housing.size = Vector3(0.24, 0.16, 0.38)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("2a2f3a")
	hm.metallic = 0.8
	hm.roughness = 0.3
	_add_mesh(_model, housing, Vector3(0.52, 0.98, 0.32), hm)
	var screen := BoxMesh.new()
	screen.size = Vector3(0.18, 0.04, 0.28)
	_core = _add_mesh(_model, screen, Vector3(0.52, 1.07, 0.32), vm)
	# weapons in the right hand
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(-0.52, 0.95, 0.4)
	_model.add_child(_weapon_pivot)
	_weapons = [_make_blade(), _make_pistol(), _make_orb(Color("6fd8ff")), _make_orb(Color("c070ff"))]
	set_weapon(0)

	rig = Node3D.new()
	rig.top_level = true
	add_child(rig)
	spring = SpringArm3D.new()
	spring.spring_length = 5.5
	spring.collision_mask = 1
	spring.margin = 0.3
	spring.position = Vector3(0.7, 0, 0)
	rig.add_child(spring)
	camera = Camera3D.new()
	camera.far = 2000.0
	camera.fov = 70.0
	spring.add_child(camera)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	return m


func _make_blade() -> Node3D:
	var n := Node3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 0.08, 1.1)
	_add_mesh(n, blade, Vector3(0, 0, 0.6), _glow(Color("5fd4ff")))
	var hilt := BoxMesh.new()
	hilt.size = Vector3(0.08, 0.08, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("222222")
	_add_mesh(n, hilt, Vector3.ZERO, dark)
	_weapon_pivot.add_child(n)
	return n


func _make_pistol() -> Node3D:
	var n := Node3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("30343c")
	dark.metallic = 0.7
	var grip := BoxMesh.new()
	grip.size = Vector3(0.1, 0.22, 0.12)
	_add_mesh(n, grip, Vector3(0, -0.08, 0), dark)
	var body := BoxMesh.new()
	body.size = Vector3(0.12, 0.12, 0.42)
	_add_mesh(n, body, Vector3(0, 0.05, 0.15), dark)
	var coil := BoxMesh.new()
	coil.size = Vector3(0.13, 0.04, 0.2)
	_add_mesh(n, coil, Vector3(0, 0.12, 0.2), _glow(Color("ff7a33")))
	_weapon_pivot.add_child(n)
	return n


func _make_orb(c: Color) -> Node3D:
	var n := Node3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.12
	orb.height = 0.24
	_add_mesh(n, orb, Vector3(0, 0.05, 0.1), _glow(c))
	_weapon_pivot.add_child(n)
	return n


func set_weapon(i: int) -> void:
	for k in range(_weapons.size()):
		_weapons[k].visible = k == i


func swing() -> void:
	_swing = 0.25


## Turn the body to face where the camera aims (used when attacking).
func face_aim() -> void:
	var d := aim_dir()
	_model.rotation.y = atan2(d.x, d.z)


func muzzle() -> Vector3:
	return _weapon_pivot.global_position + _model.global_basis.z * 0.4


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func look(relative: Vector2) -> void:
	yaw -= relative.x * MOUSE_SENS
	pitch = clampf(pitch - relative.y * MOUSE_SENS, -1.2, 0.6)


func step(delta: float) -> void:
	_t += delta
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var basis_yaw := Basis(Vector3.UP, yaw)
	var wish := basis_yaw * Vector3(input.x, 0, input.y)
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	if stun > 0.0:
		stun -= delta
		velocity.x = knock.x
		velocity.z = knock.z
		knock = knock.move_toward(Vector3.ZERO, 30.0 * delta)
	else:
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		if wish.length() > 0.1:
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(wish.x, wish.z), 12.0 * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and stun <= 0.0:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	update_camera()
	_core.scale = Vector3.ONE * (1.0 + 0.15 * sin(_t * 5.0))
	if _swing > 0.0:
		_swing = maxf(_swing - delta, 0.0)
		_weapon_pivot.rotation = Vector3(0, lerpf(-1.4, 1.2, 1.0 - _swing / 0.25), 0)
	else:
		_weapon_pivot.rotation = Vector3.ZERO


func update_camera() -> void:
	rig.global_position = global_position + Vector3(0, 1.7, 0)
	rig.rotation = Vector3(pitch, yaw, 0)


func aim_origin() -> Vector3:
	return camera.global_position


func aim_dir() -> Vector3:
	return -camera.global_basis.z


## Horizontal facing used for carrying objects.
func carry_point() -> Vector3:
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	return global_position + Vector3(0, 1.1, 0) + fwd * 1.0 + Basis(Vector3.UP, yaw) * Vector3(0.5, 0, 0)
