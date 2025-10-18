extends Control

# UI References
@onready var player_name_input = $VBoxContainer/PlayerNameInput
@onready var ip_input = $VBoxContainer/IPInput
@onready var port_input = $VBoxContainer/PortInput
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_game_button = $VBoxContainer/StartGameButton

# Default values
const DEFAULT_PORT = 7777

func _ready():
	# Set default values
	port_input.text = str(DEFAULT_PORT)
	ip_input.text = "127.0.0.1"
	player_name_input.text = "Player"
	start_game_button.visible = false

	# Connect button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)

	# Connect NetworkManager signals
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _on_host_pressed():
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Please enter a player name"
		return

	var port = int(port_input.text)

	NetworkManager.set_player_name(player_name)
	var success = NetworkManager.create_server(port)

	if success:
		status_label.text = "Hosting on port " + str(port) + "...\nWaiting for players..."
		_disable_connection_ui()
		start_game_button.visible = true  # Host can start game
		_update_player_list()
	else:
		status_label.text = "Failed to create server"

func _on_join_pressed():
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Please enter a player name"
		return

	var ip = ip_input.text.strip_edges()
	var port = int(port_input.text)

	NetworkManager.set_player_name(player_name)
	var success = NetworkManager.join_server(ip, port)

	if success:
		status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
		_disable_connection_ui()
	else:
		status_label.text = "Failed to connect to server"

func _on_start_game_pressed():
	# Only host can start the game
	if not NetworkManager.is_server():
		return

	# Load the main game scene
	_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# RPC: Client requests game state (client -> server)
@rpc("any_peer", "reliable")
func _request_game_state():
	if not NetworkManager.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	# Check if game has already started by seeing if we're in the main scene
	# If server is still in lobby, don't send them to game
	# If server is in game, send the client to game
	if get_tree().current_scene.name == "Main":
		_send_to_game.rpc_id(sender_id)

# RPC: Server tells client to join the game (server -> client)
@rpc("authority", "reliable")
func _send_to_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_server_started():
	status_label.text = "Server started!\nYour IP: Check network settings\nPort: " + port_input.text
	_update_player_list()

func _on_connected_to_server():
	status_label.text = "Connected to server!"
	_update_player_list()

	# Request game state from server
	_request_game_state.rpc_id(1)

func _on_connection_failed():
	status_label.text = "Connection failed!"
	_enable_connection_ui()

func _on_player_connected(peer_id: int, player_name: String):
	status_label.text = player_name + " joined!"
	_update_player_list()

func _on_player_disconnected(peer_id: int):
	status_label.text = "A player left"
	_update_player_list()

func _update_player_list():
	player_list.text = "Players (" + str(NetworkManager.get_player_count()) + "):\n"

	for peer_id in NetworkManager.players.keys():
		var player_name = NetworkManager.players[peer_id].get("name", "Unknown")
		var is_host = (peer_id == 1)
		var suffix = " (Host)" if is_host else ""
		player_list.text += "- " + player_name + suffix + "\n"

func _disable_connection_ui():
	player_name_input.editable = false
	ip_input.editable = false
	port_input.editable = false
	host_button.disabled = true
	join_button.disabled = true

func _enable_connection_ui():
	player_name_input.editable = true
	ip_input.editable = true
	port_input.editable = true
	host_button.disabled = false
	join_button.disabled = false
	start_game_button.visible = false
