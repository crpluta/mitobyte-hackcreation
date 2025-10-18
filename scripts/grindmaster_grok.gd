extends Node3D

# Interaction settings
@export var interaction_range: float = 3.0
@export var interaction_prompt: String = "Press E to talk to Grindmaster Grok"

# References
var player: Node3D = null
var is_player_in_range: bool = false

# Signals
signal player_entered_range
signal player_exited_range
signal interaction_triggered

func _ready():
	print("Grindmaster Grok initialized")
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Warning: Player not found in 'player' group")

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
		print("Player can interact with Grindmaster Grok")
	elif not in_range and is_player_in_range:
		is_player_in_range = false
		player_exited_range.emit()

	# Check for interaction input
	if is_player_in_range and Input.is_action_just_pressed("interact"):
		interaction_triggered.emit()
		print("Grindmaster Grok interaction triggered!")

func get_interaction_prompt() -> String:
	return interaction_prompt if is_player_in_range else ""
