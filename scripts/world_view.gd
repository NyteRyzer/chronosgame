extends Node2D
## Draws the current era snapshot of the street and owns its static colliders.

const EraData = preload("res://scripts/era_data.gd")

const LAYER_WALLS := 1
const LAYER_WATER := 2

var era := EraData.PRESENT
var changed := false
var info: Dictionary = EraData.era_info(EraData.PRESENT)
var _bodies: Array = []
var _t := 0.0


func build(new_era: int, is_changed: bool) -> void:
	era = new_era
	changed = is_changed
	info = EraData.era_info(era)
	for b in _bodies:
		b.queue_free()
	_bodies.clear()
	for r in EraData.common_walls() + EraData.era_walls(era, changed):
		_add_body(r, LAYER_WALLS)
	_add_body(EraData.WATER, LAYER_WATER)
	queue_redraw()


func all_walls() -> Array:
	return EraData.common_walls() + EraData.era_walls(era, changed)


func _add_body(r: Rect2, layer: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_bodies.append(body)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var size := EraData.WORLD_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), info.ground)
	draw_rect(Rect2(0, 190, size.x, 110), info.sidewalk)
	draw_rect(Rect2(0, 500, size.x, 80), info.sidewalk)
	_draw_road()
	_draw_water(font)
	for r in EraData.common_walls().slice(0, 8):
		_draw_building(r)
	_draw_clock_tower(font)
	_draw_plaza(font)
	if era == EraData.PAST:
		_draw_stall(font)
	_draw_npc(font)
	draw_rect(Rect2(Vector2.ZERO, size), info.tint)


func _draw_road() -> void:
	var road := EraData.ROAD
	draw_rect(road, info.road)
	match era:
		EraData.PAST:
			for y in [355.0, 445.0]:
				draw_line(Vector2(0, y), Vector2(road.end.x, y), Color(0.3, 0.22, 0.15, 0.7), 6.0)
		EraData.PRESENT:
			var x := 0.0
			while x < road.end.x:
				draw_rect(Rect2(x, 397, 50, 6), Color(0.95, 0.85, 0.3))
				x += 100.0
			for i in range(8):
				draw_rect(Rect2(1100 + i * 18, 302, 10, 196), Color(0.9, 0.9, 0.9, 0.5))
		EraData.FUTURE:
			var glow := 0.5 + 0.3 * sin(_t * 3.0)
			for y in [340.0, 460.0]:
				draw_line(Vector2(0, y), Vector2(road.end.x, y), Color(0.2, 0.9, 0.85, glow), 3.0)


func _draw_water(font: Font) -> void:
	var w := EraData.WATER
	draw_rect(w, info.water)
	for i in range(6):
		var y := w.position.y + fmod(_t * 25.0 + i * 64.0, w.size.y)
		draw_line(Vector2(w.position.x + 10, y), Vector2(w.end.x - 10, y), Color(1, 1, 1, 0.12), 2.0)
	draw_string(font, Vector2(w.position.x - 6, w.end.y - 12), info.water_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))


func _draw_building(r: Rect2) -> void:
	draw_rect(r, info.building)
	draw_rect(r.grow(-8), info.roof)
	var lit: Color = info.window
	var cols := int(r.size.x / 40.0)
	for i in range(cols):
		var wx := r.position.x + 16 + i * 40
		if era == EraData.FUTURE:
			draw_rect(Rect2(wx, r.position.y + 16, 18, r.size.y - 32), Color(lit, 0.35 + 0.15 * sin(_t * 2.0 + i)))
		else:
			draw_rect(Rect2(wx, r.end.y - 30, 18, 14), Color(lit, 0.8))
	draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)


func _draw_clock_tower(font: Font) -> void:
	var r := Rect2(700, 20, 200, 170)
	draw_rect(r, info.building.darkened(0.15))
	draw_rect(r.grow(-10), info.roof.darkened(0.1))
	var c := Vector2(800, 95)
	var face := Color(0.95, 0.92, 0.8) if era != EraData.FUTURE else Color(0.2, 0.95, 0.9)
	draw_circle(c, 46, face)
	draw_arc(c, 46, 0, TAU, 48, Color(0, 0, 0, 0.6), 3.0)
	var minute := _t * 0.5
	draw_line(c, c + Vector2.from_angle(minute - PI / 2) * 38, Color.BLACK, 3.0)
	draw_line(c, c + Vector2.from_angle(minute / 12.0 - PI / 2) * 24, Color.BLACK, 4.0)
	draw_string(font, Vector2(735, 182), "CLOCK TOWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))


func _draw_plaza(font: Font) -> void:
	var p := EraData.PLAZA
	match era:
		EraData.PAST:
			draw_rect(p, Color("6e5b40"))
			draw_rect(EraData.PLOT, Color("3b2a1a"))
			draw_rect(EraData.PLOT, Color("a07a4a"), false, 3.0)
			if changed:
				_draw_tree(EraData.PLOT_CENTER, 0.18)
				draw_string(font, Vector2(735, 680), "Your sapling", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			else:
				draw_string(font, Vector2(742, 680), "Bare soil", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
			draw_string(font, Vector2(610, 870), "OLD SQUARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		EraData.PRESENT:
			if changed:
				draw_rect(p, Color("3f7a3a"))
				draw_circle(Vector2(800, 720), 150, Color("4b8a44"))
				for b in [Rect2(640, 600, 60, 14), Rect2(900, 830, 60, 14)]:
					draw_rect(b, Color("8a6a43"))
				_draw_tree(Vector2(800, 720), 1.0)
				draw_string(font, Vector2(610, 870), "FOUNDERS' OAK PARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			else:
				draw_rect(p, Color("3a3f44"))
				for i in range(9):
					draw_line(Vector2(620 + i * 45, 630), Vector2(620 + i * 45, 740), Color(1, 1, 1, 0.5), 2.0)
				for car in EraData.era_walls(era, false):
					draw_rect(car, Color("2d6fa3"))
					draw_rect(Rect2(car.position + Vector2(6, 14), Vector2(car.size.x - 12, 22)), Color(0.75, 0.9, 1.0, 0.7))
				draw_string(font, Vector2(610, 870), "MERIDIAN PARKING", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
		EraData.FUTURE:
			if changed:
				draw_rect(p, Color("12302a"))
				draw_circle(Vector2(800, 720), 175, Color(0.2, 0.9, 0.8, 0.12))
				draw_arc(Vector2(800, 720), 175, 0, TAU, 64, Color(0.3, 1.0, 0.9, 0.6 + 0.2 * sin(_t * 2.0)), 3.0)
				_draw_tree(Vector2(800, 720), 1.25)
				draw_string(font, Vector2(610, 870), "OAK BIODOME ARCHIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.95))
			else:
				draw_rect(p, Color("24222c"))
				for crack in [[Vector2(620, 600), Vector2(760, 680)], [Vector2(980, 610), Vector2(840, 860)], [Vector2(640, 850), Vector2(800, 780)]]:
					draw_line(crack[0], crack[1], Color(0, 0, 0, 0.7), 4.0)
				for d in EraData.era_walls(era, false):
					draw_rect(d, Color("4a4658"))
					draw_rect(d, Color(0, 0, 0, 0.6), false, 2.0)
				draw_string(font, Vector2(610, 870), "COLLAPSED PLAZA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))


func _draw_tree(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c - Vector2(20, 20) * s, Vector2(40, 40) * s), Color("5a3a1e"))
	var green := Color("2f6b2a") if era != EraData.FUTURE else Color("2e8a5a")
	for off in [Vector2(-45, -30), Vector2(45, -25), Vector2(0, -60), Vector2(-30, 30), Vector2(35, 30), Vector2.ZERO]:
		draw_circle(c + off * s, 62 * s, Color(green, 0.85))
	draw_circle(c + Vector2(-15, -20) * s, 30 * s, Color(green.lightened(0.25), 0.6))


func _draw_stall(font: Font) -> void:
	var r := Rect2(220, 205, 120, 30)
	draw_rect(r, Color("8b5a2b"))
	for i in range(4):
		draw_rect(Rect2(r.position.x + i * 30, r.position.y - 8, 15, 8), Color("c94f3d"))
	draw_string(font, Vector2(222, 226), "SEEDS & SUNDRIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_npc(font: Font) -> void:
	var p := EraData.NPC_POS
	var body := Color("d9a066")
	if era == EraData.FUTURE:
		body = Color("9fb3c8")
	draw_circle(p, 13, body)
	draw_circle(p + Vector2(0, -16), 8, body.lightened(0.2))
	draw_string(font, p + Vector2(-30, 30), EraData.npc_line(era, changed).name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))
