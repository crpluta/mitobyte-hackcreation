Quest JSON Generator

This repo includes a small Python utility that uses a local open‑source LLM (via Ollama) to convert a list of tasks into a single Quest JSON object with rewards.

Quick start

- Install Ollama and pull a model (e.g., llama3):
  - `ollama pull llama3`
- Ensure Python 3.9+ is available.

Usage

- Generate a single quest and print JSON to stdout:
  - Repeated flags: `python generate_quests.py --task "Setup repo" --task "Add tests" --task "Implement login" --model llama3`
  - Single string: `python generate_quests.py --tasks "Setup repo; Add tests; Implement login" --model llama3`
  - From a file: `python generate_quests.py --input examples/tasks.txt --model llama3`
- Optional: mark generated tasks done in the same run (by ID or text):
  - `python generate_quests.py --task "Implement login endpoint" --done-text "Implement login endpoint" --model llama3`
- Show the exact prompt (dry run, no model call; requires tasks):
  - `python generate_quests.py -i examples/tasks.txt --show-prompt`

Options

- `--backend ollama` Use the local Ollama server (default).
- `--host` Ollama host URL (default `http://localhost:11434`).
- `--model` Model name in Ollama, e.g., `llama3`, `mistral`, `qwen2`.
- `--temperature` Sampling temperature (default 0.2).
- `--max-tokens` Max tokens to generate (default 2048).
- `--difficulty` Optional global difficulty hint for all quests.
- `--category` Optional global category hint for all quests.
- `--out` Write result to a file; prints to stdout if omitted.

Notes

- The script requests strict JSON output and will extract the first balanced JSON object if extra text appears.
- You can tune the prompt by passing difficulty/category hints or editing `generate_quests.py`.

Progress

- Tasks get stable IDs derived from their text, and the quest from its title.
- Tasks track status and completion time:
  - `status`: `todo | in_progress | done`
  - `completed_at`: ISO timestamp when marked done
- The quest includes `progress` with `total_tasks`, `completed_tasks`, and `percent_complete`.

Notes

- The script no longer writes or merges files; it always prints JSON to stdout. Use shell redirection if you want to save: `python generate_quests.py --tasks "..." > quests.json`.
Schema

- Single quest object with fields: `id`, `title`, `description`, `difficulty`, `category`, `rewards`, `progress`, `tasks`
- Rewards fields: `xp`, `coins` (removed: `badges`, `items`)
- Task fields: `id`, `text`, `status`, `completed_at` (removed: `estimated_effort`, `dependencies`)
- Removed top-level `metadata`; output is just the quest object.
