# JSON Schema for LLM Team

## Overview
Your Python script will take user input text and output a JSON file containing quests with tasks.

## File Location
Please output to: `todos.json` (in project root)

We'll watch for this file and reload it when it changes.

## Your Output Format (Python Script)

**Output to stdout** - quests array:

```json
{
  "quests": [
    {
      "id": "Q-abc123def",
      "title": "Short quest title (3-7 words)",
      "description": "Overall quest description",
      "frequency": "one_time",
      "difficulty": "easy",
      "tasks": [
        {
          "id": "T-xyz789",
          "text": "Specific task description"
        },
        {
          "id": "T-abc456",
          "text": "Another specific task"
        }
      ]
    }
  ]
}
```

**Note:** Game's import layer will automatically:
- Read `frequency` to determine quest type (one_time/daily/weekly)
- Map `difficulty` to NPC placement distance ("easy" = far, "hard"/"epic" = close)
- Generate `rewards` from difficulty using game_config.json (no need to include!)
- Add defaults for any missing fields

## Field Descriptions

### Quest Object - Required Fields
- **id** (string, required): Stable quest ID (your script generates this via hash)
- **title** (string, required): Short quest name for display (3-7 words ideal)
- **description** (string, required): Overall description of what this quest is about
- **difficulty** (string, required): "easy", "medium", "hard", or "epic"
  - Game maps this to NPC placement: easy=far, medium=medium, hard/epic=close
- **rewards** (object, required):
  - **xp** (integer, required): Experience points (suggest: 50-300 range based on difficulty)
  - **coins** (integer, required): Gold coins (suggest: 25-150 range)
- **tasks** (array, required): Array of individual task objects

### Optional Fields (game auto-fills if missing)
- **estimated_time_minutes** (integer): Time estimate - game defaults based on difficulty if not provided
- **priority** (string): Game derives this from difficulty automatically

**Note:** Do NOT include `quest_type`, `status`, `completed_at`, `category`, or `progress` - the game manages these internally.

### Task Object - Required Fields
- **id** (string, required): Stable task ID (your script generates this via hash)
- **text** (string, required): Clear description of this specific task

**Important:** Do NOT include `status`, `completed_at`, `category`, or `progress` fields. The game manages task completion state internally.

## File Flow

The game has TWO NPCs that trigger quest generation:

### 1. Deckard Cain (One-Time Quests)
**Input:** `user_input_onetime.txt` - Player's long-term goals, project work, one-off tasks
**Output:** `todos_onetime.json` - Your script writes fresh quests here (overwrites each time)
**Game Action:** Imports these quests and tags them internally as "one_time" → spawns green NPCs

### 2. Profession Trainer (Daily Quests)
**Input:** `user_input_daily.txt` - Player's daily habits, recurring tasks
**Output:** `todos_daily.json` - Your script writes fresh quests here (overwrites each time)
**Game Action:** Imports these quests and tags them internally as "daily" → spawns blue NPCs

### Your Script's Job
1. Watch BOTH input files
2. When `user_input_onetime.txt` changes → process it → write to `todos_onetime.json`
3. When `user_input_daily.txt` changes → process it → write to `todos_daily.json`
4. You can overwrite the output files each time - game handles merging with existing state
5. Do NOT track quest progress, status, or quest_type - game handles all that

## Example - One-Time Quests

User talks to Deckard, types: *"I need to finish my project documentation and go to the gym"*

Saved to: `user_input_onetime.txt`

Your script outputs to `todos_onetime.json`:

```json
{
  "quests": [
    {
      "id": "Q-a1b2c3d4e5",
      "title": "Complete Project Documentation",
      "description": "Finish all documentation tasks for the project including README and API docs",
      "difficulty": "medium",
      "priority": "high",
      "estimated_time_minutes": 105,
      "rewards": {
        "xp": 200,
        "coins": 100
      },
      "tasks": [
        {
          "id": "T-xyz123",
          "text": "Write comprehensive README.md with setup instructions"
        },
        {
          "id": "T-abc456",
          "text": "Document all REST API endpoints with request/response examples"
        }
      ]
    },
    {
      "id": "Q-f9g8h7i6j5",
      "title": "Complete Gym Workout",
      "description": "30-minute workout session at the gym",
      "difficulty": "easy",
      "priority": "medium",
      "estimated_time_minutes": 30,
      "rewards": {
        "xp": 100,
        "coins": 50
      },
      "tasks": [
        {
          "id": "T-def789",
          "text": "Complete 30 minutes of cardio exercise"
        },
        {
          "id": "T-ghi012",
          "text": "Complete strength training routine"
        }
      ]
    }
  ]
}
```

## Example - Daily Quests

User talks to Profession Trainer, types: *"Practice coding and meditation"*

Saved to: `user_input_daily.txt`

Your script outputs to `todos_daily.json` (separate file, fresh each time):

```json
{
  "quests": [
    {
      "id": "Q-daily001",
      "title": "Daily Coding Practice",
      "description": "Work on coding skills and algorithms",
      "difficulty": "medium",
      "priority": "high",
      "estimated_time_minutes": 60,
      "rewards": {
        "xp": 120,
        "coins": 60
      },
      "tasks": [
        {
          "id": "T-code001",
          "text": "Solve 2 LeetCode problems"
        },
        {
          "id": "T-code002",
          "text": "Read documentation for 20 minutes"
        }
      ]
    },
    {
      "id": "Q-daily002",
      "title": "Daily Meditation",
      "description": "Mindfulness and relaxation practice",
      "difficulty": "easy",
      "priority": "medium",
      "estimated_time_minutes": 15,
      "rewards": {
        "xp": 50,
        "coins": 25
      },
      "tasks": [
        {
          "id": "T-med001",
          "text": "Complete 15-minute guided meditation"
        }
      ]
    }
  ]
}
```

## NPC Placement Logic (Game-Side)

The game spawns **one NPC per quest** (up to a cap). Visual coding:
- **Blue NPCs** = Daily quests
- **Green NPCs** = One-time quests

Priority affects placement distance:
- **High priority**: NPC spawns 5-15 units from player start (close)
- **Medium priority**: NPC spawns 10-25 units from player start
- **Low priority**: NPC spawns 15-35 units from player start (far)

**NPC Cap:** Maximum 15 quest-giver NPCs spawned at once. If more quests exist, higher priority quests spawn first.

## Notes for LLM Processing

**DO:**
- Create separate quests for unrelated activities (e.g., "documentation" and "gym" are two quests)
- Group related tasks under the same quest (e.g., "write README" and "write API docs" → one documentation quest)
- Break each quest into specific, actionable task objects
- Set total `estimated_time_minutes` as sum of all tasks in that quest
- Give higher XP/coins for harder or longer quests
- Set priority based on urgency (deadlines = high, nice-to-have = low)
- Make task text clear and actionable
- Use concise quest titles (3-7 words)

**DON'T:**
- Include `status`, `completed_at`, `category`, or `progress` fields
- Combine unrelated activities into one quest
- Make tasks too granular (we're not micromanaging)
- Use negative language in descriptions
- Set everything as high priority!

## Integration Flow

### One-Time Quests (Deckard Cain)
1. Player talks to Deckard Cain → Types long-term goals → Game saves to `user_input_onetime.txt`
2. Your script watches file → Processes input → Writes to `todos_onetime.json` (overwrites)
3. Game detects `todos_onetime.json` changed → Imports quests → Tags as "one_time" internally → Spawns green NPCs
4. Player finds green NPC → Accepts quest → Opens Quest Log (Q) → Checks off tasks IRL
5. When all tasks checked → NPC turns blue with "?" → Player returns → Turns in → Gets rewards

### Daily Quests (Profession Trainer)
1. Player talks to Profession Trainer → Types daily habits → Game saves to `user_input_daily.txt`
2. Your script watches file → Processes input → Writes to `todos_daily.json` (overwrites)
3. Game detects `todos_daily.json` changed → Imports quests → Tags as "daily" internally → Spawns blue NPCs
4. Rest of flow same as one-time quests

### Game State Management
- Game maintains persistent state for all quests (accepted, task progress, completed)
- Python script only generates fresh quest templates - no state tracking
- Quest IDs allow game to merge new versions with existing progress
- Completed quests stay in game state even if script re-generates them
