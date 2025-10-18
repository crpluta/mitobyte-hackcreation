# Hackathon Development Phases

## Phase 0: Setup & Planning ✓
**Time**: 20-30 minutes
- [x] Custom slash commands created
- [x] Project context documented
- [ ] Phased plan created
- [ ] Sample JSON structure defined

**Deliverables**:
- .claude/commands/ with helpful commands
- CONTEXT.md for project understanding
- PHASES.md (this file)
- sample-todos.json structure

---

## Phase 1: Godot Project Foundation ✓
**Time**: 30-40 minutes
**Status**: COMPLETE

**Goals**:
- Initialize Godot project ✓
- Create basic 3D scene with camera and lighting ✓
- Set up player controller (2.5D WASD movement) ✓
- Create ground plane and basic environment ✓

**Deliverables**:
- project.godot ✓
- Main scene with 2.5D camera follow ✓
- Player movement script ✓
- Basic 3D environment ✓

**Review Point**: Movement feels smooth ✓

---

## Phase 2: Deckard Cain & TodoManager
**Time**: 45-60 minutes
**Status**: IN PROGRESS

**Goals**:
- Create Deckard Cain NPC (purple cylinder)
- Implement text input dialog ("What do you need to do?")
- Build TodoManager singleton for quest state
- Save player input for LLM team's Python script
- Load todos from JSON (todos.json)
- Display player stats (Level, XP, Gold)

**Deliverables**:
- Deckard Cain scene with text input UI
- TodoManager autoload singleton
- JSON file watching/loading
- Player stats tracking
- JSON_SCHEMA.md for LLM team

**Review Point**: Can talk to Deckard, enter text, see todos load from JSON

---

## Phase 3: Quest-Giver NPCs & Acceptance
**Time**: 45-60 minutes
**Status**: Not Started

**Goals**:
- Create quest-giver NPC prefab (different colors)
- Spawn one NPC per todo from JSON
- Random positioning around the map
- NPC shows assigned quest on interaction
- Player can accept quest from NPC
- Track which NPC has which quest

**Deliverables**:
- Quest-giver NPC scene
- NPC spawning system
- Quest assignment to NPCs
- Accept quest UI
- NPC-quest mapping

**Review Point**: Multiple NPCs spawn, each offers a different quest

---

## Phase 4: Quest Completion & Rewards
**Time**: 40-50 minutes
**Status**: Not Started

**Goals**:
- Return to quest-giver NPC after real-life task
- "Mark Complete" button on accepted quests
- Award XP and Gold on completion
- Level-up system (every 500 XP)
- Visual feedback for completion
- Update quest status in TodoManager

**Deliverables**:
- Quest completion UI
- Reward calculation and display
- Level-up notification
- Quest status persistence
- Completion effects/feedback

**Review Point**: Can complete quests and receive rewards

---

## Phase 5: Polish, Shop & Integration
**Time**: 30-40 minutes
**Status**: Not Started

**Goals**:
- Shop NPC for spending gold (simple items)
- UI polish and visual improvements
- Test with LLM team's JSON output
- Bug fixes and edge cases
- Demo preparation

**Deliverables**:
- Shop system (stretch goal)
- Polished UI
- LLM integration tested
- Stable demo build

**Review Point**: Final demo rehearsal

---

## NEW GAME FLOW (Updated)

1. **Player talks to Deckard Cain** → Enters text: "I need to clean house and study for exam"
2. **Text saved for LLM team** → Their Python script reads it
3. **LLM generates todos.json** → Splits into actionable quests
4. **Game detects JSON** → TodoManager loads it
5. **Quest-giver NPCs spawn** → One per todo, randomly placed on map
6. **Player explores map** → Finds NPCs, each offers their specific quest
7. **Player accepts quests** → Tracked in TodoManager
8. **Player does tasks in real life** → Outside the game
9. **Player returns to NPCs** → Marks quest complete → Gets XP/Gold
10. **Spend gold at shop** → Buy rewards (Phase 5)

---

## Notes
- Each phase ends with explicit user review
- Time estimates are aggressive but achievable
- Phases can be adjusted based on progress
- Keep scope minimal - make it work, not perfect
