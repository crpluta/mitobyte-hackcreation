# Build Instructions - Todo Quest

## Prerequisites

### 1. Install Godot Export Templates

If you haven't already, install the export templates for Godot 4.4.1:

1. Open Godot Editor
2. Go to **Editor** → **Manage Export Templates**
3. Click **Download and Install**
4. Wait for the download to complete

Alternatively, download manually:
- Visit: https://godotengine.org/download/
- Download "Export Templates" for version 4.4.1
- Install them via Editor → Manage Export Templates → Install from File

## Building for Windows

### Option 1: Using Godot Editor (Recommended)

1. **Open the project** in Godot Editor
2. Go to **Project** → **Export**
3. You should see "Windows Desktop" preset already configured
4. Click on **Windows Desktop** to select it
5. Click **Export Project** at the bottom
6. Choose export location (default: `builds/windows/TodoQuest.exe`)
7. Click **Save**

### Option 2: Using Command Line

```bash
# From the project directory
godot --headless --export-release "Windows Desktop" "./builds/windows/TodoQuest.exe"
```

## What Gets Exported

The export includes:
- `TodoQuest.exe` - Main executable
- `TodoQuest.pck` - Game data (separate file if `embed_pck=false`)
- All resources, scenes, scripts, and assets

## Post-Export Setup

After exporting, the build directory structure will be:

```
builds/windows/
├── TodoQuest.exe
└── TodoQuest.pck (if not embedded)
```

### First Run Behavior

When a user runs `TodoQuest.exe` for the first time:
1. The game creates these files **next to the executable**:
   - `game_config.json` (copied from packed resources)
   - `api/generate_quests.py` (copied from packed resources)

Final structure after first run:
```
builds/windows/
├── TodoQuest.exe
├── TodoQuest.pck
├── game_config.json          ← Editable by users
└── api/
    └── generate_quests.py    ← Editable by LLM team
```

## Distribution

### Minimum Distribution Package

To distribute the game, zip up:
```
TodoQuest.exe
TodoQuest.pck (if separate)
README.txt (optional - include Python/Ollama setup instructions)
```

The game will create `game_config.json` and `api/` on first run.

### Pre-configured Distribution Package

For a better user experience, include pre-configured files:
```
TodoQuest.exe
TodoQuest.pck (if separate)
game_config.json          ← Your custom configuration
api/
  └── generate_quests.py  ← Your customized script
README.txt
```

## User Requirements

Users need:
1. **Windows 10/11** (64-bit)
2. **Python 3.7+** (for quest generation)
   - Download: https://www.python.org/downloads/
3. **Ollama** (for LLM quest generation)
   - Download: https://ollama.ai/
   - Run: `ollama serve` in terminal
   - Pull model: `ollama pull llama3.2:1b`

## Testing the Build

After exporting:

1. Navigate to `builds/windows/`
2. Run `TodoQuest.exe`
3. Check console output (press F12 or run from command line to see console)
4. Verify external files are created:
   - `game_config.json` should appear
   - `api/generate_quests.py` should appear
5. Test quest generation:
   - Talk to Deckard Cain
   - Enter a task (e.g., "Write documentation")
   - Verify quest NPC spawns

## Troubleshooting

### "Export templates not found"
- Install export templates via Editor → Manage Export Templates

### Build fails with errors
- Check console output in Godot
- Ensure all scripts are error-free
- Check export filters in Project → Export

### External files not created on first run
- Check file permissions in build directory
- Run from a writable location (not Program Files)
- Check console output for errors

### Python script errors in deployed build
- Ensure Python is in system PATH
- Test script manually: `python api/generate_quests.py --input test.txt`
- Check that Ollama is running: `ollama serve`

## Quick Build Script

Create a `build.bat` file for quick rebuilds:

```batch
@echo off
echo Building Todo Quest for Windows...
godot --headless --export-release "Windows Desktop" "./builds/windows/TodoQuest.exe"
echo Build complete!
pause
```

Or `build.sh` for Git Bash/WSL:

```bash
#!/bin/bash
echo "Building Todo Quest for Windows..."
godot --headless --export-release "Windows Desktop" "./builds/windows/TodoQuest.exe"
echo "Build complete!"
```

## Hackathon Distribution

For your hackathon team workflow:

1. **Export the build** using steps above
2. **Run it once** to generate external files
3. **Share the entire `builds/windows/` folder** with your team
4. LLM team can edit `api/generate_quests.py` directly
5. You can continue developing while they test with the build

## Notes

- The `.pck` file contains all game resources
- External files (`.json`, `.py`) are NOT in the `.pck` - they're created at runtime
- Console wrapper is enabled (`export_console_wrapper=1`) for easier debugging
- Build is 64-bit only (`x86_64`)
