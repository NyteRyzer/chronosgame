extends Node2D
## A vehicle that patrols the road. Freezable with Stop Time.

const EraData = preload("res://scripts/era_data.gd")

const SIZE := Vector2(110, 56)
const X_MIN := 80.0
const X_MAX := 1520.0

var era := EraData.PRESENT
var speed := 340.0
var color := Color.RED
var label := ""
var dir := 1.0
var frozen := 0.0


func configure(new_era: int) -> void:
	era = new_era
	var info := EraData.era_info(era)
	speed = info.hazard_speed
	color = info.hazard_color
	label = info.hazard_name
	position = Vector2(300.0, EraData.HAZARD_Y)
	dir = 1.0
	frozen = 0.0


func step(delta: float) -> void:
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		return
	position.x += dir * speed * delta
	if position.x > X_MAX:
		position.x = X_MAX
		dir = -1.0
	elif position.x < X_MIN:
		position.x = X_MIN
		dir = 1.0


func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-SIZE / 2.0, SIZE)
	match era:
		EraData.PAST:
			draw_rect(Rect2(r.position + Vector2(30, 6), Vector2(80, 44)), color)
			draw_circle(Vector2(-38 * dir, 0), 14, Color("6b4a2e"))  # horse
			for wx in [-15.0, 35.0]:
				draw_circle(Vector2(wx, -26), 8, Color("2a1d12"))
				draw_circle(Vector2(wx, 26), 8, Color("2a1d12"))
		EraData.FUTURE:
			draw_rect(r.grow(-6), Color(color, 0.85))
			for c in [Vector2(-45, -22), Vector2(45, -22), Vector2(-45, 22), Vector2(45, 22)]:
				draw_arc(c, 10, 0, TAU, 16, Color.WHITE, 2.0)
		_:
			draw_rect(r, color)
			draw_rect(Rect2(Vector2(SIZE.x / 2.0 - 30.0 if dir > 0 else -SIZE.x / 2.0, -SIZE.y / 2.0), Vector2(30, SIZE.y)), color.lightened(0.3))
	draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
	if frozen > 0.0:
		draw_rect(r.grow(6), Color(0.5, 0.85, 1.0, 0.35))
		draw_rect(r.grow(6), Color(0.7, 0.95, 1.0), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -38), "FROZEN %.1fs" % frozen, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
