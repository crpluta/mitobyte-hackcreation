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

func set_target(new_target: Node3D):
	"""Set the camera target (used by multiplayer to set local player)"""
	target = new_target
	if target:
		print("Camera target set to: ", target.name)

func _process(delta):
	# Re-check for local player if we don't have a target (multiplayer)
	if not is_instance_valid(target):
		_find_local_player()

	if target:
		# Smoothly follow player position
		var target_position = target.global_position + offset
		global_position = global_position.lerp(target_position, smooth_speed * delta)

func _find_local_player():
	"""Find the local player in multiplayer"""
	var players = get_tree().get_nodes_in_group("player")

	for p in players:
		if p.is_multiplayer_authority():
			target = p
			print("Camera found local player: ", p.name)
			return
