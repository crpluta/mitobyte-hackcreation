extends CharacterBody3D

# Player movement constants
const SPEED = 7.0  # Base speed (increased from 5.0)
const SPRINT_MULTIPLIER = 3.0  # Sprint speed multiplier (hold Shift)
const FIXED_Y_POSITION = 1.0
const ROTATION_SPEED = 10.0  # How fast player rotates to face movement direction

# Multiplayer
var player_name: String = "Player"
var peer_id: int = 1

# Label for player name
var name_label: Label3D

func _ready():
	print("Player initialized")
	# Set initial Y position
	position.y = FIXED_Y_POSITION

	# Create name label
	_create_name_label()

	# Set player authority for multiplayer
	set_multiplayer_authority(peer_id)

func _create_name_label():
	"""Create a 3D label above the player's head"""
	name_label = Label3D.new()
	name_label.text = player_name
	name_label.position = Vector3(0, 2.5, 0)  # Above player
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.pixel_size = 0.01
	name_label.modulate = Color.WHITE
	name_label.outline_modulate = Color.BLACK
	name_label.outline_size = 8
	add_child(name_label)

func set_player_info(p_name: String, p_peer_id: int):
	"""Set player name and peer ID for multiplayer"""
	player_name = p_name
	peer_id = p_peer_id

	if name_label:
		name_label.text = player_name

	# Update authority for this player
	set_multiplayer_authority(peer_id)

func _physics_process(delta):
	# Only allow input from the player who owns this character
	if not is_multiplayer_authority():
		return

	# Get input direction (screen space for 2.5D)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Movement in screen space (X is left/right, Z is up/down on screen)
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Check for sprint (Shift key)
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = SPEED * SPRINT_MULTIPLIER if is_sprinting else SPEED

	# Apply movement
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		# Rotate to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# Lock Y position (no vertical movement)
	velocity.y = 0

	move_and_slide()

	# Force Y position to stay fixed (prevent any drift)
	position.y = FIXED_Y_POSITION
