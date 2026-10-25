extends Node3D
## Procedural human figure with a jointed rig (shoulders, elbows, hips, knees)
## and a walk cycle. Outfits are plain dictionaries so every era can dress its
## people differently. Faces +Z.
##
## Outfit keys (all optional): skin, hair, hair_style ("short", "long", "bun",
## "bald"), top, bottom, shoes, coat (Color), dress (bool), hat ("top", "bowler",
## "cap", "helmet", "hood", "bonnet"), hat_color, visor (Color, glowing),
## goggles (bool), trim (Color, glowing suit lines), pads (bool), badge (bool),
## scarf (Color), height (scale), build (width scale).

var right_hand: Node3D
var left_forearm: Node3D
var aim := false        # raise the right arm forward (guns, gadgets)
var _shoulders: Array = []
var _elbows: Array = []
var _hips: Array = []
var _knees: Array = []
var _torso: Node3D
var _phase := 0.0
var _swing_t := 0.0
var _mats := {}
var _lod := 0.0
var _chrome := false


func build(o: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_shoulders.clear()
	_elbows.clear()
	_hips.clear()
	_knees.clear()
	_lod = o.get("lod_range", 0.0)
	_chrome = o.get("chrome", false)
	var s: float = o.get("height", 1.0)
	var b: float = o.get("build", 1.0)
	scale = Vector3(b, s, b)
	var skin: Color = o.get("skin", Color("c99a74"))
	var top: Color = o.get("top", Color("4a5a7a"))
	var bottom: Color = o.get("bottom", Color("2a2e38"))
	var shoes: Color = o.get("shoes", Color("1a1a1a"))
	var dress: bool = o.get("dress", false)

	# legs
	for side in [-1.0, 1.0]:
		var hip := _joint(self, Vector3(side * 0.1, 0.92, 0))
		_hips.append(hip)
		_limb(hip, 0.4, 0.075, bottom)
		var knee := _joint(hip, Vector3(0, -0.42, 0))
		_knees.append(knee)
		_limb(knee, 0.4, 0.065, bottom)
		_part(knee, _box(Vector3(0.12, 0.08, 0.26)), Vector3(0, -0.45, 0.05), shoes)

	# torso
	_torso = _joint(self, Vector3(0, 0.92, 0))
	_part(_torso, _box(Vector3(0.34, 0.2, 0.2)), Vector3(0, 0.08, 0), bottom)  # pelvis
	_part(_torso, _capsule(0.17, 0.55), Vector3(0, 0.3, 0), top, Vector3(1.25, 1, 0.75))
	if o.has("coat"):
		# long coat: a slightly larger torso shell that flares past the hips
		_part(_torso, _capsule(0.185, 0.62), Vector3(0, 0.3, -0.005), o.coat, Vector3(1.28, 1, 0.82))
		var hem := CylinderMesh.new()
		hem.top_radius = 0.2
		hem.bottom_radius = 0.27
		hem.height = 0.42
		_part(_torso, hem, Vector3(0, -0.12, 0), o.coat, Vector3(1.1, 1, 0.8))
		_part(_torso, _box(Vector3(0.1, 0.4, 0.02)), Vector3(0, 0.36, 0.15), top)  # shirt showing
	if dress:
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.2
		skirt.bottom_radius = 0.42
		skirt.height = 0.85
		_part(_torso, skirt, Vector3(0, -0.42, 0), o.get("bottom", top))
	if o.has("trim"):
		var glow := _mat(o.trim, true)
		_part(_torso, _box(Vector3(0.03, 0.45, 0.02)), Vector3(-0.09, 0.32, 0.14), glow)
		_part(_torso, _box(Vector3(0.03, 0.45, 0.02)), Vector3(0.09, 0.32, 0.14), glow)
		_part(_torso, _box(Vector3(0.4, 0.03, 0.24)), Vector3(0, 0.02, 0), glow)
	if o.get("pads", false):
		for side in [-1.0, 1.0]:
			_part(_torso, _box(Vector3(0.16, 0.08, 0.2)), Vector3(side * 0.24, 0.55, 0), o.get("hat_color", top).darkened(0.2))
	if o.get("badge", false):
		_part(_torso, _sphere(0.035), Vector3(0.09, 0.42, 0.14), _mat(Color("ffd34d"), true))
	if o.has("scarf"):
		_part(_torso, _box(Vector3(0.3, 0.08, 0.24)), Vector3(0, 0.6, 0.02), o.scarf)

	# head
	var head := _joint(_torso, Vector3(0, 0.68, 0))
	_part(head, _capsule(0.05, 0.1), Vector3(0, -0.04, 0), skin)
	_part(head, _sphere(0.115), Vector3(0, 0.1, 0), skin, Vector3(0.92, 1.08, 1.0))
	var eye := _mat(o.eyes, true) if o.has("eyes") else _mat(Color("1a1a22"))
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.03, 0.02, 0.01)), Vector3(side * 0.04, 0.12, 0.105), eye)
	_part(head, _box(Vector3(0.025, 0.04, 0.03)), Vector3(0, 0.08, 0.115), skin.darkened(0.08))
	var hair: Color = o.get("hair", Color("2a1c12"))
	match o.get("hair_style", "short"):
		"short":
			_part(head, _sphere(0.122), Vector3(0, 0.14, -0.015), hair, Vector3(0.95, 0.8, 1.0))
		"long":
			_part(head, _sphere(0.124), Vector3(0, 0.14, -0.015), hair, Vector3(0.96, 0.82, 1.0))
			_part(head, _box(Vector3(0.22, 0.3, 0.06)), Vector3(0, -0.02, -0.09), hair)
		"bun":
			_part(head, _sphere(0.122), Vector3(0, 0.14, -0.015), hair, Vector3(0.95, 0.8, 1.0))
			_part(head, _sphere(0.06), Vector3(0, 0.2, -0.1), hair)
	if o.get("goggles", false):
		var lens := _mat(Color("ff9a40"), true)
		for side in [-1.0, 1.0]:
			_part(head, _cylinder(0.035, 0.03), Vector3(side * 0.045, 0.13, 0.11), lens, Vector3.ONE, Vector3(90, 0, 0))
		_part(head, _box(Vector3(0.26, 0.03, 0.22)), Vector3(0, 0.13, 0), _mat(Color("3a2a1a")))
	var hat_col: Color = o.get("hat_color", Color("1a1a1a"))
	match o.get("hat", ""):
		"top":
			_part(head, _cylinder(0.16, 0.015), Vector3(0, 0.2, 0), hat_col)
			_part(head, _cylinder(0.1, 0.2), Vector3(0, 0.3, 0), hat_col)
		"bowler":
			_part(head, _cylinder(0.15, 0.015), Vector3(0, 0.19, 0), hat_col)
			_part(head, _sphere(0.11), Vector3(0, 0.22, 0), hat_col, Vector3(1, 0.75, 1))
		"cap":
			_part(head, _sphere(0.125), Vector3(0, 0.16, 0), hat_col, Vector3(1, 0.7, 1))
			_part(head, _box(Vector3(0.16, 0.015, 0.12)), Vector3(0, 0.17, 0.13), hat_col)
		"bonnet":
			_part(head, _sphere(0.135), Vector3(0, 0.14, -0.02), hat_col, Vector3(1, 1, 1.05))
		"hood":
			_part(head, _sphere(0.15), Vector3(0, 0.12, -0.03), hat_col, Vector3(1, 1.1, 1.1))
		"helmet":
			_part(head, _sphere(0.145), Vector3(0, 0.13, 0), hat_col, Vector3(1, 1.05, 1.05))
	if o.has("visor"):
		_part(head, _box(Vector3(0.24, 0.05, 0.04)), Vector3(0, 0.12, 0.13), _mat(o.visor, true))

	# arms
	for side in [-1.0, 1.0]:
		var sh := _joint(_torso, Vector3(side * 0.24, 0.55, 0))
		_shoulders.append(sh)
		var sleeve: Color = o.get("coat", top)
		_limb(sh, 0.3, 0.06, sleeve)
		var el := _joint(sh, Vector3(0, -0.3, 0))
		_elbows.append(el)
		_limb(el, 0.27, 0.05, sleeve)
		var hand := _joint(el, Vector3(0, -0.3, 0))
		_part(hand, _sphere(0.05), Vector3.ZERO, o.get("gloves", skin))
		if side < 0:
			right_hand = hand
		else:
			left_forearm = el


## Walk cycle driven by horizontal speed (m/s).
func animate(delta: float, speed: float) -> void:
	var amount := clampf(speed / 6.0, 0.0, 1.3)
	_phase += delta * (2.0 + speed * 1.4)
	var sw := sin(_phase) * 0.65 * amount
	for i in range(2):
		var sgn := 1.0 if i == 0 else -1.0
		_hips[i].rotation.x = sw * sgn
		_knees[i].rotation.x = maxf(0.0, -sin(_phase * sgn + (0.0 if i == 0 else PI))) * 0.9 * amount
		_shoulders[i].rotation.x = -sw * sgn * 0.8
		_elbows[i].rotation.x = -0.25 - 0.3 * amount
	_torso.position.y = 0.92 + absf(sin(_phase)) * 0.03 * amount
	if amount < 0.05:
		_torso.position.y = 0.92 + sin(_phase * 0.5) * 0.004
	# right arm (index 0): aiming or a blade swing
	if _swing_t > 0.0:
		_swing_t = maxf(_swing_t - delta, 0.0)
		var k := 1.0 - _swing_t / 0.25
		_shoulders[0].rotation = Vector3(lerpf(-2.4, -0.6, k), 0, lerpf(-0.9, 0.6, k))
		_elbows[0].rotation.x = -0.2
	elif aim:
		_shoulders[0].rotation = Vector3(-1.45, 0, 0)
		_elbows[0].rotation.x = 0.0
	else:
		_shoulders[0].rotation.z = 0.0
	# left forearm raised slightly so the bracer reads
	_elbows[1].rotation.x = -0.9 if speed < 0.5 else _elbows[1].rotation.x


func swing() -> void:
	_swing_t = 0.25


# ------------------------------------------------------------- helpers

func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var key := "%s%s" % [c.to_html(), emissive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if _chrome and not emissive:
		m.metallic = 1.0
		m.roughness = 0.22
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _limb(joint: Node3D, length: float, radius: float, c: Color) -> void:
	_part(joint, _capsule(radius, length + radius * 2.0), Vector3(0, -length / 2.0, 0), c)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat_or_color, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	mi.material_override = mat_or_color if mat_or_color is Material else _mat(mat_or_color)
	mi.visibility_range_end = _lod
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _lod == 0.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	return m
