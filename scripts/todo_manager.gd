extends Node

# Singleton for managing all todo/quest state

# Signals
signal todos_loaded
signal quest_accepted(quest_id: String)
signal task_completed(quest_id: String, task_id: String)
signal quest_completed(quest_id: String)

# Data storage
var all_todos: Array = []  # Array of quest objects (with quest_type added internally)
var accepted_quests: Dictionary = {}  # quest_id -> quest data
var completed_tasks: Dictionary = {}  # quest_id -> Array of completed task_ids
var completed_quests: Array = []

# Quest type tracking (game-side only, not in JSON)
var quest_types: Dictionary = {}  # quest_id -> "daily" or "one_time"

# Player stats
var player_xp: int = 0
var player_gold: int = 0
var player_level: int = 1

func _ready():
	print("TodoManager initialized")
	# Load sample data initially
	load_todos_from_file()

	# TODO: Watch for todos_onetime.json and todos_daily.json changes
	# For now, just load from sample-todos.json

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

func import_quests_from_json(json_string: String, quest_type: String) -> bool:
	"""Import quests from JSON string and tag them with quest_type (daily or one_time)
	Merges with existing quests, preserving progress for matching quest IDs"""

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error in import: ", json.get_error_message())
		return false

	var data = json.data
	if not data.has("quests"):
		print("Invalid import JSON - missing 'quests' field")
		return false

	var imported_quests = data.get("quests", [])

	for quest in imported_quests:
		var quest_id = quest.get("id", "")
		if quest_id.is_empty():
			continue

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

	print("Imported %d quests as %s" % [imported_quests.size(), quest_type])
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

	accepted_quests[quest_id] = quest
	# Initialize empty completed tasks array for this quest
	completed_tasks[quest_id] = []
	quest_accepted.emit(quest_id)
	print("Quest accepted: ", quest.get("title", "Unknown"))
	return true

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

	# Award rewards (new format)
	var rewards = quest.get("rewards", {})
	var xp = rewards.get("xp", 0)
	var coins = rewards.get("coins", 0)
	player_xp += xp
	player_gold += coins

	# Check for level up (simple: every 500 XP)
	var new_level = 1 + int(player_xp / 500)
	if new_level > player_level:
		player_level = new_level
		print("LEVEL UP! Now level ", player_level)

	# Move to completed
	completed_quests.append(quest_id)
	accepted_quests.erase(quest_id)
	completed_tasks.erase(quest_id)

	quest_completed.emit(quest_id)
	print("Quest completed: ", quest.get("title", "Unknown"), " (+%d XP, +%d Coins)" % [xp, coins])
	return true

func get_quest_type(quest_id: String) -> String:
	"""Get quest type (daily or one_time)"""
	return quest_types.get(quest_id, "one_time")

func get_player_stats() -> Dictionary:
	return {
		"xp": player_xp,
		"gold": player_gold,
		"level": player_level,
		"accepted_count": accepted_quests.size(),
		"completed_count": completed_quests.size()
	}
