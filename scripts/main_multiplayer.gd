extends Node3D

# Player spawning
const PLAYER_SCENE = preload("res://scenes/player.tscn")
var spawn_positions = [
	Vector3(0, 1, 0),
	Vector3(-3, 1, -3),
	Vector3(3, 1, -3),
	Vector3(-3, 1, 3),
	Vector3(3, 1, 3),
	Vector3(0, 1, 5),
	Vector3(0, 1, -5),
	Vector3(5, 1, 0)
]

@onready var camera = $Camera3D
@onready var static_player = $Player  # The static player from the scene

var spawned_players = {}  # peer_id -> player node

func _ready():
	# Check if we're in multiplayer mode
	# Only setup multiplayer if NetworkManager has actually created a network connection
	if NetworkManager.peer != null:
		_setup_multiplayer()
	else:
		# Solo mode - keep the static player
		print("Running in solo mode")

func _setup_multiplayer():
	print("Setting up multiplayer...")

	# Remove the static player node (we'll spawn dynamic ones)
	if static_player:
		static_player.queue_free()
		static_player = null

	# Spawn players for everyone already connected
	for peer_id in NetworkManager.players.keys():
		_spawn_player(peer_id)

	# Connect signals for future connections
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

	# Set camera to follow local player
	await get_tree().create_timer(0.1).timeout
	_update_camera_target()

func _spawn_player(peer_id: int):
	if peer_id in spawned_players:
		print("Player already spawned: ", peer_id)
		return

	# Get spawn position
	var spawn_index = spawned_players.size() % spawn_positions.size()
	var spawn_pos = spawn_positions[spawn_index]

	# Create player instance
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_" + str(peer_id)

	# Set player info
	var player_name = NetworkManager.get_player_name(peer_id)
	player.set_player_info(player_name, peer_id)

	# Position the player
	player.position = spawn_pos

	# Add to scene
	add_child(player)
	spawned_players[peer_id] = player

	print("Spawned player: ", player_name, " at ", spawn_pos)

	# Update camera if this is the local player
	if peer_id == multiplayer.get_unique_id():
		_update_camera_target()

func _on_player_connected(peer_id: int, player_name: String):
	print("Player joined game: ", player_name)
	_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int):
	print("Player left game: ", peer_id)

	if peer_id in spawned_players:
		var player = spawned_players[peer_id]
		player.queue_free()
		spawned_players.erase(peer_id)

func _update_camera_target():
	"""Make camera follow the local player"""
	var my_peer_id = multiplayer.get_unique_id()

	if my_peer_id in spawned_players:
		var my_player = spawned_players[my_peer_id]
		camera.set_target(my_player)
		print("Camera now following local player")
	elif static_player:
		# Fallback to static player in solo mode
		camera.set_target(static_player)
