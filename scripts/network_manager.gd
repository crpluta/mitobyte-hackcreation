extends Node

# Singleton for managing multiplayer networking

# Signals
signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal server_started
signal connected_to_server
signal connection_failed
signal disconnected_from_server

# Network configuration
const DEFAULT_PORT = 7777
const MAX_CLIENTS = 8

# Player data
var players: Dictionary = {}  # peer_id -> {name: String, ready: bool}
var local_player_name: String = "Player"

# Multiplayer peer
var peer: ENetMultiplayerPeer = null

# Player scene for spawning
const PLAYER_SCENE = preload("res://scenes/player.tscn")

func _ready():
	print("NetworkManager initialized")

	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Host a server
func create_server(port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)

	if error != OK:
		print("Failed to create server: ", error)
		return false

	multiplayer.multiplayer_peer = peer

	# Add host player
	var host_id = multiplayer.get_unique_id()
	players[host_id] = {
		"name": local_player_name,
		"ready": true
	}

	print("Server created on port ", port)
	print("Your IP address(es):")
	print("  Local: 127.0.0.1")
	print("  For WiFi: Check your system's network settings")

	server_started.emit()
	return true

# Join a server
func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)

	if error != OK:
		print("Failed to join server: ", error)
		return false

	multiplayer.multiplayer_peer = peer
	print("Attempting to connect to ", ip, ":", port)
	return true

# Disconnect from network
func disconnect_network():
	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null
	players.clear()
	print("Disconnected from network")

# Check if we are the server
func is_server() -> bool:
	return multiplayer.is_server()

# Get player count
func get_player_count() -> int:
	return players.size()

# Set local player name
func set_player_name(player_name: String):
	local_player_name = player_name

# Register player data (called by clients when they connect)
@rpc("any_peer", "reliable")
func register_player(player_name: String):
	var sender_id = multiplayer.get_remote_sender_id()

	if sender_id == 0:  # Called locally by server
		sender_id = multiplayer.get_unique_id()

	players[sender_id] = {
		"name": player_name,
		"ready": false
	}

	print("Player registered: ", player_name, " (ID: ", sender_id, ")")
	player_connected.emit(sender_id, player_name)

	# If we're the server, sync all players to the new client
	if is_server():
		_sync_players_to_client.rpc_id(sender_id, players)

# Sync all players to a specific client (server -> client)
@rpc("authority", "reliable")
func _sync_players_to_client(all_players: Dictionary):
	players = all_players
	print("Received player list from server: ", players.keys())

# Callbacks for multiplayer signals
func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)

	if players.has(id):
		var player_name = players[id].get("name", "Unknown")
		players.erase(id)
		player_disconnected.emit(id)
		print("Player removed: ", player_name)

func _on_connected_to_server():
	print("Successfully connected to server!")

	# Register ourselves with the server
	var my_id = multiplayer.get_unique_id()
	players[my_id] = {
		"name": local_player_name,
		"ready": false
	}

	# Tell server our player name
	register_player.rpc_id(1, local_player_name)

	connected_to_server.emit()

func _on_connection_failed():
	print("Connection to server failed!")
	disconnect_network()
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected!")
	disconnect_network()
	disconnected_from_server.emit()

# Get local peer ID
func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()

# Get player name by peer ID
func get_player_name(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id].get("name", "Unknown")
	return "Unknown"
