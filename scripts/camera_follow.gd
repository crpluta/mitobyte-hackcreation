extends Camera3D

# Camera follow settings
@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 12, 15)
@export var smooth_speed: float = 5.0

var target: Node3D

func _ready():
	if target_path:
		target = get_node(target_path)
	else:
		# Try to find player in parent
		target = get_parent().get_node_or_null("Player")

	if not target:
		print("Camera: No target found!")

func _process(delta):
	if target:
		# Smoothly follow player position
		var target_position = target.global_position + offset
		global_position = global_position.lerp(target_position, smooth_speed * delta)
