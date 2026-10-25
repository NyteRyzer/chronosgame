extends Node3D
## Game orchestrator: the Time Pad bracer (era travel + Rewind + Stop Time),
## weapons and gadgets, the Timeline Causality System, threat, the Bureau hunt
## (with street-grid pathfinding) and save/load. All simulation is stepped from here so order is deterministic.

const EraData = preload("res://scripts/era_data.gd")
const City = preload("res://scripts/city.gd")
const Player = preload("res://scripts/player.gd")
const Prop = preload("res://scripts/prop.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const TimeCop = preload("res://scripts/time_cop.gd")
const Hud = preload("res://scripts/hud.gd")

const SAVE_PATH := "user://chrono_save.json"
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 9.0
const JUMP_COST := 35.0
const FREEZE_COST := 25.0
const REWIND_DRAIN := 28.0
const REWIND_RADIUS := 25.0
const FREEZE_RANGE := 60.0
const THROW_SPEED := 16.0
const GRAB_RANGE := 2.6
const PLANT_RANGE := 4.5
const FOLLOW_RANGE := 50.0
const EVADE_RANGE := 80.0
const NAV_CELL := 4.0
const WEAPONS := [
	{"id": "blade", "name": "Chrono Blade", "hint": "melee - stuns agents"},
	{"id": "pistol", "name": "Pulse Pistol", "hint": "12-shot sidearm"},
	{"id": "stasis", "name": "Stasis Grenade", "hint": "freezes a 9m area"},
	{"id": "blink", "name": "Phase Blink", "hint": "short-range teleport"},
]
const PISTOL_MAG := 12
const STASIS_COST := 20.0
const BLINK_COST := 15.0
const BLINK_RANGE := 9.0
const STASIS_RADIUS := 9.0
const TIER_THRESHOLDS := [20.0, 45.0, 70.0, 90.0, 100.0]
const TIER_NAMES := ["Unnoticed", "Temporal Suspect", "Wanted Across Time", "Chrono Fugitive", "Time Anomaly", "Threat to Reality"]

var city: City
var props_root: Node3D
var vehicles_root: Node3D
var player: Player
var cop: TimeCop = null
var beacon: MeshInstance3D
var hud: Hud
var nav := AStarGrid2D.new()

var era := EraData.PRESENT
var energy := MAX_ENERGY
var threat := 0.0
var events: Array = []
var flags := {"oak_planted": false, "cell_anachronism": false}
var seen_change := {}
var era_props := {}
var objectives: Array = [
	{"id": "rewind", "text": "Throw an object (LMB), then hold R to rewind it", "done": false},
	{"id": "freeze", "text": "Freeze traffic on an avenue (aim + F)", "done": false},
	{"id": "jump", "text": "Open the Time Pad (Tab) and jump to another era", "done": false},
	{"id": "plant", "text": "Plant the oak seed in 1890 Founders' Square", "done": false},
	{"id": "see", "text": "Return to 2025 and see what changed", "done": false},
	{"id": "evade", "text": "Shake off the Time Cop (outrun, or freeze/stun + jump)", "done": false},
]
var messages: Array = []
var banner := {}
var cop_cooldown := 0.0
var follow_timer := -1.0
var evade_timer := 0.0
var since_disruption := 999.0
var last_jump_time := -100.0
var clock := 0.0
var jump_flash := 0.0
var rewind_active := false
var rewind_frames := 0
var last_tier := 0
var escapes := 0
var arrests := 0
var weapon := 0
var pistol_ammo := PISTOL_MAG
var reload_timer := 0.0
var attack_cooldown := 0.0
var grenades: Array = []
var effects: Array = []
var pad_open := false
var pad_index := EraData.PRESENT
var user_speed := 1.0
var show_ledger := false
var show_help := true
var paused := false
var milestone_done := false


func _ready() -> void:
	randomize()
	_setup_input()
	city = City.new()
	add_child(city)
	props_root = Node3D.new()
	add_child(props_root)
	vehicles_root = Node3D.new()
	add_child(vehicles_root)
	player = Player.new()
	add_child(player)
	beacon = _make_beacon()
	add_child(beacon)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)
	for e in EraData.ERAS:
		era_props[e] = EraData.initial_props(e)
		seen_change[e] = false
	player.position = EraData.PLAYER_START
	player.yaw = PI  # face uptown, toward the square and the clock tower
	_enter_era(EraData.PRESENT, true)
	push_message("ChronoCore online. Everyone in New Meridian lost the same minute... start experimenting.", Color("5fd4ff"), 7.0)


func _make_beacon() -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 220.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 1.0, 0.5, 0.28)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT],
		"interact": [KEY_E], "rewind": [KEY_R], "freeze": [KEY_F],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
		"time_pad": [KEY_TAB],
		"ledger": [KEY_L], "help": [KEY_H], "pause": [KEY_ESCAPE, KEY_P],
		"save": [KEY_F5], "load": [KEY_F9],
		"slower": [KEY_BRACKETLEFT], "faster": [KEY_BRACKETRIGHT],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("throw"):
		InputMap.add_action("throw")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("throw", mb)


func _set_capture(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_paused():
		player.look(event.relative)
		return
	if event.is_action_pressed("help"):
		show_help = not show_help
		show_ledger = false
		_set_capture(not is_paused())
		return
	if event.is_action_pressed("ledger"):
		show_ledger = not show_ledger
		show_help = false
		_set_capture(not is_paused())
		return
	if event.is_action_pressed("pause"):
		if pad_open:
			set_pad_open(false)
			return
		if show_help or show_ledger:
			show_help = false
			show_ledger = false
		else:
			paused = not paused
		_set_capture(not is_paused())
		return
	if event.is_action_pressed("slower"):
		user_speed = maxf(0.5, user_speed - 0.25)
		_apply_speed()
		push_message("Game speed %d%%" % int(user_speed * 100.0))
	elif event.is_action_pressed("faster"):
		user_speed = minf(1.0, user_speed + 0.25)
		_apply_speed()
		push_message("Game speed %d%%" % int(user_speed * 100.0))
	if is_paused():
		return
	if event.is_action_pressed("time_pad"):
		set_pad_open(not pad_open)
		return
	var slot := -1
	for k in range(5):
		if event.is_action_pressed("slot_%d" % (k + 1)):
			slot = k
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		if pad_open:
			pad_index = posmod(pad_index + step, EraData.ERAS.size())
		else:
			select_weapon(posmod(weapon + step, WEAPONS.size()))
		return
	if pad_open:
		# the Time Pad dial: number keys or wheel + click/E
		if slot >= 0:
			pad_index = slot
			pad_confirm()
		elif event.is_action_pressed("throw") or event.is_action_pressed("interact"):
			pad_confirm()
		return
	if slot >= 0 and slot < WEAPONS.size():
		select_weapon(slot)
		return
	if event.is_action_pressed("throw"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_set_capture(true)
			return
		if player.held:
			throw_held(player.aim_dir())
		else:
			use_weapon(player.aim_origin(), player.aim_dir())
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("freeze"):
		freeze_aim(player.aim_origin(), player.aim_dir())
	elif event.is_action_pressed("save"):
		save_game()
	elif event.is_action_pressed("load"):
		load_game()


func is_paused() -> bool:
	return paused or show_help or show_ledger


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if is_paused():
		player.update_camera()
		return
	clock += delta
	since_disruption += delta
	cop_cooldown -= delta
	jump_flash = maxf(jump_flash - delta * 2.0, 0.0)

	player.step(delta)
	if player.held:
		player.held.global_position = player.carry_point()

	var want_rewind := Input.is_action_pressed("rewind") and energy > 0.5
	var any_rewound := false
	for p in props_root.get_children():
		if want_rewind and not p.held and p.global_position.distance_to(player.global_position) <= REWIND_RADIUS:
			if p.rewind_step():
				any_rewound = true
				if p.was_thrown:
					rewind_frames += 1
		else:
			p.simulate()
			p.record()
	rewind_active = want_rewind and any_rewound
	if rewind_active:
		energy = maxf(energy - REWIND_DRAIN * delta, 0.0)
	else:
		energy = minf(energy + ENERGY_REGEN * delta, MAX_ENERGY)
	if rewind_frames > 20:
		complete("rewind")
	_update_weapons(delta)

	for v in vehicles_root.get_children():
		v.step(delta)
	_vehicle_collisions()
	_update_bureau(delta)
	_update_threat(delta)
	_update_beacon()


func _process(delta: float) -> void:
	for m in messages:
		m.t -= delta
	messages = messages.filter(func(m): return m.t > 0.0)
	if not banner.is_empty():
		banner.t -= delta
		if banner.t <= 0.0:
			banner = {}


func _vehicle_collisions() -> void:
	for v in vehicles_root.get_children():
		if v.frozen > 0.0:
			continue
		if player.stun <= 0.0 and v.hits(player.global_position, 0.5):
			var side := signf(player.global_position.x - v.position.x)
			if side == 0.0:
				side = 1.0
			player.knock = Vector3(side * 12.0, 0, v.dir * 6.0)
			player.velocity.y = 5.0
			player.stun = 0.7
			energy = maxf(energy - 10.0, 0.0)
			push_message("Hit by a %s! Aim at traffic and press F to Stop Time." % v.label.to_lower(), Color("ff8a6b"))
		for p in props_root.get_children():
			if not p.held and not p.sunk and v.hits(p.global_position, 0.3):
				p.apply_central_impulse(Vector3(signf(p.global_position.x - v.position.x) * 3.0, 2.0, v.dir * v.speed) * p.mass)


# ---------------------------------------------------------------- powers

static func hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func near_plot() -> bool:
	return era == EraData.PAST and hdist(player.global_position, EraData.PLOT_CENTER) < PLANT_RANGE


func nearest_grabbable():
	var best = null
	var best_d := GRAB_RANGE
	for p in props_root.get_children():
		var d: float = hdist(p.global_position, player.global_position)
		if not p.sunk and not p.held and d < best_d:
			best = p
			best_d = d
	return best


func prompt_text() -> String:
	if player.held:
		if player.held.kind == "seed" and near_plot():
			return "[E] Plant the oak seed"
		return "[LMB] Throw %s    [E] Drop" % player.held.display_name()
	var p = nearest_grabbable()
	if p:
		return "[E] Pick up %s" % p.display_name()
	if hdist(player.global_position, EraData.NPC_POS) < 4.0:
		return "[E] Talk to %s" % EraData.npc_line(era, flags.oak_planted).name
	return ""


func interact() -> void:
	if player.held:
		var h = player.held
		if h.kind == "seed" and near_plot():
			plant_seed()
			return
		h.set_held(false)
		h.global_position = player.carry_point()
		h.clear_history()
		player.held = null
		return
	var best = nearest_grabbable()
	if best:
		best.set_held(true)
		player.held = best
		if best.kind == "seed":
			push_message("Oak seed. Founders' Square is bare soil in 1890 - follow the green beacon.", Color("9be37a"), 5.0)
		elif best.kind == "cell":
			push_message("Plasma cell (2150 tech). Carrying it into an earlier era is a serious temporal crime.", Color("2ee6d6"), 5.0)
		else:
			push_message("Picked up %s. LMB to throw where you aim." % best.display_name())
		return
	if hdist(player.global_position, EraData.NPC_POS) < 4.0:
		var npc := EraData.npc_line(era, flags.oak_planted)
		push_message("%s: \"%s\"" % [npc.name, npc.line], Color("ffe7a8"), 7.0)


func throw_held(dir: Vector3) -> void:
	if not player.held:
		return
	var p = player.held
	p.set_held(false)
	p.global_position = player.carry_point()
	p.linear_velocity = dir.normalized() * THROW_SPEED + Vector3(0, 2.5, 0)
	p.was_thrown = true
	p.clear_history()
	player.held = null


## Stop Time on whatever lies closest along the aim ray.
func freeze_aim(origin: Vector3, dir: Vector3) -> void:
	dir = dir.normalized()
	var best = null
	var best_t := INF
	var candidates := []
	for v in vehicles_root.get_children():
		candidates.append([v, v.global_position + Vector3(0, 1.0, 0), 3.5])
	if cop and cop.state == "chase":
		candidates.append([cop, cop.global_position + Vector3(0, 1.0, 0), 2.5])
	for c in candidates:
		var to: Vector3 = c[1] - origin
		var t := to.dot(dir)
		if t < 0.0 or hdist(c[1], player.global_position) > FREEZE_RANGE:
			continue
		if (origin + dir * t).distance_to(c[1]) < c[2] and t < best_t:
			best = c[0]
			best_t = t
	if best == null:
		push_message("Stop Time needs a target - aim at traffic or a Bureau agent within %dm." % int(FREEZE_RANGE))
		return
	if energy < FREEZE_COST:
		push_message("Not enough Chrono Energy to Stop Time (%d needed)." % int(FREEZE_COST), Color("ffb07a"))
		return
	energy -= FREEZE_COST
	if best == cop:
		cop.frozen = 1.8
		push_message("Agent frozen - Bureau gear resists, only 1.8s! Jump eras now and it can't follow.", Color("9fdcff"))
	else:
		best.frozen = 5.0
		complete("freeze")
		push_message("%s frozen in time for 5s." % best.label, Color("9fdcff"))


# ---------------------------------------------------------------- time pad

func _apply_speed() -> void:
	Engine.time_scale = user_speed * (0.3 if pad_open else 1.0)


## The Time Pad bracer dial. While it's open the world slows to a crawl.
func set_pad_open(open: bool) -> void:
	pad_open = open
	if open:
		pad_index = era
	_apply_speed()


func pad_confirm() -> void:
	var target := pad_index
	set_pad_open(false)
	jump_to(target)


# ---------------------------------------------------------------- weapons & gadgets

func select_weapon(i: int) -> void:
	weapon = i
	player.set_weapon(i)
	push_message("%s - %s" % [WEAPONS[i].name, WEAPONS[i].hint], Color("9fdcff"), 2.0)


func use_weapon(origin: Vector3, dir: Vector3) -> void:
	if attack_cooldown > 0.0:
		return
	dir = dir.normalized()
	player.face_aim()
	match WEAPONS[weapon].id:
		"blade":
			_blade_attack()
		"pistol":
			_fire_pistol(origin, dir)
		"stasis":
			_throw_stasis(dir)
		"blink":
			_blink(dir)


func _blade_attack() -> void:
	attack_cooldown = 0.45
	player.swing()
	var fwd := Vector3(player.aim_dir().x, 0, player.aim_dir().z).normalized()
	var me := player.global_position
	if cop and cop.state != "portal":
		var to := cop.global_position - me
		if hdist(cop.global_position, me) < 2.8 and Vector3(to.x, 0, to.z).normalized().dot(fwd) > 0.2:
			damage_cop(34.0, 1.2, "Chrono Blade")
	for p in props_root.get_children():
		var to: Vector3 = p.global_position - me
		if not p.held and not p.sunk and hdist(p.global_position, me) < 2.5 and Vector3(to.x, 0, to.z).normalized().dot(fwd) > 0.2:
			p.apply_central_impulse((fwd * 9.0 + Vector3.UP * 2.0) * p.mass)
			p.was_thrown = true
			p.clear_history()


func _fire_pistol(origin: Vector3, dir: Vector3) -> void:
	if reload_timer > 0.0:
		return
	if pistol_ammo <= 0:
		reload_timer = 1.2
		push_message("Reloading...", Color("ffd34d"), 1.2)
		return
	pistol_ammo -= 1
	attack_cooldown = 0.18
	var hit := _raycast(origin + dir * 1.0, dir, 120.0, 1 | 8 | 16)
	var end: Vector3 = origin + dir * 120.0
	var collider = null
	if not hit.is_empty():
		end = hit.position
		collider = hit.collider
	var v = _ray_pick_vehicle(origin, dir, origin.distance_to(end))
	if v:
		end = v.global_position + Vector3(0, 1, 0)
		v.frozen = maxf(v.frozen, 0.6)
	elif collider == cop and cop != null:
		damage_cop(12.0, 0.6, "Pulse Pistol")
	elif collider != null and collider.get_parent() == props_root:
		collider.apply_central_impulse(dir * 6.0 * collider.mass)
		collider.was_thrown = true
		collider.clear_history()
	_spawn_tracer(player.muzzle(), end, Color("ff7a33"))
	if pistol_ammo == 0:
		reload_timer = 1.2


func _throw_stasis(dir: Vector3) -> void:
	if energy < STASIS_COST:
		push_message("Stasis Grenade needs %d Chrono Energy." % int(STASIS_COST), Color("ffb07a"))
		return
	energy -= STASIS_COST
	attack_cooldown = 0.8
	var g := RigidBody3D.new()
	g.collision_layer = 0
	g.collision_mask = 1
	g.continuous_cd = true
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	shape.shape = sph
	g.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	mesh.mesh = sm
	mesh.material_override = _glow_mat(Color("6fd8ff"), 1.0)
	g.add_child(mesh)
	add_child(g)
	g.global_position = player.carry_point()
	g.linear_velocity = dir * 15.0 + Vector3(0, 3.0, 0)
	grenades.append({"body": g, "t": 1.2})


func detonate_stasis(pos: Vector3) -> void:
	var froze := 0
	for v in vehicles_root.get_children():
		if v.global_position.distance_to(pos) < STASIS_RADIUS + 2.0:
			v.frozen = 5.0
			froze += 1
	if froze > 0:
		complete("freeze")
	if cop and cop.state == "chase" and cop.global_position.distance_to(pos) < STASIS_RADIUS:
		cop.frozen = 2.5
		froze += 1
		push_message("Agent caught in stasis for 2.5s - jump now and it can't follow!", Color("9fdcff"))
	_spawn_burst(pos, Color("6fd8ff"), STASIS_RADIUS)
	push_message("Stasis field: %d target(s) frozen." % froze, Color("9fdcff"), 2.0)


func _blink(dir: Vector3) -> void:
	if energy < BLINK_COST:
		push_message("Phase Blink needs %d Chrono Energy." % int(BLINK_COST), Color("ffb07a"))
		return
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	if flat == Vector3.ZERO:
		return
	energy -= BLINK_COST
	attack_cooldown = 0.6
	var from := player.global_position + Vector3(0, 1.0, 0)
	var hit := _raycast(from, flat, BLINK_RANGE, 1 | 2)
	var dist := BLINK_RANGE if hit.is_empty() else maxf(from.distance_to(hit.position) - 0.8, 0.0)
	_spawn_burst(player.global_position + Vector3(0, 1, 0), Color("c070ff"), 1.5)
	player.global_position += flat * dist
	player.update_camera()
	_spawn_burst(player.global_position + Vector3(0, 1, 0), Color("c070ff"), 1.5)


func damage_cop(amount: float, stun: float, source: String) -> void:
	if cop == null or cop.state == "portal":
		return
	cop.hp -= amount
	cop.stunned = maxf(cop.stunned, stun)
	threat = clampf(threat + 2.0, 0.0, 100.0)
	since_disruption = 0.0
	if cop.hp <= 0.0:
		add_threat(10.0, "Took down a Bureau agent")
		resolve_hunt("you fought the agent off with your %s - expect reinforcements" % source, 50.0, 25.0)
	else:
		push_message("%s hit! Agent at %d%%." % [source, int(cop.hp)], Color("ffd34d"), 1.5)


func _update_weapons(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			pistol_ammo = PISTOL_MAG
	for g in grenades:
		g.t -= delta
		if g.t <= 0.0:
			detonate_stasis(g.body.global_position)
			g.body.queue_free()
	grenades = grenades.filter(func(g): return g.t > 0.0)
	for e in effects:
		e.t -= delta
		var k: float = 1.0 - e.t / e.life
		if e.grow > 0.0:
			e.node.scale = Vector3.ONE * maxf(e.grow * k, 0.01)
		e.node.material_override.albedo_color.a = 0.5 * (1.0 - k)
		if e.t <= 0.0:
			e.node.queue_free()
	effects = effects.filter(func(e): return e.t > 0.0)


func _raycast(from: Vector3, dir: Vector3, length: float, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, mask, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func _ray_pick_vehicle(origin: Vector3, dir: Vector3, max_t: float):
	var best = null
	var best_t := max_t
	for v in vehicles_root.get_children():
		var c: Vector3 = v.global_position + Vector3(0, 1.0, 0)
		var t := (c - origin).dot(dir)
		if t > 0.0 and t < best_t and (origin + dir * t).distance_to(c) < 2.8:
			best = v
			best_t = t
	return best


func _glow_mat(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = true
	m.emission = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _spawn_tracer(from: Vector3, to: Vector3, c: Color) -> void:
	var len := from.distance_to(to)
	if len < 0.1:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, len)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _glow_mat(c, 0.9)
	add_child(mi)
	mi.global_position = (from + to) / 2.0
	if not (to - from).normalized().is_equal_approx(Vector3.UP):
		mi.look_at(to, Vector3.UP)
	effects.append({"node": mi, "t": 0.08, "life": 0.08, "grow": 0.0})


func _spawn_burst(pos: Vector3, c: Color, radius: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _glow_mat(c, 0.5)
	mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.01
	effects.append({"node": mi, "t": 0.45, "life": 0.45, "grow": radius})


func plant_seed() -> void:
	var seed = player.held
	player.held = null
	seed.queue_free()
	flags.oak_planted = true
	seen_change[EraData.PAST] = true
	_rebuild_city()
	add_event("historical", "Oak planted in Founders' Square", "You planted a seed in the bare square",
		3, "Square land preserved; the 2025 garage and 2150 ruins depend on it")
	show_banner("TIMELINE EVENT RECORDED",
		"You planted an oak in 1890 Founders' Square. Future states that depend on this square will update. Open the Time Pad (Tab) and jump to 2025 to see the result.")
	complete("plant")
	add_threat(45.0, "Altered a historically significant site")
	cop_cooldown = 3.0


func jump_to(target: int) -> void:
	if target == era:
		push_message("You are already in %s." % EraData.era_info(era).year_label)
		return
	if energy < JUMP_COST:
		push_message("Era Jump needs %d Chrono Energy." % int(JUMP_COST), Color("ffb07a"))
		return
	energy -= JUMP_COST
	var tracked := false
	var shook_off := ""
	if cop:
		if cop.state == "portal":
			cop_cooldown = 6.0
			push_message("The Bureau portal collapsed behind you - they'll re-acquire you soon.", Color("ffb07a"))
		elif cop.can_track() and hdist(cop.global_position, player.global_position) < FOLLOW_RANGE:
			tracked = true
		elif cop.frozen > 0.0:
			shook_off = "you froze the agent and jumped"
		elif cop.stunned > 0.0:
			shook_off = "you stunned the agent and jumped"
		else:
			shook_off = "you jumped while out of the agent's tracking range"
		_remove_cop()
	elif follow_timer >= 0.0:
		tracked = true
	complete("jump")
	if clock - last_jump_time < 10.0:
		add_threat(6.0, "Rapid repeated era jumps - the Bureau is learning your pattern")
	else:
		add_threat(2.0, "Era jump detected")
	last_jump_time = clock
	if player.held and player.held.kind == "cell" and target < EraData.FUTURE and not flags.cell_anachronism:
		flags.cell_anachronism = true
		var from_year: String = EraData.era_info(era).year_label
		var to_year: String = EraData.era_info(target).year_label
		events.append(_event("anachronism", "2150 plasma cell brought to %s" % to_year,
			"You carried future technology from %s" % from_year, 2, "Local technology record contaminated", to_year))
		add_threat(25.0, "Anachronism: future technology introduced into the past")
	_enter_era(target, false)
	jump_flash = 1.0
	if tracked:
		follow_timer = 1.6
		push_message("!! Bureau agent locked onto your jump signature - it's coming through!", Color("ff6b6b"), 4.0)
	elif shook_off != "":
		resolve_hunt(shook_off)
	_arrival_alert()


func _rebuild_city() -> void:
	city.build(era, flags.oak_planted)
	_build_nav()


func _enter_era(target: int, initial: bool) -> void:
	if not initial:
		era_props[era] = _serialize_props()
	for p in props_root.get_children():
		if not p.held:
			props_root.remove_child(p)
			p.queue_free()
	era = target
	_rebuild_city()
	for d in era_props[era]:
		_spawn_prop(d.kind, d.pos, d.get("sunk", false))
	if player.held:
		player.held.clear_history()
	_spawn_traffic()
	player.global_position = find_free_pos(player.global_position)
	player.update_camera()


func _spawn_traffic() -> void:
	for v in vehicles_root.get_children():
		vehicles_root.remove_child(v)
		v.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + era
	for i in EraData.TRAFFIC_AVENUES:
		var x: float = i * EraData.AVE_SPACING
		var dir := 1.0 if i % 2 == 1 else -1.0
		for lane in [-4.5, 0.0, 4.5]:
			for k in range(2):
				var v = Vehicle.new()
				vehicles_root.add_child(v)
				var z := rng.randf_range(EraData.CITY_MIN.y + 10.0, EraData.CITY_MAX.y - 10.0)
				v.setup(era, x + lane, z, dir, rng.randf_range(0.8, 1.2))


func _spawn_prop(kind: String, pos: Vector3, sunk := false) -> Prop:
	var p = Prop.new()
	p.setup(kind, pos, sunk)
	props_root.add_child(p)
	return p


func _serialize_props() -> Array:
	var out := []
	for p in props_root.get_children():
		if p.held or p.is_queued_for_deletion():
			continue
		out.append({"kind": p.kind, "pos": p.global_position, "sunk": p.sunk})
	return out


func _arrival_alert() -> void:
	if not flags.oak_planted or seen_change[era]:
		return
	seen_change[era] = true
	if era == EraData.PRESENT:
		show_banner("CAUSALITY ALERT - 2025",
			"MERIDIAN GARAGE was never built. Founders' Oak Park stands in its place. Cause: the seed you planted in 1890 Founders' Square. Talk to the park keeper (E).")
		complete("see")
	elif era == EraData.FUTURE:
		show_banner("CAUSALITY ALERT - 2150",
			"The collapsed square is now the Oak Biodome Archive, a protected forest. Cause: Founders' Oak (1890) survived and was preserved.")
	elif era == EraData.WASTELAND:
		show_banner("CAUSALITY ALERT - AD 30,000",
			"The crater where Founders' Square stood is now The Last Grove - the only living trees left on Earth, grown from your 1890 oak.")


# ---------------------------------------------------------------- navigation

func _build_nav() -> void:
	var size := EraData.CITY_MAX - EraData.CITY_MIN
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, int(ceil(size.x / NAV_CELL)), int(ceil(size.y / NAV_CELL)))
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for r in city.obstacles:
		var g: Rect2 = r.grow(0.6)
		var c0 := _to_cell(Vector3(g.position.x, 0, g.position.y))
		var c1 := _to_cell(Vector3(g.end.x, 0, g.end.y))
		nav.fill_solid_region(Rect2i(c0, c1 - c0 + Vector2i.ONE), true)


func _to_cell(p: Vector3) -> Vector2i:
	var c := Vector2i(floori((p.x - EraData.CITY_MIN.x) / NAV_CELL), floori((p.z - EraData.CITY_MIN.y) / NAV_CELL))
	return c.clamp(nav.region.position, nav.region.end - Vector2i.ONE)


func _to_world(c: Vector2i) -> Vector3:
	return Vector3(EraData.CITY_MIN.x + (c.x + 0.5) * NAV_CELL, 0, EraData.CITY_MIN.y + (c.y + 0.5) * NAV_CELL)


func _nearest_open_cell(c: Vector2i) -> Vector2i:
	if not nav.is_point_solid(c):
		return c
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
					return n
	return c


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := _nearest_open_cell(_to_cell(from))
	var b := _nearest_open_cell(_to_cell(to))
	var out := PackedVector3Array()
	for c in nav.get_id_path(a, b, true):
		out.append(_to_world(c))
	return out


func is_blocked(p: Vector3) -> bool:
	if p.x < EraData.CITY_MIN.x + 1 or p.z < EraData.CITY_MIN.y + 1 or p.x > EraData.CITY_MAX.x - 1 or p.z > EraData.CITY_MAX.y - 1:
		return true
	for r in city.obstacles:
		if r.grow(0.8).has_point(Vector2(p.x, p.z)):
			return true
	return false


func find_free_pos(p: Vector3) -> Vector3:
	var flat := Vector3(p.x, maxf(p.y, 0.1), p.z)
	if not is_blocked(flat):
		return flat
	for radius in range(2, 80, 2):
		for i in range(16):
			var c := flat + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * radius
			if not is_blocked(c):
				return Vector3(c.x, 0.1, c.z)
	return EraData.PLAYER_START


# ---------------------------------------------------------------- bureau & threat

func tier() -> int:
	var t := 0
	for th in TIER_THRESHOLDS:
		if threat >= th:
			t += 1
	return t


func add_threat(amount: float, reason: String) -> void:
	threat = clampf(threat + amount, 0.0, 100.0)
	since_disruption = 0.0
	push_message("+%d threat: %s" % [int(amount), reason], Color("ffb07a"))


func _update_threat(delta: float) -> void:
	if cop == null and follow_timer < 0.0 and since_disruption > 15.0:
		threat = maxf(threat - 1.2 * delta, 0.0)
	var t := tier()
	if t > last_tier:
		match t:
			1:
				push_message("Threat 1 - Temporal Suspect: Bureau investigators are scanning for anomalies.", Color("ffd34d"), 5.0)
			2:
				push_message("Threat 2 - Wanted Across Time: pursuit squads are being dispatched.", Color("ff8a6b"), 5.0)
			_:
				push_message("Threat %d - %s." % [t, TIER_NAMES[t]], Color("ff6b6b"), 5.0)
	last_tier = t


func _update_bureau(delta: float) -> void:
	if follow_timer >= 0.0:
		follow_timer -= delta
		if follow_timer < 0.0:
			var spot := find_free_pos(player.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 14.0)
			_spawn_cop(spot, 1.2)
			push_message("The agent followed you through time!", Color("ff6b6b"), 4.0)
		return
	if cop == null:
		if tier() >= 2 and cop_cooldown <= 0.0:
			_spawn_cop(_portal_spot(), 2.5)
			push_message("!! Bureau portal opening nearby - run, hide, or fight with time.", Color("ff6b6b"), 4.0)
		return
	if cop.step(delta, player.global_position):
		arrest()
		return
	if cop.state != "chase":
		return
	for p in props_root.get_children():
		if not p.held and p.linear_velocity.length() > 6.0 and p.global_position.distance_to(cop.global_position + Vector3(0, 1, 0)) < 1.6:
			cop.stunned = 1.4
			p.linear_velocity *= -0.3
			push_message("Direct hit! Agent stunned for 1.4s - jump eras now to shake it.", Color("ffd34d"))
			add_threat(4.0, "Assaulted a Bureau agent")
	if hdist(cop.global_position, player.global_position) > EVADE_RANGE:
		evade_timer += delta
		if evade_timer > 4.0:
			resolve_hunt("you outran the agent and broke its trail")
	else:
		evade_timer = 0.0


## A street intersection at a fair distance - close enough to matter, far
## enough to react.
func _portal_spot() -> Vector3:
	var best := Vector3.ZERO
	var best_score := INF
	for i in range(EraData.AVE_COUNT):
		for j in range(EraData.ST_COUNT):
			var p := Vector3(i * EraData.AVE_SPACING, 0.1, j * EraData.ST_SPACING)
			var score := absf(hdist(p, player.global_position) - 45.0)
			if hdist(p, player.global_position) > 30.0 and score < best_score and not is_blocked(p):
				best = p
				best_score = score
	return best


func _spawn_cop(pos: Vector3, portal_seconds: float) -> void:
	_remove_cop()
	cop = TimeCop.new()
	cop.position = pos
	cop.path_provider = find_path
	add_child(cop)
	cop.open_portal(portal_seconds)
	evade_timer = 0.0


func _remove_cop() -> void:
	if cop:
		cop.queue_free()
		cop = null
	evade_timer = 0.0


func resolve_hunt(method: String, threat_after := 30.0, cooldown := 20.0) -> void:
	escapes += 1
	_remove_cop()
	follow_timer = -1.0
	threat = minf(threat, threat_after)
	last_tier = tier()
	cop_cooldown = cooldown
	complete("evade")
	show_banner("HUNT EVADED", "You lost the Bureau: %s. Threat now: %s." % [method, TIER_NAMES[tier()]])


func arrest() -> void:
	arrests += 1
	if player.held:
		player.held.set_held(false)
		player.held = null
	_remove_cop()
	follow_timer = -1.0
	threat = 15.0
	last_tier = tier()
	energy = 0.0
	cop_cooldown = 20.0
	player.global_position = find_free_pos(EraData.PLAYER_START)
	show_banner("ARRESTED",
		"The Bureau drained your Chrono Energy and released you with a warning. Provoke another hunt (e.g. smuggle the 2150 plasma cell into the past) to try escaping.")


func bureau_status() -> String:
	if follow_timer >= 0.0:
		return "Agent tracking your jump signature"
	if cop:
		if cop.state == "portal":
			return "Portal opening in %s" % EraData.era_info(era).year_label
		if cop.frozen > 0.0:
			return "Agent frozen"
		if cop.stunned > 0.0:
			return "Agent stunned"
		if evade_timer > 0.0:
			return "Losing your trail... %.1fs" % (4.0 - evade_timer)
		return "Agent in pursuit (%dm)" % int(hdist(cop.global_position, player.global_position))
	if tier() >= 2:
		return "Squad re-deploying"
	if tier() == 1:
		return "Investigators scanning %s" % EraData.era_info(era).year_label
	return "No active lead"


# ---------------------------------------------------------------- guidance

## Where the green beacon points: the next thing the milestone needs.
func objective_target() -> Dictionary:
	for o in objectives:
		if o.done or o.id == "freeze" or o.id == "jump":
			continue
		if o.id == "rewind":
			var best = null
			for p in props_root.get_children():
				if EraData.is_block_kind(p.kind) and not p.sunk and (best == null or hdist(p.global_position, player.global_position) < hdist(best.global_position, player.global_position)):
					best = p
			if best:
				return {"pos": best.global_position, "label": best.display_name()}
			continue
		if o.id == "plant":
			if era != EraData.PAST:
				return {"label": "Time Pad (Tab) -> 1890"}
			if player.held and player.held.kind == "seed":
				return {"pos": EraData.PLOT_CENTER, "label": "Founders' Square soil"}
			for p in props_root.get_children():
				if p.kind == "seed":
					return {"pos": p.global_position, "label": "Oak seed"}
			return {}
		if o.id == "see":
			if era != EraData.PRESENT:
				return {"label": "Time Pad (Tab) -> 2025"}
			return {"pos": EraData.SQUARE_CENTER, "label": "Founders' Square"}
		if o.id == "evade" and cop:
			return {"pos": cop.global_position, "label": "Time Cop"}
		return {}
	return {}


func _update_beacon() -> void:
	var t := objective_target()
	beacon.visible = t.has("pos") and not (t.label == "Time Cop")
	if beacon.visible:
		beacon.global_position = Vector3(t.pos.x, 110.0, t.pos.z)


# ---------------------------------------------------------------- causality & feedback

func branch_name() -> String:
	return "Verdant branch (altered)" if flags.oak_planted else "Baseline"


func _event(type: String, title: String, cause: String, severity: int, affected: String, year: String) -> Dictionary:
	return {
		"id": "evt_%03d" % (events.size() + 1), "type": type, "title": title,
		"year": year, "location": "New Meridian - Founders' Square", "cause": cause,
		"severity": severity, "affected": affected, "branch": branch_name(),
	}


func add_event(type: String, title: String, cause: String, severity: int, affected: String) -> void:
	events.append(_event(type, title, cause, severity, affected, EraData.era_info(era).year_label))


func complete(id: String) -> void:
	for o in objectives:
		if o.id == id and not o.done:
			o.done = true
			push_message("Objective complete: %s" % o.text, Color("9be37a"), 4.0)
	if not milestone_done and objectives.all(func(o): return o.done):
		milestone_done = true
		show_banner("FIRST PLAYABLE MILESTONE COMPLETE",
			"Rewind, freeze, three eras, a persistent causal change, and a cross-era pursuit. The city stays open - keep experimenting.")


func push_message(text: String, color := Color.WHITE, duration := 3.5) -> void:
	messages.append({"text": text, "color": color, "t": duration})
	if messages.size() > 5:
		messages.pop_front()


func show_banner(title: String, body: String) -> void:
	banner = {"title": title, "body": body, "t": 8.0}


# ---------------------------------------------------------------- save / load

static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func save_game() -> void:
	era_props[era] = _serialize_props()
	var props_out := {}
	for e in era_props:
		var arr := []
		for d in era_props[e]:
			arr.append({"kind": d.kind, "pos": _v3(d.pos), "sunk": d.get("sunk", false)})
		props_out[str(e)] = arr
	var data := {
		"version": 2, "era": era, "pos": _v3(player.global_position), "yaw": player.yaw,
		"energy": energy, "threat": threat, "events": events, "flags": flags,
		"seen_change": {"0": seen_change[0], "1": seen_change[1], "2": seen_change[2]},
		"props": props_out, "held": player.held.kind if player.held else "",
		"objectives": objectives.map(func(o): return o.done),
		"escapes": escapes, "arrests": arrests,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_message("Save failed: %s" % error_string(FileAccess.get_open_error()), Color("ff6b6b"))
		return
	f.store_string(JSON.stringify(data, "  "))
	push_message("Timeline saved (F9 to load).", Color("9be37a"))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_message("No saved timeline yet (F5 to save).")
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 2:
		push_message("Save file is from another version or corrupted.", Color("ff6b6b"))
		return false
	_remove_cop()
	follow_timer = -1.0
	if player.held:
		player.held.queue_free()
		player.held = null
	for e in EraData.ERAS:
		var arr := []
		for d in data.props.get(str(e), []):
			arr.append({"kind": d.kind, "pos": Vector3(d.pos[0], d.pos[1], d.pos[2]), "sunk": d.sunk})
		era_props[e] = arr
	energy = data.energy
	threat = data.threat
	events = data.events
	flags = {"oak_planted": data.flags.oak_planted, "cell_anachronism": data.flags.cell_anachronism}
	for k in data.seen_change:
		seen_change[int(k)] = data.seen_change[k]
	for i in range(mini(objectives.size(), data.objectives.size())):
		objectives[i].done = data.objectives[i]
	milestone_done = objectives.all(func(o): return o.done)
	escapes = int(data.escapes)
	arrests = int(data.arrests)
	era = int(data.era)
	player.global_position = Vector3(data.pos[0], data.pos[1], data.pos[2])
	player.yaw = data.yaw
	_enter_era(era, true)
	if data.held != "":
		var h := _spawn_prop(data.held, player.carry_point())
		h.set_held(true)
		player.held = h
	last_tier = tier()
	cop_cooldown = 3.0
	push_message("Timeline loaded.", Color("9be37a"))
	return true
