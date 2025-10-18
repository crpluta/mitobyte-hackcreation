extends Control

@onready var start_button = $VBoxContainer/StartButton

func _ready():
	print("Title Screen loaded")
	start_button.pressed.connect(_on_start_button_pressed)

	# Reset game state on title screen
	if TodoManager:
		TodoManager.reset_game_state()

func _on_start_button_pressed():
	print("Starting game...")
	# Load main game scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")
