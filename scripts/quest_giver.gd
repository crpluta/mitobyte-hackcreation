extends Node3D

# Quest data
var quest_data: Dictionary = {}
var quest_id: String = ""

# References
@onready var mesh = $MeshInstance3D
@onready var material = $MeshInstance3D.get_active_material(0)
@onready var marker_label = $MarkerLabel

# Interaction
@export var interaction_range: float = 3.0
var player: Node3D = null
var is_player_in_range: bool = false

# Movement
enum State { WALKING_TO_LOCATION, AT_LOCATION, WALKING_TO_SHACK }
var current_state = State.WALKING_TO_LOCATION
var target_position: Vector3 = Vector3.ZERO
var shack_position: Vector3 = Vector3.ZERO
const WALK_SPEED = 3.0
const ARRIVAL_THRESHOLD = 0.2

# Signals
signal player_entered_range
signal player_exited_range
signal interaction_triggered
signal reached_shack

# Colors for quest states - ONE-TIME QUESTS (green family)
const COLOR_ONETIME_AVAILABLE = Color(0.2, 0.8, 0.2)     # Green
const COLOR_ONETIME_IN_PROGRESS = Color(0.6, 0.8, 0.2)   # Yellow-green
const COLOR_ONETIME_COMPLETE = Color(0.2, 0.8, 0.8)      # Cyan

# Colors for quest states - DAILY QUESTS (blue family)
const COLOR_DAILY_AVAILABLE = Color(0.3, 0.6, 1.0)       # Light Blue
const COLOR_DAILY_IN_PROGRESS = Color(0.6, 0.4, 1.0)     # Purple
const COLOR_DAILY_COMPLETE = Color(0.4, 0.9, 1.0)        # Bright Blue

# Colors for quest states - WEEKLY QUESTS (yellow family)
const COLOR_WEEKLY_AVAILABLE = Color(1.0, 0.8, 0.2)      # Gold
const COLOR_WEEKLY_IN_PROGRESS = Color(1.0, 0.6, 0.2)    # Orange
const COLOR_WEEKLY_COMPLETE = Color(1.0, 1.0, 0.4)       # Bright Yellow

func _ready():
	player = get_tree().get_first_node_in_group("player")

	# Create unique material instance for this NPC (not shared!)
	var new_material = StandardMaterial3D.new()
	mesh.set_surface_override_material(0, new_material)
	material = new_material

	update_visual_state()

func setup_quest(todo: Dictionary, id: String):
	quest_data = todo
	quest_id = id
	update_visual_state()

func _process(delta):
	# Handle movement based on state
	match current_state:
		State.WALKING_TO_LOCATION:
			_move_towards(target_position, delta)
			if global_position.distance_to(target_position) < ARRIVAL_THRESHOLD:
				current_state = State.AT_LOCATION
				print("NPC reached quest location: ", quest_id)

		State.AT_LOCATION:
			# Check distance to player (only when at location)
			if player:
				var distance = global_position.distance_to(player.global_position)
				var in_range = distance <= interaction_range

				# Update state
				if in_range and not is_player_in_range:
					is_player_in_range = true
					player_entered_range.emit()
				elif not in_range and is_player_in_range:
					is_player_in_range = false
					player_exited_range.emit()

				# Check for interaction input
				if is_player_in_range and Input.is_action_just_pressed("interact"):
					interaction_triggered.emit()

		State.WALKING_TO_SHACK:
			_move_towards(shack_position, delta)
			if global_position.distance_to(shack_position) < ARRIVAL_THRESHOLD:
				print("NPC reached shack: ", quest_id)
				reached_shack.emit()

func _move_towards(target: Vector3, delta: float):
	var direction = (target - global_position).normalized()
	global_position += direction * WALK_SPEED * delta
	global_position.y = 0.0  # Keep on ground

func update_visual_state():
	if quest_id.is_empty():
		return

	# Check quest status in TodoManager
	var is_accepted = quest_id in TodoManager.accepted_quests
	var is_turned_in = quest_id in TodoManager.completed_quests
	var all_tasks_done = TodoManager.are_all_tasks_completed(quest_id)

	# Get quest type (daily or one_time)
	var quest_type = TodoManager.get_quest_type(quest_id)

	# Select colors based on quest type
	var color_available: Color
	var color_in_progress: Color
	var color_complete: Color

	match quest_type:
		"daily":
			color_available = COLOR_DAILY_AVAILABLE
			color_in_progress = COLOR_DAILY_IN_PROGRESS
			color_complete = COLOR_DAILY_COMPLETE
		"weekly":
			color_available = COLOR_WEEKLY_AVAILABLE
			color_in_progress = COLOR_WEEKLY_IN_PROGRESS
			color_complete = COLOR_WEEKLY_COMPLETE
		_:  # one_time (default)
			color_available = COLOR_ONETIME_AVAILABLE
			color_in_progress = COLOR_ONETIME_IN_PROGRESS
			color_complete = COLOR_ONETIME_COMPLETE

	# Update color and marker based on state
	if is_turned_in:
		# Quest already turned in - gray
		material.albedo_color = Color(0.5, 0.5, 0.5)
		marker_label.text = ""
		marker_label.modulate = Color(0.5, 0.5, 0.5)
	elif is_accepted and all_tasks_done:
		# All tasks complete, ready to turn in
		material.albedo_color = color_complete
		marker_label.text = "?"
		marker_label.modulate = color_complete
	elif is_accepted:
		# In progress
		material.albedo_color = color_in_progress
		marker_label.text = "!"
		marker_label.modulate = color_in_progress
	else:
		# Available
		material.albedo_color = color_available
		marker_label.text = "!"
		marker_label.modulate = color_available

func get_quest_status() -> String:
	if quest_id in TodoManager.completed_quests:
		return "turned_in"
	elif quest_id in TodoManager.accepted_quests:
		if TodoManager.are_all_tasks_completed(quest_id):
			return "complete"  # All tasks done, ready to turn in
		else:
			return "in_progress"  # Still working on tasks
	else:
		return "available"

func get_interaction_prompt() -> String:
	if is_player_in_range:
		var status = get_quest_status()
		match status:
			"available":
				return "Press E to view quest"
			"in_progress":
				return "Press E to view quest"
			"complete":
				return "Press E to turn in quest"
			"turned_in":
				return ""  # No interaction for completed quests
	return ""

func set_movement_targets(quest_location: Vector3, shack_loc: Vector3):
	"""Set where NPC should walk to and where the shack is"""
	target_position = quest_location
	shack_position = shack_loc
	current_state = State.WALKING_TO_LOCATION

func start_return_to_shack():
	"""Trigger NPC to walk back to shack after quest completion"""
	print("NPC starting return journey to shack: ", quest_id)
	current_state = State.WALKING_TO_SHACK
	is_player_in_range = false  # Disable interaction during return
