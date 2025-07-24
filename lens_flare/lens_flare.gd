extends Node

# Global script fetching for DirectionalLight3D node, aka the sun screen position and direction

var sun_dot : float = 0.0
var sun_screen_position : Vector2 = Vector2.ZERO
var sun : DirectionalLight3D = null

func _ready():
	sun = get_tree().root.find_children("", "DirectionalLight3D", true, false).pop_front()

func _process(_delta):
	var camera_node : Camera3D = get_viewport().get_camera_3d()
	if camera_node == null || sun == null: return
	var sun_direction = sun.global_transform.basis.z * maxf(camera_node.near, 1.0)
	sun_direction += camera_node.global_transform.origin
	sun_screen_position = camera_node.unproject_position(sun_direction)
	sun_dot = camera_node.global_transform.basis.z.dot(-sun.global_basis.z)
