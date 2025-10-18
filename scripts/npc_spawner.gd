extends Node3D

# NPC spawning
@export var quest_giver_scene: PackedScene
@export var spawn_center: Vector3 = Vector3.ZERO

# Priority-based distance ranges
const PRIORITY_RANGES = {
	"high": {"min": 5.0, "max": 15.0},
	"medium": {"min": 10.0, "max": 25.0},
	"low": {"min": 15.0, "max": 35.0}
}

var spawned_npcs: Array = []

func _ready():
	# Wait for TodoManager to load
	await get_tree().process_frame

	# Connect to TodoManager signals
	TodoManager.todos_loaded.connect(_on_todos_loaded)
	TodoManager.quest_accepted.connect(_on_quest_updated)
	TodoManager.quest_completed.connect(_on_quest_updated)

	# Spawn NPCs if todos already loaded
	if not TodoManager.all_todos.is_empty():
		spawn_quest_givers()

func _on_todos_loaded():
	spawn_quest_givers()

func spawn_quest_givers():
	# Clear existing NPCs
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	spawned_npcs.clear()

	# Spawn one NPC per todo
	for todo in TodoManager.all_todos:
		spawn_quest_giver(todo)

	print("Spawned %d quest-giver NPCs" % spawned_npcs.size())

func spawn_quest_giver(todo: Dictionary):
	if not quest_giver_scene:
		print("Error: quest_giver_scene not set!")
		return

	# Instantiate NPC
	var npc = quest_giver_scene.instantiate()
	add_child(npc)

	# Get priority and calculate position
	var priority = todo.get("priority", "medium")
	var spawn_pos = get_scattered_position(priority)
	npc.global_position = spawn_pos

	# Setup quest data
	var quest_id = todo.get("id", "")
	npc.setup_quest(todo, quest_id)

	# Connect signals
	npc.interaction_triggered.connect(func(): _on_npc_interaction(npc, todo, quest_id))

	# Connect to UI for prompts
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		npc.player_entered_range.connect(func(): ui.show_quest_npc_prompt(npc))
		npc.player_exited_range.connect(func(): ui.hide_quest_npc_prompt())

	spawned_npcs.append(npc)

func get_scattered_position(priority: String) -> Vector3:
	# Get distance range based on priority
	var range_data = PRIORITY_RANGES.get(priority, PRIORITY_RANGES["medium"])
	var min_dist = range_data["min"]
	var max_dist = range_data["max"]

	# Random distance within range
	var distance = randf_range(min_dist, max_dist)

	# Random angle
	var angle = randf() * TAU

	# Calculate position (renamed to avoid shadowing)
	var pos_x = spawn_center.x + cos(angle) * distance
	var pos_z = spawn_center.z + sin(angle) * distance
	var pos_y = 0.0  # Ground level

	return Vector3(pos_x, pos_y, pos_z)

func _on_npc_interaction(npc: Node3D, todo: Dictionary, quest_id: String):
	# Get UI manager and show quest dialog
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		ui.show_quest_dialog(npc, todo, quest_id)

func _on_quest_updated(_quest_id: String):
	# Update all NPC visual states
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.update_visual_state()
