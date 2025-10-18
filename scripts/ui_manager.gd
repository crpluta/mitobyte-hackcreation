extends CanvasLayer

# UI References
@onready var interaction_prompt = $InteractionPrompt
@onready var input_dialog = $InputDialog
@onready var text_input = $InputDialog/Container/TextInput
@onready var submit_button = $InputDialog/Container/SubmitButton
@onready var confirmation_label = $InputDialog/Container/ConfirmationLabel

@onready var quest_dialog = $QuestDialog
@onready var quest_title = $QuestDialog/Container/QuestTitle
@onready var quest_info = $QuestDialog/Container/QuestInfo
@onready var quest_desc = $QuestDialog/Container/QuestDesc
@onready var quest_action_button = $QuestDialog/Container/ActionButton

# Current quest interaction
var current_quest_npc: Node3D = null
var current_quest_id: String = ""
var current_quest_data: Dictionary = {}

func _ready():
	print("UI Manager initialized")

	# Set UI to always process (even when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide_all()

	# Connect to Deckard Cain signals
	var deckard = get_tree().get_first_node_in_group("deckard_cain")
	if deckard:
		deckard.player_entered_range.connect(_on_deckard_entered_range)
		deckard.player_exited_range.connect(_on_deckard_exited_range)
		deckard.interaction_triggered.connect(_on_deckard_interaction)
		print("Connected to Deckard Cain signals")

	# Connect submit button
	submit_button.pressed.connect(_on_submit_pressed)
	quest_action_button.pressed.connect(_on_quest_action_pressed)

func hide_all():
	interaction_prompt.hide()
	input_dialog.hide()
	confirmation_label.hide()
	quest_dialog.hide()

func _on_deckard_entered_range():
	interaction_prompt.text = "Press E to talk to Deckard Cain"
	interaction_prompt.show()

func _on_deckard_exited_range():
	interaction_prompt.hide()
	input_dialog.hide()
	if input_dialog.visible:
		get_tree().paused = false

func show_quest_npc_prompt(npc: Node3D):
	var prompt = npc.get_interaction_prompt()
	if not prompt.is_empty():
		interaction_prompt.text = prompt
		interaction_prompt.show()

func hide_quest_npc_prompt():
	interaction_prompt.hide()

func _on_deckard_interaction():
	interaction_prompt.hide()
	show_input_dialog()

func show_input_dialog():
	input_dialog.show()
	confirmation_label.hide()
	text_input.text = ""
	text_input.grab_focus()

	# Pause the game
	get_tree().paused = true

func _on_submit_pressed():
	var user_text = text_input.text.strip_edges()

	if user_text.is_empty():
		confirmation_label.text = "Please enter what you need to get done!"
		confirmation_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirmation_label.show()
		return

	# Save to file for LLM team
	save_user_input(user_text)

	# Show confirmation
	confirmation_label.text = "Request sent! Quest-givers will appear soon..."
	confirmation_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	confirmation_label.show()

	# Clear input
	text_input.text = ""

	# Auto-close after 2 seconds (use process_always timer)
	await get_tree().create_timer(2.0, true, false, true).timeout
	input_dialog.hide()
	interaction_prompt.show()

	# Unpause the game
	get_tree().paused = false

func save_user_input(text: String):
	# Save to project directory so LLM team can access it
	var file_path = "res://user_input.txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
		print("Saved user input: ", text)
		print("File saved to: ", ProjectSettings.globalize_path(file_path))
	else:
		print("Failed to save user input!")

func _input(event):
	if input_dialog.visible and event.is_action_pressed("ui_cancel"):
		input_dialog.hide()
		interaction_prompt.show()
		get_tree().paused = false
	elif quest_dialog.visible and event.is_action_pressed("ui_cancel"):
		quest_dialog.hide()
		interaction_prompt.show()
		get_tree().paused = false

func is_dialog_open() -> bool:
	return input_dialog.visible or quest_dialog.visible

func show_quest_dialog(npc: Node3D, todo: Dictionary, quest_id: String):
	current_quest_npc = npc
	current_quest_data = todo
	current_quest_id = quest_id

	# Pause game
	get_tree().paused = true

	# Hide other UI
	interaction_prompt.hide()

	# Set quest info
	quest_title.text = todo.get("title", "Unknown Quest")

	var info_text = "Time: %d min | Priority: %s | XP: %d | Gold: %d" % [
		todo.get("estimated_time_minutes", 0),
		todo.get("priority", "medium"),
		todo.get("xp_reward", 0),
		todo.get("gold_reward", 0)
	]
	quest_info.text = info_text
	quest_desc.text = todo.get("description", "No description")

	# Set button based on quest status
	var status = npc.get_quest_status()
	match status:
		"available":
			quest_action_button.text = "Accept Quest"
			quest_action_button.disabled = false
		"in_progress":
			quest_action_button.text = "Quest In Progress..."
			quest_action_button.disabled = true
		"complete":
			quest_action_button.text = "Turn In Quest"
			quest_action_button.disabled = false

	quest_dialog.show()

func _on_quest_action_pressed():
	if current_quest_id.is_empty():
		return

	var status = current_quest_npc.get_quest_status()

	match status:
		"available":
			# Accept the quest
			TodoManager.accept_quest(current_quest_id)
			quest_dialog.hide()
			get_tree().paused = false
			print("Quest accepted: ", current_quest_data.get("title", ""))
		"complete":
			# Turn in the quest
			TodoManager.complete_quest(current_quest_id)
			quest_dialog.hide()
			get_tree().paused = false
			print("Quest completed: ", current_quest_data.get("title", ""))
