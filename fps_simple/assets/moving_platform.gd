tool
extends Spatial

onready var mp_shadow = $mp_shadow
onready var mp_kine = $mp_kine

export (Vector3) var target = Vector3(0,0,-2)
export (float) var wait = 3
export (float) var speed = 0.5


var tool_target = Vector3()
var delta_physic = 0

var goto_shadow = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pcs_tool()
	pass # Replace with function body.

func pcs_tool():
	if tool_target != target:
		tool_target = target
		mp_shadow.translation = target
		
	
func _physics_process(delta):
	delta_physic = delta
	if Engine.editor_hint:
		pcs_tool()
		return
	if goto_shadow:
		var new_pos = mp_kine.translation.linear_interpolate(mp_shadow.translation, delta_physic * speed)
		mp_kine.translation = new_pos
		if new_pos.distance_to(mp_shadow.translation) < 0.01:
			goto_shadow = false
	else:
		var new_pos = mp_kine.translation.linear_interpolate(Vector3(), delta_physic * speed)
		mp_kine.translation = new_pos
		if new_pos.distance_to(Vector3()) < 0.01:
			goto_shadow = true
