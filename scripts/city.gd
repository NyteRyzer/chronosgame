extends Node3D
## Builds one era snapshot of New Meridian: sky, ground, river, street grid,
## buildings, the clock tower landmark, and Founders' Square. Also exposes
## footprint rectangles so the Bureau's street pathfinding knows what is solid.

const EraData = preload("res://scripts/era_data.gd")

const LAYER_WORLD := 1
const LAYER_PLAYER_BARRIER := 2

var era := EraData.PRESENT
var changed := false
var info: Dictionary = EraData.era_info(EraData.PRESENT)
var obstacles: Array = []   # Rect2 footprints (x, z) that block walking
var _solids: StaticBody3D
var _mats := {}
var _hands: Array = []
var _flyers: Array = []
var _t := 0.0


func build(new_era: int, is_changed: bool) -> void:
	era = new_era
	changed = is_changed
	info = EraData.era_info(era)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	obstacles.clear()
	_hands.clear()
	_flyers.clear()
	_mats.clear()
	_solids = StaticBody3D.new()
	_solids.collision_layer = LAYER_WORLD
	_solids.collision_mask = 0
	add_child(_solids)
	_build_environment()
	_build_ground()
	_build_river()
	if era == EraData.PREHISTORIC:
		_build_wilds()
	else:
		_build_streets()
		_build_buildings()
		_build_clock_tower()
	_build_square()
	if era == EraData.PAST:
		_build_stall()
	_build_npc()


func _process(delta: float) -> void:
	_t += delta
	for h in _hands:
		h.node.rotation.z = -_t * h.speed
	for f in _flyers:
		var a: float = _t * f.speed + f.phase
		f.node.position = f.center + Vector3(cos(a) * f.radius, sin(_t * 0.7 + f.phase) * 4.0, sin(a) * f.radius)
		f.node.rotation.y = -a
		f.wings.rotation.z = sin(_t * 6.0 + f.phase) * 0.4


# ------------------------------------------------------------- helpers

func _mat(color: Color, emissive := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), emissive, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.85
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(bm, pos, mat)
	if collide:
		_collider(size, pos)
	return mi


func _collider(size: Vector3, pos: Vector3, body: StaticBody3D = null) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	(body if body else _solids).add_child(cs)


## Scales a footprint about its centre (fraction removed per axis).
func _shrink(r: Rect2, f: float) -> Rect2:
	return Rect2(r.position + r.size * f / 2.0, r.size * (1.0 - f))


## A footprint-sized building block with its base on the ground.
func _building(r: Rect2, h: float, mat: Material, base := 0.0) -> void:
	_box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, base + h / 2.0, r.get_center().y), mat)


func _label(text: String, pos: Vector3, size := 64, range_end := 80.0, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.visibility_range_end = range_end
	add_child(l)
	return l


func _window_material(palette: Color) -> StandardMaterial3D:
	var key := "win|%s" % palette.to_html()
	if _mats.has(key):
		return _mats[key]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var glow := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	glow.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(palette.to_html())
	var lit: Color = info.window
	for gx in range(4):
		for gy in range(4):
			var on: bool = rng.randf() < info.window_lit
			var c := lit if on else Color(0.12, 0.14, 0.18)
			var w := 8 if era == EraData.PAST else 11
			var hgt := 10 if era == EraData.PAST else 9
			if era == EraData.FUTURE:
				w = 13
				hgt = 3
			for px in range(w):
				for py in range(hgt):
					img.set_pixel(gx * 16 + 2 + px, gy * 16 + 3 + py, c)
					if on:
						glow.set_pixel(gx * 16 + 2 + px, gy * 16 + 3 + py, lit)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_color = palette
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 14.0, 1.0 / 14.0, 1.0 / 14.0)
	m.roughness = 0.8
	if info.glow:
		glow.generate_mipmaps()
		m.emission_enabled = true
		m.emission_texture = ImageTexture.create_from_image(glow)
		m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m


# ------------------------------------------------------------- pieces

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = info.sky_top
	sky_mat.sky_horizon_color = info.sky_horizon
	sky_mat.ground_horizon_color = info.sky_horizon
	sky_mat.ground_bottom_color = info.fog
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = info.ambient
	env.ambient_light_energy = 0.5
	env.tonemap_exposure = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = info.fog
	env.fog_density = info.fog_density
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = info.sun
	sun.light_energy = info.sun_energy
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)


func _build_ground() -> void:
	var size := EraData.CITY_MAX - EraData.CITY_MIN
	var center := (EraData.CITY_MAX + EraData.CITY_MIN) / 2.0
	_box(Vector3(size.x, 1.0, size.y), Vector3(center.x, -0.5, center.y), _mat(info.ground))
	# city edge walls (river side handled separately)
	var wall_mat := _mat(info.ground.darkened(0.3))
	_box(Vector3(1, 3, size.y), Vector3(EraData.CITY_MAX.x, 1.5, center.y), wall_mat)
	_box(Vector3(size.x, 3, 1), Vector3(center.x, 1.5, EraData.CITY_MIN.y), wall_mat)
	_box(Vector3(size.x, 3, 1), Vector3(center.x, 1.5, EraData.CITY_MAX.y), wall_mat)
	for w in [Rect2(EraData.CITY_MAX.x - 1, EraData.CITY_MIN.y, 2, size.y), Rect2(EraData.CITY_MIN.x, EraData.CITY_MIN.y - 1, size.x, 2),
			Rect2(EraData.CITY_MIN.x, EraData.CITY_MAX.y - 1, size.x, 2)]:
		obstacles.append(w)


func _build_river() -> void:
	var z0 := EraData.CITY_MIN.y - 400.0
	var z1 := EraData.CITY_MAX.y + 400.0
	var bed_w := 400.0
	_box(Vector3(bed_w, 1.0, z1 - z0), Vector3(EraData.RIVER_X - bed_w / 2.0, EraData.RIVER_BED_Y - 0.5, (z0 + z1) / 2.0), _mat(Color("2a2a22")))
	var water: Color = {EraData.PREHISTORIC: Color("3a6a5a"), EraData.PAST: Color("3d6a6e"), EraData.PRESENT: Color("2a5a86"),
		EraData.FUTURE: Color("5a2a8a"), EraData.WASTELAND: Color("6a8a2a")}[era]
	var glowing := era == EraData.FUTURE or era == EraData.WASTELAND
	_box(Vector3(bed_w, 0.1, z1 - z0), Vector3(EraData.RIVER_X - bed_w / 2.0, -0.7, (z0 + z1) / 2.0), _mat(water, glowing, 0.75), false)
	# seawall railing (low, visible) + tall invisible barrier that only stops people
	_box(Vector3(0.4, 1.1, z1 - z0), Vector3(EraData.RIVER_X + 0.2, 0.55, (z0 + z1) / 2.0), _mat(Color("3a3a3a")), false)
	var barrier := StaticBody3D.new()
	barrier.collision_layer = LAYER_PLAYER_BARRIER
	barrier.collision_mask = 0
	add_child(barrier)
	_collider(Vector3(0.6, 8, z1 - z0), Vector3(EraData.RIVER_X + 0.2, 4, (z0 + z1) / 2.0), barrier)
	obstacles.append(Rect2(EraData.RIVER_X - 400.0, z0, 400.0, z1 - z0))
	var river_name: String = {EraData.PREHISTORIC: "THE ANCIENT RIVER", EraData.WASTELAND: "THE SLUDGE"}.get(era, "NORTH RIVER")
	_label(river_name, Vector3(-60, 6, 300), 160, 400.0, Color(1, 1, 1, 0.8))
	if era == EraData.PREHISTORIC:
		return
	# far-bank skyline
	var rng := RandomNumberGenerator.new()
	rng.seed = 1890 + era
	var far := _mat(info.palettes[2].darkened(0.4))
	for k in range(40):
		var h := EraData.building_height(era, rng.randf()) * 0.8
		var w := rng.randf_range(12, 30)
		_box(Vector3(w, h, w), Vector3(rng.randf_range(-330, -250), h / 2.0 - 1.0, -80 + k * 20.0), far, false)


func _build_streets() -> void:
	var size := EraData.CITY_MAX - EraData.CITY_MIN
	var center := (EraData.CITY_MAX + EraData.CITY_MIN) / 2.0
	var road := _mat(info.road)
	var line := _mat(info.line, era == EraData.FUTURE)
	for i in range(EraData.AVE_COUNT):
		var x := i * EraData.AVE_SPACING
		_box(Vector3(EraData.AVE_WIDTH, 0.04, size.y), Vector3(x, 0.02, center.y), road, false)
		if era == EraData.PRESENT:
			_box(Vector3(0.25, 0.05, size.y), Vector3(x - 0.2, 0.03, center.y), line, false)
			_box(Vector3(0.25, 0.05, size.y), Vector3(x + 0.2, 0.03, center.y), line, false)
		elif era == EraData.FUTURE:
			_box(Vector3(0.2, 0.05, size.y), Vector3(x - EraData.AVE_WIDTH / 2.0 + 0.5, 0.03, center.y), line, false)
			_box(Vector3(0.2, 0.05, size.y), Vector3(x + EraData.AVE_WIDTH / 2.0 - 0.5, 0.03, center.y), line, false)
	for j in range(EraData.ST_COUNT):
		_box(Vector3(size.x, 0.045, EraData.ST_WIDTH), Vector3(center.x, 0.022, j * EraData.ST_SPACING), road, false)
	# corner lamps + street signs
	var pole := _mat(Color("2a2a2a"))
	var lamp := _mat(info.lamp, true)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.1
	pole_mesh.bottom_radius = 0.14
	pole_mesh.height = 5.0
	var head := SphereMesh.new()
	head.radius = 0.35
	head.height = 0.7
	for i in range(EraData.AVE_COUNT):
		for j in range(EraData.ST_COUNT):
			var corner := Vector3(i * EraData.AVE_SPACING + EraData.AVE_WIDTH / 2.0 + 1.0, 0, j * EraData.ST_SPACING + EraData.ST_WIDTH / 2.0 + 1.0)
			if era == EraData.WASTELAND:
				# bent, dead lamp posts; only a few still flicker
				var bent := _mesh(pole_mesh, corner + Vector3(0, 2.3, 0), pole)
				bent.rotation_degrees = Vector3((i * 7 + j * 13) % 30 - 15, 0, (i * 11 + j * 5) % 40 - 20)
				if (i + j) % 5 == 0:
					_mesh(head, corner + Vector3(0, 4.8, 0), lamp)
				continue
			_mesh(pole_mesh, corner + Vector3(0, 2.5, 0), pole)
			_mesh(head, corner + Vector3(0, 5.1, 0), lamp)
			_label("%s & %s" % [EraData.avenue_name(i), EraData.street_name(j)], corner + Vector3(0, 3.6, 0), 40, 45.0, Color("d8f0ff"))


func _build_buildings() -> void:
	var mats := []
	for p in info.palettes:
		mats.append(_window_material(p))
	var crown := _mat(info.window, true)
	for lot in EraData.building_lots():
		var r: Rect2 = lot.rect
		var h := EraData.building_height(era, lot.h)
		var mat: Material = mats[lot.palette]
		obstacles.append(r)
		if era == EraData.WASTELAND:
			_ruin(r, h, mat, lot.h)
			continue
		if era == EraData.PRESENT and h > 70.0:
			# art-deco setbacks
			_building(r, h * 0.6, mat)
			_building(_shrink(r, 0.3), h * 0.3, mat, h * 0.6)
			_building(_shrink(r, 0.6), h * 0.1, mat, h * 0.9)
		else:
			_building(r, h, mat)
		if era == EraData.PAST:
			_box(Vector3(r.size.x + 0.6, 0.6, r.size.y + 0.6), Vector3(r.get_center().x, h, r.get_center().y), _mat(Color("4a3426")), false)
		elif era == EraData.FUTURE and h > 140.0:
			_box(Vector3(r.size.x + 0.4, 1.2, r.size.y + 0.4), Vector3(r.get_center().x, h * 0.75, r.get_center().y), crown, false)
			_box(Vector3(r.size.x * 0.6, 0.8, r.size.y * 0.6), Vector3(r.get_center().x, h + 0.4, r.get_center().y), crown, false)


func _build_clock_tower() -> void:
	var r := EraData.block_rect(EraData.CLOCK_BLOCK.x, EraData.CLOCK_BLOCK.y).grow(-EraData.SIDEWALK)
	obstacles.append(r)
	var c := r.get_center()
	var face_z := r.position.y - 0.4
	var face_y := 0.0
	match era:
		EraData.WASTELAND:
			var ash := _window_material(Color("5a4a40"))
			_building(r, 48.0, ash)
			_building(_shrink(r, 0.4), 18.0, ash, 48.0)
			var spar := _box(Vector3(3, 60, 3), Vector3(c.x + 10, 70, c.y), _mat(Color("4a3a30")), false)
			spar.rotation_degrees.z = 25
			face_y = 30.0
		EraData.PAST:
			var brick := _mat(Color("7a3b2a"))
			_building(r, 24.0, brick)
			var t := Rect2(c.x - 6, c.y - 6, 12, 12)
			_building(t, 30.0, brick, 24.0)
			_box(Vector3(14, 4, 14), Vector3(c.x, 56, c.y), _mat(Color("4a5a4a")), false)
			face_y = 46.0
			face_z = c.y - 6.4
		EraData.FUTURE:
			var dark := _window_material(Color("2a2f5a"))
			_building(r, 260.0, dark)
			_building(r.grow(-8), 140.0, dark, 260.0)
			var ring := TorusMesh.new()
			ring.inner_radius = 26.0
			ring.outer_radius = 29.0
			_mesh(ring, Vector3(c.x, 300, c.y), _mat(Color("ff4fd8"), true))
			_box(Vector3(1.5, 120, 1.5), Vector3(c.x, 460, c.y), _mat(Color("2ee6d6"), true), false)
			face_y = 230.0
		_:
			var stone := _window_material(Color("b7a98f"))
			_building(r, 140.0, stone)
			_building(r.grow(-6), 70.0, stone, 140.0)
			_building(r.grow(-11), 40.0, stone, 210.0)
			var spire := CylinderMesh.new()
			spire.top_radius = 0.2
			spire.bottom_radius = 2.5
			spire.height = 60.0
			_mesh(spire, Vector3(c.x, 280, c.y), _mat(Color("d0d0d0")))
			face_y = 120.0
	# clock face looking down the avenue toward the square
	var face := CylinderMesh.new()
	face.top_radius = 5.0
	face.bottom_radius = 5.0
	face.height = 0.4
	var f := _mesh(face, Vector3(c.x, face_y, face_z), _mat(Color("f2ead0") if era != EraData.FUTURE else Color("2ee6d6"), era == EraData.FUTURE))
	f.rotation_degrees = Vector3(90, 0, 0)
	for spec in [[3.8, 0.35, 0.5], [2.6, 0.5, 0.04]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(c.x, face_y, face_z - 0.35)
		add_child(pivot)
		var hand := BoxMesh.new()
		hand.size = Vector3(spec[1], spec[0], 0.1)
		_mesh(hand, Vector3(0, spec[0] / 2.0, 0), _mat(Color.BLACK), pivot)
		_hands.append({"node": pivot, "speed": spec[2]})
	if era == EraData.WASTELAND:
		f.rotation_degrees = Vector3(90, 0, 18)  # cracked, stopped clock
		for h in _hands:
			h.speed = 0.0
			h.node.rotation.z = 2.4
	var tower_name := "RUINED CLOCK TOWER" if era == EraData.WASTELAND else "CLOCK TOWER"
	_label(tower_name, Vector3(c.x, 30 if era == EraData.PAST else 12, r.position.y - 1), 90, 220.0)


func _tree(pos: Vector3, s: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.8 * s
	trunk.bottom_radius = 1.3 * s
	trunk.height = 9.0 * s
	_mesh(trunk, pos + Vector3(0, 4.5 * s, 0), _mat(Color("5a3a1e")))
	_collider(Vector3(2.4 * s, 9.0 * s, 2.4 * s), pos + Vector3(0, 4.5 * s, 0))
	obstacles.append(Rect2(pos.x - 1.6 * s, pos.z - 1.6 * s, 3.2 * s, 3.2 * s))
	var green := _mat({EraData.FUTURE: Color("2e8a5a"), EraData.WASTELAND: Color("4a6a3a")}.get(era, Color("2f6b2a")))
	for off in [Vector3(0, 12, 0), Vector3(5, 10, 2), Vector3(-5, 10, -2), Vector3(2, 10, -5), Vector3(-2, 11, 5), Vector3(0, 15, 0)]:
		var sph := SphereMesh.new()
		sph.radius = 6.0 * s
		sph.height = 11.0 * s
		_mesh(sph, pos + off * s, green)


func _build_square() -> void:
	var sq := EraData.SQUARE
	var center := Vector3(sq.get_center().x, 0, sq.get_center().y)
	var top: Color
	var title := ""
	match era:
		EraData.PREHISTORIC:
			top = Color("5a6a32")
			title = "THE CLEARING"
		EraData.WASTELAND:
			top = Color("3a5a2a") if changed else Color("4a3a2e")
			title = "THE LAST GROVE" if changed else "THE CRATER"
		EraData.PAST:
			top = Color("6e5a3e")
			title = "FOUNDERS' SQUARE"
		EraData.PRESENT:
			top = Color("355f30") if changed else Color("4a4c50")
			title = "FOUNDERS' OAK PARK" if changed else "MERIDIAN GARAGE"
		_:
			top = Color("1f4a3e") if changed else Color("2a2830")
			title = "OAK BIODOME ARCHIVE" if changed else "COLLAPSED SQUARE"
	_box(Vector3(sq.size.x, 0.08, sq.size.y), center + Vector3(0, 0.04, 0), _mat(top), false)
	_label(title, center + Vector3(0, 26, -20), 110, 260.0, Color("ffe7a8"))
	var bench := _mat(Color("6a4a2a"))
	match era:
		EraData.PREHISTORIC:
			var fern := _mat(Color("3f6a2a"))
			for k in range(10):
				var a := TAU * k / 10.0
				var leaf := _box(Vector3(1.2, 0.2, 4), center + Vector3(cos(a) * 24, 0.5, sin(a) * 34), fern, false)
				leaf.rotation_degrees = Vector3(20, rad_to_deg(-a), 0)
		EraData.WASTELAND:
			if changed:
				_tree(EraData.PLOT_CENTER, 1.8)
				for k in range(6):
					var a := TAU * k / 6.0
					_tree(EraData.PLOT_CENTER + Vector3(cos(a) * 20, 0, sin(a) * 30), 0.45)
				for sh in [Rect2(194, 262, 6, 5), Rect2(240, 334, 6, 5)]:
					_box(Vector3(sh.size.x, 3, sh.size.y), Vector3(sh.get_center().x, 1.5, sh.get_center().y), _mat(Color("6a5a48")))
					obstacles.append(sh)
			else:
				var rim := TorusMesh.new()
				rim.inner_radius = 18.0
				rim.outer_radius = 24.0
				var crater := _mesh(rim, center + Vector3(0, -0.6, 0), _mat(Color("2e241c")))
				crater.scale = Vector3(1, 0.3, 1.4)
				_box(Vector3(30, 0.1, 46), center + Vector3(0, 0.1, 0), _mat(Color("1e1814")), false)
		EraData.PAST:
			var plot := EraData.PLOT_CENTER
			_box(Vector3(4, 0.25, 4), plot + Vector3(0, 0.12, 0), _mat(Color("a07a4a")), false)
			_box(Vector3(3.2, 0.3, 3.2), plot + Vector3(0, 0.15, 0), _mat(Color("3b2a1a")), false)
			if changed:
				_tree(plot, 0.15)
			else:
				_label("bare soil", plot + Vector3(0, 1.6, 0), 40, 30.0)
			for b in [Vector3(205, 0.4, 270), Vector3(235, 0.4, 330)]:
				_box(Vector3(3, 0.8, 0.8), b, bench)
		EraData.PRESENT:
			if changed:
				_tree(EraData.PLOT_CENTER, 1.0)
				for b in [Vector3(200, 0.4, 275), Vector3(240, 0.4, 325), Vector3(200, 0.4, 325), Vector3(240, 0.4, 275)]:
					_box(Vector3(3, 0.8, 0.8), b, bench)
			else:
				var g := Rect2(202, 272, 36, 56)
				_box(Vector3(g.size.x, 10, g.size.y), Vector3(g.get_center().x, 5, g.get_center().y), _window_material(Color("70747a")))
				obstacles.append(g)
				_box(Vector3(g.size.x + 0.2, 0.6, 1), Vector3(g.get_center().x, 9.5, g.position.y), _mat(Color("f2c230")), false)
		EraData.FUTURE:
			if changed:
				_tree(EraData.PLOT_CENTER, 1.5)
				var dome := SphereMesh.new()
				dome.radius = 30.0
				dome.height = 40.0
				_mesh(dome, center, _mat(Color(0.3, 1.0, 0.9), true, 0.12))
			else:
				var ruin := _mat(Color("4a4658"))
				for rr in [Rect2(200, 280, 14, 10), Rect2(226, 300, 10, 16), Rect2(206, 318, 12, 8)]:
					var piece := _box(Vector3(rr.size.x, 5, rr.size.y), Vector3(rr.get_center().x, 2.0, rr.get_center().y), ruin)
					piece.rotation_degrees = Vector3(8, 15, -6)
					obstacles.append(rr)


func _build_stall() -> void:
	var p := Vector3(130, 0, 241.5)
	_box(Vector3(4, 2.2, 2), p + Vector3(0, 1.1, 0), _mat(Color("8b5a2b")))
	_box(Vector3(4.4, 0.2, 2.6), p + Vector3(0, 2.4, 0.2), _mat(Color("c94f3d")), false)
	obstacles.append(Rect2(128, 240.5, 4, 2))
	_label("SEEDS & SUNDRIES", p + Vector3(0, 3.4, 0), 48, 60.0, Color("ffe7a8"))


func _build_npc() -> void:
	var p := EraData.NPC_POS
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.7
	var col: Color = {EraData.FUTURE: Color("9fb3c8"), EraData.WASTELAND: Color("8a6a50"), EraData.PREHISTORIC: Color("c0a080")}.get(era, Color("d9a066"))
	_mesh(body, p + Vector3(0, 0.85, 0), _mat(col))
	_label(EraData.npc_line(era, changed).name, p + Vector3(0, 2.3, 0), 40, 40.0, Color("ffe7a8"))


## Wasteland: the same lots as broken, leaning stumps and rubble.
func _ruin(r: Rect2, h: float, mat: Material, seed_h: float) -> void:
	if seed_h < 0.25:
		_box(Vector3(r.size.x * 0.8, 2.0, r.size.y * 0.8), Vector3(r.get_center().x, 1.0, r.get_center().y), _mat(Color("4a3e34")))
		return
	var mi := _box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, h / 2.0 - 1.0, r.get_center().y), mat)
	mi.rotation_degrees = Vector3((seed_h - 0.5) * 8.0, seed_h * 40.0, (0.5 - seed_h) * 10.0)
	if h > 25.0:
		var beam := _box(Vector3(0.8, h * 0.4, 0.8), Vector3(r.get_center().x + r.size.x * 0.3, h + h * 0.15, r.get_center().y), _mat(Color("3a2a22")), false)
		beam.rotation_degrees.z = 20.0


## Cretaceous: no streets - jungle, rock outcrops, a volcano, pterosaurs.
func _build_wilds() -> void:
	var size := EraData.CITY_MAX - EraData.CITY_MIN
	var center := (EraData.CITY_MAX + EraData.CITY_MIN) / 2.0
	var trail := _mat(info.road)
	for i in EraData.TRAFFIC_AVENUES:
		_box(Vector3(12, 0.04, size.y), Vector3(i * EraData.AVE_SPACING, 0.02, center.y), trail, false)
	var bark := _mat(Color("4a3420"))
	var needles := _mat(Color("2a4a22"))
	var rock := _mat(Color("6a6458"))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 4.0
	cone.height = 14.0
	for lot in EraData.building_lots():
		if lot.h < 0.45:
			continue
		var r: Rect2 = lot.rect
		var p := Vector3(r.get_center().x, 0, r.get_center().y)
		if lot.palette == 0:
			var size_r: float = minf(r.size.x, r.size.y) * 0.6
			var b := _box(Vector3(size_r, size_r * 0.7, size_r), p + Vector3(0, size_r * 0.3, 0), rock)
			b.rotation_degrees.y = lot.h * 90.0
			obstacles.append(Rect2(p.x - size_r / 2.0, p.z - size_r / 2.0, size_r, size_r))
		else:
			var h := EraData.building_height(era, lot.h)
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.6
			trunk.bottom_radius = 1.0
			trunk.height = h
			_mesh(trunk, p + Vector3(0, h / 2.0, 0), bark)
			_collider(Vector3(2, h, 2), p + Vector3(0, h / 2.0, 0))
			obstacles.append(Rect2(p.x - 1.2, p.z - 1.2, 2.4, 2.4))
			for k in range(3):
				var c := _mesh(cone, p + Vector3(0, h * 0.55 + k * 5.0, 0), needles)
				c.scale = Vector3.ONE * (1.4 - k * 0.35)
	# Sentinel Rock: where the clock tower will one day stand
	var cr := EraData.block_rect(EraData.CLOCK_BLOCK.x, EraData.CLOCK_BLOCK.y).grow(-EraData.SIDEWALK)
	var spire := CylinderMesh.new()
	spire.top_radius = 4.0
	spire.bottom_radius = 14.0
	spire.height = 60.0
	_mesh(spire, Vector3(cr.get_center().x, 30, cr.get_center().y), rock)
	_collider(Vector3(24, 60, 24), Vector3(cr.get_center().x, 30, cr.get_center().y))
	obstacles.append(Rect2(cr.get_center().x - 13, cr.get_center().y - 13, 26, 26))
	_label("SENTINEL ROCK", Vector3(cr.get_center().x, 66, cr.get_center().y), 120, 400.0)
	# volcano on the uptown horizon
	var volcano := CylinderMesh.new()
	volcano.top_radius = 30.0
	volcano.bottom_radius = 260.0
	volcano.height = 240.0
	_mesh(volcano, Vector3(240, 110, 1150), _mat(Color("3a3028")))
	var lava := CylinderMesh.new()
	lava.top_radius = 26.0
	lava.bottom_radius = 30.0
	lava.height = 6.0
	_mesh(lava, Vector3(240, 232, 1150), _mat(Color("ff5a1a"), true))
	# pterosaurs circling the clearing
	var wing_mat := _mat(Color("6a4a3a"))
	for k in range(5):
		var node := Node3D.new()
		add_child(node)
		var body := BoxMesh.new()
		body.size = Vector3(0.6, 0.5, 2.6)
		_mesh(body, Vector3.ZERO, wing_mat, node)
		var wings := Node3D.new()
		node.add_child(wings)
		var wing := BoxMesh.new()
		wing.size = Vector3(9, 0.15, 1.6)
		_mesh(wing, Vector3.ZERO, wing_mat, wings)
		_flyers.append({"node": node, "wings": wings, "center": Vector3(220, 45 + k * 8, 300 + k * 30),
			"radius": 40.0 + k * 15.0, "speed": 0.25 + k * 0.05, "phase": k * 1.3})
