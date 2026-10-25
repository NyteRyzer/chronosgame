extends SceneTree
## Headless end-to-end check of the first playable milestone in the 3D city.
## Run: godot --headless -s tests/milestone_test.gd

const EraData = preload("res://scripts/era_data.gd")

var main: Node
var failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func place(p: Vector3) -> void:
	main.player.global_position = p
	main.player.velocity = Vector3.ZERO


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://chrono_save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)
	main.show_help = false
	main.stutter_timer = 99999.0  # stutters are tested explicitly below
	await frames(30)

	print("Phase 0: city")
	check(main.city.obstacles.size() > 150, "city built with %d footprints" % main.city.obstacles.size())
	check(main.player.is_on_floor(), "player stands on the street")
	check(main.vehicles_root.get_child_count() == 24, "avenue traffic spawned")
	var path: PackedVector3Array = main.find_path(Vector3(10, 0, 10), Vector3(400, 0, 560))
	check(path.size() > 20, "street-grid path across town (%d steps)" % path.size())
	var path_clear := true
	for p in path:
		for r in main.city.obstacles:
			if r.has_point(Vector2(p.x, p.z)):
				path_clear = false
	check(path_clear, "path never enters a building")

	print("Phase 1: throw into the river + rewind")
	place(Vector3(-4, 0.1, 250))
	await frames(5)
	var crate = main.nearest_grabbable()
	check(crate != null, "crate within reach by the seawall")
	main.interact()
	check(main.player.held == crate, "picked up crate")
	main.throw_held(Vector3(-1, 0.3, 0))
	await frames(120)
	check(crate.sunk, "thrown crate sank in the North River")
	Input.action_press("rewind")
	await frames(150)
	Input.action_release("rewind")
	await frames(2)
	check(not crate.sunk, "rewind raised the sunk crate")
	check(crate.global_position.x > EraData.RIVER_X, "crate back on the promenade")
	check(main.objectives[0].done, "rewind objective complete")

	print("Phase 2: freeze traffic")
	main.energy = 100.0
	var v = main.vehicles_root.get_child(0)
	place(Vector3(v.global_position.x + 15, 0.1, v.global_position.z))
	await frames(1)
	var origin: Vector3 = main.player.global_position + Vector3(0, 1.6, 0)
	main.freeze_aim(origin, (v.global_position + Vector3(0, 1, 0)) - origin)
	var vz: float = v.global_position.z
	await frames(60)
	check(v.frozen > 0.0 and is_equal_approx(v.global_position.z, vz), "vehicle frozen in place")
	check(main.objectives[1].done, "freeze objective complete")

	print("Phase 3: Time Pad era jump")
	place(EraData.PLAYER_START)
	main.energy = 100.0
	main.set_pad_open(true)
	check(Engine.time_scale < 0.5, "world slows while the Time Pad dial is open")
	main.pad_index = EraData.PAST
	main.pad_confirm()
	check(not main.pad_open and is_equal_approx(Engine.time_scale, 1.0), "dial closes and time resumes")
	await frames(10)
	check(main.era == EraData.PAST and main.city.info.year == 1890, "city rebuilt as 1890")
	var seed = null
	for p in main.props_root.get_children():
		if p.kind == "seed":
			seed = p
	check(seed != null, "seed exists in 1890")
	check(main.objective_target().get("label", "") == "Oak seed", "beacon points at the seed")

	print("Phase 4: plant seed -> causality + threat")
	place(seed.global_position + Vector3(1.0, 0, 0))
	await frames(2)
	main.interact()
	check(main.player.held == seed, "picked up seed")
	place(EraData.PLOT_CENTER + Vector3(0, 0.3, 3.0))
	await frames(2)
	main.interact()
	check(main.flags.oak_planted, "oak planted flag set")
	check(main.events.size() == 1 and main.events[0].year == "1890", "temporal event recorded in ledger")
	check(main.tier() >= 2, "threat reached Wanted Across Time (tier %d, %.0f)" % [main.tier(), main.threat])

	print("Phase 5: Time Cop arrives, chases along streets, follows through a jump")
	place(Vector3(220, 0.1, 250))
	await frames(60 * 4)
	check(main.cop != null and main.cop.state == "portal" or (main.cop != null and main.cop.state == "chase"), "Bureau portal opened")
	for i in range(240):
		if main.cop and main.cop.state == "chase":
			break
		await frames(1)
	check(main.cop != null and main.cop.state == "chase", "Time Cop came through the portal")
	var d0: float = main.hdist(main.cop.global_position, main.player.global_position)
	await frames(60)
	var d1: float = main.hdist(main.cop.global_position, main.player.global_position) if main.cop else 0.0
	check(d1 < d0, "agent closes distance (%.0fm -> %.0fm)" % [d0, d1])
	main.cop.global_position = main.player.global_position + Vector3(8, 0, 0)
	main.energy = 100.0
	main.jump_to(EraData.PRESENT)
	check(main.follow_timer > 0.0, "agent locked onto jump signature")
	check(main.city.changed and main.era == EraData.PRESENT, "2025 shows the altered square")
	check(main.objectives[4].done, "see-the-change objective complete")
	await frames(110)
	check(main.cop != null, "agent followed into 2025")

	print("Phase 6: freeze agent + jump = evade")
	for i in range(120):
		if main.cop and main.cop.state == "chase":
			break
		await frames(1)
	main.energy = 100.0
	var o2: Vector3 = main.player.global_position + Vector3(0, 1.6, 0)
	main.freeze_aim(o2, (main.cop.global_position + Vector3(0, 1, 0)) - o2)
	check(main.cop.frozen > 0.0, "agent frozen")
	main.jump_to(EraData.FUTURE)
	check(main.cop == null and main.follow_timer < 0.0, "agent could not follow")
	check(main.objectives[5].done, "evade objective complete")
	check(main.tier() <= 1, "threat dropped after escape")
	check(main.city.changed and main.era == EraData.FUTURE, "2150 shows the biodome")

	print("Phase 6b: Cretaceous + wasteland eras")
	main.energy = 100.0
	main.jump_to(EraData.PREHISTORIC)
	await frames(5)
	check(main.era == EraData.PREHISTORIC and main.vehicles_root.get_child(0).label == "Triceratops", "Cretaceous loaded with triceratops herds")
	check(main.city.obstacles.size() > 50, "jungle obstacles for pathfinding (%d)" % main.city.obstacles.size())
	check(not main.is_blocked(main.player.global_position), "player placed in open ground")
	main.energy = 100.0
	main.jump_to(EraData.WASTELAND)
	await frames(5)
	check(main.era == EraData.WASTELAND and main.vehicles_root.get_child(0).label == "Scrap crawler", "wasteland loaded with scrap crawlers")
	check(main.seen_change[EraData.WASTELAND] and main.banner.title.contains("30,000"), "the 1890 oak echoes as The Last Grove")

	print("Phase 7: persistence")
	main.energy = 100.0
	main.jump_to(EraData.PRESENT)
	await frames(2)
	main.save_game()
	var saved_threat: float = main.threat
	main.flags.oak_planted = false
	main.threat = 99.0
	check(main.load_game(), "save loaded")
	check(main.flags.oak_planted and is_equal_approx(main.threat, saved_threat), "timeline + threat restored from save")
	check(main.era == EraData.PRESENT and main.city.changed, "era + causal state restored")

	print("Phase 8: arrest path")
	main.threat = 60.0
	main.cop_cooldown = 0.0
	await frames(60 * 3)
	check(main.cop != null, "new hunt started at tier 2")
	main.cop.state = "chase"
	main.cop.global_position = main.player.global_position + Vector3(0.5, 0, 0)
	await frames(5)
	check(main.arrests == 1 and main.cop == null, "player can be arrested")

	print("Phase 9: weapons and gadgets")
	main.threat = 60.0
	main.cop_cooldown = 0.0
	place(Vector3(220, 0.1, 250))
	for i in range(400):
		if main.cop and main.cop.state == "chase":
			break
		await frames(1)
	main.cop.global_position = main.player.global_position + Vector3(0, 0, 6)
	await frames(1)
	main.select_weapon(1)
	var eye: Vector3 = main.player.global_position + Vector3(0, 1.6, 0)
	main.attack_cooldown = 0.0
	main.use_weapon(eye, (main.cop.global_position + Vector3(0, 1.0, 0)) - eye)
	check(main.cop.hp < 100.0 and main.cop.stunned > 0.0, "Pulse Pistol hits and stuns the agent (%d%%)" % int(main.cop.hp))
	check(main.pistol_ammo == main.PISTOL_MAG - 1, "pistol uses ammo")
	main.cop.global_position = main.player.global_position + Vector3(0, 0, 1.8)
	main.player.yaw = PI
	main.player.pitch = 0.0
	main.player.update_camera()
	main.select_weapon(0)
	var hp_before: float = main.cop.hp
	main.attack_cooldown = 0.0
	main.use_weapon(main.player.aim_origin(), main.player.aim_dir())
	check(main.cop.hp < hp_before, "Chrono Blade strikes the agent")
	for i in range(3):
		main.attack_cooldown = 0.0
		if main.cop:
			main.cop.global_position = main.player.global_position + Vector3(0, 0, 1.8)
			main.use_weapon(main.player.aim_origin(), main.player.aim_dir())
	check(main.cop == null and main.escapes >= 2, "agent fought off")
	check(main.tier() >= 2, "fighting escalates: reinforcements will come (tier %d)" % main.tier())
	main.select_weapon(2)
	main.energy = 100.0
	var veh = main.vehicles_root.get_child(0)
	place(Vector3(veh.global_position.x + 10, 0.1, veh.global_position.z))
	await frames(1)
	veh.frozen = 0.0
	main.detonate_stasis(veh.global_position)
	check(veh.frozen > 4.0, "stasis field freezes traffic")
	main.attack_cooldown = 0.0
	main.use_weapon(main.player.aim_origin(), main.player.aim_dir())
	check(main.grenades.size() == 1 and main.energy < 100.0, "stasis grenade thrown")
	await frames(90)
	check(main.grenades.is_empty(), "grenade detonated")
	main.select_weapon(3)
	main.energy = 100.0
	place(Vector3(220, 0.1, 250))
	main.player.yaw = PI / 2.0  # face down the open street (-X)
	main.player.update_camera()
	var before: Vector3 = main.player.global_position
	main.attack_cooldown = 0.0
	main.use_weapon(main.player.aim_origin(), main.player.aim_dir())
	check(main.hdist(before, main.player.global_position) > 5.0, "Phase Blink teleports (%.1fm)" % main.hdist(before, main.player.global_position))

	print("Phase 10: hijack + 88 mph time jump")
	main.threat = 0.0
	main._remove_cop()
	main.energy = 100.0
	main.jump_to(EraData.PRESENT)
	await frames(2)
	var cab = main.vehicles_root.get_child(0)
	place(cab.global_position + Vector3(3.0, 0.1, 0))
	await frames(1)
	check(main.prompt_text().begins_with("[F] Hijack"), "hijack prompt next to a cab")
	main.toggle_vehicle()
	check(main.player.driving and main.player.vehicle == cab, "player drives the cab")
	main.set_pad_open(true)
	main.pad_index = EraData.PAST
	main.pad_confirm()
	check(main.dialed_era == EraData.PAST and main.era == EraData.PRESENT, "Time Pad sets a destination instead of jumping")
	main.energy = 100.0
	main.player.car_speed = 40.0  # 89.5 mph
	await frames(2)
	check(main.era == EraData.PAST, "hitting 88 mph jumps to 1890")
	check(main.player.driving and main.player.vehicle == cab, "the cab came through time with you")
	check(main.tier() >= 1, "anachronistic cab raises threat (%.0f)" % main.threat)
	main.toggle_vehicle()
	check(not main.player.driving and cab.parked, "exit and park the vehicle")

	print("Phase 11: hacking, profiler, time dodge, stutter")
	main.energy = 100.0
	main.jump_to(EraData.PRESENT)
	await frames(2)
	var w = main.city.walkers[0]
	var eye2: Vector3 = w.node.global_position + Vector3(6, 1.6, 0)
	var bio := EraData.citizen_bio(main.era, w.idx)
	check(bio.name != "" and bio.line != "", "Profiler bio: %s - %s" % [bio.name, bio.line])
	main.energy = 100.0
	var car = main.vehicles_root.get_child(1)
	car.stall = 0.0
	var eye3: Vector3 = car.global_position + Vector3(12, 1.6, 0)
	main.hack_aim(eye3, (car.global_position + Vector3(0, 1, 0)) - eye3)
	check(car.stall > 0.0 and main.energy < 100.0, "hack stalls a car")
	place(Vector3(220, 0.1, 252))
	main.player.yaw = PI / 2.0
	await frames(1)
	var p0: Vector3 = main.player.global_position
	main.time_dodge()
	await frames(15)
	check(main.hdist(p0, main.player.global_position) > 5.0 and main.dodge_cooldown > 0.0, "Time Dodge dashes (%.1fm)" % main.hdist(p0, main.player.global_position))
	main.stutter_timer = 0.0
	await frames(2)
	var vz2: float = main.vehicles_root.get_child(2).global_position.z
	await frames(30)
	check(main.stutter > 0.0 and is_equal_approx(main.vehicles_root.get_child(2).global_position.z, vz2), "time stutter freezes the city")
	main.stutter_timer = 99999.0
	await frames(150)
	check(main.stutter <= 0.0 and not main.city.time_frozen, "stutter ends")

	print("Phase 12: Hunter-Killer + jamming")
	main.threat = 75.0
	main.cop_cooldown = 0.0
	for i in range(400):
		if main.cop and main.cop.state == "chase":
			break
		await frames(1)
	check(main.cop != null and main.cop.hunter, "threat 3 sends the HK hunter-killer")
	var hk = main.cop
	main.damage_cop(500.0, 1.0, "test")
	check(main.cop == hk and hk.stunned > 0.0, "HK unit only staggers - cannot be destroyed")
	hk.stunned = 0.0
	hk.global_position = main.player.global_position + Vector3(0, 0, 6)
	main.energy = 100.0
	var eye4: Vector3 = main.player.global_position + Vector3(0, 1.6, 0)
	main.hack_aim(eye4, (hk.global_position + Vector3(0, 1, 0)) - eye4)
	check(hk.jammed > 0.0 and not hk.can_track(), "hack jams the hunter's tracking")
	main.energy = 100.0
	main.jump_to(EraData.FUTURE)
	check(main.cop == null and main.follow_timer < 0.0, "jumping while it's jammed escapes it")

	print("Phase 13: aberrations")
	var egg = null
	for p in main.props_root.get_children():
		if p.kind == "egg":
			egg = p
	check(egg != null, "dinosaur egg aberration found in 2150")
	place(egg.global_position + Vector3(1, 0, 0))
	await frames(1)
	main.interact()
	check(main.player.held == egg, "picked up the egg")
	main.energy = 100.0
	main.jump_to(EraData.PREHISTORIC)
	await frames(2)
	check(main.prompt_text().contains("Restore"), "restore prompt in its home era")
	var before_threat: float = main.threat
	main.interact()
	check(main.aberrations_fixed == 1 and main.threat < before_threat, "aberration restored, threat reduced")

	print("Milestone complete: ", main.milestone_done)
	check(main.milestone_done, "all first-playable objectives done")
	print("RESULT: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
