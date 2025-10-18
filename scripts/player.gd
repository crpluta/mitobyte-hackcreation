extends CharacterBody3D

# Player movement constants
const SPEED = 7.0  # Base speed (increased from 5.0)
const SPRINT_MULTIPLIER = 3.0  # Sprint speed multiplier (hold Shift)
const FIXED_Y_POSITION = 1.0

func _ready():
	print("Player initialized")
	# Set initial Y position
	position.y = FIXED_Y_POSITION

func _physics_process(_delta):
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
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# Lock Y position (no vertical movement)
	velocity.y = 0

	move_and_slide()

	# Force Y position to stay fixed (prevent any drift)
	position.y = FIXED_Y_POSITION
