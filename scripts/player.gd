extends CharacterBody2D
## The independent time traveller. Movement only; powers live in main.gd.

const SPEED := 240.0

var facing := Vector2.RIGHT
var stun := 0.0
var knock := Vector2.ZERO
var held = null  # the prop being carried (prop.gd)
var _t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1600
	cam.limit_bottom = 900
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)


func step(delta: float, aim_at: Vector2) -> void:
	_t += delta
	if stun > 0.0:
		stun -= delta
		velocity = knock
		knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * SPEED
	move_and_slide()
	var to_aim := aim_at - global_position
	if to_aim.length() > 4.0:
		facing = to_aim.normalized()
	queue_redraw()


func _draw() -> void:
	var body := Color("f2f2f2")
	if stun > 0.0 and int(_t * 20.0) % 2 == 0:
		body = Color("ff7a6b")
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, 13, body)
	# ChronoCore glow on the wrist, pointing at the cursor
	draw_circle(facing * 13.0, 5, Color("5fd4ff"))
	draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color(0.37, 0.83, 1.0, 0.35 + 0.2 * sin(_t * 4.0)), 2.0)
