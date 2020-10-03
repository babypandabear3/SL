extends KinematicBody

onready var node_yaw = $yaw
onready var node_head = $yaw/head
onready var node_ray_slope = $ray_slope
onready var node_feet = $feet
onready var node_anim = $AnimationPlayer
onready var node_camera_hand = $Viewport/Camera_hand

onready var node_ray_climb1 = $yaw/ray_climb1
onready var node_ray_climb2 = $yaw/ray_climb2
onready var node_ray_climb3 = $yaw/ray_climb3

var MOUSE_SENSITIVITY = 0.07
var physic_fps = 60
var velocity = Vector3()
var prev_velocity = Vector3()
var dir = Vector3()
var delta_physic = 0

var on_floor = false

enum LIST_STATE {
	walk,
	climb
}
var state = LIST_STATE.walk

var walk_acc = 4
var speed = 0
var walk_speed = 4
var run_speed = 6
var crouch_speed = 2.5
var climb_speed = 2

var jump_force = 6
var gravity = -9
var jump_nocheck = 0
var jump_nocheck_timeout = 0.2

var is_crouching = false

var air_jump = 0
var air_jump_limit = 1
var air_control = true
var air_time = 0
var air_time_limit = 0.2

var floor_obj = null
var floor_pos = Vector3()

var climb_pos1 = Vector3()
var climb_pos2 = Vector3()
var climb_phase = 0
var climb_timer = 0
var climb_timeout = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass # Replace with function body.

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		node_head.rotate_x(-deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		node_yaw.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		var camera_rot = node_head.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		node_head.rotation_degrees = camera_rot
		
func _physics_process(delta):
	delta_physic = delta
	
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	
	match state:
		LIST_STATE.walk:
			do_walk()
		
		LIST_STATE.climb:
			do_climb()
		
	update_camera_hand()
			
func do_walk():
	prev_velocity = velocity
	
	var left = Input.is_action_pressed("move_left")
	var right = Input.is_action_pressed("move_right")
	var up = Input.is_action_pressed("move_fwd")
	var down = Input.is_action_pressed("move_back")
	var jump = Input.is_action_just_pressed("jump")
	var jump_pressed = Input.is_action_pressed("jump")
	var run = Input.is_action_pressed("run")
	var crouch = Input.is_action_just_pressed("crouch")
	
	var dir_target = Vector3()
	if left:
		dir_target += -node_yaw.global_transform.basis.x
	if right:
		dir_target += node_yaw.global_transform.basis.x
	if up:
		dir_target += -node_yaw.global_transform.basis.z
	if down:
		dir_target += node_yaw.global_transform.basis.z
	dir_target = dir_target.normalized()
	
	dir = dir.linear_interpolate(dir_target, delta_physic * walk_acc)
		
	if on_floor and crouch:
		try_crouch()
		
	if not on_floor and jump_pressed:
		try_climb()
		
	speed = walk_speed
	if run:
		speed = run_speed
	if is_crouching:
		speed = crouch_speed
		
	velocity = dir * speed
	velocity.y = prev_velocity.y
	
	if jump:
		if on_floor:
			jump_nocheck = jump_nocheck_timeout
			on_floor = false
			velocity.y = jump_force
			air_jump = 0
		elif air_time < air_time_limit:
			jump_nocheck = jump_nocheck_timeout
			on_floor = false
			velocity.y = jump_force
			air_jump = 0
		else:
			if air_jump < air_jump_limit:
				jump_nocheck = jump_nocheck_timeout
				on_floor = false
				velocity.y = jump_force
				air_jump += 1

	if on_floor:
		velocity.y = 0
		air_time = 0
		
		velocity += get_current_floor_velocity()
	else:
		if not air_control:
			velocity.x = prev_velocity.x
			velocity.z = prev_velocity.z
		velocity.y += gravity * delta_physic
		air_time += delta_physic
		
	move_and_slide(velocity, Vector3.UP, false, 4, 0.785398, false)
	if on_floor:
		try_put_feet_on_floor()
	else:
		try_drop()
		
	jump_nocheck = clamp(jump_nocheck-delta_physic, 0, jump_nocheck_timeout)
	
func try_put_feet_on_floor():
	if jump_nocheck == 0:
		if node_ray_slope.is_colliding():
			var point = node_ray_slope.get_collision_point()
			var diff = point.y - node_feet.global_transform.origin.y 
			move_and_collide(Vector3(0,diff,0))
			on_floor = true
		else:
			on_floor = false
		
func try_drop():
	if jump_nocheck == 0 and velocity.y < 0:
		if node_ray_slope.is_colliding():
			var point = node_ray_slope.get_collision_point()
			if node_feet.global_transform.origin.y <= point.y:
				var diff = point.y - node_feet.global_transform.origin.y
				move_and_collide(Vector3(0,diff,0))
				on_floor = true
		else:
			on_floor = false

func try_crouch():
	if not is_crouching:
		is_crouching = true
		node_anim.play("CROUCH")
	else:
		is_crouching = false
		node_anim.play_backwards("CROUCH")

func update_camera_hand():
	node_camera_hand.global_transform = node_head.global_transform

func get_current_floor_velocity():
	var ret = Vector3()
	if node_ray_slope.is_colliding():
		var obj = node_ray_slope.get_collider()
		if obj == floor_obj:
			ret = floor_obj.global_transform.origin - floor_pos
			floor_pos = floor_obj.global_transform.origin
		else:
			floor_obj = obj
			floor_pos = floor_obj.global_transform.origin
	else:
		floor_obj = null
	
	return ret * physic_fps

func try_climb():
	if not node_ray_climb1.is_colliding() and node_ray_climb2.is_colliding() :
		if node_ray_climb3.is_colliding():
			climb_pos2 = node_ray_climb3.get_collision_point()
			climb_pos2.y += 0.75
			climb_pos1 = global_transform.origin
			climb_pos1.y = climb_pos2.y
			climb_phase = 0
			climb_timer = climb_timeout
			state = LIST_STATE.climb
			if not is_crouching:
				try_crouch()
			velocity = Vector3()
			prev_velocity = Vector3()
		
func do_climb():
	if climb_phase == 0:
		var cdir = (climb_pos1 - global_transform.origin).normalized()
		move_and_slide(cdir * climb_speed)
		if global_transform.origin.distance_to(climb_pos1) < 0.05:
			climb_phase += 1
	elif climb_phase == 1:
		var cdir = (climb_pos2 - global_transform.origin).normalized()
		move_and_slide(cdir * climb_speed)
		if global_transform.origin.distance_to(climb_pos2) < 0.05:
			state = LIST_STATE.walk
			
	climb_timer -= delta_physic
	if climb_timer <= 0:
		state = LIST_STATE.walk
