extends CharacterBody3D
## Chrono Enforcement Bureau field agent. Telegraphs arrival through a portal,
## then pursues along the street grid. Can be frozen (briefly - agents resist),
## stunned by thrown objects, outrun, or shaken off with an era jump while it
## can't track you.

const EraData = preload("res://scripts/era_data.gd")
const Humanoid = preload("res://scripts/humanoid.gd")

const SPEED := 7.6
const CATCH_RADIUS := 1.5
const GRAVITY := 20.0
const REPATH := 0.4

var state := "portal"  # portal -> chase
var portal_time := 2.5
var portal_total := 2.5
var frozen := 0.0
var stunned := 0.0
var hp := 100.0
var hunter := false    # Terminator-style HK unit: cannot be destroyed
var jammed := 0.0      # hacked: tracking offline
var path := PackedVector3Array()
var path_provider: Callable  # func(from: Vector3, to: Vector3) -> PackedVector3Array
var _repath := 0.0
var _model: Humanoid
var _portal: MeshInstance3D
var _ice: MeshInstance3D
var _label: Label3D
var _t := 0.0


func speed() -> float:
	return 6.7 if hunter else SPEED


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	shape.shape = cap
	shape.position.y = 0.95
	add_child(shape)
	_model = Humanoid.new()
	add_child(_model)
	_model.build(EraData.HUNTER_OUTFIT if hunter else EraData.COP_OUTFIT)
	var baton := BoxMesh.new()
	baton.size = Vector3(0.05, 0.05, 0.6)
	var b := _mesh(_model.right_hand, baton, Vector3(0, -0.25, 0.05), _mat(Color("ff5a3a"), true))
	b.rotation_degrees.x = 80
	var ring := TorusMesh.new()
	ring.inner_radius = 1.6
	ring.outer_radius = 2.0
	_portal = _mesh(self, ring, Vector3(0, 1.4, 0), _mat(Color("ff7a33"), true))
	_portal.rotation_degrees.x = 90
	var ice := SphereMesh.new()
	ice.radius = 1.0
	ice.height = 2.4
	_ice = _mesh(self, ice, Vector3(0, 1.0, 0), _mat(Color(0.5, 0.85, 1.0), true, 0.35))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.outline_size = 8
	_label.pixel_size = 0.012
	_label.no_depth_test = true
	_label.position.y = 2.7
	_label.modulate = Color("ff8a8a")
	add_child(_label)
	_update_visuals()


func _mat(c: Color, emissive := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if emissive:
		m.emission_enabled = true
		m.emission = c
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func open_portal(seconds: float) -> void:
	state = "portal"
	portal_time = seconds
	portal_total = seconds


func can_track() -> bool:
	return state == "chase" and frozen <= 0.0 and stunned <= 0.0 and jammed <= 0.0


## Returns true when the agent catches the player this frame.
func step(delta: float, target: Vector3) -> bool:
	_t += delta
	_update_visuals()
	if state == "portal":
		portal_time -= delta
		_portal.rotate_object_local(Vector3.FORWARD, delta * 6.0)
		if portal_time <= 0.0:
			state = "chase"
		return false
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		return false
	if stunned > 0.0:
		stunned = maxf(stunned - delta, 0.0)
		velocity = Vector3.ZERO
		return false
	if jammed > 0.0:
		jammed = maxf(jammed - delta, 0.0)
		_model.animate(delta, 0.0)
		return false
	_repath -= delta
	if _repath <= 0.0 and path_provider.is_valid():
		path = path_provider.call(global_position, target)
		_repath = REPATH
	var goal := target
	while path.size() > 0 and Vector2(path[0].x - global_position.x, path[0].z - global_position.z).length() < 1.5:
		path.remove_at(0)
	if path.size() > 1:
		goal = path[0]
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var dir := to.normalized() if to.length() > 0.01 else Vector3.ZERO
	velocity.x = dir.x * speed()
	velocity.z = dir.z * speed()
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if dir.length() > 0.1:
		_model.rotation.y = atan2(dir.x, dir.z)
	_model.animate(delta, Vector2(velocity.x, velocity.z).length())
	return global_position.distance_to(target) < CATCH_RADIUS


func _update_visuals() -> void:
	_portal.visible = state == "portal"
	_model.visible = state != "portal" or portal_time < 0.6
	_ice.visible = frozen > 0.0
	if state == "portal":
		var k := 1.0 - portal_time / portal_total
		_portal.scale = Vector3.ONE * (0.3 + 0.9 * k)
		_label.text = "BUREAU PORTAL %.1fs" % maxf(portal_time, 0.0)
	else:
		var who := "HK-800 HUNTER-KILLER" if hunter else "TIME COP %d%%" % int(hp)
		if frozen > 0.0:
			_label.text = "%s - FROZEN %.1fs" % [who, frozen]
		elif jammed > 0.0:
			_label.text = "%s - SIGNAL JAMMED" % who
		elif stunned > 0.0:
			_label.text = "%s - STAGGERED" % who
		else:
			_label.text = who
