#!/usr/bin/env python3
import argparse
import json
import sys
import re
import hashlib
import datetime as _dt
from typing import List, Dict, Any, Optional, Tuple
from urllib import request, error


SYSTEM_INSTRUCTIONS = (
    "You are a helpful assistant that converts a plain list of tasks into a single game-like Quest JSON object. "
    "Output STRICT JSON only with no markdown or commentary. Use concise, clear titles and descriptions. "
    "Always include reasonable rewards."
)


SCHEMA_GUIDE = {
    "id": "Q-001",
    "title": "string",
    "description": "string",
    "difficulty": "easy|medium|hard|epic",
    "rewards": {"xp": 0, "coins": 0},
    "tasks": [
        {"id": "T-001", "text": "string"}
    ]
}


def _read_tasks_from_file(path: str) -> List[str]:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    return _parse_tasks(content)


def _parse_tasks(content: str) -> List[str]:
    # Accept newline- or semicolon-separated; trim bullets like '-', '*', '1.'
    tasks: List[str] = []
    for raw in content.replace("\r\n", "\n").split("\n"):
        line = raw.strip()
        if not line:
            continue
        # Strip common bullet prefixes
        for prefix in ("- ", "* ", "• ", "+ "):
            if line.startswith(prefix):
                line = line[len(prefix):].strip()
        # Strip numeric bullets like "1. " or "1) "
        if len(line) > 2 and line[0].isdigit() and (line[1:3] in (". ", ") ")):
            line = line[3:].strip()
        # Split on semicolons if present
        parts = [p.strip() for p in line.split(";") if p.strip()] if ";" in line else [line]
        for p in parts:
            if p:
                tasks.append(p)
    return tasks


def _build_messages(tasks: List[str], difficulty_hint: Optional[str]) -> List[Dict[str, str]]:
    schema_json = json.dumps(SCHEMA_GUIDE, ensure_ascii=False)
    user_lines = [
        "Create a SINGLE quest object in JSON matching this guide exactly (keys and shape), but with real values:",
        schema_json,
        "Rules:",
        "- Output STRICT JSON only (no markdown).",
        "- Consolidate all tasks under this one quest.",
        "- Provide reasonable 'difficulty' and 'rewards'.",
        "- Use concise titles and descriptions.",
    ]
    if difficulty_hint:
        user_lines.append(f"- Overall difficulty hint: {difficulty_hint}")
    user_lines.append("Tasks:")
    for i, t in enumerate(tasks, 1):
        user_lines.append(f"{i}. {t}")
    user_prompt = "\n".join(user_lines)
    return [
        {"role": "system", "content": SYSTEM_INSTRUCTIONS},
        {"role": "user", "content": user_prompt},
    ]


def _http_post_json(url: str, payload: Dict[str, Any], timeout: int = 60) -> Dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            text = resp.read().decode("utf-8")
    except error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'ignore')}")
    except error.URLError as e:
        raise RuntimeError(f"Connection error: {e.reason}")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Some Ollama endpoints stream JSONL; try to parse the last JSON object
        try:
            last_line = [ln for ln in text.splitlines() if ln.strip()][-1]
            return json.loads(last_line)
        except Exception:
            raise RuntimeError("Failed to parse response JSON from LLM backend")


def call_ollama(messages: List[Dict[str, str]], model: str, host: str, temperature: float, max_tokens: int) -> str:
    # Prefer chat API for instruction following
    url = host.rstrip("/") + "/api/chat"
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        # Constrain output to JSON for faster, cleaner parsing
        "format": "json",
        "options": {
            "temperature": temperature,
            "num_predict": max_tokens,
        },
    }
    resp = _http_post_json(url, payload)
    # Ollama chat response
    try:
        return resp["message"]["content"]
    except Exception:
        # Fallback for generate-like response shape
        return resp.get("response", "")


def _stable_id(text: str, prefix: str, salt: str = "") -> str:
    base = (salt + "\n" + (text or "")).strip().lower()
    h = hashlib.sha1(base.encode("utf-8")).hexdigest()[:10]
    return f"{prefix}-{h}"


def _norm_text(x: Optional[str]) -> str:
    return re.sub(r"\s+", " ", (x or "").strip()).lower()


def _coerce_to_single_quest(obj: Any) -> Dict[str, Any]:
    # If obj already looks like a quest
    if isinstance(obj, dict):
        if isinstance(obj.get("quest"), dict):
            return obj["quest"]
        if isinstance(obj.get("quests"), list) and obj.get("quests"):
            first = obj["quests"][0]
            if isinstance(first, dict):
                return first
        if "tasks" in obj and isinstance(obj["tasks"], list):
            return obj
    # Fallback: wrap list of tasks into a quest
    quest: Dict[str, Any] = {
        "title": "Generated Quest",
        "description": "",
        "difficulty": "medium",
        "rewards": {"xp": 0, "coins": 0},
        "tasks": [],
    }
    if isinstance(obj, list):
        for item in obj:
            if isinstance(item, str):
                quest["tasks"].append({"text": item})
            elif isinstance(item, dict):
                quest["tasks"].append({"text": item.get("text") or item.get("title") or "Task"})
    return quest


def _normalize_quest(q: Dict[str, Any]) -> None:
    title = q.get("title") or q.get("name") or "Untitled Quest"
    qid = _stable_id(title, "Q")
    q["id"] = qid
    q.setdefault("description", "")
    q.setdefault("difficulty", "medium")
    q.setdefault("rewards", {})
    q.setdefault("tasks", [])
    for t in q["tasks"]:
        if not t.get("text") and t.get("title"):
            t["text"] = t.get("title")
        text = t.get("text") or "Untitled Task"
        tid = _stable_id(text, "T", salt=qid)
        t["id"] = tid


# Done-state updates removed: no status/completed tracking


# Progress computation removed: we no longer include progress in the output


def _prune_fields_one(q: Dict[str, Any]) -> None:
    for k in ["due_date", "prerequisites", "metadata", "category"]:
        if k in q:
            q.pop(k, None)
    if isinstance(q.get("rewards"), dict):
        q["rewards"] = {k: v for k, v in q["rewards"].items() if k in ("xp", "coins")}
    for t in q.get("tasks", []) or []:
        if "estimated_effort" in t:
            t.pop("estimated_effort", None)
        if "dependencies" in t:
            t.pop("dependencies", None)
        if "metadata" in t:
            t.pop("metadata", None)
        # Remove status/completion fields
        if "status" in t:
            t.pop("status", None)
        if "completed_at" in t:
            t.pop("completed_at", None)
def _normalize_and_assign_ids(obj: Dict[str, Any]) -> None:
    quests = obj.get("quests") or []
    for q in quests:
        title = q.get("title") or q.get("name") or "Untitled Quest"
        qid = _stable_id(title, "Q")
        q["id"] = qid
        # Ensure fields exist
        q.setdefault("description", "")
        q.setdefault("difficulty", "medium")
        q.setdefault("rewards", {})
        q.setdefault("tasks", [])
        # Normalize tasks
        for t in q["tasks"]:
            # Accept either 'text' or 'title' as the task text
            if not t.get("text") and t.get("title"):
                t["text"] = t.get("title")
            text = t.get("text") or "Untitled Task"
            tid = _stable_id(text, "T", salt=qid)
            t["id"] = tid


def _merge_root(existing: Dict[str, Any], new: Dict[str, Any]) -> Dict[str, Any]:
    # Assumes both already normalized with stable IDs
    out: Dict[str, Any] = {"quests": [], "metadata": {}}
    # Start with existing quests
    existing_map: Dict[str, Dict[str, Any]] = {}
    for q in existing.get("quests", []):
        existing_map[q.get("id")] = q
    # Merge new quests into existing ones
    for nq in new.get("quests", []) or []:
        qid = nq.get("id")
        if not qid:
            continue
        if qid in existing_map:
            eq = existing_map[qid]
            # Merge top-level fields conservatively
            for k in ("title", "description", "difficulty"):
                if not eq.get(k) and nq.get(k):
                    eq[k] = nq[k]
            # Merge rewards (fill missing keys only)
            eq.setdefault("rewards", {})
            for rk, rv in (nq.get("rewards") or {}).items():
                if rk not in eq["rewards"] or eq["rewards"][rk] in (None, 0, [], {}):
                    eq["rewards"][rk] = rv
            # Merge tasks by id
            eq.setdefault("tasks", [])
            task_map = {t.get("id"): t for t in eq["tasks"]}
            for nt in nq.get("tasks", []) or []:
                tid = nt.get("id")
                if not tid:
                    continue
                if tid in task_map:
                    et = task_map[tid]
                    # Fill other empty fields
                    for tk in ("text",):
                        if not et.get(tk) and nt.get(tk):
                            et[tk] = nt[tk]
                else:
                    # New task
                    eq["tasks"].append(nt)
        else:
            # New quest; ensure defaults
            nq.setdefault("tasks", [])
            for nt in nq["tasks"]:
                pass
            existing_map[qid] = nq
    # Rebuild list
    out["quests"] = list(existing_map.values())
    # Merge metadata (latest generation time wins)
    out["metadata"] = existing.get("metadata") or {}
    new_meta = new.get("metadata") or {}
    if new_meta:
        out["metadata"].update(new_meta)
    return out


def _prune_fields(root: Dict[str, Any]) -> None:
    # Remove fields we no longer support
    for q in root.get("quests", []) or []:
        # Drop deprecated quest-level fields
        for k in ["due_date", "prerequisites", "category"]:
            if k in q:
                q.pop(k, None)
        # Rewards: keep only xp, coins
        if isinstance(q.get("rewards"), dict):
            q["rewards"] = {k: v for k, v in q["rewards"].items() if k in ("xp", "coins")}
        # Tasks cleanup
        for t in q.get("tasks", []) or []:
            if "estimated_effort" in t:
                t.pop("estimated_effort", None)
            if "dependencies" in t:
                t.pop("dependencies", None)
            if "status" in t:
                t.pop("status", None)
            if "completed_at" in t:
                t.pop("completed_at", None)


    # Done-state updates removed for multi-quest structures as well


# Progress aggregation removed for multi-quest structures as well


def _extract_json(text: str) -> str:
    # If already valid JSON, return as is
    try:
        json.loads(text)
        return text
    except Exception:
        pass
    # Try to locate the first balanced JSON object
    start = text.find("{")
    if start == -1:
        raise ValueError("No JSON object start '{' found in model output")
    stack = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == '{':
                stack += 1
            elif ch == '}':
                stack -= 1
                if stack == 0:
                    candidate = text[start : i + 1]
                    # Validate
                    json.loads(candidate)
                    return candidate
    raise ValueError("Failed to find balanced JSON in model output")


def _ensure_metadata(obj: Dict[str, Any], model: str, in_count: int) -> None:
    meta = obj.get("metadata")
    if not isinstance(meta, dict):
        meta = {}
        obj["metadata"] = meta
    meta.setdefault(
        "generated_at",
        _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    )
    meta.setdefault("model", model)
    meta.setdefault("input_count", in_count)


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Convert a list of tasks into structured Quest JSON using a local open-source LLM (Ollama).")
    src = p.add_mutually_exclusive_group(required=False)
    src.add_argument("--input", "-i", help="Path to a text file with tasks (newline- or semicolon-separated)")
    src.add_argument("--tasks", "-t", help="Tasks as a single string; separate with newlines or semicolons")
    src.add_argument("--task", action="append", help="Add a single task; repeat this flag for multiple tasks")

    p.add_argument("--backend", choices=["ollama"], default="ollama", help="LLM backend to use")
    p.add_argument(
        "--model", "-m", default="llama3.2:1b",
        help=(
            "Ollama model name (default: 'phi3:mini'). Examples: 'llama3', 'mistral', 'qwen2'. "
            "For speed, try tiny models like 'phi3:mini', 'llama3.2:1b-instruct', 'qwen2.5:1.5b-instruct'."
        ),
    )
    p.add_argument("--host", default="http://localhost:11434", help="Ollama host URL")
    p.add_argument("--temperature", type=float, default=0.2, help="Sampling temperature")
    p.add_argument("--max-tokens", type=int, default=2048, help="Max tokens to generate")
    p.add_argument(
        "--fast",
        action="store_true",
        help="Favor speed: keep model but cap output length for faster responses",
    )
    p.add_argument("--difficulty", help="Optional overall difficulty hint (e.g., easy, medium, hard)")
    p.add_argument("--output", "-o", required=False, help="Optional: write JSON to this file instead of stdout")
    p.add_argument("--show-prompt", action="store_true", help="Print the constructed prompt and exit (dry run)")

    args = p.parse_args(argv)

    if args.task:
        tasks = [t.strip() for t in args.task if t and t.strip()]
    elif args.input:
        tasks = _read_tasks_from_file(args.input)
    elif args.tasks:
        tasks = _parse_tasks(args.tasks)
    else:
        tasks = []

    if not tasks and not args.show_prompt:
        print("No tasks provided.", file=sys.stderr)
        return 2

    messages = _build_messages(tasks, args.difficulty)

    if args.show_prompt and tasks:
        # Print as a readable block
        sys.stdout.write("\n=== SYSTEM ===\n" + messages[0]["content"] + "\n\n")
        sys.stdout.write("=== USER ===\n" + messages[1]["content"] + "\n")
        return 0
    elif args.show_prompt and not tasks:
        print("--show-prompt requires tasks to be provided.", file=sys.stderr)
        return 2

    new_obj: Dict[str, Any] = {}
    if tasks:
        if args.backend == "ollama":
            selected_model = args.model
            selected_max_tokens = args.max_tokens
            if args.fast and selected_max_tokens == 2048:
                selected_max_tokens = 512
            raw = call_ollama(
                messages,
                model=selected_model,
                host=args.host,
                temperature=args.temperature,
                max_tokens=selected_max_tokens,
            )
        else:
            raise RuntimeError(f"Unsupported backend: {args.backend}")

        try:
            json_text = _extract_json(raw)
            new_obj = json.loads(json_text)
        except Exception as e:
            print("Failed to parse model output as JSON:", file=sys.stderr)
            print(str(e), file=sys.stderr)
            # Emit the raw text for debugging
            print("\n----- RAW MODEL OUTPUT -----\n", file=sys.stderr)
            print(raw, file=sys.stderr)
            return 3

    # Coerce to a single quest and normalize
    quest = _coerce_to_single_quest(new_obj)
    _normalize_quest(quest)
    # No status/completed tracking
    # No progress field generation
    _prune_fields_one(quest)

    # Write JSON to file or print to stdout
    json_output = json.dumps(quest, ensure_ascii=False, indent=2)

    if args.output:
        # Write to file for non-blocking Godot integration
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(json_output)
        print(f"Quest written to: {args.output}", file=sys.stderr)
    else:
        # Print to stdout (original behavior)
        print(json_output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
