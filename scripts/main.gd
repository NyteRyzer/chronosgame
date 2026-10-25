extends Node2D
## Game orchestrator for the first playable milestone: ChronoCore powers,
## era jumps, the Timeline Causality System, threat, the Bureau hunt, and
## save/load. All simulation is stepped from here so order is deterministic.

const EraData = preload("res://scripts/era_data.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Player = preload("res://scripts/player.gd")
const Prop = preload("res://scripts/prop.gd")
const Hazard = preload("res://scripts/hazard.gd")
const TimeCop = preload("res://scripts/time_cop.gd")
const Hud = preload("res://scripts/hud.gd")

const SAVE_PATH := "user://chrono_save.json"
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 9.0
const JUMP_COST := 35.0
const FREEZE_COST := 25.0
const REWIND_DRAIN := 28.0
const REWIND_RADIUS := 420.0
const FREEZE_RANGE := 520.0
const FREEZE_RADIUS := 90.0
const THROW_SPEED := 680.0
const TIER_THRESHOLDS := [20.0, 45.0, 70.0, 90.0, 100.0]
const TIER_NAMES := ["Unnoticed", "Temporal Suspect", "Wanted Across Time", "Chrono Fugitive", "Time Anomaly", "Threat to Reality"]

var world: WorldView
var props_root: Node2D
var player: Player
var hazard: Hazard
var cop: TimeCop = null
var overlay: Node2D
var hud: Hud

var era := EraData.PRESENT
var energy := MAX_ENERGY
var threat := 0.0
var events: Array = []
var flags := {"oak_planted": false, "cell_anachronism": false}
var seen_change := {EraData.PAST: false, EraData.PRESENT: false, EraData.FUTURE: false}
var era_props := {}
var objectives: Array = [
	{"id": "rewind", "text": "Throw an object (LMB), then hold R to rewind it", "done": false},
	{"id": "freeze", "text": "Freeze the vehicle on the road (aim + F)", "done": false},
	{"id": "jump", "text": "Jump to another era (1 / 2 / 3)", "done": false},
	{"id": "plant", "text": "Plant the oak seed in the 1890 plaza soil", "done": false},
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
var show_ledger := false
var show_help := true
var paused := false
var milestone_done := false


func _ready() -> void:
	randomize()
	_setup_input()
	world = WorldView.new()
	add_child(world)
	props_root = Node2D.new()
	add_child(props_root)
	hazard = Hazard.new()
	add_child(hazard)
	player = Player.new()
	add_child(player)
	overlay = Node2D.new()
	overlay.z_index = 20
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)
	for e in [EraData.PAST, EraData.PRESENT, EraData.FUTURE]:
		era_props[e] = EraData.initial_props(e)
	player.position = EraData.PLAYER_START
	_enter_era(EraData.PRESENT, true)
	push_message("ChronoCore online. Something happened to the Missing Minute... start experimenting.", Color("5fd4ff"), 7.0)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E], "rewind": [KEY_R], "freeze": [KEY_F],
		"era_1": [KEY_1], "era_2": [KEY_2], "era_3": [KEY_3],
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		show_help = not show_help
		show_ledger = false
		return
	if event.is_action_pressed("ledger"):
		show_ledger = not show_ledger
		show_help = false
		return
	if event.is_action_pressed("pause"):
		if show_help or show_ledger:
			show_help = false
			show_ledger = false
		else:
			paused = not paused
		return
	if event.is_action_pressed("slower"):
		Engine.time_scale = maxf(0.5, Engine.time_scale - 0.25)
		push_message("Game speed %d%%" % int(Engine.time_scale * 100.0))
	elif event.is_action_pressed("faster"):
		Engine.time_scale = minf(1.0, Engine.time_scale + 0.25)
		push_message("Game speed %d%%" % int(Engine.time_scale * 100.0))
	if is_paused():
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("throw"):
		throw_held(get_global_mouse_position())
	elif event.is_action_pressed("freeze"):
		freeze_at(get_global_mouse_position())
	elif event.is_action_pressed("era_1"):
		jump_to(EraData.PAST)
	elif event.is_action_pressed("era_2"):
		jump_to(EraData.PRESENT)
	elif event.is_action_pressed("era_3"):
		jump_to(EraData.FUTURE)
	elif event.is_action_pressed("save"):
		save_game()
	elif event.is_action_pressed("load"):
		load_game()


func is_paused() -> bool:
	return paused or show_help or show_ledger


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if is_paused():
		return
	clock += delta
	since_disruption += delta
	cop_cooldown -= delta
	jump_flash = maxf(jump_flash - delta * 2.0, 0.0)

	player.step(delta, get_global_mouse_position())
	if player.held:
		player.held.position = player.position + player.facing * 22.0

	var want_rewind := Input.is_action_pressed("rewind") and energy > 0.5
	var any_rewound := false
	for p in props_root.get_children():
		if want_rewind and not p.held and p.position.distance_to(player.position) <= REWIND_RADIUS:
			if p.rewind_step():
				any_rewound = true
				if p.was_thrown:
					rewind_frames += 1
		else:
			p.simulate(delta)
			p.record()
	rewind_active = want_rewind and any_rewound
	if rewind_active:
		energy = maxf(energy - REWIND_DRAIN * delta, 0.0)
	else:
		energy = minf(energy + ENERGY_REGEN * delta, MAX_ENERGY)
	if rewind_frames > 20:
		complete("rewind")

	hazard.step(delta)
	_hazard_collisions()
	_update_bureau(delta)
	_update_threat(delta)


func _process(delta: float) -> void:
	for m in messages:
		m.t -= delta
	messages = messages.filter(func(m): return m.t > 0.0)
	if not banner.is_empty():
		banner.t -= delta
		if banner.t <= 0.0:
			banner = {}
	overlay.queue_redraw()


func _hazard_collisions() -> void:
	if hazard.frozen > 0.0:
		return
	var hr: Rect2 = hazard.rect()
	if player.stun <= 0.0 and hr.grow(12.0).has_point(player.position):
		var away := 1.0 if player.position.y >= hazard.position.y else -1.0
		player.knock = Vector2(hazard.dir * 200.0, away * 560.0)
		player.stun = 0.6
		energy = maxf(energy - 10.0, 0.0)
		push_message("Hit by the %s! Aim at it and press F to Stop Time." % hazard.label.to_lower(), Color("ff8a6b"))
	for p in props_root.get_children():
		if not p.held and not p.sunk and hr.grow(10.0).has_point(p.position):
			p.velocity = Vector2(hazard.dir * hazard.speed * 1.6, (p.position.y - hazard.position.y) * 6.0)


# ---------------------------------------------------------------- powers

func interact() -> void:
	if player.held:
		var h = player.held
		if h.kind == "seed" and era == EraData.PAST and player.position.distance_to(EraData.PLOT_CENTER) < 75.0:
			plant_seed()
			return
		h.held = false
		h.position = player.position + player.facing * 24.0
		h.clear_history()
		player.held = null
		return
	var best = null
	var best_d := 48.0
	for p in props_root.get_children():
		var d: float = p.position.distance_to(player.position)
		if not p.sunk and d < best_d:
			best = p
			best_d = d
	if best:
		best.held = true
		best.velocity = Vector2.ZERO
		player.held = best
		if best.kind == "seed":
			push_message("Oak seed. The old square south of the road has bare soil...", Color("9be37a"), 5.0)
		elif best.kind == "cell":
			push_message("Plasma cell (2150 tech). Carrying it into an earlier era is a serious temporal crime.", Color("2ee6d6"), 5.0)
		else:
			push_message("Picked up %s. LMB to throw." % best.display_name())
		return
	if player.position.distance_to(EraData.NPC_POS) < 70.0:
		var npc := EraData.npc_line(era, flags.oak_planted)
		push_message("%s: \"%s\"" % [npc.name, npc.line], Color("ffe7a8"), 6.0)


func throw_held(target: Vector2) -> void:
	if not player.held:
		return
	var p = player.held
	var dir := (target - player.position).normalized()
	if dir == Vector2.ZERO:
		dir = player.facing
	p.held = false
	p.position = player.position + dir * 24.0
	p.velocity = dir * THROW_SPEED
	p.was_thrown = true
	p.clear_history()
	player.held = null


func freeze_at(target: Vector2) -> void:
	if target.distance_to(player.position) > FREEZE_RANGE:
		push_message("Stop Time is out of range - move closer.", Color("ffb07a"))
		return
	if energy < FREEZE_COST:
		push_message("Not enough Chrono Energy to Stop Time (%d needed)." % int(FREEZE_COST), Color("ffb07a"))
		return
	if cop and cop.state == "chase" and cop.position.distance_to(target) < FREEZE_RADIUS + 20.0:
		energy -= FREEZE_COST
		cop.frozen = 1.8
		push_message("Agent frozen - Bureau gear resists, only 1.8s! Jump now and it can't follow.", Color("9fdcff"))
		return
	if hazard.rect().grow(FREEZE_RADIUS).has_point(target):
		energy -= FREEZE_COST
		hazard.frozen = 4.0
		complete("freeze")
		push_message("%s frozen in time for 4s." % hazard.label, Color("9fdcff"))
		return
	push_message("Stop Time needs a target - aim at the vehicle or a Bureau agent.")


func plant_seed() -> void:
	var seed = player.held
	player.held = null
	seed.queue_free()
	flags.oak_planted = true
	seen_change[EraData.PAST] = true
	world.build(era, true)
	add_event("historical", "Oak planted in the Old Square", "You planted a seed in the bare plaza soil", 3,
		"Plaza land preserved; 2025 parking lot and 2150 ruins depend on it")
	show_banner("TIMELINE EVENT RECORDED",
		"You planted an oak in the 1890 Old Square. Future states that depend on this plaza will update. Jump to 2025 (key 2) to see the result.")
	complete("plant")
	add_threat(45.0, "Altered a historically significant site")
	cop_cooldown = 3.0


func jump_to(target: int) -> void:
	if target == era:
		push_message("You are already in %d." % EraData.era_info(era).year)
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
		elif cop.can_track() and cop.position.distance_to(player.position) < 480.0:
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
		var from_era := era
		era = target
		add_event("anachronism", "2150 plasma cell brought to %d" % EraData.era_info(target).year,
			"You carried future technology from %d" % EraData.era_info(from_era).year, 2, "Local technology record contaminated")
		era = from_era
		add_threat(25.0, "Anachronism: future technology introduced into the past")
	_enter_era(target, false)
	jump_flash = 1.0
	if tracked:
		follow_timer = 1.6
		push_message("!! Bureau agent locked onto your jump signature - it's coming through!", Color("ff6b6b"), 4.0)
	elif shook_off != "":
		resolve_hunt(shook_off)
	_arrival_alert()


func _enter_era(target: int, initial: bool) -> void:
	if not initial:
		era_props[era] = _serialize_props(false)
	for p in props_root.get_children():
		if not p.held:
			props_root.remove_child(p)
			p.queue_free()
	era = target
	world.build(era, flags.oak_planted)
	for d in era_props[era]:
		_spawn_prop(d.kind, d.pos, d.get("sunk", false))
	if player.held:
		player.held.clear_history()
	hazard.configure(era)
	player.position = find_free_pos(player.position)


func _spawn_prop(kind: String, pos: Vector2, sunk := false) -> Prop:
	var p = Prop.new()
	p.setup(kind, pos, sunk)
	props_root.add_child(p)
	return p


func _serialize_props(include_held: bool) -> Array:
	var out := []
	for p in props_root.get_children():
		if p.held and not include_held:
			continue
		if p.is_queued_for_deletion():
			continue
		out.append({"kind": p.kind, "pos": p.position, "sunk": p.sunk})
	return out


func _arrival_alert() -> void:
	if not flags.oak_planted or seen_change[era]:
		return
	seen_change[era] = true
	if era == EraData.PRESENT:
		show_banner("CAUSALITY ALERT - 2025",
			"MERIDIAN PARKING no longer exists. Founders' Oak Park stands in its place. Cause: the seed you planted in the 1890 Old Square. Talk to the park keeper (E).")
		complete("see")
	elif era == EraData.FUTURE:
		show_banner("CAUSALITY ALERT - 2150",
			"The collapsed plaza is now the Oak Biodome Archive, a protected forest. Cause: Founders' Oak (1890) survived and was preserved.")


func find_free_pos(p: Vector2) -> Vector2:
	if not _blocked(p):
		return p
	for radius in range(20, 600, 20):
		for i in range(16):
			var c := p + Vector2.from_angle(TAU * i / 16.0) * radius
			if not _blocked(c):
				return c
	return EraData.PLAYER_START


func _blocked(p: Vector2) -> bool:
	if p.x < 20 or p.y < 20 or p.x > EraData.WORLD_SIZE.x - 20 or p.y > EraData.WORLD_SIZE.y - 20:
		return true
	for r in world.all_walls() + [EraData.WATER]:
		if r.grow(18.0).has_point(p):
			return true
	return false


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
			var spot := find_free_pos(player.position + Vector2.from_angle(randf() * TAU) * 180.0)
			_spawn_cop(spot, 1.2)
			push_message("The agent followed you through time!", Color("ff6b6b"), 4.0)
		return
	if cop == null:
		if tier() >= 2 and cop_cooldown <= 0.0:
			_spawn_cop(_portal_spot(), 2.5)
			push_message("!! Bureau portal opening nearby - get ready to run, hide, or fight with time.", Color("ff6b6b"), 4.0)
		return
	if cop.step(delta, player.position):
		arrest()
		return
	if cop.state != "chase":
		return
	for p in props_root.get_children():
		if not p.held and p.velocity.length() > 250.0 and p.position.distance_to(cop.position) < 30.0:
			cop.stunned = 1.4
			p.velocity *= -0.3
			push_message("Direct hit! Agent stunned for 1.4s - jump now to shake them.", Color("ffd34d"))
			add_threat(4.0, "Assaulted a Bureau agent")
	if cop.position.distance_to(player.position) > 560.0:
		evade_timer += delta
		if evade_timer > 4.0:
			resolve_hunt("you outran the agent and broke its trail")
	else:
		evade_timer = 0.0


func _portal_spot() -> Vector2:
	var candidates := [Vector2(100, 400), Vector2(1500, 400), Vector2(800, 250), Vector2(1200, 545),
		Vector2(450, 545), Vector2(1100, 250), Vector2(300, 400), Vector2(1250, 780)]
	candidates.sort_custom(func(a, b): return absf(a.distance_to(player.position) - 420.0) < absf(b.distance_to(player.position) - 420.0))
	for c in candidates:
		if c.distance_to(player.position) > 300.0 and not _blocked(c):
			return c
	return find_free_pos(candidates[0])


func _spawn_cop(pos: Vector2, portal_seconds: float) -> void:
	_remove_cop()
	cop = TimeCop.new()
	cop.position = pos
	add_child(cop)
	cop.open_portal(portal_seconds)
	evade_timer = 0.0


func _remove_cop() -> void:
	if cop:
		cop.queue_free()
		cop = null
	evade_timer = 0.0


func resolve_hunt(method: String) -> void:
	escapes += 1
	_remove_cop()
	follow_timer = -1.0
	threat = minf(threat, 30.0)
	last_tier = tier()
	cop_cooldown = 20.0
	complete("evade")
	show_banner("HUNT EVADED", "You lost the Bureau: %s. Threat lowered to Temporal Suspect." % method)


func arrest() -> void:
	arrests += 1
	if player.held:
		player.held.held = false
		player.held.position = player.position
		player.held = null
	_remove_cop()
	follow_timer = -1.0
	threat = 15.0
	last_tier = tier()
	energy = 0.0
	cop_cooldown = 20.0
	player.position = find_free_pos(EraData.PLAYER_START)
	show_banner("ARRESTED",
		"The Bureau drained your Chrono Energy and released you with a warning. Provoke another hunt (e.g. smuggle the 2150 plasma cell into the past) to try escaping.")


func bureau_status() -> String:
	if follow_timer >= 0.0:
		return "Agent tracking your jump signature"
	if cop:
		if cop.state == "portal":
			return "Portal opening in %d" % EraData.era_info(era).year
		if cop.frozen > 0.0:
			return "Agent frozen"
		if cop.stunned > 0.0:
			return "Agent stunned"
		if evade_timer > 0.0:
			return "Losing your trail... %.1fs" % (4.0 - evade_timer)
		return "Agent in pursuit (%dm)" % int(cop.position.distance_to(player.position) / 10.0)
	if tier() >= 2:
		return "Squad re-deploying"
	if tier() == 1:
		return "Investigators scanning %d" % EraData.era_info(era).year
	return "No active lead"


# ---------------------------------------------------------------- causality & feedback

func branch_name() -> String:
	return "Verdant branch (altered)" if flags.oak_planted else "Baseline"


func add_event(type: String, title: String, cause: String, severity: int, affected: String) -> void:
	var info := EraData.era_info(era)
	events.append({
		"id": "evt_%03d" % (events.size() + 1), "type": type, "title": title,
		"year": info.year, "location": "Meridian - Old Square", "cause": cause,
		"severity": severity, "affected": affected, "branch": branch_name(),
	})


func complete(id: String) -> void:
	for o in objectives:
		if o.id == id and not o.done:
			o.done = true
			push_message("Objective complete: %s" % o.text, Color("9be37a"), 4.0)
	if not milestone_done and objectives.all(func(o): return o.done):
		milestone_done = true
		show_banner("FIRST PLAYABLE MILESTONE COMPLETE",
			"Rewind, freeze, three eras, a persistent causal change, and a cross-era pursuit - all in one street. Keep experimenting: the sandbox stays open.")


func push_message(text: String, color := Color.WHITE, duration := 3.5) -> void:
	messages.append({"text": text, "color": color, "t": duration})
	if messages.size() > 5:
		messages.pop_front()


func show_banner(title: String, body: String) -> void:
	banner = {"title": title, "body": body, "t": 8.0}


# ---------------------------------------------------------------- save / load

func save_game() -> void:
	era_props[era] = _serialize_props(false)
	var props_out := {}
	for e in era_props:
		var arr := []
		for d in era_props[e]:
			arr.append({"kind": d.kind, "x": d.pos.x, "y": d.pos.y, "sunk": d.get("sunk", false)})
		props_out[str(e)] = arr
	var data := {
		"version": 1, "era": era, "x": player.position.x, "y": player.position.y,
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
	if typeof(data) != TYPE_DICTIONARY:
		push_message("Save file is corrupted.", Color("ff6b6b"))
		return false
	_remove_cop()
	follow_timer = -1.0
	if player.held:
		player.held.queue_free()
		player.held = null
	for e in [EraData.PAST, EraData.PRESENT, EraData.FUTURE]:
		var arr := []
		for d in data.props.get(str(e), []):
			arr.append({"kind": d.kind, "pos": Vector2(d.x, d.y), "sunk": d.sunk})
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
	_enter_era(era, true)
	player.position = Vector2(data.x, data.y)
	if data.held != "":
		var h := _spawn_prop(data.held, player.position)
		h.held = true
		player.held = h
	last_tier = tier()
	cop_cooldown = 3.0
	push_message("Timeline loaded.", Color("9be37a"))
	return true


# ---------------------------------------------------------------- world-space overlay

func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	var in_range := mouse.distance_to(player.position) <= FREEZE_RANGE
	var ring := Color(0.6, 0.9, 1.0, 0.5) if in_range else Color(1, 1, 1, 0.2)
	overlay.draw_arc(mouse, FREEZE_RADIUS * 0.5, 0, TAU, 32, ring, 2.0)
	overlay.draw_line(mouse - Vector2(8, 0), mouse + Vector2(8, 0), ring, 2.0)
	overlay.draw_line(mouse - Vector2(0, 8), mouse + Vector2(0, 8), ring, 2.0)
	if rewind_active:
		overlay.draw_arc(player.position, REWIND_RADIUS, 0, TAU, 96, Color(0.37, 0.83, 1.0, 0.5), 3.0)
	if player.held and player.held.kind == "seed" and era == EraData.PAST:
		var near := player.position.distance_to(EraData.PLOT_CENTER) < 75.0
		var txt := "[E] Plant seed" if near else "Plant here"
		overlay.draw_string(font, EraData.PLOT_CENTER + Vector2(-48, -50), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9be37a"))
	elif not player.held:
		for p in props_root.get_children():
			if not p.sunk and p.position.distance_to(player.position) < 48.0:
				overlay.draw_string(font, p.position + Vector2(-40, -22), "[E] %s" % p.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
				break
	if player.position.distance_to(EraData.NPC_POS) < 120.0:
		var npc := EraData.npc_line(era, flags.oak_planted)
		var pos := EraData.NPC_POS + Vector2(-150, -70)
		overlay.draw_rect(Rect2(pos - Vector2(8, 18), Vector2(316, 46)), Color(0, 0, 0, 0.7))
		overlay.draw_multiline_string(font, pos, npc.line, HORIZONTAL_ALIGNMENT_LEFT, 300, 13, 3, Color("ffe7a8"))
