# Deployment Guide - Todo Quest

## Overview
This game is designed to be deployed with editable configuration files that sit **outside the executable**. This allows your team to modify game settings and the LLM quest generation system without recompiling.

## External Files Location

When you export and run the game, it will automatically create these files **next to the executable**:

```
TodoQuest.exe          (or TodoQuest.x86_64 on Linux, TodoQuest.app on Mac)
game_config.json       <- Editable game configuration
api/
  └── generate_quests.py  <- Editable Python script for quest generation
```

## First Run Behavior

On the **first run**, the game will:
1. Create an `api/` directory next to the executable
2. Copy `game_config.json` from the packed resources to the external location
3. Copy `generate_quests.py` from the packed resources to `api/generate_quests.py`

On **subsequent runs**, the game will:
- Load configuration from the external `game_config.json`
- Use the external `api/generate_quests.py` for quest generation
- **Never overwrite** these files (preserving your edits)

## Editing Configuration

### game_config.json
This file controls:
- XP required per level
- Reward amounts per difficulty (XP and coins)
- Shop items and prices
- Estimated time per difficulty level

**Example:**
```json
{
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
    "items": [
      {
        "name": "Cool Hat",
        "description": "A stylish hat",
        "price": 100,
        "cosmetic": "Hat"
      }
    ]
  }
}
```

### api/generate_quests.py
This Python script handles quest generation from user input. Your LLM team can modify:
- Prompt templates
- Quest difficulty detection
- Task splitting logic
- Title/description generation
- Ollama model selection

**Requirements:**
- Python 3.x must be installed on the user's machine
- Ollama must be running locally (default: `http://localhost:11434`)

## Export Settings (Godot)

When exporting from Godot:

1. **File -> Export**
2. Select your platform (Windows, Linux, Mac)
3. **Ensure these files are included**:
   - `game_config.json`
   - `api/generate_quests.py`

The game will automatically copy them to external locations on first run.

## Distribution

When distributing to users, you can either:

### Option A: Bare Executable
- Just ship the `.exe` (or platform equivalent)
- The game will create default files on first run

### Option B: Pre-configured Package
- Ship the executable + pre-configured `game_config.json` and `api/` folder
- Users get your custom configuration immediately
- Users can still edit these files after

## Team Workflow

For your hackathon setup:

1. **Game Developer (You)**:
   - Export the game executable
   - Share the build folder with your team

2. **LLM Team**:
   - Run the game once to generate default files
   - Edit `api/generate_quests.py` to tweak quest generation
   - Edit `game_config.json` to balance rewards/difficulty
   - Test changes by running the game again (no recompile needed!)

## Troubleshooting

### "Python script not found" error
- Ensure Python is installed: `python --version`
- Check that `api/generate_quests.py` exists next to the executable

### "Ollama connection failed" error
- Ensure Ollama is running: Open a terminal and run `ollama serve`
- Check that the model is installed: `ollama pull llama3.2:1b`

### Config changes not taking effect
- The game loads config on startup
- Restart the game to see configuration changes
- Check console output for "Loading game config from: [path]"

### Files not being created
- Check file permissions in the executable directory
- On Linux/Mac, ensure the directory is writable
- Try running from a user directory (not `/usr/bin`, etc.)

## Development vs. Deployed Builds

The `DeploymentManager` detects the environment:

- **In Godot Editor**: Uses `res://` (project directory)
- **Exported Build**: Uses executable directory

This means you can develop and test using the project files, and the system automatically switches to external files when deployed.

## Python Dependencies

The `generate_quests.py` script has minimal dependencies:
- Standard library only (no pip packages required)
- Uses urllib for HTTP requests to Ollama
- Compatible with Python 3.7+

## Notes for Hackathon

- This setup allows **parallel work**: You can keep building the game while the LLM team tweaks quest generation
- Changes to `game_config.json` and `generate_quests.py` don't require rebuilding the game
- Perfect for rapid iteration during a time-limited hackathon!
