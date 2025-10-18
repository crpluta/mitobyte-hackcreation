extends CanvasLayer

# UI References
@onready var interaction_prompt = $InteractionPrompt
@onready var input_dialog = $InputDialog
@onready var text_input = $InputDialog/Container/TextInput
@onready var submit_button = $InputDialog/Container/SubmitButton
@onready var confirmation_label = $InputDialog/Container/ConfirmationLabel
@onready var loading_label = $InputDialog/Container/LoadingLabel

@onready var quest_dialog = $QuestDialog
@onready var quest_title = $QuestDialog/Container/QuestTitle
@onready var quest_info = $QuestDialog/Container/QuestInfo
@onready var quest_desc = $QuestDialog/Container/QuestDesc
@onready var quest_action_button = $QuestDialog/Container/ActionButton

@onready var quest_log = $QuestLog
@onready var quest_list_container = $QuestLog/Container/ScrollContainer/QuestList

@onready var toast_notification = $ToastNotification
@onready var toast_quest_title = $ToastNotification/Container/QuestTitle
@onready var toast_rewards = $ToastNotification/Container/Rewards
@onready var toast_dismiss_button = $ToastNotification/Container/DismissButton

@onready var levelup_panel = $LevelUpPanel
@onready var levelup_level_info = $LevelUpPanel/Container/LevelInfo
@onready var levelup_quest_title = $LevelUpPanel/Container/QuestTitle
@onready var levelup_rewards = $LevelUpPanel/Container/Rewards
@onready var levelup_dismiss_button = $LevelUpPanel/Container/DismissButton

@onready var active_quests_hud = $ActiveQuestsHUD
@onready var active_quests_list = $ActiveQuestsHUD/Container/ScrollContainer/QuestsList

@onready var shop_dialog = $ShopDialog
@onready var shop_gold_display = $ShopDialog/Container/GoldDisplay
@onready var shop_items_list = $ShopDialog/Container/ScrollContainer/ItemsList

@onready var portrait_camera = $PlayerPortrait/Container/PortraitFrame/SubViewport/PortraitCamera
@onready var level_label = $PlayerPortrait/Container/LevelLabel
@onready var gold_label = $PlayerPortrait/Container/GoldLabel
@onready var xp_progress = $XPBar/ProgressBar
@onready var xp_label = $XPBar/XPLabel

# Current quest interaction
var current_quest_npc: Node3D = null
var current_quest_id: String = ""
var current_quest_data: Dictionary = {}

# Track which NPC opened the dialog (for quest_type)
var current_input_quest_type: String = "one_time"  # default

# LLM processing
var llm_quest_type: String = ""
var llm_thread: Thread = null
var llm_result: Dictionary = {}

# Player reference for portrait camera
var player: Node3D = null

func _ready():
	print("UI Manager initialized")

	# Set UI to always process (even when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide_all()

	# Connect to Deckard Cain signals (one-time quests)
	var deckard = get_tree().get_first_node_in_group("deckard_cain")
	if deckard:
		deckard.player_entered_range.connect(func(): _on_npc_entered_range("Deckard Cain"))
		deckard.player_exited_range.connect(_on_npc_exited_range)
		deckard.interaction_triggered.connect(func(): _on_npc_interaction("one_time"))
		print("Connected to Deckard Cain signals")

	# Connect to Shop Keeper signals
	var shop = get_tree().get_first_node_in_group("shop_keeper")
	if shop:
		shop.player_entered_range.connect(func(): _on_npc_entered_range("Shop Keeper"))
		shop.player_exited_range.connect(_on_npc_exited_range)
		shop.interaction_triggered.connect(_on_shop_interaction)
		print("Connected to Shop Keeper signals")

	# Connect submit button
	submit_button.pressed.connect(_on_submit_pressed)
	quest_action_button.pressed.connect(_on_quest_action_pressed)

	# Connect notification dismiss buttons
	toast_dismiss_button.pressed.connect(_on_toast_dismiss)
	levelup_dismiss_button.pressed.connect(_on_levelup_dismiss)

	# Connect to TodoManager for active quests HUD
	TodoManager.quest_accepted.connect(_update_active_quests_hud)
	TodoManager.task_completed.connect(func(_qid, _tid): _update_active_quests_hud(""))
	TodoManager.quest_completed.connect(_update_active_quests_hud)

	# Initial population
	_update_active_quests_hud("")

	# Get player reference - find the local player
	_find_local_player()

	# Connect to quest completion for stat updates
	TodoManager.quest_completed.connect(func(_qid): _update_player_stats())

	# Initial stats update
	_update_player_stats()

func _find_local_player():
	"""Find the local player (the one controlled by this client)"""
	# In solo mode, just get the first player
	var players = get_tree().get_nodes_in_group("player")

	if players.is_empty():
		player = null
		return

	# In multiplayer, find the player we have authority over
	for p in players:
		if p.is_multiplayer_authority():
			player = p
			print("Found local player for portrait: ", p.name)
			return

	# Fallback to first player (solo mode)
	player = players[0]

func _process(_delta):
	# Re-find player if we lost the reference (can happen in multiplayer)
	if not is_instance_valid(player):
		_find_local_player()

	# Update portrait camera to follow local player only
	if player and portrait_camera:
		# Position camera in front of player, slightly above
		portrait_camera.global_position = player.global_position + Vector3(0, 1.5, 2.5)
		# Look at player's head area
		portrait_camera.look_at(player.global_position + Vector3(0, 1.3, 0), Vector3.UP)

func hide_all():
	interaction_prompt.hide()
	input_dialog.hide()
	confirmation_label.hide()
	loading_label.hide()
	quest_dialog.hide()
	quest_log.hide()
	shop_dialog.hide()
	toast_notification.hide()
	levelup_panel.hide()

func _on_npc_entered_range(npc_name: String):
	interaction_prompt.text = "Press E to talk to %s" % npc_name
	interaction_prompt.show()

func _on_npc_exited_range():
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

func _on_npc_interaction(quest_type: String):
	current_input_quest_type = quest_type
	interaction_prompt.hide()
	show_input_dialog()

func show_input_dialog():
	input_dialog.show()
	confirmation_label.hide()
	loading_label.hide()
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

	# Show loading message
	confirmation_label.hide()
	loading_label.text = "Generating quest... (this may take a moment)"
	loading_label.show()
	submit_button.disabled = true
	text_input.text = ""

	# Wait a frame to show loading message before blocking
	await get_tree().process_frame

	# Save to file and call LLM (this WILL freeze briefly!)
	save_user_input(user_text)

	# Hide loading and close dialog
	loading_label.hide()
	input_dialog.hide()
	interaction_prompt.show()
	submit_button.disabled = false
	get_tree().paused = false

func save_user_input(text: String):
	# Save to appropriate file based on quest type
	var file_path = "res://user_input_onetime.txt" if current_input_quest_type == "one_time" else "res://user_input_daily.txt"

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
		print("Saved user input (%s): %s" % [current_input_quest_type, text])

		# Call Python script to generate quests
		call_llm_script(file_path, current_input_quest_type)
	else:
		print("Failed to save user input!")

func call_llm_script(input_file: String, quest_type: String):
	"""Call the LLM Python script in a thread (non-blocking)"""
	llm_quest_type = quest_type

	var abs_input_path = ProjectSettings.globalize_path(input_file)
	# Use external Python script path for deployment
	var script_path = DeploymentManager.get_python_script_path()

	# Prepare thread data
	llm_result = {"success": false, "json": "", "error": ""}
	llm_thread = Thread.new()

	var thread_data = {
		"script_path": script_path,
		"input_path": abs_input_path
	}

	print("Starting LLM thread...")
	llm_thread.start(_run_llm_in_thread.bind(thread_data))

	# Poll for completion
	_check_llm_thread()

func _run_llm_in_thread(data: Dictionary):
	"""Thread function - runs Python script"""
	print("Calling LLM script: ", data.script_path)
	print("Input file: ", data.input_path)

	var output = []
	# OS.execute params: path, args, output, read_stderr, open_console
	# Set open_console to false to hide the Python console window
	var exit_code = OS.execute("python", [data.script_path, "--input", data.input_path], output, true, false)

	if exit_code != 0:
		print("ERROR: Python script failed with exit code: ", exit_code)
		# Capture error message from output (stderr)
		var error_msg = "Quest generation failed"
		if not output.is_empty():
			var error_output = output[0] if output.size() > 0 else ""
			print("Python error: ", error_output)
			# Extract useful error message
			if "Needs clarification" in error_output or "clarify" in error_output:
				error_msg = "Tasks unclear! Please be more specific."
			elif "no tasks" in error_output.to_lower():
				error_msg = "No valid tasks found. Please describe what you need to do!"
		llm_result.error = error_msg
		llm_result.success = false
		return

	if output.is_empty():
		print("ERROR: No output from Python script")
		llm_result.error = "No quest generated"
		llm_result.success = false
		return

	var json_output = output[0]
	print("Received JSON from LLM script (length: %d)" % json_output.length())

	llm_result.json = json_output
	llm_result.success = true

func _check_llm_thread():
	"""Check if thread completed (non-blocking poll)"""
	if llm_thread and llm_thread.is_alive():
		# Still running, check again
		await get_tree().create_timer(0.1, true, false, true).timeout
		_check_llm_thread()
	elif llm_thread:
		# Thread finished
		llm_thread.wait_to_finish()
		llm_thread = null

		if llm_result.success:
			# Import on main thread
			var success = TodoManager.import_quests_from_json(llm_result.json, llm_quest_type)
			if success:
				print("Successfully imported quests!")
			else:
				print("Failed to import quests")
				_show_error_toast("Failed to parse quest. Please try simpler text!")
		else:
			print("LLM generation failed: ", llm_result.error)
			_show_error_toast(llm_result.error)

func _input(event):
	if input_dialog.visible and event.is_action_pressed("ui_cancel"):
		input_dialog.hide()
		interaction_prompt.show()
		get_tree().paused = false
	elif quest_dialog.visible and event.is_action_pressed("ui_cancel"):
		quest_dialog.hide()
		interaction_prompt.show()
		get_tree().paused = false
	elif shop_dialog.visible and event.is_action_pressed("ui_cancel"):
		shop_dialog.hide()
		interaction_prompt.show()
		get_tree().paused = false
	elif quest_log.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("quest_log")):
		quest_log.hide()
		get_tree().paused = false
	elif event.is_action_pressed("quest_log") and not is_dialog_open():
		toggle_quest_log()

func is_dialog_open() -> bool:
	return input_dialog.visible or quest_dialog.visible or quest_log.visible or shop_dialog.visible

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

	var rewards = todo.get("rewards", {})
	var info_text = "Time: %d min | Difficulty: %s | Priority: %s | XP: %d | Coins: %d" % [
		todo.get("estimated_time_minutes", 0),
		todo.get("difficulty", "medium"),
		todo.get("priority", "medium"),
		rewards.get("xp", 0),
		rewards.get("coins", 0)
	]
	quest_info.text = info_text

	# Build description with tasks
	var desc_text = todo.get("description", "No description")
	desc_text += "\n\n[b]Tasks:[/b]"

	var tasks = todo.get("tasks", [])
	var completed_tasks = TodoManager.get_completed_tasks_for_quest(quest_id)

	for task in tasks:
		var task_id = task.get("id", "")
		var task_text = task.get("text", "")
		var is_complete = task_id in completed_tasks

		if is_complete:
			desc_text += "\n[color=green][✓][/color] " + task_text
		else:
			desc_text += "\n[ ] " + task_text

	quest_desc.text = desc_text

	# Set button based on quest status
	var status = npc.get_quest_status()
	match status:
		"available":
			quest_action_button.text = "Accept Quest"
			quest_action_button.disabled = false
		"in_progress":
			quest_action_button.text = "Open Quest Log (Q)"
			quest_action_button.disabled = true
		"complete":
			quest_action_button.text = "Turn In Quest"
			quest_action_button.disabled = false
		"locked":
			var holder = TodoManager.get_quest_lock_holder(quest_id)
			quest_action_button.text = "Taken by %s" % holder
			quest_action_button.disabled = true
		"turned_in":
			quest_action_button.text = "Already Completed"
			quest_action_button.disabled = true

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
			# Turn in the quest - capture level before completion
			var old_level = TodoManager.player_level
			var rewards = current_quest_data.get("rewards", {})
			var xp = rewards.get("xp", 0)
			var coins = rewards.get("coins", 0)
			var quest_title = current_quest_data.get("title", "Unknown Quest")

			TodoManager.complete_quest(current_quest_id)
			quest_dialog.hide()
			get_tree().paused = false  # Unpause immediately

			# Check if leveled up
			var new_level = TodoManager.player_level
			if new_level > old_level:
				show_levelup_notification(quest_title, old_level, new_level, xp, coins)
			else:
				show_toast_notification(quest_title, xp, coins)

			print("Quest completed: ", quest_title)

func toggle_quest_log():
	if quest_log.visible:
		quest_log.hide()
		get_tree().paused = false
	else:
		populate_quest_log()
		quest_log.show()
		get_tree().paused = true

func populate_quest_log():
	# Clear existing quest items
	for child in quest_list_container.get_children():
		child.queue_free()

	var accepted_quests = TodoManager.get_accepted_quests()

	if accepted_quests.is_empty():
		var label = Label.new()
		label.text = "No active quests. Talk to quest-giver NPCs to accept quests!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quest_list_container.add_child(label)
		return

	# Add each quest with its tasks
	for quest in accepted_quests:
		var quest_id = quest.get("id", "")
		var quest_title_text = quest.get("title", "Unknown Quest")
		var tasks = quest.get("tasks", [])
		var rewards = quest.get("rewards", {})

		# Quest header
		var quest_panel = PanelContainer.new()
		var quest_vbox = VBoxContainer.new()
		quest_panel.add_child(quest_vbox)

		# Title
		var title_label = RichTextLabel.new()
		title_label.bbcode_enabled = true
		title_label.text = "[b]%s[/b]" % quest_title_text
		title_label.add_theme_font_size_override("normal_font_size", 20)
		title_label.fit_content = true
		title_label.scroll_active = false
		quest_vbox.add_child(title_label)

		# Info line
		var info_label = Label.new()
		info_label.text = "XP: %d | Coins: %d" % [rewards.get("xp", 0), rewards.get("coins", 0)]
		info_label.add_theme_font_size_override("font_size", 14)
		quest_vbox.add_child(info_label)

		# Description
		var desc_label = RichTextLabel.new()
		desc_label.bbcode_enabled = true
		desc_label.text = "[i]%s[/i]" % quest.get("description", "")
		desc_label.add_theme_font_size_override("normal_font_size", 13)
		desc_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
		desc_label.fit_content = true
		desc_label.scroll_active = false
		quest_vbox.add_child(desc_label)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		quest_vbox.add_child(spacer)

		# Tasks with checkboxes
		for task in tasks:
			var task_id = task.get("id", "")
			var task_text = task.get("text", "")
			var is_completed = TodoManager.is_task_completed(quest_id, task_id)

			var task_hbox = HBoxContainer.new()

			# Checkbox
			var checkbox = CheckBox.new()
			checkbox.button_pressed = is_completed
			checkbox.toggled.connect(func(checked): _on_task_checkbox_toggled(quest_id, task_id, checked))
			task_hbox.add_child(checkbox)

			# Task text
			var task_label = Label.new()
			task_label.text = task_text
			task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			task_hbox.add_child(task_label)

			quest_vbox.add_child(task_hbox)

		quest_list_container.add_child(quest_panel)

		# Separator
		var separator = Control.new()
		separator.custom_minimum_size = Vector2(0, 15)
		quest_list_container.add_child(separator)

func _on_task_checkbox_toggled(quest_id: String, task_id: String, checked: bool):
	TodoManager.toggle_task(quest_id, task_id)
	# Refresh the quest log to show updated state
	populate_quest_log()

func show_toast_notification(quest_name: String, xp: int, coins: int):
	"""Show small toast notification for normal quest completion"""
	toast_quest_title.text = quest_name
	toast_rewards.text = "+%d XP  +%d Gold" % [xp, coins]

	# Show with fade-in animation (non-blocking)
	toast_notification.modulate.a = 0.0
	toast_notification.show()

	var tween = create_tween()
	tween.tween_property(toast_notification, "modulate:a", 1.0, 0.3)

	# Auto-dismiss after 3 seconds
	_auto_dismiss_toast()

func show_levelup_notification(quest_name: String, old_level: int, new_level: int, xp: int, coins: int):
	"""Show dramatic level-up panel"""
	levelup_level_info.text = "Level %d → %d" % [old_level, new_level]
	levelup_quest_title.text = "Quest: \"%s\"" % quest_name
	levelup_rewards.text = "+%d XP    +%d Gold" % [xp, coins]

	# Show with scale animation (non-blocking)
	levelup_panel.scale = Vector2(0.8, 0.8)
	levelup_panel.modulate.a = 0.0
	levelup_panel.show()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(levelup_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(levelup_panel, "modulate:a", 1.0, 0.3)

func _auto_dismiss_toast():
	"""Auto-dismiss toast after delay"""
	await get_tree().create_timer(3.0, true, false, true).timeout
	if toast_notification.visible:  # Only dismiss if still visible
		_on_toast_dismiss()

func _on_toast_dismiss():
	"""Dismiss toast notification"""
	var tween = create_tween()
	tween.tween_property(toast_notification, "modulate:a", 0.0, 0.2)
	tween.tween_callback(toast_notification.hide)

func _on_levelup_dismiss():
	"""Dismiss level-up notification"""
	var tween = create_tween()
	tween.tween_property(levelup_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(levelup_panel.hide)

func _show_error_toast(message: String):
	"""Show error message in toast notification"""
	toast_quest_title.text = "Error"
	toast_rewards.text = message
	toast_rewards.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red for errors

	# Show with fade-in
	toast_notification.modulate.a = 0.0
	toast_notification.show()

	var tween = create_tween()
	tween.tween_property(toast_notification, "modulate:a", 1.0, 0.3)

	# Auto-dismiss after 4 seconds (longer for errors)
	await get_tree().create_timer(4.0, true, false, true).timeout
	if toast_notification.visible:
		_on_toast_dismiss()

	# Reset color for next use
	toast_rewards.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

func _update_active_quests_hud(_quest_id: String):
	"""Update the active quests HUD with current accepted quests"""
	# Clear existing content
	for child in active_quests_list.get_children():
		child.queue_free()

	var accepted_quests = TodoManager.get_accepted_quests()

	if accepted_quests.is_empty():
		# Show "No active quests" message
		var empty_label = Label.new()
		empty_label.text = "No active quests"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		active_quests_list.add_child(empty_label)
		return

	# Add each active quest
	for quest in accepted_quests:
		var quest_id = quest.get("id", "")
		var quest_title = quest.get("title", "Unknown Quest")
		var tasks = quest.get("tasks", [])

		# Quest title with frequency indicator
		var quest_type = TodoManager.get_quest_type(quest_id)
		var frequency_badge = ""
		var title_color = Color(1.0, 1.0, 1.0)

		match quest_type:
			"daily":
				frequency_badge = "[D] "
				title_color = Color(0.4, 0.7, 1.0)  # Blue
			"weekly":
				frequency_badge = "[W] "
				title_color = Color(1.0, 0.8, 0.2)  # Gold
			_:  # one_time
				frequency_badge = ""
				title_color = Color(0.3, 1.0, 0.3)  # Green

		var title_label = RichTextLabel.new()
		title_label.bbcode_enabled = true
		title_label.text = "[b]%s%s[/b]" % [frequency_badge, quest_title]
		title_label.add_theme_font_size_override("normal_font_size", 16)
		title_label.add_theme_color_override("default_color", title_color)
		title_label.fit_content = true
		title_label.scroll_active = false

		active_quests_list.add_child(title_label)

		# Tasks
		for task in tasks:
			var task_id = task.get("id", "")
			var task_text = task.get("text", "")
			var is_completed = TodoManager.is_task_completed(quest_id, task_id)

			var task_label = RichTextLabel.new()
			task_label.bbcode_enabled = true
			task_label.fit_content = true
			task_label.scroll_active = false

			if is_completed:
				# Strikethrough for completed tasks
				task_label.text = "[s][color=gray]• %s[/color][/s]" % task_text
			else:
				# Normal for incomplete tasks
				task_label.text = "• %s" % task_text

			task_label.add_theme_font_size_override("normal_font_size", 14)
			active_quests_list.add_child(task_label)

		# Spacer between quests
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		active_quests_list.add_child(spacer)

func _update_player_stats():
	"""Update player stats display (level, gold, XP bar)"""
	var stats = TodoManager.get_player_stats()

	# Update level
	level_label.text = "Level %d" % stats.level

	# Update gold
	gold_label.text = "%d Gold" % stats.gold

	# Update XP bar (use config value for XP per level)
	var xp_per_level = TodoManager.get_xp_per_level()
	var current_xp = stats.xp % xp_per_level  # XP within current level
	xp_progress.max_value = xp_per_level
	xp_progress.value = current_xp
	xp_label.text = "%d / %d XP" % [current_xp, xp_per_level]

func _on_shop_interaction():
	"""Open shop dialog"""
	interaction_prompt.hide()
	populate_shop()
	shop_dialog.show()
	get_tree().paused = true

func populate_shop():
	"""Populate shop with purchasable items"""
	# Clear existing items
	for child in shop_items_list.get_children():
		child.queue_free()

	# Update gold display
	shop_gold_display.text = "Your Gold: %d" % TodoManager.player_gold

	# Get shop items from config
	var items = TodoManager.get_shop_items()

	# Create item panels
	for item in items:
		var item_panel = PanelContainer.new()
		var item_hbox = HBoxContainer.new()
		item_panel.add_child(item_hbox)

		# Item info (left side)
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_hbox.add_child(info_vbox)

		# Item name
		var name_label = RichTextLabel.new()
		name_label.bbcode_enabled = true
		name_label.text = "[b]%s[/b]" % item.name
		name_label.add_theme_font_size_override("normal_font_size", 18)
		name_label.fit_content = true
		name_label.scroll_active = false
		info_vbox.add_child(name_label)

		# Description
		var desc_label = Label.new()
		desc_label.text = item.description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(desc_label)

		# Price and button (right side)
		var button_vbox = VBoxContainer.new()
		item_hbox.add_child(button_vbox)

		var price_label = Label.new()
		price_label.text = "%d Gold" % item.price
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_vbox.add_child(price_label)

		var buy_button = Button.new()
		buy_button.text = "Buy"
		buy_button.disabled = TodoManager.player_gold < item.price
		buy_button.pressed.connect(func(): _purchase_item(item))
		button_vbox.add_child(buy_button)

		shop_items_list.add_child(item_panel)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		shop_items_list.add_child(spacer)

func _purchase_item(item: Dictionary):
	"""Purchase and equip a cosmetic item"""
	var price = item.price
	var cosmetic_name = item.cosmetic

	# Check if player has enough gold
	if TodoManager.player_gold < price:
		print("Not enough gold!")
		return

	# Deduct gold
	TodoManager.player_gold -= price
	print("Purchased %s for %d gold" % [item.name, price])

	# Equip cosmetic via RPC (syncs to all clients)
	if player:
		player.equip_cosmetic.rpc(cosmetic_name)
		print("Equipped: ", item.name)

	# Update shop display
	populate_shop()
	_update_player_stats()
