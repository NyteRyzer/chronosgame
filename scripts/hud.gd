extends Control
## Screen-space ChronoCore interface: era/branch display, energy, threat
## (text + shapes, not colour alone), objectives, minimap, alerts, ledger, help.

const EraData = preload("res://scripts/era_data.gd")

const TIER_COLORS := [Color("8fd18f"), Color("ffd34d"), Color("ff9f43"), Color("ff6b6b"), Color("d65cff"), Color("ffffff")]
const MAP_SIZE := 210.0

var main: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.player == null:
		return
	var font := ThemeDB.fallback_font
	var vs := size
	var info := EraData.era_info(main.era)

	if main.rewind_active:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.3, 0.7, 1.0, 0.12))
		draw_string(font, Vector2(vs.x / 2.0 - 70, vs.y * 0.3), "<< REWINDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("9fdcff"))
	if main.jump_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, main.jump_flash * 0.8))

	# --- crosshair + context prompt
	var c := vs / 2.0
	draw_arc(c, 10, 0, TAU, 24, Color(1, 1, 1, 0.7), 1.5)
	draw_circle(c, 1.5, Color.WHITE)
	var prompt: String = main.prompt_text()
	if prompt != "":
		draw_string(font, Vector2(c.x - 200, c.y + 60), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color("ffe7a8"))

	# --- era, energy, threat panel
	draw_rect(Rect2(12, 12, 390, 150), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(24, 42), info.name, HORIZONTAL_ALIGNMENT_LEFT, 360, 21, Color.WHITE)
	draw_string(font, Vector2(24, 62), info.short, HORIZONTAL_ALIGNMENT_RIGHT, 356, 13, Color("5fd4ff"))
	var branch_col := Color("9be37a") if main.flags.oak_planted else Color(1, 1, 1, 0.7)
	draw_string(font, Vector2(24, 62), "Timeline: %s" % main.branch_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, branch_col)

	draw_string(font, Vector2(24, 86), "CHRONO ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
	draw_rect(Rect2(130, 76, 260, 12), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(130, 76, 260.0 * main.energy / main.MAX_ENERGY, 12), Color("5fd4ff"))
	for cost in [main.FREEZE_COST, main.JUMP_COST]:
		var x: float = 130.0 + 260.0 * cost / main.MAX_ENERGY
		draw_line(Vector2(x, 74), Vector2(x, 90), Color(1, 1, 1, 0.6), 1.0)
	draw_string(font, Vector2(24, 104), "Freeze %d  |  Era Jump %d  |  Rewind %d/s" % [main.FREEZE_COST, main.JUMP_COST, main.REWIND_DRAIN],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))

	var t: int = main.tier()
	var tc: Color = TIER_COLORS[t]
	draw_string(font, Vector2(24, 128), "THREAT %d/5" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tc)
	for i in range(5):
		var r := Rect2(118 + i * 18, 117, 13, 13)
		if i < t:
			draw_rect(r, tc)
		else:
			draw_rect(r, Color(1, 1, 1, 0.4), false, 1.5)
	draw_string(font, Vector2(214, 128), main.TIER_NAMES[t].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)
	draw_string(font, Vector2(24, 150), "Bureau: %s" % main.bureau_status(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))

	# --- objectives
	var ox := vs.x - 392
	var obj_h: float = 52 + main.objectives.size() * 22
	draw_rect(Rect2(ox, 12, 380, obj_h), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(ox + 12, 32), "FIRST PLAYABLE MILESTONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5fd4ff"))
	var y := 54.0
	for o in main.objectives:
		var mark := "[x]" if o.done else "[ ]"
		var col := Color("9be37a") if o.done else Color.WHITE
		draw_string(font, Vector2(ox + 12, y), "%s %s" % [mark, o.text], HORIZONTAL_ALIGNMENT_LEFT, 360, 12, col)
		y += 22.0
	var target: Dictionary = main.objective_target()
	if target.has("label"):
		var where := ""
		if target.has("pos"):
			where = "  (%dm)" % int(main.hdist(target.pos, main.player.global_position))
		draw_string(font, Vector2(ox + 12, y + 2), "> %s%s" % [target.label, where], HORIZONTAL_ALIGNMENT_LEFT, 360, 13, Color("9be37a"))

	_draw_minimap(font, Rect2(vs.x - MAP_SIZE - 12, vs.y - MAP_SIZE - 46, MAP_SIZE, MAP_SIZE), target)

	# --- portal warning (telegraphed, never a surprise)
	if (main.cop and main.cop.state == "portal") or main.follow_timer >= 0.0:
		var pulse := 0.5 + 0.5 * sin(main.clock * 10.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.3, 0.2, 0.9 * pulse), false, 10.0)
		draw_string(font, Vector2(vs.x / 2.0 - 200, vs.y * 0.25), "!! BUREAU INCOMING - RUN, HIDE, OR PREPARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff8a6b"))

	# --- banner (causality alerts etc.), top-centre between the side panels
	if not main.banner.is_empty():
		var bw := clampf(vs.x - 820.0, 420.0, 640.0)
		var bx := (vs.x - bw) / 2.0
		var a := clampf(main.banner.t, 0.0, 1.0)
		draw_rect(Rect2(bx, 12, bw, 150), Color(0.03, 0.06, 0.12, 0.9 * a))
		draw_rect(Rect2(bx, 12, bw, 150), Color(0.37, 0.83, 1.0, a), false, 2.0)
		draw_string(font, Vector2(bx + 14, 38), main.banner.title, HORIZONTAL_ALIGNMENT_LEFT, bw - 28, 18, Color(0.6, 0.95, 1.0, a))
		draw_multiline_string(font, Vector2(bx + 14, 62), main.banner.body, HORIZONTAL_ALIGNMENT_LEFT, bw - 28, 13, 6, Color(1, 1, 1, a))

	# --- message log
	var my := vs.y - 112.0
	for i in range(main.messages.size() - 1, -1, -1):
		var m = main.messages[i]
		var ma := clampf(m.t, 0.0, 1.0)
		draw_string(font, Vector2(20, my), m.text, HORIZONTAL_ALIGNMENT_LEFT, vs.x - MAP_SIZE - 60, 15, Color(m.color, ma))
		my -= 22.0

	# --- controls bar
	draw_rect(Rect2(0, vs.y - 34, vs.x, 34), Color(0, 0, 0, 0.65))
	draw_string(font, Vector2(16, vs.y - 12),
		"WASD move  Shift sprint  Space jump  Tab TIME PAD  1-4/wheel weapons  LMB attack/throw  E grab/plant/talk  R(hold) Rewind  F Stop Time  L Ledger  H Help  F5/F9 Save/Load",
		HORIZONTAL_ALIGNMENT_LEFT, vs.x - 32, 13, Color(1, 1, 1, 0.85))
	if main.user_speed < 1.0:
		draw_string(font, Vector2(20, vs.y - 180), "SPEED %d%%" % int(main.user_speed * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd34d"))

	_draw_weapons(font, vs)
	if main.pad_open:
		_draw_time_pad(font, vs)

	if main.show_ledger:
		_draw_ledger(font, vs)
	elif main.show_help:
		_draw_help(font, vs)
	elif main.paused:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(vs.x / 2.0 - 60, vs.y / 2.0), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(font, Vector2(vs.x / 2.0 - 120, vs.y / 2.0 + 34), "Esc to resume, click to recapture mouse", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


## Rotating-free north-up map of the street grid.
func _draw_minimap(font: Font, r: Rect2, target: Dictionary) -> void:
	var lo := EraData.CITY_MIN
	var span := EraData.CITY_MAX - lo
	var k := minf(r.size.x / span.x, r.size.y / span.y)
	var origin := r.position + (r.size - span * k) / 2.0
	var to_map := func(p: Vector3) -> Vector2:
		# +Z (uptown) is drawn upward
		return origin + Vector2((p.x - lo.x) * k, (EraData.CITY_MAX.y - p.z) * k)
	draw_rect(r.grow(4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position.x - 4, r.position.y - 4, maxf((EraData.RIVER_X - lo.x) * k, 0.0) + 6, r.size.y + 8), Color(0.2, 0.4, 0.6, 0.6))
	var road := Color(1, 1, 1, 0.25)
	for i in range(EraData.AVE_COUNT):
		var a: Vector2 = to_map.call(Vector3(i * EraData.AVE_SPACING, 0, lo.y))
		var b: Vector2 = to_map.call(Vector3(i * EraData.AVE_SPACING, 0, EraData.CITY_MAX.y))
		draw_line(a, b, road, maxf(EraData.AVE_WIDTH * k, 1.0))
	for j in range(EraData.ST_COUNT):
		var a: Vector2 = to_map.call(Vector3(lo.x, 0, j * EraData.ST_SPACING))
		var b: Vector2 = to_map.call(Vector3(EraData.CITY_MAX.x, 0, j * EraData.ST_SPACING))
		draw_line(a, b, road, maxf(EraData.ST_WIDTH * k, 1.0))
	var sq := EraData.SQUARE
	var sq0: Vector2 = to_map.call(Vector3(sq.position.x, 0, sq.end.y))
	draw_rect(Rect2(sq0, sq.size * k), Color(0.4, 0.8, 0.4, 0.5) if main.flags.oak_planted else Color(0.8, 0.7, 0.5, 0.4))
	var cb := EraData.block_rect(EraData.CLOCK_BLOCK.x, EraData.CLOCK_BLOCK.y)
	draw_rect(Rect2(to_map.call(Vector3(cb.position.x, 0, cb.end.y)), cb.size * k), Color(0.9, 0.9, 0.6, 0.5))
	if target.has("pos"):
		var tp: Vector2 = to_map.call(target.pos)
		draw_circle(tp, 5, Color("9be37a"))
		draw_arc(tp, 8, 0, TAU, 16, Color("9be37a"), 1.5)
	for v in main.vehicles_root.get_children():
		draw_rect(Rect2(to_map.call(v.global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.8, 0.3, 0.8) if v.frozen <= 0.0 else Color("9fdcff"))
	if main.cop:
		draw_circle(to_map.call(main.cop.global_position), 5, Color("ff4040"))
	var pp: Vector2 = to_map.call(main.player.global_position)
	var fwd: Vector3 = Basis(Vector3.UP, main.player.yaw) * Vector3(0, 0, -1)
	var f2 := Vector2(fwd.x, -fwd.z).normalized()
	draw_colored_polygon(PackedVector2Array([pp + f2 * 8, pp + f2.orthogonal() * 4 - f2 * 4, pp - f2.orthogonal() * 4 - f2 * 4]), Color.WHITE)
	draw_string(font, r.position + Vector2(4, 14), "UPTOWN ^", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))


func _draw_weapons(font: Font, vs: Vector2) -> void:
	var n: int = main.WEAPONS.size()
	var w := 150.0
	var x0 := (vs.x - n * (w + 6)) / 2.0
	var y0 := vs.y - 92.0
	for i in range(n):
		var r := Rect2(x0 + i * (w + 6), y0, w, 48)
		var sel: bool = i == main.weapon
		draw_rect(r, Color(0.05, 0.1, 0.18, 0.85 if sel else 0.55))
		draw_rect(r, Color("5fd4ff") if sel else Color(1, 1, 1, 0.25), false, 2.0 if sel else 1.0)
		var wd: Dictionary = main.WEAPONS[i]
		draw_string(font, r.position + Vector2(8, 18), "%d  %s" % [i + 1, wd.name], HORIZONTAL_ALIGNMENT_LEFT, w - 12, 13, Color.WHITE if sel else Color(1, 1, 1, 0.6))
		var sub := ""
		match wd.id:
			"pistol":
				sub = "RELOADING" if main.reload_timer > 0.0 else "%d / %d" % [main.pistol_ammo, main.PISTOL_MAG]
			"stasis":
				sub = "%d energy" % int(main.STASIS_COST)
			"blink":
				sub = "%d energy" % int(main.BLINK_COST)
			_:
				sub = "melee"
		draw_string(font, r.position + Vector2(8, 38), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 12, 12, Color("ffd34d") if wd.id == "pistol" else Color(1, 1, 1, 0.55))


## The Time Pad bracer dial, drawn like the device's own screen.
func _draw_time_pad(font: Font, vs: Vector2) -> void:
	var w := 560.0
	var h := 64.0 + EraData.ERAS.size() * 44.0
	var r := Rect2((vs.x - w) / 2.0, (vs.y - h) / 2.0, w, h)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.05, 0.1, 0.35))
	draw_rect(r.grow(10), Color("2a2f3a"))
	draw_rect(r, Color(0.02, 0.08, 0.12, 0.96))
	draw_rect(r, Color("5fd4ff"), false, 2.0)
	draw_string(font, r.position + Vector2(18, 30), "TIME PAD  //  CHRONOCORE BRACER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("5fd4ff"))
	var can_jump: bool = main.energy >= main.JUMP_COST
	draw_string(font, r.position + Vector2(18, 52), "Energy %d / jump cost %d%s" % [int(main.energy), int(main.JUMP_COST), "" if can_jump else "  - RECHARGING"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if can_jump else Color("ffb07a"))
	for i in EraData.ERAS:
		var info: Dictionary = EraData.era_info(i)
		var row := Rect2(r.position.x + 12, r.position.y + 64 + i * 44, w - 24, 38)
		var sel: bool = i == main.pad_index
		var here: bool = i == main.era
		draw_rect(row, Color(0.37, 0.83, 1.0, 0.25) if sel else Color(1, 1, 1, 0.04))
		if sel:
			draw_rect(row, Color("5fd4ff"), false, 2.0)
		draw_string(font, row.position + Vector2(12, 25), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("5fd4ff"))
		draw_string(font, row.position + Vector2(44, 25), info.year_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(font, row.position + Vector2(220, 25), info.short + ("   (you are here)" if here else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
	draw_string(font, Vector2(r.position.x + 18, r.end.y + 32), "1-5 or wheel + click to jump.  Tab / Esc to close.  The world is slowed while the dial is open.",
		HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color(1, 1, 1, 0.8))


func _panel(font: Font, vs: Vector2, title: String) -> Rect2:
	var r := Rect2(vs.x * 0.12, vs.y * 0.1, vs.x * 0.76, vs.y * 0.78)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(0.04, 0.07, 0.13, 0.96))
	draw_rect(r, Color("5fd4ff"), false, 2.0)
	draw_string(font, r.position + Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	return r


func _draw_ledger(font: Font, vs: Vector2) -> void:
	var r := _panel(font, vs, "TIMELINE LEDGER")
	var y := r.position.y + 72
	var x := r.position.x + 24
	draw_string(font, Vector2(x, y), "Branch: %s     Bureau escapes: %d     Arrests: %d" % [main.branch_name(), main.escapes, main.arrests],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fdcff"))
	y += 32
	if main.events.is_empty():
		draw_string(font, Vector2(x, y), "No recorded changes. The timeline matches the baseline.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.7))
	for e in main.events:
		draw_string(font, Vector2(x, y), "%s  [%s]  %s" % [e.id, e.year, e.title], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		y += 20
		draw_string(font, Vector2(x + 20, y), "Cause: %s   Severity: %d   Type: %s" % [e.cause, e.severity, e.type], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 13, Color(1, 1, 1, 0.7))
		y += 18
		draw_string(font, Vector2(x + 20, y), "Affects: %s" % e.affected, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 13, Color("9be37a"))
		y += 30
	draw_string(font, Vector2(x, r.end.y - 20), "Game paused.  L or Esc to close.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))


func _draw_help(font: Font, vs: Vector2) -> void:
	var r := _panel(font, vs, "CHRONO: SHATTERED TIMELINE")
	var lines := [
		["Everyone in New Meridian lost the same minute. You found the device responsible: the ChronoCore.", Color("9fdcff")],
		["", Color.WHITE],
		["WASD - move.  Shift - sprint.  Space - jump.  Mouse - look and aim.  E - pick up, drop, plant, talk.", Color.WHITE],
		["Left click - throw where you aim.   R (hold) - REWIND objects near you (undo a throw, raise a sunk crate).", Color.WHITE],
		["F - STOP TIME on the traffic or agent under the crosshair (traffic 5s, Bureau agents resist: 1.8s).", Color.WHITE],
		["Tab - TIME PAD bracer: pick an era (1-5 or wheel + click). 66M BC / 1890 / 2025 / 2150 / AD 30,000.", Color.WHITE],
		["1-4 / wheel - weapons: Chrono Blade, Pulse Pistol, Stasis Grenade, Phase Blink. LMB to use.", Color.WHITE],
		["L - Timeline Ledger.   F5 / F9 - save / load.   [ / ] - game speed.   Esc - pause / free the mouse.", Color.WHITE],
		["", Color.WHITE],
		["Change the past and the present will remember. Change too much and the Chrono Enforcement Bureau", Color("ffd34d")],
		["comes for you: outrun it, freeze it and jump eras before it can follow, or fight it off (reinforcements will come).", Color("ffd34d")],
		["", Color.WHITE],
		["The green beacon and the minimap marker point to your next objective.", Color("9be37a")],
	]
	var y := r.position.y + 80
	for l in lines:
		draw_string(font, Vector2(r.position.x + 24, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48, 15, l[1])
		y += 26
	draw_string(font, Vector2(r.position.x + 24, r.end.y - 20), "Press H to begin, then click to capture the mouse.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("5fd4ff"))
