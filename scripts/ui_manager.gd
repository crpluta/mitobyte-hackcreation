extends CanvasLayer

# UI References
@onready var interaction_prompt = $InteractionPrompt
@onready var input_dialog = $InputDialog
@onready var text_input = $InputDialog/Container/TextInput
@onready var submit_button = $InputDialog/Container/SubmitButton
@onready var confirmation_label = $InputDialog/Container/ConfirmationLabel

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

func hide_all():
	interaction_prompt.hide()
	input_dialog.hide()
	confirmation_label.hide()

func _on_deckard_entered_range():
	interaction_prompt.text = "Press E to talk to Deckard Cain"
	interaction_prompt.show()

func _on_deckard_exited_range():
	interaction_prompt.hide()
	input_dialog.hide()
	if input_dialog.visible:
		get_tree().paused = false

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

func is_dialog_open() -> bool:
	return input_dialog.visible
