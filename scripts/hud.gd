extends Control
## Screen-space ChronoCore interface: era/branch display, energy, threat
## (text + shapes, not colour alone), objectives, alerts, ledger and help.

const EraData = preload("res://scripts/era_data.gd")

const TIER_COLORS := [Color("8fd18f"), Color("ffd34d"), Color("ff9f43"), Color("ff6b6b"), Color("d65cff"), Color("ffffff")]

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
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.3, 0.7, 1.0, 0.10))
		draw_string(font, Vector2(vs.x / 2.0 - 70, 150), "<< REWINDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("9fdcff"))
	if main.jump_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, main.jump_flash * 0.8))

	# --- era, energy, threat panel
	draw_rect(Rect2(12, 12, 380, 150), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(24, 42), "%s" % info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(300, 42), info.short, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5fd4ff"))
	var branch_col := Color("9be37a") if main.flags.oak_planted else Color(1, 1, 1, 0.7)
	draw_string(font, Vector2(24, 62), "Timeline: %s" % main.branch_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, branch_col)

	draw_string(font, Vector2(24, 86), "CHRONO ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
	draw_rect(Rect2(130, 76, 250, 12), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(130, 76, 250.0 * main.energy / main.MAX_ENERGY, 12), Color("5fd4ff"))
	for cost in [main.FREEZE_COST, main.JUMP_COST]:
		var x: float = 130.0 + 250.0 * cost / main.MAX_ENERGY
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
	var obj_h: float = 30 + main.objectives.size() * 22
	draw_rect(Rect2(ox, 12, 380, obj_h), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(ox + 12, 32), "FIRST PLAYABLE MILESTONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5fd4ff"))
	var y := 54.0
	for o in main.objectives:
		var mark := "[x]" if o.done else "[ ]"
		var col := Color("9be37a") if o.done else Color.WHITE
		draw_string(font, Vector2(ox + 12, y), "%s %s" % [mark, o.text], HORIZONTAL_ALIGNMENT_LEFT, 360, 12, col)
		y += 22.0

	# --- portal warning (telegraphed, never a surprise)
	if main.cop and main.cop.state == "portal" or main.follow_timer >= 0.0:
		var pulse := 0.5 + 0.5 * sin(main.clock * 10.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.3, 0.2, 0.9 * pulse), false, 10.0)
		draw_string(font, Vector2(vs.x / 2.0 - 190, 196), "!! BUREAU INCOMING - RUN, HIDE, OR PREPARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff8a6b"))

	# --- banner (causality alerts etc.)
	if not main.banner.is_empty():
		# top-centre, between the side panels, so it never hides the road
		var bw := clampf(vs.x - 820.0, 420.0, 640.0)
		var bx := (vs.x - bw) / 2.0
		var a := clampf(main.banner.t, 0.0, 1.0)
		draw_rect(Rect2(bx, 12, bw, 150), Color(0.03, 0.06, 0.12, 0.9 * a))
		draw_rect(Rect2(bx, 12, bw, 150), Color(0.37, 0.83, 1.0, a), false, 2.0)
		draw_string(font, Vector2(bx + 14, 38), main.banner.title, HORIZONTAL_ALIGNMENT_LEFT, bw - 28, 18, Color(0.6, 0.95, 1.0, a))
		draw_multiline_string(font, Vector2(bx + 14, 62), main.banner.body, HORIZONTAL_ALIGNMENT_LEFT, bw - 28, 13, 6, Color(1, 1, 1, a))

	# --- message log
	var my := vs.y - 64.0
	for i in range(main.messages.size() - 1, -1, -1):
		var m = main.messages[i]
		var ma := clampf(m.t, 0.0, 1.0)
		draw_string(font, Vector2(20, my), m.text, HORIZONTAL_ALIGNMENT_LEFT, vs.x - 40, 15, Color(m.color, ma))
		my -= 22.0

	# --- controls bar
	draw_rect(Rect2(0, vs.y - 34, vs.x, 34), Color(0, 0, 0, 0.65))
	draw_string(font, Vector2(16, vs.y - 12),
		"WASD move   E grab/plant/talk   LMB throw   R (hold) Rewind   F Stop Time   1/2/3 Era Jump   L Ledger   H Help   F5/F9 Save/Load",
		HORIZONTAL_ALIGNMENT_LEFT, vs.x - 32, 13, Color(1, 1, 1, 0.85))
	if Engine.time_scale < 1.0:
		draw_string(font, Vector2(vs.x - 150, vs.y - 44), "SPEED %d%%" % int(Engine.time_scale * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd34d"))

	if main.show_ledger:
		_draw_ledger(font, vs)
	elif main.show_help:
		_draw_help(font, vs)
	elif main.paused:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(vs.x / 2.0 - 60, vs.y / 2.0), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)


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
		draw_string(font, Vector2(x, y), "%s  [%d]  %s" % [e.id, e.year, e.title], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		y += 20
		draw_string(font, Vector2(x + 20, y), "Cause: %s   Severity: %d   Type: %s" % [e.cause, e.severity, e.type], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 13, Color(1, 1, 1, 0.7))
		y += 18
		draw_string(font, Vector2(x + 20, y), "Affects: %s" % e.affected, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 13, Color("9be37a"))
		y += 30
	draw_string(font, Vector2(x, r.end.y - 20), "Game paused.  L or Esc to close.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))


func _draw_help(font: Font, vs: Vector2) -> void:
	var r := _panel(font, vs, "CHRONO: SHATTERED TIMELINE")
	var lines := [
		["Everyone in Meridian lost the same minute. You found the device responsible: the ChronoCore.", Color("9fdcff")],
		["", Color.WHITE],
		["WASD / arrows - move.   Mouse - aim.   E - pick up, drop, plant, talk.   LMB - throw held object.", Color.WHITE],
		["R (hold) - REWIND tracked objects near you (undo a throw, raise a sunk crate).", Color.WHITE],
		["F - STOP TIME on the target under your cursor (vehicles 4s, Bureau agents resist: 1.8s).", Color.WHITE],
		["1 / 2 / 3 - ERA JUMP to 1890 / 2025 / 2150. You keep what you carry; the world loads that era.", Color.WHITE],
		["L - Timeline Ledger.   F5 / F9 - save / load.   [ / ] - game speed.   Esc - pause.", Color.WHITE],
		["", Color.WHITE],
		["Change the past and the present will remember. Change too much and the Chrono Enforcement Bureau", Color("ffd34d")],
		["comes for you: outrun an agent, stun it with a thrown crate, or freeze it and jump eras before it can follow.", Color("ffd34d")],
		["", Color.WHITE],
		["Hint: there is an oak seed at a market stall in 1890...", Color("9be37a")],
	]
	var y := r.position.y + 80
	for l in lines:
		draw_string(font, Vector2(r.position.x + 24, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48, 15, l[1])
		y += 26
	draw_string(font, Vector2(r.position.x + 24, r.end.y - 20), "Press H to begin / close help (game is paused while help is open).", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("5fd4ff"))
