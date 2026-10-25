extends Node3D
## Procedural human figure with a jointed rig (shoulders, elbows, hips, knees)
## and a walk cycle. Outfits are plain dictionaries so every era can dress its
## people differently. Faces +Z.
##
## Outfit keys (all optional): skin, hair, hair_style ("short", "long", "bun",
## "bald"), top, bottom, shoes, coat (Color), dress (bool), hat ("top", "bowler",
## "cap", "helmet", "hood", "bonnet"), hat_color, visor (Color, glowing),
## goggles (bool), trim (Color, glowing suit lines), pads (bool), badge (bool),
## scarf (Color), gloves (Color), eyes (Color, glowing), collar (bool), hero
## (bool: belt pouches + shoulder plates), chrome (bool), height, build.

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
	var hands: Color = o.get("gloves", skin)
	var dress: bool = o.get("dress", false)
	var coat_col = o.get("coat", null)
	var hair: Color = o.get("hair", Color("2a1c12"))

	# ---- legs: tapered thigh/shin, knee caps, shaped shoes
	for side in [-1.0, 1.0]:
		var hip := _joint(self, Vector3(side * 0.1, 0.93, 0))
		_hips.append(hip)
		_part(hip, _cyl(0.085, 0.062, 0.44), Vector3(0, -0.21, 0), bottom)
		var knee := _joint(hip, Vector3(0, -0.43, 0))
		_knees.append(knee)
		_part(knee, _sphere(0.064), Vector3(0, 0, 0.005), bottom)
		_part(knee, _cyl(0.06, 0.045, 0.42), Vector3(0, -0.2, 0), bottom)
		_part(knee, _box(Vector3(0.1, 0.07, 0.2)), Vector3(0, -0.45, 0.03), shoes)
		_part(knee, _sphere(0.052), Vector3(0, -0.45, 0.13), shoes, Vector3(1, 0.7, 1))
		_part(knee, _box(Vector3(0.11, 0.025, 0.26)), Vector3(0, -0.49, 0.04), shoes.darkened(0.4))

	# ---- torso: V-shaped chest, waist, pelvis, belt
	_torso = _joint(self, Vector3(0, 0.92, 0))
	_part(_torso, _box(Vector3(0.3, 0.16, 0.18)), Vector3(0, 0.05, 0), bottom)
	_part(_torso, _cyl(0.155, 0.15, 0.2), Vector3(0, 0.18, 0), top, Vector3(1.12, 1, 0.72))
	_part(_torso, _cyl(0.2, 0.155, 0.36), Vector3(0, 0.44, 0), top, Vector3(1.22, 1, 0.68))
	_part(_torso, _sphere(0.17), Vector3(0, 0.6, 0), top, Vector3(1.4, 0.45, 0.78))  # shoulder line
	if not dress:
		_part(_torso, _cyl(0.162, 0.162, 0.05), Vector3(0, 0.1, 0), Color("1a1612"), Vector3(1.12, 1, 0.75))
		_part(_torso, _box(Vector3(0.06, 0.045, 0.02)), Vector3(0, 0.1, 0.125), _mat(Color("c8b070"), false, 0.9))
	if o.get("hero", false):
		# utility belt pouches and shoulder plates for the time traveller
		for side in [-1.0, 1.0]:
			_part(_torso, _box(Vector3(0.07, 0.08, 0.06)), Vector3(side * 0.14, 0.08, 0.1), Color("2a2622"))
			_part(_torso, _box(Vector3(0.14, 0.04, 0.16)), Vector3(side * 0.22, 0.63, 0), Color("3a4258"), Vector3.ONE, Vector3(0, 0, side * -18))
	if coat_col != null:
		_part(_torso, _cyl(0.215, 0.17, 0.42), Vector3(0, 0.42, -0.005), coat_col, Vector3(1.22, 1, 0.74))
		var hem := _cyl(0.19, 0.26, 0.55)
		_part(_torso, hem, Vector3(0, -0.08, -0.01), coat_col, Vector3(1.12, 1, 0.78))
		# lapels showing the shirt underneath
		_part(_torso, _box(Vector3(0.09, 0.32, 0.02)), Vector3(0, 0.44, 0.15), top)
		if o.get("collar", false):
			_part(_torso, _cyl(0.125, 0.11, 0.1), Vector3(0, 0.68, -0.015), coat_col, Vector3(1.1, 1, 1.0))
	if dress:
		_part(_torso, _cyl(0.17, 0.44, 0.88), Vector3(0, -0.4, 0), o.get("bottom", top))
	if o.has("trim"):
		var glow := _mat(o.trim, true)
		for side in [-1.0, 1.0]:
			_part(_torso, _box(Vector3(0.022, 0.4, 0.02)), Vector3(side * 0.075, 0.42, 0.155), glow)
		_part(_torso, _box(Vector3(0.36, 0.022, 0.02)), Vector3(0, 0.26, 0.135), glow)
	if o.get("pads", false):
		for side in [-1.0, 1.0]:
			_part(_torso, _sphere(0.1), Vector3(side * 0.25, 0.6, 0), o.get("hat_color", top).darkened(0.15), Vector3(1.1, 0.7, 1.1))
	if o.get("badge", false):
		_part(_torso, _sphere(0.035), Vector3(0.1, 0.5, 0.14), _mat(Color("ffd34d"), true))
	if o.has("scarf"):
		_part(_torso, _cyl(0.12, 0.15, 0.1), Vector3(0, 0.66, 0.0), o.scarf)

	# ---- head: skull, jaw, ears, brows, eyes, nose, mouth, hair
	var head := _joint(_torso, Vector3(0, 0.7, 0))
	_part(head, _cyl(0.048, 0.055, 0.12), Vector3(0, 0.0, 0), skin)
	_part(head, _sphere(0.112), Vector3(0, 0.15, 0), skin, Vector3(0.9, 1.05, 1.0))
	_part(head, _sphere(0.08), Vector3(0, 0.085, 0.03), skin, Vector3(0.95, 0.75, 0.95))  # jaw
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.025), Vector3(side * 0.1, 0.14, 0), skin.darkened(0.06), Vector3(0.6, 1.2, 1))
		if o.has("eyes"):
			_part(head, _sphere(0.017), Vector3(side * 0.038, 0.165, 0.098), _mat(o.eyes, true))
		else:
			_part(head, _sphere(0.016), Vector3(side * 0.038, 0.165, 0.094), Color("f2f2f0"))
			_part(head, _sphere(0.009), Vector3(side * 0.038, 0.165, 0.108), Color("2a1c14"))
		_part(head, _box(Vector3(0.045, 0.011, 0.015)), Vector3(side * 0.04, 0.192, 0.1), hair if o.get("hair_style", "short") != "bald" else skin.darkened(0.3))
	_part(head, _box(Vector3(0.022, 0.05, 0.035)), Vector3(0, 0.135, 0.112), skin.darkened(0.05))
	_part(head, _box(Vector3(0.045, 0.009, 0.01)), Vector3(0, 0.085, 0.098), skin.darkened(0.35))
	match o.get("hair_style", "short"):
		"short":
			_part(head, _sphere(0.118), Vector3(0, 0.19, -0.012), hair, Vector3(0.95, 0.72, 1.02))
			_part(head, _box(Vector3(0.18, 0.07, 0.04)), Vector3(0, 0.15, -0.09), hair)
		"long":
			_part(head, _sphere(0.12), Vector3(0, 0.19, -0.012), hair, Vector3(0.97, 0.75, 1.04))
			_part(head, _box(Vector3(0.22, 0.32, 0.07)), Vector3(0, 0.05, -0.085), hair)
		"bun":
			_part(head, _sphere(0.118), Vector3(0, 0.19, -0.012), hair, Vector3(0.95, 0.72, 1.02))
			_part(head, _sphere(0.055), Vector3(0, 0.25, -0.1), hair)
	if o.get("goggles", false):
		var lens := _mat(Color("ff9a40"), true)
		for side in [-1.0, 1.0]:
			_part(head, _cyl(0.033, 0.033, 0.03), Vector3(side * 0.042, 0.168, 0.106), lens, Vector3.ONE, Vector3(90, 0, 0))
		_part(head, _cyl(0.118, 0.118, 0.03), Vector3(0, 0.168, -0.005), Color("3a2a1a"))
	var hat_col: Color = o.get("hat_color", Color("1a1a1a"))
	match o.get("hat", ""):
		"top":
			_part(head, _cyl(0.16, 0.16, 0.015), Vector3(0, 0.25, 0), hat_col)
			_part(head, _cyl(0.1, 0.105, 0.2), Vector3(0, 0.35, 0), hat_col)
			_part(head, _cyl(0.106, 0.106, 0.03), Vector3(0, 0.27, 0), Color("5a1a1a"))
		"bowler":
			_part(head, _cyl(0.15, 0.15, 0.015), Vector3(0, 0.24, 0), hat_col)
			_part(head, _sphere(0.11), Vector3(0, 0.27, 0), hat_col, Vector3(1, 0.75, 1))
		"cap":
			_part(head, _sphere(0.122), Vector3(0, 0.21, 0), hat_col, Vector3(1, 0.66, 1.05))
			_part(head, _box(Vector3(0.16, 0.012, 0.11)), Vector3(0, 0.22, 0.13), hat_col)
		"bonnet":
			_part(head, _sphere(0.132), Vector3(0, 0.18, -0.02), hat_col, Vector3(1, 1, 1.05))
		"hood":
			_part(head, _sphere(0.148), Vector3(0, 0.16, -0.03), hat_col, Vector3(1, 1.1, 1.1))
		"helmet":
			_part(head, _sphere(0.142), Vector3(0, 0.18, 0), hat_col, Vector3(1, 1.02, 1.06))
			_part(head, _box(Vector3(0.24, 0.05, 0.25)), Vector3(0, 0.1, -0.02), hat_col)
	if o.has("visor"):
		_part(head, _box(Vector3(0.23, 0.045, 0.04)), Vector3(0, 0.165, 0.125), _mat(o.visor, true))

	# ---- arms: shoulder ball, tapered upper/forearm, elbow, hand with thumb
	for side in [-1.0, 1.0]:
		var sh := _joint(_torso, Vector3(side * 0.24, 0.58, 0))
		_shoulders.append(sh)
		var sleeve: Color = coat_col if coat_col != null else top
		_part(sh, _sphere(0.07), Vector3.ZERO, sleeve)
		_part(sh, _cyl(0.064, 0.05, 0.3), Vector3(0, -0.15, 0), sleeve)
		var el := _joint(sh, Vector3(0, -0.3, 0))
		_elbows.append(el)
		_part(el, _sphere(0.05), Vector3.ZERO, sleeve)
		_part(el, _cyl(0.05, 0.04, 0.27), Vector3(0, -0.135, 0), sleeve)
		_part(el, _cyl(0.044, 0.044, 0.04), Vector3(0, -0.26, 0), skin if not o.has("gloves") else hands)
		var hand := _joint(el, Vector3(0, -0.31, 0))
		_part(hand, _box(Vector3(0.05, 0.09, 0.08)), Vector3(0, -0.02, 0), hands)
		_part(hand, _box(Vector3(0.045, 0.06, 0.07)), Vector3(0, -0.085, 0.005), hands, Vector3.ONE, Vector3(15, 0, 0))
		_part(hand, _box(Vector3(0.025, 0.05, 0.025)), Vector3(side * -0.03, -0.03, 0.045), hands)
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

func _mat(c: Color, emissive := false, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s%s%s" % [c.to_html(), emissive, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	m.metallic = metallic
	if metallic > 0.0:
		m.roughness = 0.3
	if _chrome and not emissive:
		m.metallic = 1.0
		m.roughness = 0.22
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.9
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


func _cyl(r_top: float, r_bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return m


func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	return m
