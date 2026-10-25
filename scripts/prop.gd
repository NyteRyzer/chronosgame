extends CharacterBody2D
## A rewindable physics object. Records a rolling state buffer every physics
## frame so the ChronoCore can reverse it (the "local rewind" system).

const EraData = preload("res://scripts/era_data.gd")

const BUFFER_MAX := 300  # 5 seconds at 60 Hz
const DRAG := 2.6

var kind := "crate"
var sunk := false
var held := false
var was_thrown := false
var rewinding := false
var buffer: Array = []
var _t := 0.0


func setup(k: String, pos: Vector2, is_sunk := false) -> void:
	kind = k
	position = pos
	sunk = is_sunk


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	if kind == "crate":
		var r := RectangleShape2D.new()
		r.size = Vector2(26, 26)
		shape.shape = r
	else:
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape.shape = c
	add_child(shape)


func display_name() -> String:
	match kind:
		"seed":
			return "Oak seed"
		"cell":
			return "Plasma cell (2150 tech)"
	return "Crate"


func record() -> void:
	buffer.append([position, velocity, sunk])
	if buffer.size() > BUFFER_MAX:
		buffer.pop_front()


## Applies one recorded frame in reverse. Returns false when the buffer is empty.
func rewind_step() -> bool:
	if buffer.is_empty():
		rewinding = false
		return false
	var s: Array = buffer.pop_back()
	position = s[0]
	velocity = s[1]
	sunk = s[2]
	rewinding = true
	return true


func simulate(delta: float) -> void:
	rewinding = false
	if held or sunk:
		return
	if velocity.length() > 1.0:
		var col := move_and_collide(velocity * delta)
		if col:
			velocity = velocity.bounce(col.get_normal()) * 0.55
		velocity *= exp(-DRAG * delta)
		if velocity.length() < 6.0:
			velocity = Vector2.ZERO
	if EraData.WATER.has_point(position):
		sunk = true
		velocity = Vector2.ZERO


func clear_history() -> void:
	buffer.clear()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if sunk:
		var a := 0.25 + 0.15 * sin(_t * 3.0)
		draw_arc(Vector2.ZERO, 12, 0, TAU, 24, Color(1, 1, 1, a), 2.0)
		draw_arc(Vector2.ZERO, 20, 0, TAU, 24, Color(1, 1, 1, a * 0.5), 2.0)
		return
	match kind:
		"crate":
			draw_rect(Rect2(-13, -13, 26, 26), Color("a0703c"))
			draw_rect(Rect2(-13, -13, 26, 26), Color("5a3a1e"), false, 2.0)
			draw_line(Vector2(-13, -13), Vector2(13, 13), Color("5a3a1e"), 2.0)
			draw_line(Vector2(13, -13), Vector2(-13, 13), Color("5a3a1e"), 2.0)
		"seed":
			draw_circle(Vector2.ZERO, 9, Color("7a5a2a"))
			draw_circle(Vector2(0, -5), 4, Color("6fbf4a"))
			draw_arc(Vector2.ZERO, 14, 0, TAU, 24, Color(0.6, 1.0, 0.4, 0.4 + 0.3 * sin(_t * 4.0)), 2.0)
		"cell":
			draw_circle(Vector2.ZERO, 9, Color("2ee6d6"))
			draw_circle(Vector2.ZERO, 5, Color.WHITE)
			draw_arc(Vector2.ZERO, 14, 0, TAU, 24, Color(0.2, 0.9, 0.85, 0.4 + 0.3 * sin(_t * 5.0)), 2.0)
	if rewinding:
		draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color("5fd4ff"), 3.0)
