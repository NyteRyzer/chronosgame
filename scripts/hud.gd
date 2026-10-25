extends Control
## Futuristic ChronoCore HUD. Everything is drawn procedurally: chamfered
## holo-panels tinted with the current era's accent colour, segmented meters,
## a compass strip, the radial Time Pad dial, a reactive crosshair, a
## speedometer for the 88 mph jump, the hacking Profiler, and full-screen
## feedback (rewind, damage, time stutters, Bureau incursion). Threat is always
## shown with text and shapes as well as colour.

const EraData = preload("res://scripts/era_data.gd")

const PANEL := Color(0.02, 0.05, 0.09, 0.74)
const PANEL_DARK := Color(0.01, 0.02, 0.04, 0.9)
const WHITE := Color(0.92, 0.97, 1.0)
const DIM := Color(0.6, 0.72, 0.8, 0.75)
const GREEN := Color("7dffb0")
const AMBER := Color("ffb347")
const RED := Color("ff4d5e")
const TIER_COLORS := [Color("7dffb0"), Color("ffe066"), Color("ffb347"), Color("ff6b5e"), Color("e05cff"), Color("ffffff")]
const MAP_SIZE := 200.0

var main: Node
var f_title: Font   # Orbitron bold
var f_head: Font    # Orbitron
var f_body: Font    # Rajdhani medium
var f_bold: Font    # Rajdhani bold
var accent := Color("5fd4ff")
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var orb = load("res://fonts/Orbitron.ttf")
	var raj = load("res://fonts/Rajdhani-Medium.ttf")
	var raj_b = load("res://fonts/Rajdhani-Bold.ttf")
	var fallback := ThemeDB.fallback_font
	f_head = _variation(orb, 600, 1) if orb else fallback
	f_title = _variation(orb, 800, 3) if orb else fallback
	f_body = raj if raj else fallback
	f_bold = raj_b if raj_b else fallback


func _variation(base: Font, weight: int, spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	fv.spacing_glyph = spacing
	return fv


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	queue_redraw()


# ================================================================ drawing kit

func _chamfer(r: Rect2, cut := 12.0) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y - cut), r.end - Vector2(cut, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut),
	])


func _panel(r: Rect2, col := accent, cut := 12.0, fill := PANEL) -> void:
	var poly := _chamfer(r, cut)
	draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Color(col, 0.45), 1.2, true)
	# bright accent on the cut corners
	draw_line(r.position + Vector2(0, cut), r.position + Vector2(cut, 0), col, 2.0, true)
	draw_line(r.end - Vector2(cut, 0), Vector2(r.end.x, r.end.y - cut), col, 2.0, true)
	draw_line(r.position + Vector2(cut + 6, 0), r.position + Vector2(cut + 46, 0), col, 3.0)


func _brackets(r: Rect2, col: Color, len := 14.0, w := 2.0) -> void:
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		draw_line(c[0], c[0] + Vector2(len * c[1].x, 0), col, w)
		draw_line(c[0], c[0] + Vector2(0, len * c[1].y), col, w)


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, s, align, width, size, col)


func _text_w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Skewed segmented meter.
func _seg_bar(r: Rect2, value: float, segments: int, col: Color) -> void:
	var gap := 3.0
	var w := (r.size.x - gap * (segments - 1)) / segments
	var skew := r.size.y * 0.5
	for i in range(segments):
		var x := r.position.x + i * (w + gap)
		var on := float(i) / segments < value - 0.001
		var c := col if on else Color(col, 0.13)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + skew, r.position.y), Vector2(x + w + skew, r.position.y),
			Vector2(x + w, r.end.y), Vector2(x, r.end.y)]), c)


func _keycap(pos: Vector2, key: String, size := 15) -> float:
	var w := maxf(_text_w(f_bold, key, size) + 12.0, 24.0)
	var r := Rect2(pos - Vector2(0, size + 3), Vector2(w, size + 9))
	draw_rect(r, Color(accent, 0.15))
	draw_rect(r, accent, false, 1.2)
	_text(f_bold, Vector2(pos.x, pos.y + 1), key, size, WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	return w


func _vignette(vs: Vector2, col: Color, depth: float) -> void:
	var clear := Color(col, 0.0)
	var inner := Rect2(Vector2(depth, depth), vs - Vector2(depth, depth) * 2.0)
	var o := [Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]
	var i := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for k in range(4):
		var n := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([col, col, clear, clear]))


# ================================================================ main HUD

func _draw() -> void:
	if main == null or main.player == null:
		return
	var vs := size
	var info := EraData.era_info(main.era)
	accent = info.accent

	_draw_screen_fx(vs)
	if main.show_help:
		_draw_boot(vs)
		return
	if not main.player.driving:
		_draw_crosshair(vs)
	_draw_status(vs, info)
	_draw_compass(vs)
	_draw_mission(vs)
	_draw_minimap(Rect2(vs.x - MAP_SIZE - 20, vs.y - MAP_SIZE - 58, MAP_SIZE, MAP_SIZE))
	if main.player.driving:
		_draw_speedometer(vs)
	else:
		_draw_weapons(vs)
	_draw_profiler(vs)
	_draw_feed(vs)
	_draw_banner(vs)
	_draw_footer(vs)
	if main.pad_open:
		_draw_time_pad(vs)
	if main.show_ledger:
		_draw_ledger(vs)
	elif main.paused:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0.02, 0.05, 0.6))
		_text(f_title, Vector2(0, vs.y / 2.0), "PAUSED", 40, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_text(f_body, Vector2(0, vs.y / 2.0 + 36), "Esc to resume  //  click to recapture the mouse", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_screen_fx(vs: Vector2) -> void:
	_vignette(vs, Color(0, 0.02, 0.05, 0.35), 90.0)
	if main.stutter > 0.0:
		# time stutter: the world hangs, the screen tears
		var a: float = minf(main.stutter, 1.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.6, 0.85, 1.0, 0.06 * a))
		for k in range(7):
			var y := fmod(k * 97.0 + floorf(_t * 24.0) * 53.0, vs.y)
			var off := sin(_t * 40.0 + k) * 18.0
			draw_rect(Rect2(off, y, vs.x, 3 + k % 3), Color(accent, 0.22 * a))
		_text(f_title, Vector2(0, vs.y * 0.22), "TIME STUTTER", 18, Color(accent, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if main.rewind_active:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.3, 0.75, 1.0, 0.1))
		for y in range(0, int(vs.y), 4):
			draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0.6, 0.9, 1.0, 0.05))
		_text(f_title, Vector2(0, vs.y * 0.28), "<< REWINDING", 26, Color("9fe4ff"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if main.dodge_flash > 0.0:
		_vignette(vs, Color(accent, main.dodge_flash * 0.8), 140.0)
	if main.hurt_flash > 0.0:
		_vignette(vs, Color(RED, minf(main.hurt_flash, 0.7)), 160.0)
	if main.jump_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(accent.lightened(0.6), main.jump_flash * 0.85))
		for k in range(12):
			var y := fmod(k * 61.0 + _t * 900.0, vs.y)
			draw_rect(Rect2(0, y, vs.x, 2), Color(WHITE, main.jump_flash * 0.6))
	var incoming: bool = (main.cop != null and main.cop.state == "portal") or main.follow_timer >= 0.0
	if incoming:
		var pulse := 0.5 + 0.5 * sin(_t * 10.0)
		var hunter: bool = main.cop != null and main.cop.hunter
		_vignette(vs, Color(RED, 0.35 * pulse), 120.0)
		_brackets(Rect2(Vector2(20, 20), vs - Vector2(40, 40)), Color(RED, 0.5 + 0.5 * pulse), 50.0, 3.0)
		var r := Rect2(vs.x / 2.0 - 250, 62, 500, 30)
		_panel(r, RED, 8.0, Color(0.15, 0.0, 0.02, 0.8))
		var msg := "WARNING // HUNTER-KILLER INBOUND" if hunter else "WARNING // BUREAU INCURSION"
		_text(f_title, r.position + Vector2(0, 21), msg, 14, Color(RED.lightened(0.3), 0.6 + 0.4 * pulse), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_crosshair(vs: Vector2) -> void:
	var c := (vs / 2.0).round()
	var g: float = 7.0 + main.kick * 8.0
	var col := Color(WHITE, 0.85)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * g, c + d * (g + 7.0), col, 2.0)
	draw_circle(c, 1.6, accent)
	if main.hit_flash > 0.0:
		var a: float = main.hit_flash / 0.25
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 6.0, c + d * 13.0, Color(RED, a), 2.5)
	_draw_prompt(vs, c)


func _draw_prompt(vs: Vector2, c: Vector2) -> void:
	var prompt: String = main.prompt_text()
	if prompt == "":
		return
	# "[E] Pick up Crate" -> keycap + label
	var key := ""
	var rest := prompt
	if prompt.begins_with("["):
		var close := prompt.find("]")
		key = prompt.substr(1, close - 1)
		rest = prompt.substr(close + 1).strip_edges()
	var tw := _text_w(f_bold, rest, 18)
	var x := c.x - (tw + 44) / 2.0
	var r := Rect2(x - 12, c.y + 46, tw + 68, 32)
	_panel(r, accent, 6.0)
	if key != "":
		x += _keycap(Vector2(x, c.y + 68), key, 14) + 10.0
	_text(f_bold, Vector2(x, c.y + 69), rest, 18, WHITE)


func _draw_status(vs: Vector2, info: Dictionary) -> void:
	var r := Rect2(18, 18, 380, 138)
	_panel(r)
	_text(f_head, r.position + Vector2(18, 24), "CHRONOCORE  //  TEMPORAL LOCK", 9, DIM)
	_text(f_title, r.position + Vector2(18, 56), info.year_label, 26, accent)
	_text(f_bold, r.position + Vector2(18, 78), "%s   |   %s" % [info.name.to_upper(), info.short], 14, WHITE, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30)
	var altered: bool = main.flags.oak_planted
	var bcol := GREEN if altered else DIM
	var bp := r.position + Vector2(22, 94)
	draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -5), bp + Vector2(5, 0), bp + Vector2(0, 5), bp + Vector2(-5, 0)]), bcol)
	_text(f_bold, bp + Vector2(12, 5), ("TIMELINE: " + main.branch_name()).to_upper(), 13, bcol)
	# energy
	var e: float = main.energy / main.MAX_ENERGY
	var er := Rect2(r.position.x + 18, r.position.y + 110, 290, 12)
	_seg_bar(er, e, 25, accent if e > 0.35 else AMBER)
	for cost in [main.FREEZE_COST, main.JUMP_COST]:
		var x: float = er.position.x + er.size.x * cost / main.MAX_ENERGY
		draw_colored_polygon(PackedVector2Array([Vector2(x, er.end.y + 2), Vector2(x - 4, er.end.y + 8), Vector2(x + 4, er.end.y + 8)]), Color(WHITE, 0.6))
	_text(f_title, Vector2(er.end.x + 14, er.end.y + 1), "%d" % int(main.energy), 15, WHITE)
	_text(f_head, Vector2(er.end.x + 14, er.position.y - 6), "NRG", 8, DIM)

	# threat
	var tr := Rect2(18, 164, 380, 62)
	var t: int = main.tier()
	var tc: Color = TIER_COLORS[t]
	_panel(tr, tc if t >= 2 else accent)
	_text(f_head, tr.position + Vector2(18, 22), "BUREAU THREAT", 9, DIM)
	for i in range(5):
		var p := tr.position + Vector2(130 + i * 22, 16)
		var poly := PackedVector2Array([p, p + Vector2(14, 0), p + Vector2(18, 6), p + Vector2(4, 6)])
		draw_colored_polygon(poly, tc if i < t else Color(WHITE, 0.12))
	_text(f_title, tr.position + Vector2(250, 23), "%d/5" % t, 13, tc)
	var blink := t > 0 and int(_t * 2.0) % 2 == 0
	draw_circle(tr.position + Vector2(24, 44), 4, tc if blink or t == 0 else Color(tc, 0.3))
	_text(f_bold, tr.position + Vector2(36, 49), "%s  -  %s" % [main.TIER_NAMES[t].to_upper(), main.bureau_status()], 14, tc if t > 0 else WHITE, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 50)


## Heading strip. North = uptown (+Z).
func _draw_compass(vs: Vector2) -> void:
	var w := 460.0
	var r := Rect2(vs.x / 2.0 - w / 2.0, 18, w, 34)
	_panel(r, accent, 8.0)
	var fwd: Vector3 = Basis(Vector3.UP, main.player.yaw) * Vector3(0, 0, -1)
	var heading := rad_to_deg(atan2(fwd.x, fwd.z))  # 0 = uptown, 90 = east (+X)
	var span := 120.0
	var cx := r.get_center().x
	for deg in range(-180, 541, 15):
		var rel := wrapf(deg - heading, -180.0, 180.0)
		if absf(rel) > span / 2.0:
			continue
		var x := cx + rel / span * w
		var label: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(posmod(deg, 360), "")
		if label != "":
			_text(f_title, Vector2(x - 20, r.position.y + 22), label, 13, accent if label == "N" else WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40)
		else:
			draw_line(Vector2(x, r.position.y + 8), Vector2(x, r.position.y + (14 if posmod(deg, 45) == 0 else 11)), Color(WHITE, 0.4), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 6, r.end.y), Vector2(cx + 6, r.end.y), Vector2(cx, r.end.y - 7)]), accent)
	var markers := []
	var target: Dictionary = main.objective_target()
	if target.has("pos"):
		markers.append([target.pos, GREEN])
	if main.cop:
		markers.append([main.cop.global_position, RED])
	for m in markers:
		var d: Vector3 = m[0] - main.player.global_position
		var rel := wrapf(rad_to_deg(atan2(d.x, d.z)) - heading, -180.0, 180.0)
		var x := cx + clampf(rel / span, -0.5, 0.5) * w
		var p := Vector2(x, r.end.y + 6)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(-6, 9), p + Vector2(6, 9)]), m[1])
	_text(f_head, Vector2(r.position.x, r.end.y + 30), "%03d" % posmod(int(round(heading)), 360), 10, DIM, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_mission(vs: Vector2) -> void:
	var n: int = main.objectives.size()
	var r := Rect2(vs.x - 398, 18, 380, 96 + n * 24)
	_panel(r)
	_text(f_head, r.position + Vector2(18, 24), "MISSION  //  THE MISSING MINUTE", 9, DIM)
	var y := r.position.y + 50
	for o in main.objectives:
		var p := Vector2(r.position.x + 24, y - 5)
		var diamond := PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)])
		if o.done:
			draw_colored_polygon(diamond, GREEN)
		else:
			var closed := diamond.duplicate()
			closed.append(diamond[0])
			draw_polyline(closed, WHITE, 1.4)
		_text(f_bold, Vector2(r.position.x + 40, y), o.text, 15, Color(GREEN, 0.75) if o.done else WHITE, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 52)
		y += 24
	draw_rect(Rect2(r.position.x + 14, y - 8, r.size.x - 28, 1), Color(accent, 0.3))
	_text(f_bold, Vector2(r.position.x + 24, y + 10), "ABERRATIONS RESTORED  %d / %d" % [main.aberrations_fixed, main.ABERRATIONS.size()], 14, AMBER)
	y += 26
	var target: Dictionary = main.objective_target()
	if target.has("label"):
		var where := ""
		if target.has("pos"):
			where = "   %dm" % int(main.hdist(target.pos, main.player.global_position))
		_text(f_title, Vector2(r.position.x + 18, y + 6), ">> " + target.label.to_upper() + where, 11, GREEN, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30)


## North-up map of the street grid with chamfered frame.
func _draw_minimap(r: Rect2) -> void:
	_panel(r.grow(8), accent, 10.0, PANEL_DARK)
	var lo := EraData.CITY_MIN
	var span := EraData.CITY_MAX - lo
	var k := minf(r.size.x / span.x, r.size.y / span.y)
	var origin := r.position + (r.size - span * k) / 2.0
	var to_map := func(p: Vector3) -> Vector2:
		return origin + Vector2((p.x - lo.x) * k, (EraData.CITY_MAX.y - p.z) * k)
	draw_rect(Rect2(r.position.x, r.position.y, maxf((EraData.RIVER_X - lo.x) * k, 0.0) + 2, r.size.y), Color(0.2, 0.5, 0.8, 0.35))
	var road := Color(accent, 0.22)
	for i in range(EraData.AVE_COUNT):
		draw_line(to_map.call(Vector3(i * EraData.AVE_SPACING, 0, lo.y)), to_map.call(Vector3(i * EraData.AVE_SPACING, 0, EraData.CITY_MAX.y)), road, maxf(EraData.AVE_WIDTH * k, 1.0))
	for j in range(EraData.ST_COUNT):
		draw_line(to_map.call(Vector3(lo.x, 0, j * EraData.ST_SPACING)), to_map.call(Vector3(EraData.CITY_MAX.x, 0, j * EraData.ST_SPACING)), road, maxf(EraData.ST_WIDTH * k, 1.0))
	var sq := EraData.SQUARE
	draw_rect(Rect2(to_map.call(Vector3(sq.position.x, 0, sq.end.y)), sq.size * k), Color(GREEN, 0.4) if main.flags.oak_planted else Color(WHITE, 0.2))
	var cb := EraData.block_rect(EraData.CLOCK_BLOCK.x, EraData.CLOCK_BLOCK.y)
	draw_rect(Rect2(to_map.call(Vector3(cb.position.x, 0, cb.end.y)), cb.size * k), Color(AMBER, 0.4))
	for v in main.vehicles_root.get_children():
		draw_rect(Rect2(to_map.call(v.global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), Color("9fe4ff") if v.frozen > 0.0 else Color(AMBER, 0.8))
	for p in main.props_root.get_children():
		if p.kind in main.ABERRATIONS:
			var ap: Vector2 = to_map.call(p.global_position)
			draw_colored_polygon(PackedVector2Array([ap + Vector2(0, -5), ap + Vector2(5, 0), ap + Vector2(0, 5), ap + Vector2(-5, 0)]), AMBER)
	var target: Dictionary = main.objective_target()
	if target.has("pos"):
		var tp: Vector2 = to_map.call(target.pos)
		draw_arc(tp, 6.0 + 2.0 * sin(_t * 5.0), 0, TAU, 20, GREEN, 1.5)
		draw_circle(tp, 3, GREEN)
	if main.cop:
		var cp: Vector2 = to_map.call(main.cop.global_position)
		draw_arc(cp, 7, 0, TAU, 16, Color(RED, 0.6), 1.5)
		draw_circle(cp, 3.5, RED)
	var pp: Vector2 = to_map.call(main.player.global_position)
	var fwd: Vector3 = Basis(Vector3.UP, main.player.yaw) * Vector3(0, 0, -1)
	var f2 := Vector2(fwd.x, -fwd.z).normalized()
	draw_colored_polygon(PackedVector2Array([pp + f2 * 8, pp + f2.orthogonal() * 4.5 - f2 * 4, pp - f2.orthogonal() * 4.5 - f2 * 4]), WHITE)
	_text(f_head, r.position + Vector2(4, -14), "SECTOR MAP", 9, DIM)
	_text(f_head, Vector2(r.position.x, r.end.y + 4), "N ^", 9, DIM, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x)
	_text(f_head, r.position + Vector2(4, r.size.y + 4), "%04d . %04d" % [int(main.player.global_position.x), int(main.player.global_position.z)], 9, DIM)


func _weapon_icon(id: String, c: Vector2, col: Color) -> void:
	match id:
		"blade":
			draw_line(c + Vector2(-14, 10), c + Vector2(14, -10), col, 3.0)
			draw_line(c + Vector2(-16, 4), c + Vector2(-8, 14), col, 3.0)
		"pistol":
			draw_rect(Rect2(c + Vector2(-14, -6), Vector2(26, 8)), col)
			draw_rect(Rect2(c + Vector2(-12, 2), Vector2(7, 10)), col)
		"stasis":
			draw_arc(c, 9, 0, TAU, 24, col, 2.5)
			draw_circle(c, 4, col)
		"blink":
			for k in range(3):
				var o := c + Vector2(-12 + k * 9, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-4, -8), o + Vector2(4, 0), o + Vector2(-4, 8)]), col, 2.5)


func _draw_weapons(vs: Vector2) -> void:
	var n: int = main.WEAPONS.size()
	var w := 136.0
	var gap := 8.0
	var x0 := (vs.x - n * w - (n - 1) * gap - 186.0) / 2.0
	var y0 := vs.y - 104.0
	for i in range(n):
		var wd: Dictionary = main.WEAPONS[i]
		var sel: bool = i == main.weapon
		var r := Rect2(x0 + i * (w + gap), y0 - (8.0 if sel else 0.0), w, 58)
		_panel(r, accent if sel else Color(WHITE, 0.4), 8.0, Color(0.03, 0.09, 0.15, 0.85) if sel else PANEL)
		var col := accent if sel else Color(WHITE, 0.55)
		_weapon_icon(wd.id, r.position + Vector2(26, 27), col)
		_text(f_title, r.position + Vector2(48, 20), "%d" % (i + 1), 10, col)
		_text(f_bold, r.position + Vector2(48, 36), wd.name.to_upper(), 12, WHITE if sel else DIM, HORIZONTAL_ALIGNMENT_LEFT, w - 50)
		match wd.id:
			"pistol":
				if main.reload_timer > 0.0:
					_text(f_head, r.position + Vector2(48, 50), "RELOADING", 8, AMBER)
				else:
					for a in range(main.PISTOL_MAG):
						draw_rect(Rect2(r.position.x + 48 + a * 6, r.position.y + 43, 4, 8), AMBER if a < main.pistol_ammo else Color(WHITE, 0.15))
			"stasis":
				_text(f_bold, r.position + Vector2(48, 51), "%d NRG" % int(main.STASIS_COST), 12, DIM)
			"blink":
				_text(f_bold, r.position + Vector2(48, 51), "%d NRG" % int(main.BLINK_COST), 12, DIM)
			_:
				_text(f_bold, r.position + Vector2(48, 51), "MELEE", 12, DIM)
	# power cooldown chips (Quantum Break style)
	var px := x0 + n * (w + gap) + 6
	for pw in [["Q", "STOP", main.energy >= main.FREEZE_COST], ["C", "DODGE", main.dodge_cooldown <= 0.0], ["T", "HACK", main.energy >= main.HACK_COST]]:
		var pr := Rect2(px, y0 + 4, 54, 50)
		_panel(pr, accent if pw[2] else Color(WHITE, 0.3), 6.0)
		_text(f_title, pr.position + Vector2(0, 22), pw[0], 14, accent if pw[2] else DIM, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		_text(f_head, pr.position + Vector2(0, 40), pw[1], 7, DIM, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		px += 60


## Speedometer while driving, with the 88 mph time-jump threshold.
func _draw_speedometer(vs: Vector2) -> void:
	var c := Vector2(vs.x / 2.0, vs.y - 92)
	var R := 70.0
	var mph: float = absf(main.player.car_speed) * 2.23694
	var a0 := PI * 0.8
	var a1 := PI * 2.2
	var k := clampf(mph / 110.0, 0.0, 1.0)
	draw_circle(c, R + 10, Color(0.01, 0.03, 0.06, 0.85))
	draw_arc(c, R, a0, a1, 64, Color(WHITE, 0.15), 6.0)
	var threshold := a0 + (a1 - a0) * (88.0 / 110.0)
	draw_arc(c, R, threshold, a1, 24, Color(AMBER, 0.5), 6.0)
	var hot := mph >= 88.0
	draw_arc(c, R, a0, a0 + (a1 - a0) * k, 64, AMBER if hot else accent, 6.0)
	for m in range(0, 111, 10):
		var a := a0 + (a1 - a0) * m / 110.0
		draw_line(c + Vector2.from_angle(a) * (R - 12), c + Vector2.from_angle(a) * (R - 6), Color(WHITE, 0.5), 1.0)
	_text(f_title, c + Vector2(-60, 8), "%d" % int(mph), 26, AMBER if hot else WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120)
	_text(f_head, c + Vector2(-60, 26), "MPH", 9, DIM, HORIZONTAL_ALIGNMENT_CENTER, 120)
	var dialed: int = main.dialed_era
	var label := "TAB: SET DESTINATION" if dialed < 0 else "DESTINATION %s  //  HIT 88" % EraData.era_info(dialed).year_label
	var tw := _text_w(f_head, label, 10) + 30
	var r := Rect2(c.x - tw / 2.0, c.y - R - 44, tw, 26)
	_panel(r, AMBER if dialed >= 0 else accent, 6.0)
	_text(f_head, r.position + Vector2(0, 17), label, 10, AMBER if dialed >= 0 else WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(f_bold, Vector2(0, vs.y - 40), "W/S throttle  //  A/D steer  //  SPACE brake  //  F exit  //  " + main.player.vehicle_label, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


## Watch_Dogs-style Profiler readout for whoever is under the crosshair.
func _draw_profiler(vs: Vector2) -> void:
	var p: Dictionary = main.profile
	if p.is_empty():
		return
	var r := Rect2(vs.x / 2.0 + 40, vs.y / 2.0 - 96, 380, 76)
	_panel(r, accent, 8.0)
	_text(f_head, r.position + Vector2(14, 18), "PROFILER  //  %s" % p.era, 8, DIM)
	_text(f_bold, r.position + Vector2(14, 40), p.name.to_upper(), 17, WHITE, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
	_text(f_body, r.position + Vector2(14, 62), p.line, 15, accent.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)


func _draw_feed(vs: Vector2) -> void:
	var y := vs.y - 130.0
	for i in range(main.messages.size() - 1, -1, -1):
		var m = main.messages[i]
		var a := clampf(m.t, 0.0, 1.0)
		var tw := minf(_text_w(f_bold, m.text, 16), vs.x * 0.36)
		var r := Rect2(20, y - 17, tw + 22, 24)
		draw_rect(r, Color(0.02, 0.05, 0.09, 0.55 * a))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(m.color, a))
		_text(f_bold, Vector2(r.position.x + 12, y + 1), m.text, 16, Color(m.color.lightened(0.2), a), HORIZONTAL_ALIGNMENT_LEFT, vs.x * 0.36)
		y -= 28.0


func _draw_banner(vs: Vector2) -> void:
	if main.banner.is_empty():
		return
	var a := clampf(main.banner.t, 0.0, 1.0)
	var reveal := clampf((8.0 - main.banner.t) * 4.0, 0.0, 1.0)
	var w := clampf(vs.x - 860.0, 400.0, 560.0)
	var full := Rect2(vs.x / 2.0 - w / 2.0, 104, w, 118)
	var r := Rect2(full.position, Vector2(full.size.x * reveal, full.size.y))
	if r.size.x < 30:
		return
	_panel(r, Color(accent, a), 12.0, Color(0.02, 0.05, 0.09, 0.86 * a))
	if reveal < 1.0:
		return
	_text(f_title, r.position + Vector2(18, 30), main.banner.title, 14, Color(accent.lightened(0.3), a), HORIZONTAL_ALIGNMENT_LEFT, w - 36)
	draw_rect(Rect2(r.position.x + 18, r.position.y + 40, 60, 2), Color(accent, a))
	draw_multiline_string(f_body, r.position + Vector2(18, 64), main.banner.body, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 16, 4, Color(WHITE, a))


func _draw_footer(vs: Vector2) -> void:
	var r := Rect2(0, vs.y - 30, vs.x, 30)
	draw_rect(r, Color(0.01, 0.03, 0.06, 0.8))
	draw_rect(Rect2(0, r.position.y, vs.x, 1), Color(accent, 0.4))
	var x := 16.0
	for pair in [["TAB", "Time Pad"], ["1-4", "weapons"], ["LMB", "attack"], ["E", "interact"], ["F", "vehicle"],
			["Q", "stop time"], ["R", "rewind"], ["C", "dodge"], ["T", "hack"], ["L", "ledger"], ["H", "help"]]:
		x += _keycap(Vector2(x, vs.y - 9), pair[0], 11) + 5.0
		_text(f_bold, Vector2(x, vs.y - 9), pair[1], 13, DIM)
		x += _text_w(f_bold, pair[1], 13) + 14.0
		if x > vs.x - 80:
			break
	if main.user_speed < 1.0:
		_text(f_title, Vector2(vs.x - 140, vs.y - 9), "SPEED %d%%" % int(main.user_speed * 100.0), 10, AMBER)


# ================================================================ Time Pad dial

func _draw_time_pad(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.03, 0.07, 0.55))
	for y in range(0, int(vs.y), 3):
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(accent, 0.03))
	var c := vs / 2.0 + Vector2(0, 10)
	var R := minf(vs.y * 0.34, 230.0)
	var n: int = EraData.ERAS.size()
	# rotating outer tick ring
	for k in range(72):
		var a := TAU * k / 72.0 + _t * 0.15
		var l := 10.0 if k % 6 == 0 else 5.0
		draw_line(c + Vector2.from_angle(a) * (R + 18), c + Vector2.from_angle(a) * (R + 18 + l), Color(accent, 0.5), 1.0)
	draw_arc(c, R + 12, 0, TAU, 96, Color(accent, 0.35), 1.0)
	# era sectors
	var seg := TAU / n
	for i in range(n):
		var a0 := -PI / 2.0 + i * seg - seg / 2.0 + 0.04
		var a1 := a0 + seg - 0.08
		var sel: bool = i == main.pad_index
		var here: bool = i == main.era
		var col: Color = EraData.era_info(i).accent
		var pts := PackedVector2Array()
		for k in range(17):
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 16.0)) * R)
		for k in range(16, -1, -1):
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 16.0)) * (R * 0.62))
		draw_colored_polygon(pts, Color(col, 0.42 if sel else 0.1))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(col, 1.0 if sel else 0.45), 2.0 if sel else 1.0)
		var mid := c + Vector2.from_angle((a0 + a1) / 2.0) * (R * 0.81)
		var info := EraData.era_info(i)
		_text(f_title, mid + Vector2(-60, -6), "%d" % (i + 1), 12, col, HORIZONTAL_ALIGNMENT_CENTER, 120)
		_text(f_bold, mid + Vector2(-70, 12), info.year_label, 15 if sel else 13, WHITE if sel else DIM, HORIZONTAL_ALIGNMENT_CENTER, 140)
		if here:
			_text(f_head, mid + Vector2(-60, 26), "HERE", 8, col, HORIZONTAL_ALIGNMENT_CENTER, 120)
	# hub
	var target_info := EraData.era_info(main.pad_index)
	draw_circle(c, R * 0.55, Color(0.01, 0.03, 0.06, 0.95))
	draw_arc(c, R * 0.55, 0, TAU, 64, Color(target_info.accent, 0.8), 2.0)
	var e: float = main.energy / main.MAX_ENERGY
	draw_arc(c, R * 0.5, -PI / 2.0, -PI / 2.0 + TAU * e, 64, accent, 4.0)
	_text(f_head, c + Vector2(-100, -34), "TIME PAD", 10, DIM, HORIZONTAL_ALIGNMENT_CENTER, 200)
	_text(f_title, c + Vector2(-110, 0), target_info.year_label, 20 if target_info.year_label.length() > 8 else 28, target_info.accent, HORIZONTAL_ALIGNMENT_CENTER, 220)
	_text(f_bold, c + Vector2(-100, 22), target_info.short, 15, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200)
	var ok: bool = main.energy >= main.JUMP_COST and main.pad_index != main.era
	var status := "READY  -  %d NRG" % int(main.JUMP_COST)
	if main.player.driving:
		status = "SET DESTINATION - THEN HIT 88 MPH"
	elif main.pad_index == main.era:
		status = "CURRENT ERA"
	elif not ok:
		status = "RECHARGING  %d/%d" % [int(main.energy), int(main.JUMP_COST)]
	_text(f_head, c + Vector2(-110, 46), status, 8, GREEN if ok else AMBER, HORIZONTAL_ALIGNMENT_CENTER, 220)
	_text(f_body, Vector2(0, c.y - R - 40), "1-5 or scroll to select  //  click or E to confirm  //  Tab to close  //  world slowed", 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


# ================================================================ full-screen panels

func _draw_boot(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.05, 0.88))
	for y in range(0, int(vs.y), 3):
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(accent, 0.025))
	var top := vs.y * 0.08
	_text(f_title, Vector2(0, top + 60), "CHRONO", 72, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_text(f_head, Vector2(0, top + 96), "S H A T T E R E D   T I M E L I N E", 16, accent, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	draw_rect(Rect2(vs.x / 2.0 - 120, top + 112, 240, 2), accent)
	_text(f_body, Vector2(0, top + 144), "Everyone in New Meridian lost the same minute. You found the device responsible: the ChronoCore Time Pad.", 19, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var col_w := minf(vs.x * 0.36, 440.0)
	var lx := vs.x / 2.0 - col_w - 20
	var rx := vs.x / 2.0 + 20
	var y0 := top + 196
	var left := [["WASD", "Move  (SHIFT sprint, SPACE jump)"], ["MOUSE", "Look & aim"], ["E", "Grab / drop / plant / talk / restore"],
		["LMB", "Attack, or throw what you hold"], ["1-4", "Blade / Pistol / Stasis / Blink"], ["F", "Hijack or exit a vehicle"], ["T", "Hack: stall cars, jam agents, profile"]]
	var right := [["TAB", "Time Pad - travel between 5 eras"], ["88", "In a vehicle: set a destination, hit 88 mph"], ["Q", "Stop Time on the target in your sights"],
		["R", "Hold to rewind nearby objects"], ["C", "Time Dodge"], ["L", "Timeline ledger"], ["F5/F9", "Save / load    [ ] game speed"]]
	_panel(Rect2(lx - 16, y0 - 34, col_w + 16, 262), accent)
	_panel(Rect2(rx - 16, y0 - 34, col_w + 16, 262), accent)
	_text(f_head, Vector2(lx, y0 - 12), "MOVEMENT & ACTION", 10, DIM)
	_text(f_head, Vector2(rx, y0 - 12), "CHRONOCORE", 10, DIM)
	for k in range(left.size()):
		var y := y0 + 22 + k * 31
		var w := _keycap(Vector2(lx, y), left[k][0], 13)
		_text(f_bold, Vector2(lx + w + 12, y), left[k][1], 17, WHITE)
		var w2 := _keycap(Vector2(rx, y), right[k][0], 13)
		_text(f_bold, Vector2(rx + w2 + 12, y), right[k][1], 17, WHITE)
	var yb := y0 + 258
	_text(f_body, Vector2(0, yb), "Change the past and the present remembers. Change too much and the Chrono Enforcement Bureau hunts you across time -", 17, AMBER, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_text(f_body, Vector2(0, yb + 24), "and if you push them far enough, they send something that does not stop.", 17, AMBER, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var pulse := 0.55 + 0.45 * sin(_t * 3.0)
	_text(f_title, Vector2(0, vs.y - 40), "PRESS  H  TO  BEGIN", 16, Color(accent, pulse), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_ledger(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.05, 0.6))
	var r := Rect2(vs.x * 0.14, vs.y * 0.1, vs.x * 0.72, vs.y * 0.76)
	_panel(r, accent, 18.0, Color(0.01, 0.04, 0.08, 0.95))
	_text(f_title, r.position + Vector2(28, 44), "TIMELINE LEDGER", 22, WHITE)
	_text(f_bold, r.position + Vector2(28, 72), "BRANCH: %s     ESCAPES: %d     ARRESTS: %d     ABERRATIONS RESTORED: %d" % [main.branch_name().to_upper(), main.escapes, main.arrests, main.aberrations_fixed], 15, accent)
	var y := r.position.y + 112
	var x := r.position.x + 28
	if main.events.is_empty():
		_text(f_body, Vector2(x, y), "No recorded changes. The timeline matches the baseline.", 18, DIM)
	for e in main.events:
		if y > r.end.y - 60:
			break
		draw_rect(Rect2(x - 10, y - 18, 3, 64), accent)
		_text(f_title, Vector2(x, y), "%s  [%s]" % [e.id.to_upper(), e.year], 12, accent)
		_text(f_bold, Vector2(x + 220, y), e.title, 18, WHITE)
		_text(f_body, Vector2(x, y + 22), "Cause: %s   //   Severity %d   //   %s" % [e.cause, e.severity, e.type], 15, DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60)
		_text(f_body, Vector2(x, y + 42), "Affects: %s" % e.affected, 15, GREEN, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60)
		y += 82
	_text(f_head, Vector2(x, r.end.y - 22), "GAME PAUSED  //  L OR ESC TO CLOSE", 10, DIM)
