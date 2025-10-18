extends Node3D

# NPC spawning
@export var quest_giver_scene: PackedScene
@export var spawn_center: Vector3 = Vector3.ZERO
@export var max_npcs: int = 15  # Cap on number of quest-giver NPCs

# Shack reference
var shack_position: Vector3 = Vector3.ZERO

# Priority-based distance ranges (constrained to 50x50 plane = 22 max radius)
const PRIORITY_RANGES = {
	"high": {"min": 5.0, "max": 10.0},
	"medium": {"min": 10.0, "max": 16.0},
	"low": {"min": 16.0, "max": 22.0}
}

# Minimum distance between NPCs to prevent overlap
const MIN_NPC_DISTANCE = 3.0

# Priority ordering for spawn cap
const PRIORITY_ORDER = {
	"high": 0,
	"medium": 1,
	"low": 2
}

var spawned_npcs: Array = []

func _ready():
	# Wait for TodoManager to load
	await get_tree().process_frame

	# Find the shack SpawnPoint
	var shack = get_tree().get_first_node_in_group("npc_shack")
	if shack:
		var spawn_point = shack.get_node_or_null("SpawnPoint")
		if spawn_point:
			shack_position = spawn_point.global_position
			print("Found shack spawn point at: ", shack_position)
		else:
			shack_position = shack.global_position
			print("Using shack base position: ", shack_position)
	else:
		print("WARNING: Shack not found, NPCs will spawn at origin")

	# Connect to TodoManager signals
	TodoManager.todos_loaded.connect(_on_todos_loaded)
	TodoManager.quest_accepted.connect(_on_quest_updated)
	TodoManager.task_completed.connect(_on_task_updated)
	TodoManager.quest_completed.connect(_on_quest_updated)

	# Spawn NPCs if todos already loaded
	if not TodoManager.all_todos.is_empty():
		spawn_quest_givers()

func _on_todos_loaded():
	spawn_quest_givers()

func spawn_quest_givers():
	# Build a map of existing NPCs by quest_id
	var existing_npcs = {}
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			existing_npcs[npc.quest_id] = npc

	# Get all quests EXCEPT completed ones (only available and accepted spawn NPCs)
	var all_quests = []
	for quest in TodoManager.all_todos:
		var quest_id = quest.get("id", "")
		if quest_id not in TodoManager.completed_quests:
			all_quests.append(quest)

	# Sort by priority (high -> medium -> low)
	all_quests.sort_custom(func(a, b):
		var priority_a = PRIORITY_ORDER.get(a.get("priority", "medium"), 1)
		var priority_b = PRIORITY_ORDER.get(b.get("priority", "medium"), 1)
		return priority_a < priority_b  # Lower number = higher priority
	)

	# Track which quest_ids we're keeping
	var active_quest_ids = {}

	# Spawn or update NPCs up to the cap
	var spawn_count = min(all_quests.size(), max_npcs)
	for i in range(spawn_count):
		var quest = all_quests[i]
		var quest_id = quest.get("id", "")
		active_quest_ids[quest_id] = true

		if quest_id in existing_npcs:
			# NPC already exists - update its data and keep position/state
			var npc = existing_npcs[quest_id]
			npc.setup_quest(quest, quest_id)
			npc.update_visual_state()
			# Don't reset movement - let them stay where they are
			print("Updated existing NPC (keeping position) for quest: ", quest_id)
		else:
			# New quest - spawn new NPC
			spawn_quest_giver(quest)
			print("Spawned new NPC for quest: ", quest_id)

	# Remove NPCs for quests that no longer exist
	for i in range(spawned_npcs.size() - 1, -1, -1):
		var npc = spawned_npcs[i]
		if is_instance_valid(npc) and npc.quest_id not in active_quest_ids:
			print("Removing NPC for quest no longer in list: ", npc.quest_id)
			npc.queue_free()
			spawned_npcs.remove_at(i)

	var total_quests = TodoManager.all_todos.size()
	var completed_count = TodoManager.completed_quests.size()
	var spawnable_count = all_quests.size()

	if spawnable_count > max_npcs:
		print("WARNING: %d spawnable quests but only spawning %d NPCs (cap)" % [spawnable_count, max_npcs])

	print("Quest-giver NPCs: %d active (%d completed, %d total quests)" % [spawned_npcs.size(), completed_count, total_quests])

func spawn_quest_giver(todo: Dictionary):
	if not quest_giver_scene:
		print("Error: quest_giver_scene not set!")
		return

	# Instantiate NPC at shack position
	var npc = quest_giver_scene.instantiate()
	add_child(npc)
	npc.global_position = shack_position

	# Get priority and calculate final quest location
	var priority = todo.get("priority", "medium")
	var quest_location = get_scattered_position(priority)

	# Setup quest data
	var quest_id = todo.get("id", "")
	npc.setup_quest(todo, quest_id)

	# Set movement targets (shack -> location)
	npc.set_movement_targets(quest_location, shack_position)

	# Connect signals
	npc.interaction_triggered.connect(func(): _on_npc_interaction(npc, todo, quest_id))
	npc.reached_shack.connect(func(): _on_npc_reached_shack(npc))

	# Connect to UI for prompts
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		npc.player_entered_range.connect(func(): ui.show_quest_npc_prompt(npc))
		npc.player_exited_range.connect(func(): ui.hide_quest_npc_prompt())

	spawned_npcs.append(npc)
	print("Spawned NPC at shack, walking to quest location: ", quest_id)

func get_scattered_position(priority: String) -> Vector3:
	# Get distance range based on priority
	var range_data = PRIORITY_RANGES.get(priority, PRIORITY_RANGES["medium"])
	var min_dist = range_data["min"]
	var max_dist = range_data["max"]

	# Try to find a valid position (avoid overlap)
	var max_attempts = 20
	for attempt in range(max_attempts):
		# Random distance within range
		var distance = randf_range(min_dist, max_dist)

		# Random angle
		var angle = randf() * TAU

		# Calculate position
		var pos_x = spawn_center.x + cos(angle) * distance
		var pos_z = spawn_center.z + sin(angle) * distance
		var pos_y = 0.0  # Ground level

		var candidate_pos = Vector3(pos_x, pos_y, pos_z)

		# Check distance from all existing NPCs
		var too_close = false
		for npc in spawned_npcs:
			if is_instance_valid(npc):
				var dist = candidate_pos.distance_to(npc.global_position)
				if dist < MIN_NPC_DISTANCE:
					too_close = true
					break

		# If position is valid, use it
		if not too_close:
			return candidate_pos

	# Fallback: return position anyway if we couldn't find a perfect spot
	var distance = randf_range(min_dist, max_dist)
	var angle = randf() * TAU
	return Vector3(
		spawn_center.x + cos(angle) * distance,
		0.0,
		spawn_center.z + sin(angle) * distance
	)

func _on_npc_interaction(npc: Node3D, todo: Dictionary, quest_id: String):
	# Get UI manager and show quest dialog
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		ui.show_quest_dialog(npc, todo, quest_id)

func _on_quest_updated(quest_id: String):
	# When quest is turned in, trigger NPC return journey
	if quest_id in TodoManager.completed_quests:
		# Find the NPC and send them back to shack
		for npc in spawned_npcs:
			if is_instance_valid(npc) and npc.quest_id == quest_id:
				print("Quest completed, sending NPC back to shack: ", quest_id)
				npc.start_return_to_shack()
				return

	# Otherwise, update visual states for the specific NPC
	for npc in spawned_npcs:
		if is_instance_valid(npc) and npc.quest_id == quest_id:
			npc.update_visual_state()

func _on_npc_reached_shack(npc: Node3D):
	"""Handle NPC reaching shack - despawn them"""
	print("Despawning NPC that reached shack: ", npc.quest_id)

	# Remove from array
	var index = spawned_npcs.find(npc)
	if index != -1:
		spawned_npcs.remove_at(index)

	# Despawn
	npc.queue_free()

func _on_task_updated(quest_id: String, _task_id: String):
	# Update visual state for specific quest's NPC when tasks are checked off
	for npc in spawned_npcs:
		if is_instance_valid(npc) and npc.quest_id == quest_id:
			npc.update_visual_state()
