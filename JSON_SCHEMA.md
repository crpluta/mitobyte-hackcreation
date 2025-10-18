# JSON Schema for LLM Team

## Overview
Your Python script will take user input text and output a JSON file containing split todos.

## File Location
Please output to: `todos.json` (in project root)

We'll watch for this file and reload it when it changes.

## Required Schema

```json
{
  "user_input": "Original text the player typed",
  "timestamp": "2025-10-18T10:30:00Z",
  "todos": [
    {
      "title": "Short quest title (3-5 words)",
      "description": "Detailed description of what needs to be done",
      "xp_reward": 100,
      "gold_reward": 50,
      "estimated_time_minutes": 60,
      "priority": "high"
    }
  ]
}
```

## Field Descriptions

### Root Level
- **user_input** (string, required): The original text the player entered
- **timestamp** (string, required): ISO 8601 timestamp when generated
- **todos** (array, required): Array of todo objects

### Todo Object - Required Fields
- **title** (string, required): Short quest name for display (3-7 words ideal)
- **description** (string, required): Detailed explanation of the task
- **xp_reward** (integer, required): Experience points (suggest: 50-200 range)
- **gold_reward** (integer, required): Gold coins (suggest: 25-100 range)
- **estimated_time_minutes** (integer, required): Rough estimate for completion - helps player plan their day
- **priority** (string, required): "low", "medium", or "high" - affects NPC placement (high priority = closer to spawn, but still scattered)

**Note:** The game will auto-generate unique IDs for each todo when loading the JSON, so you don't need to include an "id" field.

### Todo Object - Optional Fields
- **difficulty** (string): "easy", "medium", or "hard" - visual flavor
- **category** (string): Group similar tasks (e.g., "work", "personal", "health")

## Example

```json
{
  "user_input": "I need to finish my project documentation and go to the gym",
  "timestamp": "2025-10-18T14:30:00Z",
  "todos": [
    {
      "title": "Write project README",
      "description": "Create comprehensive README.md with setup instructions, API docs, and examples",
      "xp_reward": 150,
      "gold_reward": 75,
      "estimated_time_minutes": 60,
      "priority": "high",
      "difficulty": "medium",
      "category": "work"
    },
    {
      "title": "Document API endpoints",
      "description": "Write detailed documentation for all REST API endpoints including request/response examples",
      "xp_reward": 120,
      "gold_reward": 60,
      "estimated_time_minutes": 45,
      "priority": "high",
      "difficulty": "medium",
      "category": "work"
    },
    {
      "title": "30-minute gym workout",
      "description": "Complete a 30-minute workout session at the gym including cardio and strength training",
      "xp_reward": 100,
      "gold_reward": 50,
      "estimated_time_minutes": 30,
      "priority": "medium",
      "difficulty": "easy",
      "category": "health"
    }
  ]
}
```

## NPC Placement Logic (Game-Side)

The game uses **priority** to influence NPC placement:
- **High priority**: NPCs spawn 5-15 units from player start (still with randomization)
- **Medium priority**: NPCs spawn 10-25 units from player start
- **Low priority**: NPCs spawn 15-35 units from player start

All placements include random scatter within those ranges for natural exploration.

**estimated_time_minutes** helps players decide which quests to tackle first (shown in UI).

## Notes for LLM Processing

**DO:**
- Split vague tasks into specific, actionable todos
- Give higher XP/Gold for harder or longer tasks
- Set priority based on urgency (deadlines = high, nice-to-have = low)
- Estimate realistic completion times
- Make descriptions clear and motivating
- Ensure each todo is completable in one session

**DON'T:**
- Include game-specific fields (npc_id, completed status, etc.) - we handle those
- Make todos too granular (we're not micromanaging)
- Use negative language in descriptions
- Set everything as high priority (defeats the purpose!)

## Integration Flow

1. Player talks to Deckard Cain in-game
2. Player types what they need to do
3. Game saves this text for your script to read
4. Your Python script processes it → Outputs `todos.json`
5. Game detects file change → Loads todos → Assigns to NPCs
6. Player finds NPCs around map and accepts quests
7. Player does tasks in real life
8. Player returns to NPC to mark complete → Gets rewards!
