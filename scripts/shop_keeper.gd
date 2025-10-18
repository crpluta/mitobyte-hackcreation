extends Node3D

@export var interaction_range: float = 3.0

var player: Node3D = null
var is_player_in_range: bool = false

signal player_entered_range
signal player_exited_range
signal interaction_triggered

func _ready():
	print("Shop Keeper initialized")
	_find_local_player()

func _find_local_player():
	"""Find the local player (the one controlled by this client)"""
	var players = get_tree().get_nodes_in_group("player")

	for p in players:
		if p.is_multiplayer_authority():
			player = p
			print("Shop Keeper found local player: ", p.name)
			return

	# Fallback to first player (solo mode)
	if not players.is_empty():
		player = players[0]

func _process(_delta):
	# Re-find player if we lost the reference (multiplayer)
	if not is_instance_valid(player):
		_find_local_player()

	if not player:
		return

	var distance = global_position.distance_to(player.global_position)
	var in_range = distance <= interaction_range

	if in_range and not is_player_in_range:
		is_player_in_range = true
		player_entered_range.emit()
		print("Player can interact with Shop Keeper")
	elif not in_range and is_player_in_range:
		is_player_in_range = false
		player_exited_range.emit()

	if is_player_in_range and Input.is_action_just_pressed("interact"):
		interaction_triggered.emit()
		print("Shop Keeper interaction triggered!")
