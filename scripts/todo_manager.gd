extends Node

# Singleton for managing all todo/quest state

# Signals
signal todos_loaded
signal quest_accepted(todo_id: String)
signal quest_assigned(todo_id: String, worker_id: String)
signal quest_completed(todo_id: String)

# Data storage
var all_todos: Array = []
var accepted_quests: Dictionary = {}  # todo_id -> todo data
var assigned_quests: Dictionary = {}  # todo_id -> worker_id
var completed_quests: Array = []

# Player stats
var player_xp: int = 0
var player_gold: int = 0
var player_level: int = 1

func _ready():
	print("TodoManager initialized")
	load_todos_from_file()

func load_todos_from_file(file_path: String = "res://sample-todos.json"):
	if not FileAccess.file_exists(file_path):
		print("Todo file not found: ", file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open todo file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return

	var data = json.data
	all_todos = data.get("todos", [])

	print("Loaded %d todos from file" % all_todos.size())
	todos_loaded.emit()

func get_available_quests() -> Array:
	var available = []
	for todo in all_todos:
		var todo_id = todo.get("id", "")
		if todo_id not in accepted_quests and todo_id not in completed_quests:
			available.append(todo)
	return available

func get_accepted_quests() -> Array:
	return accepted_quests.values()

func get_unassigned_quests() -> Array:
	var unassigned = []
	for todo_id in accepted_quests.keys():
		if todo_id not in assigned_quests:
			unassigned.append(accepted_quests[todo_id])
	return unassigned

func accept_quest(todo_id: String) -> bool:
	# Find the todo
	var todo = null
	for t in all_todos:
		if t.get("id", "") == todo_id:
			todo = t
			break

	if not todo:
		print("Quest not found: ", todo_id)
		return false

	if todo_id in accepted_quests:
		print("Quest already accepted: ", todo_id)
		return false

	accepted_quests[todo_id] = todo
	quest_accepted.emit(todo_id)
	print("Quest accepted: ", todo.get("title", "Unknown"))
	return true

func assign_quest(todo_id: String, worker_id: String) -> bool:
	if todo_id not in accepted_quests:
		print("Cannot assign quest that hasn't been accepted: ", todo_id)
		return false

	if todo_id in assigned_quests:
		print("Quest already assigned: ", todo_id)
		return false

	assigned_quests[todo_id] = worker_id
	quest_assigned.emit(todo_id, worker_id)
	print("Quest assigned to worker: ", todo_id, " -> ", worker_id)
	return true

func complete_quest(todo_id: String) -> bool:
	if todo_id not in accepted_quests:
		print("Cannot complete quest that wasn't accepted: ", todo_id)
		return false

	var todo = accepted_quests[todo_id]

	# Award rewards
	var xp = todo.get("xp_reward", 0)
	var gold = todo.get("gold_reward", 0)
	player_xp += xp
	player_gold += gold

	# Check for level up (simple: every 500 XP)
	var new_level = 1 + int(player_xp / 500)
	if new_level > player_level:
		player_level = new_level
		print("LEVEL UP! Now level ", player_level)

	# Move to completed
	completed_quests.append(todo_id)
	accepted_quests.erase(todo_id)
	assigned_quests.erase(todo_id)

	quest_completed.emit(todo_id)
	print("Quest completed: ", todo.get("title", "Unknown"), " (+%d XP, +%d Gold)" % [xp, gold])
	return true

func get_player_stats() -> Dictionary:
	return {
		"xp": player_xp,
		"gold": player_gold,
		"level": player_level,
		"accepted_count": accepted_quests.size(),
		"completed_count": completed_quests.size()
	}
