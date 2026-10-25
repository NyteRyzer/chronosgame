extends CharacterBody3D
## The independent time traveller: third-person movement and camera, the
## Time Pad bracer on the left forearm, and the equipped weapon in the right
## hand. Powers and weapon logic live in main.gd.

const WALK := 6.0
const SPRINT := 10.0
const JUMP := 6.5
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025

const EraData = preload("res://scripts/era_data.gd")
const Humanoid = preload("res://scripts/humanoid.gd")

var stun := 0.0
var knock := Vector3.ZERO
var held = null  # the prop being carried (prop.gd)
var yaw := 0.0
var pitch := -0.25
var rig: Node3D
var spring: SpringArm3D
var camera: Camera3D
var _model: Humanoid
var _core: MeshInstance3D
var _weapon_pivot: Node3D
var _weapons: Array = []
var weapon_index := 0
# driving (GTA-style hijacking)
var driving := false
var vehicle: Node3D = null
var vehicle_label := ""
var car_speed := 0.0
var car_yaw := 0.0
var car_top_speed := 40.0
var crashed := 0.0
# Time Dodge (Quantum Break-style dash)
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var _cap_shape: CollisionShape3D
var _car_shape: CollisionShape3D
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
	_cap_shape = shape
	_car_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 1.4, 4.8)
	_car_shape.shape = box
	_car_shape.position.y = 0.9
	_car_shape.disabled = true
	add_child(_car_shape)

	_model = Humanoid.new()
	add_child(_model)
	_model.build(EraData.PLAYER_OUTFIT)
	# Time Pad bracer on the left forearm: housing + glowing screen
	var housing := BoxMesh.new()
	housing.size = Vector3(0.13, 0.11, 0.24)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("2a2f3a")
	hm.metallic = 0.8
	hm.roughness = 0.3
	var bracer := _add_mesh(_model.left_forearm, housing, Vector3(0, -0.16, 0), hm)
	bracer.rotation_degrees.x = 90
	var screen := BoxMesh.new()
	screen.size = Vector3(0.09, 0.02, 0.18)
	_core = _add_mesh(_model.left_forearm, screen, Vector3(0, -0.16, 0.06), _glow(Color("5fd4ff")))
	_core.rotation_degrees.x = 90
	# weapons in the right hand
	_weapon_pivot = Node3D.new()
	_weapon_pivot.rotation_degrees.x = 90  # point the weapon along the forearm
	_model.right_hand.add_child(_weapon_pivot)
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
	weapon_index = i
	for k in range(_weapons.size()):
		_weapons[k].visible = k == i


func swing() -> void:
	_model.swing()


## Turn the body to face where the camera aims (used when attacking).
func face_aim() -> void:
	var d := aim_dir()
	_model.rotation.y = atan2(d.x, d.z)


func muzzle() -> Vector3:
	return _weapon_pivot.global_position


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


func dashing() -> bool:
	return dash_t > 0.0


func dash(dir: Vector3) -> void:
	dash_dir = Vector3(dir.x, 0, dir.z).normalized()
	dash_t = 0.2


func enter_vehicle(v: Node3D, top_speed: float) -> void:
	driving = true
	vehicle = v
	vehicle_label = v.label
	car_top_speed = top_speed
	car_yaw = v.global_rotation.y
	car_speed = 0.0
	global_position = Vector3(v.global_position.x, global_position.y, v.global_position.z)
	v.get_parent().remove_child(v)
	add_child(v)
	v.position = Vector3.ZERO
	v.rotation = Vector3(0, car_yaw, 0)
	_model.visible = false
	_cap_shape.disabled = true
	_car_shape.disabled = false
	_car_shape.rotation.y = car_yaw
	spring.spring_length = 9.0


## Leaves the vehicle; returns it so the caller can park it in the world.
func exit_vehicle() -> Node3D:
	var v := vehicle
	var xf := v.global_transform
	remove_child(v)
	v.transform = xf
	driving = false
	vehicle = null
	car_speed = 0.0
	_model.visible = true
	_cap_shape.disabled = false
	_car_shape.disabled = true
	spring.spring_length = 5.5
	global_position += Basis(Vector3.UP, car_yaw) * Vector3(-2.8, 0, 0)
	return v


func _drive(delta: float) -> void:
	var throttle := Input.get_axis("move_down", "move_up")
	var steer := Input.get_axis("move_right", "move_left")
	if Input.is_action_pressed("jump"):
		car_speed = move_toward(car_speed, 0.0, 30.0 * delta)
	elif throttle != 0.0:
		car_speed = clampf(car_speed + throttle * 14.0 * delta, -10.0, car_top_speed)
	else:
		car_speed = move_toward(car_speed, 0.0, 4.0 * delta)
	var grip := clampf(absf(car_speed) / 8.0, 0.0, 1.0)
	car_yaw += steer * 1.7 * delta * grip * signf(car_speed)
	var fwd := Vector3(sin(car_yaw), 0, cos(car_yaw))
	velocity.x = fwd.x * car_speed
	velocity.z = fwd.z * car_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# hitting a wall at speed bleeds most of it off
	if get_slide_collision_count() > 0 and absf(car_speed) > 12.0:
		var n := get_slide_collision(0).get_normal()
		if absf(n.y) < 0.5 and fwd.dot(-n) > 0.5:
			car_speed *= 0.35
			crashed = 0.5
	crashed = maxf(crashed - delta, 0.0)
	vehicle.rotation.y = car_yaw
	_car_shape.rotation.y = car_yaw
	if absf(car_speed) > 2.0:
		yaw = lerp_angle(yaw, car_yaw + PI, 3.0 * delta)
		pitch = lerpf(pitch, -0.22, 2.0 * delta)
	update_camera()


func step(delta: float) -> void:
	_t += delta
	if driving:
		_drive(delta)
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var basis_yaw := Basis(Vector3.UP, yaw)
	var wish := basis_yaw * Vector3(input.x, 0, input.y)
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	if dash_t > 0.0:
		dash_t -= delta
		velocity.x = dash_dir.x * 45.0
		velocity.z = dash_dir.z * 45.0
	elif stun > 0.0:
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
	# ranged weapons/gadgets are held up and the body turns to the aim
	_model.aim = weapon_index != 0 and held == null
	if _model.aim and stun <= 0.0:
		var d := aim_dir()
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(d.x, d.z), 14.0 * delta)
	_model.animate(delta, Vector2(velocity.x, velocity.z).length())


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
