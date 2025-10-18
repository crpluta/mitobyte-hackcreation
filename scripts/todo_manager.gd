extends Node

# Singleton for managing all todo/quest state

# Signals
signal todos_loaded
signal quest_accepted(quest_id: String)
signal task_completed(quest_id: String, task_id: String)
signal quest_completed(quest_id: String)

# Game configuration
var game_config: Dictionary = {}

# Data storage
var all_todos: Array = []  # Array of quest objects (with quest_type added internally)
var accepted_quests: Dictionary = {}  # quest_id -> quest data
var completed_tasks: Dictionary = {}  # quest_id -> Array of completed task_ids
var completed_quests: Array = []

# Quest type tracking (game-side only, not in JSON)
var quest_types: Dictionary = {}  # quest_id -> "daily" or "one_time"

# Multiplayer: Track which player has accepted which quest
var quest_locks: Dictionary = {}  # quest_id -> {peer_id: int, player_name: String}

# Player stats
var player_xp: int = 0
var player_gold: int = 0
var player_level: int = 1

func _ready():
	print("TodoManager initialized")

	# Initialize external files for deployment
	DeploymentManager.initialize_external_files()

	# Load game configuration first
	load_game_config()

	# Load sample data initially
	load_todos_from_file()

	# Connect to NetworkManager for multiplayer events
	if NetworkManager:
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

	# TODO: Watch for todos_onetime.json and todos_daily.json changes
	# For now, just load from sample-todos.json

# Handle player disconnection - release their quests
func _on_player_disconnected(peer_id: int):
	print("Releasing quests from disconnected player: ", peer_id)

	# Find and release all quests locked by this player
	var quests_to_unlock = []
	for quest_id in quest_locks.keys():
		var lock_info = quest_locks[quest_id]
		if lock_info.get("peer_id", -1) == peer_id:
			quests_to_unlock.append(quest_id)

	for quest_id in quests_to_unlock:
		quest_locks.erase(quest_id)
		print("Released quest: ", quest_id)

		# Broadcast unlock to all clients (if we're the server)
		if multiplayer.is_server():
			_sync_quest_unlock.rpc(quest_id)

# RPC: Unlock a quest (server -> all)
@rpc("authority", "reliable")
func _sync_quest_unlock(quest_id: String):
	quest_locks.erase(quest_id)
	print("Quest unlocked: ", quest_id)

func load_game_config():
	"""Load game configuration from game_config.json"""
	# Use external config path for deployed builds
	var config_path = DeploymentManager.get_config_path()

	# Fallback to res:// if external doesn't exist (shouldn't happen after init)
	if not FileAccess.file_exists(config_path):
		print("WARNING: External config not found at: ", config_path)
		config_path = "res://game_config.json"

	if not FileAccess.file_exists(config_path):
		print("WARNING: game_config.json not found, using defaults")
		_set_default_config()
		return

	print("Loading game config from: ", config_path)
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("ERROR: Failed to open game_config.json")
		_set_default_config()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("ERROR: Failed to parse game_config.json: ", json.get_error_message())
		_set_default_config()
		return

	game_config = json.data
	print("Game configuration loaded successfully")

func _set_default_config():
	"""Fallback default configuration"""
	game_config = {
		"progression": {
			"xp_per_level": 500,
			"difficulty_rewards": {
				"easy": {"xp": 100, "coins": 50},
				"medium": {"xp": 200, "coins": 100},
				"hard": {"xp": 400, "coins": 200},
				"epic": {"xp": 800, "coins": 400}
			}
		},
		"shop": {
			"items": []
		}
	}
	print("Using default game configuration")

func load_todos_from_file(file_path: String = "res://todos.json"):
	# Try todos.json first, fall back to sample if not found
	if not FileAccess.file_exists(file_path):
		print("Quest file not found: ", file_path)
		file_path = "res://sample-todos.json"
		if not FileAccess.file_exists(file_path):
			print("Sample file also not found, no quests to load")
			return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open quest file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return

	var data = json.data

	# Expect format: {"quests": [...]}
	if not data.has("quests"):
		print("Invalid JSON format - missing 'quests' field")
		return

	all_todos = data.get("quests", [])

	# Tag sample quests as one_time by default (for testing)
	for quest in all_todos:
		var quest_id = quest.get("id", "")
		if not quest_id.is_empty() and not quest_id in quest_types:
			quest_types[quest_id] = "one_time"

	print("Loaded %d quest(s) from file: %s" % [all_todos.size(), file_path])
	todos_loaded.emit()

func import_quests_from_json(json_string: String, fallback_quest_type: String = "one_time") -> bool:
	"""Import quests from JSON string
	Merges with existing quests, preserving progress for matching quest IDs

	NEW: LLM now provides 'frequency' field (one_time/daily/weekly) per quest
	Fallback quest_type only used if frequency is missing
	"""

	# In multiplayer, sync to all clients via server
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			# Server broadcasts to all clients (including self via call_local)
			_sync_import_quests.rpc(json_string, fallback_quest_type)
		else:
			# Client requests server to broadcast
			_request_import_quests.rpc_id(1, json_string, fallback_quest_type)
		return true

	# Solo mode - import directly
	return _import_quests_internal(json_string, fallback_quest_type)

# RPC: Client requests server to import and broadcast quests (client -> server)
@rpc("any_peer", "reliable")
func _request_import_quests(json_string: String, fallback_quest_type: String):
	if not multiplayer.is_server():
		return

	# Server broadcasts to all clients
	_sync_import_quests.rpc(json_string, fallback_quest_type)

# RPC: Server broadcasts quest import to all clients (server -> all)
@rpc("authority", "call_local", "reliable")
func _sync_import_quests(json_string: String, fallback_quest_type: String):
	"""RPC function to sync quest imports across all clients"""
	_import_quests_internal(json_string, fallback_quest_type)

func _import_quests_internal(json_string: String, fallback_quest_type: String = "one_time") -> bool:
	"""Internal function that actually imports quests"""
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error in import: ", json.get_error_message())
		return false

	var data = json.data
	var imported_quests = []

	# Expect: {"quests": [...]}
	if data.has("quests"):
		imported_quests = data.get("quests", [])
	else:
		print("Invalid import JSON - expected {quests: [...]}")
		return false

	for quest in imported_quests:
		var quest_id = quest.get("id", "")
		if quest_id.is_empty():
			continue

		# Get quest type from LLM's 'frequency' field (new!)
		var quest_type = quest.get("frequency", fallback_quest_type)
		if quest_type not in ["one_time", "daily", "weekly"]:
			quest_type = fallback_quest_type  # Fallback to safe value

		# Map difficulty -> priority for placement
		if not quest.has("priority"):
			var difficulty = quest.get("difficulty", "medium")
			match difficulty:
				"easy":
					quest["priority"] = "low"  # Easy tasks = far away
				"medium":
					quest["priority"] = "medium"
				"hard", "epic":
					quest["priority"] = "high"  # Hard tasks = close by
				_:
					quest["priority"] = "medium"

		# Add default rewards if missing (from config)
		if not quest.has("rewards") or quest.get("rewards", {}).is_empty():
			var difficulty = quest.get("difficulty", "medium")
			var defaults = game_config.get("progression", {}).get("difficulty_rewards", {}).get(difficulty, {})
			if not defaults.is_empty():
				quest["rewards"] = {
					"xp": defaults.get("xp", 100),
					"coins": defaults.get("coins", 50)
				}
			else:
				# Fallback if config not loaded
				quest["rewards"] = {"xp": 100, "coins": 50}

		# Add estimated_time_minutes if missing (from config)
		if not quest.has("estimated_time_minutes"):
			var difficulty = quest.get("difficulty", "medium")
			var defaults = game_config.get("progression", {}).get("difficulty_rewards", {}).get(difficulty, {})
			if defaults.has("estimated_time_minutes"):
				quest["estimated_time_minutes"] = defaults.get("estimated_time_minutes")
			else:
				# Fallback
				match difficulty:
					"easy": quest["estimated_time_minutes"] = 15
					"medium": quest["estimated_time_minutes"] = 30
					"hard": quest["estimated_time_minutes"] = 60
					"epic": quest["estimated_time_minutes"] = 120
					_: quest["estimated_time_minutes"] = 30

		# Check if quest already exists
		var existing_quest = null
		for q in all_todos:
			if q.get("id", "") == quest_id:
				existing_quest = q
				break

		if existing_quest:
			# Quest exists - update its data but preserve acceptance/completion state
			# Update quest details (title, description, tasks, etc.)
			for key in quest.keys():
				existing_quest[key] = quest[key]

			# Preserve quest_type
			quest_types[quest_id] = quest_type
			print("Updated existing quest: ", quest_id)
		else:
			# New quest - add it
			all_todos.append(quest)
			quest_types[quest_id] = quest_type
			print("Imported new quest: ", quest_id, " as ", quest_type)

	print("Imported %d quests (multiplayer: %s)" % [imported_quests.size(), multiplayer.has_multiplayer_peer()])
	todos_loaded.emit()
	return true

func get_available_quests() -> Array:
	var available = []
	for todo in all_todos:
		var todo_id = todo.get("id", "")
		if todo_id not in accepted_quests and todo_id not in completed_quests:
			available.append(todo)
	return available

func get_accepted_quests() -> Array:
	return accepted_quests.values()

func get_quest_tasks(quest_id: String) -> Array:
	"""Get all tasks for a specific quest"""
	var quest = null
	# Check if in accepted quests first
	if quest_id in accepted_quests:
		quest = accepted_quests[quest_id]
	else:
		# Otherwise find in all_todos
		for q in all_todos:
			if q.get("id", "") == quest_id:
				quest = q
				break

	if quest:
		return quest.get("tasks", [])
	return []

func get_completed_tasks_for_quest(quest_id: String) -> Array:
	"""Get list of completed task IDs for a quest"""
	return completed_tasks.get(quest_id, [])

func is_task_completed(quest_id: String, task_id: String) -> bool:
	"""Check if a specific task is marked complete"""
	var completed = completed_tasks.get(quest_id, [])
	return task_id in completed

func are_all_tasks_completed(quest_id: String) -> bool:
	"""Check if all tasks in a quest are completed"""
	var tasks = get_quest_tasks(quest_id)
	if tasks.is_empty():
		return false

	var completed = completed_tasks.get(quest_id, [])
	for task in tasks:
		var task_id = task.get("id", "")
		if task_id not in completed:
			return false
	return true

func accept_quest(quest_id: String) -> bool:
	# In multiplayer, always go through server validation
	if multiplayer.has_multiplayer_peer():
		var my_peer_id = multiplayer.get_unique_id()
		var my_name = NetworkManager.get_player_name(my_peer_id)

		if multiplayer.is_server():
			# Server handles directly
			if _can_accept_quest(quest_id, my_peer_id):
				_sync_quest_accept.rpc(quest_id, my_peer_id, my_name)
				return true
			return false
		else:
			# Client sends request to server
			_request_quest_accept.rpc_id(1, quest_id, my_peer_id, my_name)
			return true  # Optimistic return, actual acceptance happens via RPC
	else:
		# Solo mode - accept directly
		return _accept_quest_internal(quest_id, 1, "Player")

# RPC: Request to accept a quest (any peer -> server)
@rpc("any_peer", "reliable")
func _request_quest_accept(quest_id: String, peer_id: int, player_name: String):
	if not multiplayer.is_server():
		return

	# Server validates the request
	if _can_accept_quest(quest_id, peer_id):
		# Broadcast acceptance to all clients (including sender via call_local)
		_sync_quest_accept.rpc(quest_id, peer_id, player_name)
	else:
		# Quest is already locked, notify the requester
		print("Quest acceptance rejected for %s: already locked" % player_name)

# RPC: Server broadcasts quest acceptance to all clients (server -> all)
@rpc("authority", "call_local", "reliable")
func _sync_quest_accept(quest_id: String, peer_id: int, player_name: String):
	_accept_quest_internal(quest_id, peer_id, player_name)

# Check if a quest can be accepted (for server validation)
func _can_accept_quest(quest_id: String, peer_id: int) -> bool:
	# Check if already locked by someone else
	if quest_locks.has(quest_id):
		var lock_peer = quest_locks[quest_id].get("peer_id", -1)
		if lock_peer != peer_id:
			return false

	# Check if quest exists
	var quest_exists = false
	for q in all_todos:
		if q.get("id", "") == quest_id:
			quest_exists = true
			break

	if not quest_exists:
		return false

	# Check if already accepted
	if quest_id in accepted_quests:
		return false

	return true

# Internal function that actually accepts a quest
func _accept_quest_internal(quest_id: String, peer_id: int, player_name: String) -> bool:
	# Check if quest is locked by another player
	if quest_locks.has(quest_id) and quest_locks[quest_id].get("peer_id", -1) != peer_id:
		var other_player = quest_locks[quest_id].get("player_name", "Another player")
		print("Quest already taken by: ", other_player)
		return false

	# Find the quest
	var quest = null
	for q in all_todos:
		if q.get("id", "") == quest_id:
			quest = q
			break

	if not quest:
		print("Quest not found: ", quest_id)
		return false

	if quest_id in accepted_quests:
		print("Quest already accepted: ", quest_id)
		return false

	# Update quest lock (synced to all clients)
	quest_locks[quest_id] = {
		"peer_id": peer_id,
		"player_name": player_name
	}

	# Only add to accepted quests if this is OUR quest
	var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == my_peer_id:
		# This is our quest - add it to accepted quests
		accepted_quests[quest_id] = quest
		completed_tasks[quest_id] = []
		print("Quest accepted: %s" % quest.get("title", "Unknown"))
	else:
		# Someone else's quest - just update the lock
		print("Quest locked by %s: %s" % [player_name, quest.get("title", "Unknown")])

	# Emit signal on ALL clients so NPCs update their visual state
	quest_accepted.emit(quest_id)

	return true

# Check if a quest is locked by another player
func is_quest_locked_by_other(quest_id: String) -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false

	if not quest_locks.has(quest_id):
		return false

	var lock_info = quest_locks[quest_id]
	var my_peer_id = multiplayer.get_unique_id()
	return lock_info.get("peer_id", -1) != my_peer_id

# Get who has locked a quest (returns player name or empty string)
func get_quest_lock_holder(quest_id: String) -> String:
	if quest_locks.has(quest_id):
		return quest_locks[quest_id].get("player_name", "Unknown")
	return ""

# RPC: Client requests to lock a quest (client -> server)
@rpc("any_peer", "reliable")
func _request_quest_lock(quest_id: String, peer_id: int, player_name: String):
	if not multiplayer.is_server():
		return

	# Check if quest is already locked
	if quest_locks.has(quest_id):
		# Quest already locked, notify requester
		_quest_lock_rejected.rpc_id(peer_id, quest_id, quest_locks[quest_id].get("player_name", "Unknown"))
		return

	# Lock the quest
	quest_locks[quest_id] = {
		"peer_id": peer_id,
		"player_name": player_name
	}

	# Broadcast to all clients
	_sync_quest_lock.rpc(quest_id, peer_id, player_name)

# RPC: Sync quest lock to all clients (server -> all)
@rpc("authority", "reliable")
func _sync_quest_lock(quest_id: String, peer_id: int, player_name: String):
	quest_locks[quest_id] = {
		"peer_id": peer_id,
		"player_name": player_name
	}
	print("Quest locked by ", player_name, ": ", quest_id)

# RPC: Quest lock was rejected (server -> client)
@rpc("authority", "reliable")
func _quest_lock_rejected(quest_id: String, taken_by: String):
	print("Quest ", quest_id, " already taken by: ", taken_by)
	# Could emit a signal here to show UI message

func complete_task(quest_id: String, task_id: String) -> bool:
	"""Mark a task as completed"""
	if quest_id not in accepted_quests:
		print("Cannot complete task for quest that wasn't accepted: ", quest_id)
		return false

	# Check if task exists
	var tasks = get_quest_tasks(quest_id)
	var task_exists = false
	for task in tasks:
		if task.get("id", "") == task_id:
			task_exists = true
			break

	if not task_exists:
		print("Task not found: ", task_id)
		return false

	# Check if already completed
	var completed = completed_tasks.get(quest_id, [])
	if task_id in completed:
		print("Task already completed: ", task_id)
		return false

	# Mark as completed
	if quest_id not in completed_tasks:
		completed_tasks[quest_id] = []
	completed_tasks[quest_id].append(task_id)

	task_completed.emit(quest_id, task_id)
	print("Task completed: ", task_id)
	return true

func toggle_task(quest_id: String, task_id: String) -> bool:
	"""Toggle task completion state (for Quest Log UI)"""
	if is_task_completed(quest_id, task_id):
		# Uncomplete the task
		var completed = completed_tasks.get(quest_id, [])
		completed.erase(task_id)
		print("Task unchecked: ", task_id)
		return false
	else:
		# Complete the task
		return complete_task(quest_id, task_id)

func complete_quest(quest_id: String) -> bool:
	"""Turn in a completed quest for rewards"""
	if quest_id not in accepted_quests:
		print("Cannot complete quest that wasn't accepted: ", quest_id)
		return false

	# Check if all tasks are completed
	if not are_all_tasks_completed(quest_id):
		print("Cannot complete quest - not all tasks are done!")
		return false

	var quest = accepted_quests[quest_id]
	var rewards = quest.get("rewards", {})

	# In multiplayer, sync completion to all clients
	if multiplayer.has_multiplayer_peer():
		var my_peer_id = multiplayer.get_unique_id()

		if multiplayer.is_server():
			# Server broadcasts directly
			_sync_quest_complete.rpc(quest_id, my_peer_id)
		else:
			# Client requests server to broadcast
			_request_quest_complete.rpc_id(1, quest_id, my_peer_id)
	else:
		# Solo mode - complete directly
		_complete_quest_internal(quest_id, 1)

	return true

# RPC: Request to complete a quest (any peer -> server)
@rpc("any_peer", "reliable")
func _request_quest_complete(quest_id: String, peer_id: int):
	if not multiplayer.is_server():
		return

	# Server broadcasts completion to all clients
	_sync_quest_complete.rpc(quest_id, peer_id)

# RPC: Server broadcasts quest completion to all clients (server -> all)
@rpc("authority", "call_local", "reliable")
func _sync_quest_complete(quest_id: String, peer_id: int):
	_complete_quest_internal(quest_id, peer_id)

# Internal function that actually completes a quest
func _complete_quest_internal(quest_id: String, peer_id: int):
	var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var is_my_quest = (peer_id == my_peer_id)

	# Find quest data
	var quest = null
	if is_my_quest and quest_id in accepted_quests:
		quest = accepted_quests[quest_id]
	else:
		# Find in all_todos for other players' quests
		for q in all_todos:
			if q.get("id", "") == quest_id:
				quest = q
				break

	if not quest:
		print("Quest not found for completion: ", quest_id)
		return

	# Award rewards ONLY to the owner
	if is_my_quest:
		var rewards = quest.get("rewards", {})
		var xp = rewards.get("xp", 0)
		var coins = rewards.get("coins", 0)
		player_xp += xp
		player_gold += coins

		# Check for level up (configurable XP per level)
		var xp_per_level = game_config.get("progression", {}).get("xp_per_level", 500)
		var new_level = 1 + int(player_xp / xp_per_level)
		if new_level > player_level:
			player_level = new_level
			print("LEVEL UP! Now level ", player_level)

		# Remove from accepted quests
		accepted_quests.erase(quest_id)
		completed_tasks.erase(quest_id)
		print("Quest completed: ", quest.get("title", "Unknown"), " (+%d XP, +%d Coins)" % [xp, coins])
	else:
		print("Quest completed by another player: ", quest.get("title", "Unknown"))

	# Mark as completed for ALL clients (so NPCs despawn for everyone)
	if quest_id not in completed_quests:
		completed_quests.append(quest_id)

	# Unlock quest (remove from locks)
	if quest_locks.has(quest_id):
		quest_locks.erase(quest_id)

	# Emit signal so NPCs can react
	quest_completed.emit(quest_id)

func get_quest_type(quest_id: String) -> String:
	"""Get quest type (daily or one_time)"""
	return quest_types.get(quest_id, "one_time")

func get_xp_per_level() -> int:
	"""Get XP required per level from config"""
	return game_config.get("progression", {}).get("xp_per_level", 500)

func get_shop_items() -> Array:
	"""Get shop items from config"""
	return game_config.get("shop", {}).get("items", [])

func get_player_stats() -> Dictionary:
	return {
		"xp": player_xp,
		"gold": player_gold,
		"level": player_level,
		"accepted_count": accepted_quests.size(),
		"completed_count": completed_quests.size()
	}

func reset_game_state():
	"""Reset all game state for demo purposes"""
	print("Resetting game state...")

	# Clear all quest data
	all_todos.clear()
	accepted_quests.clear()
	completed_tasks.clear()
	completed_quests.clear()
	quest_types.clear()

	# Reset player stats
	player_xp = 0
	player_gold = 0
	player_level = 1

	print("Game state reset complete")
