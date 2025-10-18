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
    "category": "string",
    "rewards": {"xp": 0, "coins": 0},
    "progress": {"total_tasks": 0, "completed_tasks": 0, "percent_complete": 0},
    "tasks": [
        {"id": "T-001", "text": "string", "status": "todo|in_progress|done", "completed_at": None}
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


def _build_messages(tasks: List[str], difficulty_hint: Optional[str], category_hint: Optional[str]) -> List[Dict[str, str]]:
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
    if category_hint:
        user_lines.append(f"- Overall category hint: {category_hint}")
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
        "category": "general",
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
    q.setdefault("category", "general")
    q.setdefault("rewards", {})
    q.setdefault("tasks", [])
    for t in q["tasks"]:
        if not t.get("text") and t.get("title"):
            t["text"] = t.get("title")
        text = t.get("text") or "Untitled Task"
        tid = _stable_id(text, "T", salt=qid)
        t["id"] = tid
        t.setdefault("status", "todo")
        t.setdefault("completed_at", None)


def _apply_done_updates_one(q: Dict[str, Any], done_ids: List[str], done_texts: List[str]) -> Tuple[int, int]:
    done_ids_set = {d.strip() for d in done_ids or [] if d and d.strip()}
    done_texts_norm = {_norm_text(t) for t in (done_texts or []) if t and t.strip()}
    id_updates = 0
    text_updates = 0
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    for t in q.get("tasks", []) or []:
        tid = t.get("id")
        ttext = _norm_text(t.get("text"))
        if tid in done_ids_set or (ttext and ttext in done_texts_norm):
            if t.get("status") != "done":
                t["status"] = "done"
                t["completed_at"] = t.get("completed_at") or now
                if tid in done_ids_set:
                    id_updates += 1
                if ttext in done_texts_norm:
                    text_updates += 1
    return id_updates, text_updates


def _recompute_progress_one(q: Dict[str, Any]) -> None:
    tasks = q.get("tasks") or []
    total = len(tasks)
    done = sum(1 for t in tasks if (t.get("status") == "done"))
    pct = int(round((done / total) * 100)) if total else 0
    q["progress"] = {"total_tasks": total, "completed_tasks": done, "percent_complete": pct}


def _prune_fields_one(q: Dict[str, Any]) -> None:
    for k in ["due_date", "prerequisites", "metadata"]:
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
def _normalize_and_assign_ids(obj: Dict[str, Any]) -> None:
    quests = obj.get("quests") or []
    for q in quests:
        title = q.get("title") or q.get("name") or "Untitled Quest"
        qid = _stable_id(title, "Q")
        q["id"] = qid
        # Ensure fields exist
        q.setdefault("description", "")
        q.setdefault("difficulty", "medium")
        q.setdefault("category", "general")
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
            t.setdefault("status", "todo")
            t.setdefault("completed_at", None)


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
            for k in ("title", "description", "difficulty", "category"):
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
                    # Preserve status and completed_at; fill other empty fields
                    preserved_status = et.get("status")
                    preserved_completed = et.get("completed_at")
                    for tk in ("text",):
                        if not et.get(tk) and nt.get(tk):
                            et[tk] = nt[tk]
                    if preserved_status:
                        et["status"] = preserved_status
                    if preserved_completed is not None:
                        et["completed_at"] = preserved_completed
                else:
                    # New task; default status todo
                    nt.setdefault("status", "todo")
                    nt.setdefault("completed_at", None)
                    eq["tasks"].append(nt)
        else:
            # New quest; ensure defaults
            nq.setdefault("tasks", [])
            for nt in nq["tasks"]:
                nt.setdefault("status", "todo")
                nt.setdefault("completed_at", None)
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
        for k in ["due_date", "prerequisites"]:
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


def _apply_done_updates(root: Dict[str, Any], done_ids: List[str], done_texts: List[str]) -> Tuple[int, int]:
    done_ids_set = {d.strip() for d in done_ids or [] if d and d.strip()}
    done_texts_norm = {_norm_text(t) for t in (done_texts or []) if t and t.strip()}
    id_updates = 0
    text_updates = 0
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    for q in root.get("quests", []) or []:
        for t in q.get("tasks", []) or []:
            tid = t.get("id")
            ttext = _norm_text(t.get("text"))
            if tid in done_ids_set or (ttext and ttext in done_texts_norm):
                if t.get("status") != "done":
                    t["status"] = "done"
                    t["completed_at"] = t.get("completed_at") or now
                    if tid in done_ids_set:
                        id_updates += 1
                    if ttext in done_texts_norm:
                        text_updates += 1
    return id_updates, text_updates


def _recompute_progress(root: Dict[str, Any]) -> None:
    for q in root.get("quests", []) or []:
        tasks = q.get("tasks") or []
        total = len(tasks)
        done = sum(1 for t in tasks if (t.get("status") == "done"))
        pct = int(round((done / total) * 100)) if total else 0
        q["progress"] = {"total_tasks": total, "completed_tasks": done, "percent_complete": pct}


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
    p.add_argument("--model", "-m", default="llama3", help="Ollama model name, e.g. 'llama3', 'mistral', 'qwen2' ")
    p.add_argument("--host", default="http://localhost:11434", help="Ollama host URL")
    p.add_argument("--temperature", type=float, default=0.2, help="Sampling temperature")
    p.add_argument("--max-tokens", type=int, default=2048, help="Max tokens to generate")
    p.add_argument("--difficulty", help="Optional overall difficulty hint (e.g., easy, medium, hard)")
    p.add_argument("--category", help="Optional overall category hint (e.g., onboarding, devops)")
    # File output is deprecated; script always prints JSON to stdout.
    p.add_argument("--out", "-o", required=False, help="(Deprecated) Ignored. Script prints JSON to stdout.")
    p.add_argument("--show-prompt", action="store_true", help="Print the constructed prompt and exit (dry run)")
    p.add_argument("--done-id", action="append", help="Mark a task as done by its ID; repeatable")
    p.add_argument("--done-text", action="append", help="Mark task(s) as done by exact text; repeatable")

    args = p.parse_args(argv)

    if args.task:
        tasks = [t.strip() for t in args.task if t and t.strip()]
    elif args.input:
        tasks = _read_tasks_from_file(args.input)
    elif args.tasks:
        tasks = _parse_tasks(args.tasks)
    else:
        tasks = []

    if not tasks and not (args.done_id or args.done_text or args.show_prompt):
        print("No tasks provided.", file=sys.stderr)
        return 2

    messages = _build_messages(tasks, args.difficulty, args.category)

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
            raw = call_ollama(messages, model=args.model, host=args.host, temperature=args.temperature, max_tokens=args.max_tokens)
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
    _apply_done_updates_one(quest, args.done_id or [], args.done_text or [])
    _recompute_progress_one(quest)
    _prune_fields_one(quest)

    # Always print JSON to stdout; never write files.
    if args.out:
        print("Note: --out is deprecated and ignored; printing to stdout", file=sys.stderr)
    print(json.dumps(quest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
