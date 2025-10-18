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

# Signals
signal player_entered_range
signal player_exited_range
signal interaction_triggered

# Colors for quest states
const COLOR_AVAILABLE = Color(0.2, 0.8, 0.2)    # Green - quest available
const COLOR_IN_PROGRESS = Color(0.8, 0.8, 0.2)  # Yellow - quest accepted
const COLOR_COMPLETE = Color(0.3, 0.6, 1.0)     # Blue - ready to turn in

func _ready():
	player = get_tree().get_first_node_in_group("player")
	update_visual_state()

func setup_quest(todo: Dictionary, id: String):
	quest_data = todo
	quest_id = id
	update_visual_state()

func _process(_delta):
	if not player:
		return

	# Check distance to player
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

func update_visual_state():
	if quest_id.is_empty():
		return

	# Check quest status in TodoManager
	var is_accepted = quest_id in TodoManager.accepted_quests
	var is_completed = quest_id in TodoManager.completed_quests

	# Create material if needed
	if not material:
		material = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, material)

	# Update color and marker based on state
	if is_completed:
		# Blue with ? - ready to turn in
		material.albedo_color = COLOR_COMPLETE
		marker_label.text = "?"
		marker_label.modulate = COLOR_COMPLETE
	elif is_accepted:
		# Yellow with ! - in progress
		material.albedo_color = COLOR_IN_PROGRESS
		marker_label.text = "!"
		marker_label.modulate = COLOR_IN_PROGRESS
	else:
		# Green with ! - available
		material.albedo_color = COLOR_AVAILABLE
		marker_label.text = "!"
		marker_label.modulate = COLOR_AVAILABLE

func get_quest_status() -> String:
	if quest_id in TodoManager.completed_quests:
		return "complete"
	elif quest_id in TodoManager.accepted_quests:
		return "in_progress"
	else:
		return "available"

func get_interaction_prompt() -> String:
	if is_player_in_range:
		var status = get_quest_status()
		match status:
			"available":
				return "Press E to view quest"
			"in_progress":
				return "Press E to check progress"
			"complete":
				return "Press E to turn in quest"
	return ""
