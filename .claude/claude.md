# Diablo-like Todo Tracker - Hackathon Project

## Project Context
This is a **5-hour hackathon project** building a 3D gamified todo tracker in Godot 4.x. The user is relying heavily on Claude Code to drive development while they focus on reviewing and approving phases.

## Critical Constraints
- **Time**: 5 hours total
- **No custom assets**: Use Godot primitives only (MeshInstance3D with box, sphere, capsule)
- **No audio**: Skip all sound effects and music
- **Team split**: Other team handles LLM/JSON generation in same repo
- **Keep it simple**: MVP over polish - make it work, not perfect

## Technology Stack
- **Engine**: Godot 4.4.1 (installed and verified)
- **Language**: GDScript exclusively
- **3D**: Node3D scenes with basic shapes and materials
- **Data**: JSON file parsing for todos

## Development Philosophy
1. **User drives phases**: Complete each phase, then use `/phase-review` to get approval before continuing
2. **Aggressive scope management**: If a feature takes >20 minutes, simplify it
3. **Working > Beautiful**: Functional game loop is more important than visual polish
4. **Fast iteration**: Use simple shapes with different colors to distinguish NPCs/objects

## Key Game Systems

### 1. NPC Interaction
- Proximity-based (player walks near NPC)
- Simple UI overlay for dialog
- Mouse clicks for interaction
- Deckard Cain = quest giver/todo manager

### 2. Todo Management
- Load from `todos.json` (or similar file from other team)
- Display in-game UI
- Track completion status
- Support subtasks from LLM processing

### 3. Worker NPCs
- Multiple instances in scene
- Assignable to specific todos
- Visual states: Idle (gray), Working (yellow), Complete (green)
- Simple timer-based completion

### 4. Reward System
- XP and Gold from completed todos
- Player level-up system
- Shop NPC to spend rewards
- Persistent save data

## JSON Structure
Reference `sample-todos.json` for structure:
```json
{
  "todos": [
    {
      "id": "unique_id",
      "title": "Task name",
      "description": "Details",
      "difficulty": "easy|medium|hard",
      "estimated_time_minutes": 60,
      "xp_reward": 100,
      "gold_reward": 50,
      "subtasks": [...],
      "completed": false
    }
  ]
}
```

## Godot Best Practices for This Project

### Scene Structure
- Keep scenes small and modular
- Use instancing for NPCs
- Main scene contains: Player, Environment, NPCs, UI

### GDScript Patterns
```gdscript
# Signals for communication
signal todo_completed(todo_id)

# Autoloads for global state
# Create singleton for TodoManager, PlayerStats

# Simple state machines for NPCs
enum State { IDLE, WORKING, COMPLETE }
var current_state = State.IDLE
```

### UI Approach
- Use CanvasLayer for UI overlay
- Control nodes for dialogs
- Simple Panel + Label + Button components
- Minimal styling (hackathon pace)

## Phase-by-Phase Approach
See `PHASES.md` for detailed breakdown:
- Phase 0: Setup ✓
- Phase 1: Foundation (project init, player movement)
- Phase 2: Deckard Cain NPC & todos
- Phase 3: Worker NPCs & assignment
- Phase 4: Rewards & shop
- Phase 5: Polish & integration

## Custom Commands
- `/test-game` - Run the project
- `/validate-todos` - Check JSON format
- `/quick-scene <name> [type]` - Create new scene
- `/phase-review` - Review and approve current phase
- `/hackathon-status` - See overall progress

## When Helping
1. **Always use TodoWrite** to track tasks within each phase
2. **Mark todos complete immediately** after finishing
3. **Ask before proceeding** to next phase - user reviews each phase
4. **Keep code simple** - no over-engineering
5. **Focus on game loop** - can player complete a todo and buy something?
6. **Test frequently** - use `/test-game` after major changes

## Integration Points with Other Team
- They will commit JSON files to this repo
- LLM processes user input and splits tasks into subtasks
- Our game reads their JSON and displays it
- We update completion status (optionally write back to JSON)
- Coordinate on JSON schema early

## Success Metrics
- [ ] Can load todos from JSON
- [ ] Can interact with Deckard Cain NPC
- [ ] Can view todo list
- [ ] Can assign todos to worker NPCs
- [ ] Workers complete todos over time
- [ ] XP/Gold awarded on completion
- [ ] Can visit shop and buy items
- [ ] Game loop is satisfying and complete

## Debugging Tips
- Use `print()` liberally in GDScript
- Check Godot console output in `/test-game`
- Verify JSON loading with `/validate-todos`
- Keep scenes simple to avoid crashes

## Remember
This is a hackathon - **done is better than perfect**. Focus on the core loop working end-to-end before any polish.
