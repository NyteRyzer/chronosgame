extends Node3D
## Avenue traffic: triceratops herds (Cretaceous), horse-drawn carriages (1890),
## yellow cabs (2025), hover-cars (2150) and scrap crawlers (AD 30,000), plus
## the player's own Chrono Cruiser. One-way avenues like Manhattan; traffic
## wraps at the end of the grid. Freezable with Stop Time, hackable, drivable.

const EraData = preload("res://scripts/era_data.gd")
const Kit = preload("res://scripts/mesh_kit.gd")

const SIZE := Vector3(2.4, 2.0, 5.0)

var era := EraData.PRESENT
var kind := ""         # "" = era traffic, "cruiser" = the player's time car
var speed := 12.0
var dir := 1.0
var label := ""
var frozen := 0.0
var stall := 0.0       # hacked engine
var driven := false    # the player is driving it
var parked := false    # abandoned by the player
var top_speed := 40.0
var _ice: MeshInstance3D
var _wheels: Array = []     # [pivot, radius]
var _rotors: Array = []
var _legs: Array = []       # [pivot, phase offset]
var _hover: Node3D
var _flux: Array = []
var _phase := 0.0
var _t := 0.0


func setup(new_era: int, x: float, z: float, direction: float, speed_scale: float, special := "") -> void:
	era = new_era
	kind = special
	var info := EraData.era_info(era)
	speed = info.vehicle_speed * speed_scale
	top_speed = info.vehicle_top_speed
	label = info.vehicle
	dir = direction
	position = Vector3(x, 0, z)
	rotation.y = 0.0 if dir > 0 else PI
	if kind == "cruiser":
		label = "Chrono Cruiser"
		top_speed = 62.0
		parked = true
		_build_cruiser()
	else:
		match era:
			EraData.PREHISTORIC:
				_build_triceratops(info.vehicle_color)
			EraData.PAST:
				_build_carriage()
			EraData.FUTURE:
				_build_hovercar(info.vehicle_color)
			EraData.WASTELAND:
				_build_crawler(info.vehicle_color)
			_:
				_build_cab(info.vehicle_color)
	_ice = Kit.add(self, Kit.box(SIZE + Vector3(0.6, 0.8, 0.6)), Vector3(0, SIZE.y / 2.0 + 0.3, 0), Kit.mat(Color(0.5, 0.85, 1.0), 0.0, 0.2, true, 0.35))
	_ice.visible = false


# ------------------------------------------------------------- models

func _common_car_bits(body_len: float, width: float, light_y: float, tyre: Material, hub: Material, radius := 0.36) -> void:
	var front := body_len / 2.0
	var head := Kit.mat(Color("fff6d8"), 0.0, 0.2, true)
	var tail := Kit.mat(Color("ff2a2a"), 0.0, 0.2, true)
	for sx in [-1.0, 1.0]:
		Kit.add(self, Kit.box(Vector3(0.38, 0.14, 0.06)), Vector3(sx * (width / 2.0 - 0.3), light_y, front + 0.02), head)
		Kit.add(self, Kit.box(Vector3(0.34, 0.12, 0.06)), Vector3(sx * (width / 2.0 - 0.28), light_y + 0.05, -front - 0.02), tail)
		for wz in [front - 0.95, -front + 0.95]:
			_wheels.append([Kit.wheel(self, Vector3(sx * (width / 2.0 - 0.08), radius, wz), radius, 0.26, tyre, hub), radius])


func _build_cab(yellow: Color) -> void:
	var paint := Kit.mat(yellow, 0.2, 0.35)
	var glass := Kit.mat(Color("1d2a38"), 0.6, 0.08)
	var chrome := Kit.mat(Color("c8ccd2"), 0.9, 0.2)
	var tyre := Kit.mat(Color("141414"), 0.0, 0.9)
	var black := Kit.mat(Color("101010"))
	# lower body + glasshouse with sloped screens
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(-2.4, 0.32), Vector2(2.4, 0.32), Vector2(2.46, 0.62), Vector2(2.3, 0.92),
		Vector2(1.15, 0.98), Vector2(-1.55, 1.0), Vector2(-2.38, 0.94), Vector2(-2.46, 0.6)]), 1.92), Vector3.ZERO, paint)
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(1.15, 0.97), Vector2(0.35, 1.48), Vector2(-0.95, 1.5), Vector2(-1.55, 0.99)]), 1.72), Vector3.ZERO, glass)
	Kit.add(self, Kit.box(Vector3(1.66, 0.06, 1.25)), Vector3(0, 1.52, -0.3), paint)
	# checker stripe, bumpers, grille, roof sign
	for i in range(14):
		for sx in [-0.965, 0.965]:
			Kit.add(self, Kit.box(Vector3(0.02, 0.1, 0.16)), Vector3(sx, 0.72 + (0.1 if i % 2 else 0.0), -1.9 + i * 0.29), black)
	Kit.add(self, Kit.box(Vector3(1.96, 0.16, 0.14)), Vector3(0, 0.42, 2.46), chrome)
	Kit.add(self, Kit.box(Vector3(1.96, 0.16, 0.14)), Vector3(0, 0.42, -2.46), chrome)
	Kit.add(self, Kit.box(Vector3(0.9, 0.2, 0.04)), Vector3(0, 0.66, 2.45), black)
	Kit.add(self, Kit.box(Vector3(0.7, 0.24, 0.26)), Vector3(0, 1.67, -0.2), Kit.mat(Color("fff2c0"), 0.0, 0.3, true))
	_common_car_bits(4.8, 1.92, 0.72, tyre, chrome)


## The Chrono Cruiser: a gull-wing stainless wedge with a glowing flux core.
func _build_cruiser() -> void:
	var steel := Kit.mat(Color("b9bec4"), 0.95, 0.32)
	var glass := Kit.mat(Color("141c24"), 0.6, 0.05)
	var black := Kit.mat(Color("1a1a1c"), 0.2, 0.6)
	var tyre := Kit.mat(Color("121212"), 0.0, 0.9)
	var flux := Kit.mat(Color("5fd4ff"), 0.0, 0.2, true)
	var vent := Kit.mat(Color("ff7a1a"), 0.0, 0.3, true)
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(-2.15, 0.3), Vector2(2.15, 0.3), Vector2(2.25, 0.52), Vector2(2.1, 0.68),
		Vector2(0.95, 0.86), Vector2(-1.15, 0.92), Vector2(-2.15, 0.9), Vector2(-2.25, 0.5)]), 1.86), Vector3.ZERO, steel)
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(0.95, 0.85), Vector2(0.1, 1.2), Vector2(-0.75, 1.2), Vector2(-1.15, 0.91)]), 1.6), Vector3.ZERO, glass)
	Kit.add(self, Kit.box(Vector3(1.88, 0.12, 4.3)), Vector3(0, 0.36, 0), black)  # lower stripe
	# rear louvres + time-circuit vents
	for i in range(6):
		Kit.add(self, Kit.box(Vector3(1.4, 0.03, 0.08)), Vector3(0, 0.93 + i * 0.012, -1.3 - i * 0.13), black)
	for sx in [-0.55, 0.0, 0.55]:
		_flux.append(Kit.add(self, Kit.box(Vector3(0.3, 0.16, 0.06)), Vector3(sx, 0.62, -2.26), vent))
	# flux core and conduits
	_flux.append(Kit.add(self, Kit.box(Vector3(0.5, 0.06, 0.6)), Vector3(0, 0.95, -1.0), flux))
	for sx in [-0.94, 0.94]:
		_flux.append(Kit.add(self, Kit.box(Vector3(0.03, 0.04, 3.6)), Vector3(sx, 0.55, 0), flux))
	_common_car_bits(4.4, 1.86, 0.55, tyre, steel, 0.34)


func _build_hovercar(glow: Color) -> void:
	var shell := Kit.mat(Color("e8ecf2"), 0.5, 0.25)
	var canopy := Kit.mat(Color("1a1030"), 0.7, 0.05)
	var neon := Kit.mat(glow, 0.0, 0.2, true)
	_hover = Node3D.new()
	add_child(_hover)
	_hover.position.y = 1.2
	Kit.add(_hover, Kit.extrude(PackedVector2Array([Vector2(-2.2, -0.25), Vector2(1.9, -0.25), Vector2(2.4, 0.05), Vector2(1.6, 0.4),
		Vector2(-1.8, 0.45), Vector2(-2.35, 0.1)]), 1.9), Vector3.ZERO, shell)
	Kit.add(_hover, Kit.extrude(PackedVector2Array([Vector2(1.3, 0.4), Vector2(0.3, 0.95), Vector2(-1.0, 0.95), Vector2(-1.6, 0.44)]), 1.5), Vector3.ZERO, canopy)
	Kit.add(_hover, Kit.box(Vector3(1.95, 0.05, 4.2)), Vector3(0, -0.02, 0), neon)
	Kit.add(_hover, Kit.box(Vector3(1.6, 0.06, 3.4)), Vector3(0, -0.3, 0), Kit.mat(glow, 0.0, 0.2, true, 0.6))
	for c in [Vector3(-1.35, 0.1, -1.6), Vector3(1.35, 0.1, -1.6), Vector3(-1.35, 0.1, 1.6), Vector3(1.35, 0.1, 1.6)]:
		Kit.add(_hover, Kit.box(Vector3(0.6, 0.08, 0.12)), c * Vector3(0.7, 1, 1), shell)
		var rotor := Node3D.new()
		rotor.position = c
		_hover.add_child(rotor)
		Kit.add(rotor, Kit.torus(0.5, 0.6), Vector3.ZERO, shell)
		Kit.add(rotor, Kit.cylinder(0.48, 0.48, 0.02), Vector3.ZERO, Kit.mat(glow, 0.0, 0.2, true, 0.35))
		Kit.add(rotor, Kit.box(Vector3(0.9, 0.03, 0.08)), Vector3.ZERO, shell)
		_rotors.append(rotor)
	Kit.add(_hover, Kit.box(Vector3(0.5, 0.08, 0.04)), Vector3(0, 0.1, 2.38), Kit.mat(Color.WHITE, 0.0, 0.2, true))
	Kit.add(_hover, Kit.box(Vector3(1.6, 0.06, 0.04)), Vector3(0, 0.2, -2.36), Kit.mat(Color("ff2a6a"), 0.0, 0.2, true))


func _build_carriage() -> void:
	var lacquer := Kit.mat(Color("2a1a14"), 0.3, 0.3)
	var trim := Kit.mat(Color("b08a3a"), 0.8, 0.3)
	var wood := Kit.mat(Color("6a4a2a"))
	var horse := Kit.mat(Color("5a3a24"), 0.0, 0.6)
	var mane := Kit.mat(Color("1e140e"))
	# carriage (rear) with curved roof
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(-2.3, 0.7), Vector2(-0.4, 0.7), Vector2(-0.3, 1.5), Vector2(-0.6, 2.1),
		Vector2(-1.4, 2.25), Vector2(-2.2, 2.1), Vector2(-2.4, 1.5)]), 1.6), Vector3.ZERO, lacquer)
	Kit.add(self, Kit.box(Vector3(1.64, 0.5, 0.6)), Vector3(0, 1.55, -1.35), Kit.mat(Color("2a3038"), 0.5, 0.1))  # window
	Kit.add(self, Kit.box(Vector3(1.66, 0.06, 2.0)), Vector3(0, 1.1, -1.35), trim)
	Kit.add(self, Kit.box(Vector3(1.2, 0.1, 0.7)), Vector3(0, 1.75, 0.0), wood)   # driver's bench
	var tyre := Kit.mat(Color("2a1a10"))
	for sx in [-0.95, 0.95]:
		_wheels.append([Kit.wheel(self, Vector3(sx, 0.62, -1.9), 0.62, 0.08, tyre, wood, 8), 0.62])
		_wheels.append([Kit.wheel(self, Vector3(sx, 0.45, -0.3), 0.45, 0.08, tyre, wood, 6), 0.45])
		Kit.add(self, Kit.box(Vector3(0.06, 0.06, 2.2)), Vector3(sx * 0.45, 1.05, 1.3), wood)  # shafts
	# horse
	var h := Node3D.new()
	h.position = Vector3(0, 0, 1.9)
	add_child(h)
	Kit.add(h, Kit.capsule_mesh(0.42, 1.9), Vector3(0, 1.45, 0), horse, Vector3(90, 0, 0))
	var neck := Kit.add(h, Kit.cylinder(0.18, 0.28, 0.9), Vector3(0, 1.95, 0.85), horse, Vector3(35, 0, 0))
	Kit.add(h, Kit.box(Vector3(0.26, 0.3, 0.62)), Vector3(0, 2.3, 1.25), horse, Vector3(25, 0, 0))
	Kit.add(h, Kit.box(Vector3(0.06, 0.36, 0.7)), Vector3(0, 2.15, 0.75), mane, Vector3(35, 0, 0))
	var tail := Kit.add(h, Kit.cylinder(0.04, 0.12, 0.8), Vector3(0, 1.3, -1.0), mane, Vector3(-30, 0, 0))
	for lz in [0.6, -0.6]:
		for lx in [-0.22, 0.22]:
			var hip := Node3D.new()
			hip.position = Vector3(lx, 1.2, lz)
			h.add_child(hip)
			Kit.add(hip, Kit.cylinder(0.07, 0.1, 1.15), Vector3(0, -0.58, 0), horse)
			Kit.add(hip, Kit.box(Vector3(0.14, 0.08, 0.16)), Vector3(0, -1.16, 0.02), mane)
			_legs.append([hip, (0.0 if lx < 0 else PI) + (0.0 if lz > 0 else PI)])
	neck.name = "neck"
	tail.name = "tail"


func _build_crawler(rust: Color) -> void:
	var hull := Kit.mat(rust, 0.6, 0.75)
	var dark := Kit.mat(Color("2a2420"), 0.5, 0.8)
	var tread := Kit.mat(Color("1a1612"), 0.2, 0.95)
	var bone := Kit.mat(Color("c8b8a0"))
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(-2.4, 0.7), Vector2(2.0, 0.7), Vector2(2.6, 1.1), Vector2(1.9, 1.7),
		Vector2(-2.2, 1.75), Vector2(-2.5, 1.2)]), 2.0), Vector3.ZERO, hull)
	Kit.add(self, Kit.extrude(PackedVector2Array([Vector2(0.9, 1.7), Vector2(0.4, 2.35), Vector2(-1.2, 2.35), Vector2(-1.5, 1.7)]), 1.5), Vector3.ZERO, dark)
	Kit.add(self, Kit.box(Vector3(1.2, 0.18, 0.04)), Vector3(0, 2.1, 0.62), Kit.mat(Color("ff6a2a"), 0.0, 0.3, true))  # slit visor
	for sx in [-1.12, 1.12]:
		Kit.add(self, Kit.box(Vector3(0.45, 0.75, 4.9)), Vector3(sx, 0.4, 0), tread)
		for wz in [-1.8, -0.6, 0.6, 1.8]:
			_wheels.append([Kit.wheel(self, Vector3(sx * 1.12, 0.36, wz), 0.3, 0.5, dark, hull), 0.3])
	for sx in [-0.7, 0.0, 0.7]:
		Kit.add(self, Kit.cylinder(0.0, 0.12, 0.9), Vector3(sx, 1.1, 2.85), bone, Vector3(90, 0, 0))
	for sx in [-0.7, 0.7]:
		Kit.add(self, Kit.cylinder(0.1, 0.12, 1.2), Vector3(sx, 2.3, -1.9), dark)
		Kit.add(self, Kit.cylinder(0.11, 0.11, 0.08), Vector3(sx, 2.92, -1.9), Kit.mat(Color("ff7a1a"), 0.0, 0.3, true))
	Kit.add(self, Kit.box(Vector3(2.1, 0.08, 1.2)), Vector3(0, 1.8, -1.0), Kit.mat(Color("5a4a3a"), 0.4, 0.9))  # cage roof


func _build_triceratops(skin: Color) -> void:
	var hide := Kit.mat(skin, 0.0, 0.85)
	var belly := Kit.mat(skin.lightened(0.25), 0.0, 0.85)
	var frill := Kit.mat(Color("a8603a"), 0.0, 0.7)
	var horn := Kit.mat(Color("ece0c4"), 0.0, 0.5)
	Kit.add(self, Kit.sphere(1.0), Vector3(0, 1.75, -0.3), hide, Vector3.ZERO, Vector3(1.1, 0.95, 2.1))
	Kit.add(self, Kit.sphere(0.8), Vector3(0, 1.35, -0.2), belly, Vector3.ZERO, Vector3(1.05, 0.7, 1.8))
	var head := Node3D.new()
	head.position = Vector3(0, 1.75, 1.9)
	add_child(head)
	Kit.add(head, Kit.sphere(0.55), Vector3(0, -0.1, 0.35), hide, Vector3.ZERO, Vector3(0.9, 0.8, 1.4))
	Kit.add(head, Kit.cylinder(1.15, 1.15, 0.14, 24), Vector3(0, 0.45, -0.2), frill, Vector3(70, 0, 0), Vector3(1, 1, 0.85))
	Kit.add(head, Kit.cylinder(0.0, 0.11, 1.1), Vector3(-0.32, 0.45, 0.75), horn, Vector3(65, 0, 0))
	Kit.add(head, Kit.cylinder(0.0, 0.11, 1.1), Vector3(0.32, 0.45, 0.75), horn, Vector3(65, 0, 0))
	Kit.add(head, Kit.cylinder(0.0, 0.09, 0.45), Vector3(0, 0.0, 1.05), horn, Vector3(60, 0, 0))
	Kit.add(head, Kit.cylinder(0.0, 0.12, 0.3), Vector3(0, -0.28, 1.0), Kit.mat(Color("3a3a2a")), Vector3(120, 0, 0))  # beak
	for sx in [-0.3, 0.3]:
		Kit.add(head, Kit.sphere(0.06), Vector3(sx, 0.05, 0.75), Kit.mat(Color("101010")))
	Kit.add(self, Kit.cylinder(0.08, 0.45, 2.4), Vector3(0, 1.55, -2.9), hide, Vector3(-80, 0, 0))
	for lz in [1.0, -1.4]:
		for lx in [-0.75, 0.75]:
			var hip := Node3D.new()
			hip.position = Vector3(lx, 1.45, lz)
			add_child(hip)
			Kit.add(hip, Kit.cylinder(0.22, 0.3, 1.45), Vector3(0, -0.72, 0), hide)
			Kit.add(hip, Kit.cylinder(0.3, 0.32, 0.12), Vector3(0, -1.42, 0.05), belly)
			_legs.append([hip, (0.0 if lx < 0 else PI) + (0.0 if lz > 0 else PI)])


# ------------------------------------------------------------- behaviour

## Spins wheels/rotors and swings legs for the given ground speed (m/s).
func animate(delta: float, ground_speed: float) -> void:
	_t += delta
	for w in _wheels:
		w[0].rotation.x += ground_speed * delta / w[1]
	for r in _rotors:
		r.rotate_y(delta * (8.0 + absf(ground_speed) * 2.0))
	if _hover:
		_hover.position.y = 1.2 + sin(_t * 2.0) * 0.08
	if not _legs.is_empty():
		_phase += delta * absf(ground_speed) * 0.9
		var amount := clampf(absf(ground_speed) / 6.0, 0.0, 1.0)
		for l in _legs:
			l[0].rotation.x = sin(_phase + l[1]) * 0.45 * amount
	for f in _flux:
		f.visible = int(_t * 8.0) % 5 != 0 or ground_speed < 30.0


func step(delta: float) -> void:
	_ice.visible = frozen > 0.0
	if driven:
		return
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		return
	if stall > 0.0 or parked:
		stall = maxf(stall - delta, 0.0)
		animate(delta, 0.0)
		return
	animate(delta, speed)
	position.z += dir * speed * delta
	if position.z > EraData.CITY_MAX.y - 4.0:
		position.z = EraData.CITY_MIN.y + 4.0
	elif position.z < EraData.CITY_MIN.y + 4.0:
		position.z = EraData.CITY_MAX.y - 4.0


## Ground-plane hit test (x, z) with a margin.
func hits(p: Vector3, margin: float) -> bool:
	return absf(p.x - position.x) < SIZE.x / 2.0 + margin and absf(p.z - position.z) < SIZE.z / 2.0 + margin and p.y < 3.5
