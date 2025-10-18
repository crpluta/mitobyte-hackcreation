extends Node

# Deployment Manager - handles external file management for deployed builds
# This ensures game_config.json and Python scripts are editable outside the exe

const CONFIG_FILE = "game_config.json"
const PYTHON_SCRIPT_DIR = "api"
const PYTHON_SCRIPT = "generate_quests.py"

# Returns the directory where external files should be stored
# For deployed builds, this is next to the executable
# For development, this is the project directory
func get_external_dir() -> String:
	if OS.has_feature("editor"):
		# Running in editor - use project directory
		return ProjectSettings.globalize_path("res://")
	else:
		# Running as exported build - use executable directory
		return OS.get_executable_path().get_base_dir()

# Get path to external config file
func get_config_path() -> String:
	return get_external_dir().path_join(CONFIG_FILE)

# Get path to external Python script
func get_python_script_path() -> String:
	return get_external_dir().path_join(PYTHON_SCRIPT_DIR).path_join(PYTHON_SCRIPT)

# Get path to Python API directory
func get_python_api_dir() -> String:
	return get_external_dir().path_join(PYTHON_SCRIPT_DIR)

# Initialize external files on first run
func initialize_external_files():
	print("Initializing external files...")

	var external_dir = get_external_dir()
	print("External directory: ", external_dir)

	# Ensure api directory exists
	var api_dir = get_python_api_dir()
	if not DirAccess.dir_exists_absolute(api_dir):
		DirAccess.make_dir_recursive_absolute(api_dir)
		print("Created API directory: ", api_dir)

	# Copy game_config.json if it doesn't exist
	var config_path = get_config_path()
	if not FileAccess.file_exists(config_path):
		print("Copying default game_config.json to: ", config_path)
		_copy_file("res://game_config.json", config_path)

	# Copy Python script if it doesn't exist
	var python_path = get_python_script_path()
	if not FileAccess.file_exists(python_path):
		print("Copying Python script to: ", python_path)
		_copy_file("res://api/generate_quests.py", python_path)

func _copy_file(source_path: String, dest_path: String) -> bool:
	var source = FileAccess.open(source_path, FileAccess.READ)
	if not source:
		print("ERROR: Failed to open source file: ", source_path)
		return false

	var content = source.get_buffer(source.get_length())
	source.close()

	var dest = FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest:
		print("ERROR: Failed to open destination file: ", dest_path)
		return false

	dest.store_buffer(content)
	dest.close()

	print("Successfully copied: ", source_path, " -> ", dest_path)
	return true
