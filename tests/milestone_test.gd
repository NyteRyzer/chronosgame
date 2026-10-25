extends SceneTree
## Headless end-to-end check of the first playable milestone.
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


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://chrono_save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)
	main.show_help = false

	print("Phase 1: throw + rewind")
	main.player.position = Vector2(1250, 560)
	await frames(2)
	var crate = _nearest_prop("crate")
	main.player.position = crate.position + Vector2(-20, 0)
	main.interact()
	check(main.player.held == crate, "picked up crate")
	main.throw_held(Vector2(1500, 560))  # toward the canal
	await frames(90)
	check(crate.sunk, "thrown crate sank in the canal")
	Input.action_press("rewind")
	await frames(120)
	Input.action_release("rewind")
	await frames(1)
	check(not crate.sunk, "rewind restored the sunk crate")
	check(crate.position.distance_to(main.player.position) < 80.0, "crate rewound back to the throw point")
	check(main.objectives[0].done, "rewind objective complete")

	print("Phase 2: freeze hazard")
	main.energy = 100.0
	main.player.position = Vector2(main.hazard.position.x, 260)
	main.freeze_at(main.hazard.position)
	var hx: float = main.hazard.position.x
	await frames(60)
	check(main.hazard.frozen > 0.0 and is_equal_approx(main.hazard.position.x, hx), "hazard frozen in place")
	check(main.objectives[1].done, "freeze objective complete")

	print("Phase 3: era jump keeps carried item")
	main.energy = 100.0
	main.jump_to(EraData.PAST)
	await frames(2)
	check(main.era == EraData.PAST, "now in 1890")
	check(main.world.info.year == 1890, "world loaded 1890 snapshot")
	var seed = _nearest_prop("seed")
	check(seed != null, "seed exists in 1890")

	print("Phase 4: plant seed -> causality + threat")
	main.player.position = seed.position + Vector2(0, 20)
	main.interact()
	check(main.player.held == seed, "picked up seed")
	main.player.position = EraData.PLOT_CENTER + Vector2(0, 40)
	main.interact()
	check(main.flags.oak_planted, "oak planted flag set")
	check(main.events.size() == 1 and main.events[0].year == 1890, "temporal event recorded in ledger")
	check(main.tier() >= 2, "threat reached Wanted Across Time (tier %d, %.0f)" % [main.tier(), main.threat])

	print("Phase 5: Time Cop arrives and follows through an era jump")
	main.player.position = Vector2(1000, 560)
	await frames(60 * 6)
	check(main.cop != null and main.cop.state == "chase", "Time Cop came through the portal")
	main.cop.position = main.player.position + Vector2(150, 0)
	main.energy = 100.0
	main.jump_to(EraData.PRESENT)
	check(main.follow_timer > 0.0, "agent locked onto jump signature")
	check(main.world.changed and main.era == EraData.PRESENT, "2025 shows the altered plaza")
	check(main.objectives[4].done, "see-the-change objective complete")
	await frames(60 * 2)
	check(main.cop != null, "agent followed into 2025")

	print("Phase 6: freeze agent + jump = evade")
	for i in range(120):
		if main.cop and main.cop.state == "chase":
			break
		await frames(1)
	main.energy = 100.0
	main.freeze_at(main.cop.position)
	check(main.cop.frozen > 0.0, "agent frozen")
	main.jump_to(EraData.FUTURE)
	check(main.cop == null and main.follow_timer < 0.0, "agent could not follow")
	check(main.objectives[5].done, "evade objective complete")
	check(main.tier() <= 1, "threat dropped after escape")
	check(main.world.changed and main.era == EraData.FUTURE, "2150 shows the biodome")

	print("Phase 7: persistence")
	main.jump_to(EraData.PRESENT)
	await frames(2)
	main.save_game()
	var saved_threat: float = main.threat
	main.flags.oak_planted = false
	main.threat = 99.0
	check(main.load_game(), "save loaded")
	check(main.flags.oak_planted and is_equal_approx(main.threat, saved_threat), "timeline + threat restored from save")
	check(main.era == EraData.PRESENT and main.world.changed, "era + causal state restored")

	print("Phase 8: arrest path")
	main.threat = 60.0
	main.cop_cooldown = 0.0
	await frames(60 * 3)
	check(main.cop != null, "new hunt started at tier 2")
	main.player.position = main.cop.position
	await frames(5)
	check(main.arrests == 1 and main.cop == null, "player can be arrested")

	print("Milestone complete: ", main.milestone_done)
	check(main.milestone_done, "all first-playable objectives done")
	print("RESULT: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _nearest_prop(kind: String):
	var best = null
	for p in main.props_root.get_children():
		if p.kind == kind and not p.is_queued_for_deletion():
			if best == null or p.position.distance_to(main.player.position) < best.position.distance_to(main.player.position):
				best = p
	return best
