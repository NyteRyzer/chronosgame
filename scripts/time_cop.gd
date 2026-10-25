extends CharacterBody2D
## Chrono Enforcement Bureau field agent. Telegraphs arrival through a portal,
## then pursues. Can be frozen (briefly - agents resist), stunned by thrown
## objects, outrun, or shaken off with an era jump while it can't track you.

const SPEED := 212.0
const CATCH_RADIUS := 28.0

var state := "portal"  # portal -> chase
var portal_time := 2.5
var portal_total := 2.5
var frozen := 0.0
var stunned := 0.0
var _t := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _detour := Vector2.ZERO
var _detour_time := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_last_pos = position


func open_portal(seconds: float) -> void:
	state = "portal"
	portal_time = seconds
	portal_total = seconds


func can_track() -> bool:
	return state == "chase" and frozen <= 0.0 and stunned <= 0.0


## Returns true when the agent catches the player this frame.
func step(delta: float, target: Vector2) -> bool:
	_t += delta
	queue_redraw()
	if state == "portal":
		portal_time -= delta
		if portal_time <= 0.0:
			state = "chase"
			_last_pos = position
		return false
	if frozen > 0.0:
		frozen = maxf(frozen - delta, 0.0)
		return false
	if stunned > 0.0:
		stunned = maxf(stunned - delta, 0.0)
		return false
	var dir := (target - position).normalized()
	if _detour_time > 0.0:
		_detour_time -= delta
		dir = (dir * 0.3 + _detour).normalized()
	velocity = dir * SPEED
	move_and_slide()
	# Simple unstick: if barely moving while blocked, slide sideways for a moment.
	_stuck_timer += delta
	if _stuck_timer > 0.8:
		if position.distance_to(_last_pos) < 40.0:
			_detour = dir.orthogonal() * (1.0 if randf() > 0.5 else -1.0)
			_detour_time = 0.9
		_last_pos = position
		_stuck_timer = 0.0
	return position.distance_to(target) < CATCH_RADIUS


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if state == "portal":
		var k := 1.0 - portal_time / portal_total
		for i in range(3):
			var r := 10.0 + 30.0 * k + i * 8.0
			draw_arc(Vector2.ZERO, r, _t * (3.0 + i), _t * (3.0 + i) + PI * 1.4, 24, Color(1.0, 0.45, 0.2, 0.9 - i * 0.25), 4.0)
		draw_string(font, Vector2(-62, -54), "BUREAU PORTAL %.1fs" % maxf(portal_time, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffb07a"))
		return
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, 14, Color("1d2b5c"))
	draw_rect(Rect2(-9, -6, 18, 5), Color("ff3b3b"))  # visor
	draw_circle(Vector2(0, 7), 3, Color("ffd34d"))  # badge
	draw_string(font, Vector2(-30, -24), "TIME COP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff8a8a"))
	if frozen > 0.0:
		draw_circle(Vector2.ZERO, 22, Color(0.5, 0.85, 1.0, 0.35))
		draw_string(font, Vector2(-34, 34), "FROZEN %.1fs" % frozen, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	elif stunned > 0.0:
		draw_string(font, Vector2(-30, 34), "STUNNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd34d"))
