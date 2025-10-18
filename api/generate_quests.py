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
    ""
    "If the user input is not clear ask for clarity and wait to generate tasks until clear input. "
    "Make a user input need to be at least 3 characters and alert the user if they need to update their input. "
    "Do not generate a quest if the user input text is less than 3 characters. "
    "If the user enters gibberish please ask for clarity so that the quests is clear and simple tasks. "
    "ALWAYS split compound items into multiple atomic tasks: one clear action per task. "
    "Detect conjunctions or multiple verbs (e.g., 'and', 'then', '&', commas) and separate them into distinct tasks. "
    "Avoid 'and/then/&' inside a single task; prefer two shorter tasks instead. "
    "Tasks must omit frequency words (e.g., 'every', 'each', weekday names, 'daily', 'weekly'); capture cadence via the quest 'frequency' field instead. "
    "Tasks must never use first person (no 'I', 'I'm', 'my'); use imperative verb-first phrasing (e.g., 'Finish Documentation'). "
    "Do NOT invent new tasks: only include tasks explicitly provided by the user (you may split compound items into multiple atomic tasks, but do not add actions beyond those items). "
    "Title style: evocative medieval D&D quest name (3-8 words), lore-like and atmospheric, but generic (no proper nouns or setting lore). "
    "Description style: NPC quest-giver directive written as a short story in a medieval setting (3-6 sentences). Provide brief background and establish context, address the player as 'you', and keep within the scope of the tasks without adding new requirements."
)


COMMON_TASK_WORDS = {
    # Common verbs
    "plan", "prepare", "write", "review", "update", "create", "build", "design", "test", "deploy",
    "research", "organize", "clean", "practice", "study", "learn", "call", "email", "schedule",
    "draft", "read", "analyze", "improve", "fix", "debug", "code", "submit", "complete", "assemble",
    "document", "sketch", "present", "train", "brainstorm", "evaluate", "deliver",
    "install", "configure", "refine", "optimize", "monitor", "report", "coordinate",
    "cook", "bake", "shop", "exercise", "walk", "run", "workout", "record",
    "edit", "upload", "publish", "arrange", "budget", "investigate", "organise", "planify",
    "research", "prototype", "outline", "prepare", "assist", "support", "manage", "organize",
    "develop", "draft", "collect", "gather", "practice", "negotiate", "brainstorm", "document",
    "calibrate", "assemble", "summarize", "prioritize", "refactor", "automate", "prototype",
    "paint", "draw", "design", "compose", "record", "mentor", "coach", "build",
    # Common nouns/objects
    "presentation", "proposal", "meeting", "report", "summary", "article", "blog", "video", "module",
    "feature", "design", "project", "task", "assignment", "homework", "plan", "timeline",
    "notes", "itinerary", "experiment", "exercise", "lesson", "workout", "cleanup",
    "laundry", "groceries", "budget", "resume", "portfolio", "documentation", "deployment",
    "release", "feedback", "analysis", "research", "draft", "strategy", "campaign", "presentation",
    "prototype", "blueprint", "roadmap", "calendar", "agenda", "vacation", "dinner", "lunch",
    "breakfast", "meal", "shopping", "garden", "workshop", "seminar", "webinar", "invoice",
    "website", "content", "lesson", "exercise", "journal", "summary", "overview", "travel",
    "meditation", "meditate", "presentation", "reflection", "strategy", "analysis"
}

BASIC_ENGLISH_WORDS = {
    "the", "and", "for", "with", "from", "into", "about", "over", "under", "after", "before",
    "team", "client", "customer", "project", "task", "goal", "milestone", "deadline",
    "complete", "finish", "start", "begin", "launch", "deliver", "prepare", "organize",
    "plan", "planning", "strategy", "strategic", "analysis", "analyze", "research", "study",
    "lesson", "assignment", "homework", "essay", "paper", "report", "presentation", "slides",
    "meeting", "agenda", "minutes", "notes", "follow", "review", "feedback", "summary",
    "update", "upgrade", "improve", "refine", "optimize", "support", "assist", "help",
    "documentation", "document", "manual", "guide", "outline", "draft", "prototype",
    "feature", "module", "system", "application", "software", "hardware", "server",
    "deploy", "release", "build", "develop", "design", "code", "debug", "fix", "test",
    "quality", "assurance", "qa", "integration", "unit", "automation", "pipeline",
    "marketing", "campaign", "content", "social", "media", "email", "newsletter",
    "finance", "budget", "invoice", "expense", "revenue", "profit", "reporting",
    "sales", "lead", "prospect", "call", "followup", "deal", "contract", "proposal",
    "training", "coaching", "mentoring", "practice", "exercise", "fitness", "health",
    "nutrition", "meal", "recipe", "dinner", "lunch", "breakfast", "grocery", "shopping",
    "house", "home", "apartment", "cleaning", "laundry", "organization", "declutter",
    "travel", "trip", "journey", "vacation", "holiday", "flight", "hotel", "booking",
    "itinerary", "packing", "reservation", "ticket", "passport", "visa",
    "garden", "yard", "maintenance", "repair", "fix", "upgrade", "install",
    "study", "learn", "practice", "skill", "language", "english", "spanish", "french",
    "music", "piano", "guitar", "violin", "lesson", "practice", "rehearsal",
    "writing", "reading", "drawing", "painting", "creative", "brainstorm",
    "family", "friend", "community", "volunteer", "event", "planning",
    "career", "resume", "portfolio", "interview", "application", "network",
    "health", "doctor", "appointment", "medication", "therapy", "wellness",
    "finance", "savings", "investment", "insurance", "taxes", "budgeting",
    "school", "class", "lecture", "study", "exam", "quiz", "project",
    "research", "data", "analysis", "survey", "report", "presentation",
    "cleanup", "organize", "arrange", "coordinate", "manage", "plan",
    "meeting", "call", "email", "message", "respond", "reply", "confirm",
    "prepare", "setup", "configure", "install", "calibrate", "test",
    "collect", "gather", "analyze", "summarize", "prioritize", "delegate",
    "create", "edit", "review", "publish", "share", "submit", "approve",
    "monitor", "track", "measure", "report", "audit", "inspect",
    "brainstorm", "ideate", "innovate", "prototype", "refactor",
    "optimize", "streamline", "simplify", "clarify", "document",
    "prepare", "pack", "schedule", "calendar", "timeline",
    "festival", "conference", "workshop", "seminar", "webinar",
    "budget", "forecast", "analysis", "planning", "strategy",
    "support", "maintain", "upgrade", "transition", "handoff",
    "lesson", "module", "course", "curriculum", "syllabus",
    "projector", "laptop", "device", "network", "security",
    "policy", "procedure", "compliance", "audit", "risk",
    "inventory", "supplies", "asset", "equipment", "tool",
    "feedback", "survey", "assessment", "evaluation",
    "goal", "objective", "milestone", "deliverable",
    "celebrate", "appreciate", "recognize", "reward",
    "brainstorming", "collaborate", "coordinate", "communicate",
    "drafting", "editing", "formatting", "proofread",
    "developing", "testing", "deploying", "supporting"
}

KNOWN_TASK_WORDS = COMMON_TASK_WORDS | BASIC_ENGLISH_WORDS


SCHEMA_GUIDE = {
    "id": "Q-001",
    "title": "string",
    "description": "string",
    "frequency": "daily|weekly|one_time",
    "difficulty": "easy|medium|hard|epic",
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


def _split_atomic_tasks(items: List[str]) -> List[str]:
    # Split compound items into atomic tasks using simple conjunction and punctuation heuristics
    out: List[str] = []
    for raw in items or []:
        if not raw:
            continue
        parts = re.split(r"\b(?:and|then)\b|&|,", raw, flags=re.IGNORECASE)
        for p in parts:
            txt = (p or "").strip()
            # Strip leading list markers again if any
            for prefix in ("- ", "* ", "+ ", "• "):
                if txt.startswith(prefix):
                    txt = txt[len(prefix):].strip()
            if txt:
                out.append(txt)
    # De-duplicate while preserving order (case-insensitive, whitespace-normalized)
    seen = set()
    unique: List[str] = []
    for t in out:
        key = re.sub(r"\s+", " ", t.strip().lower())
        if key and key not in seen:
            seen.add(key)
            unique.append(t.strip())
    return unique


def _normalize_task_phrase(text: str) -> str:
    # Remove common first-person lead-ins and convert to imperative phrase
    s = (text or "").strip()
    low = s.lower()
    patterns = [
        "i need to ",
        "i have to ",
        "i must ",
        "i should ",
        "i will ",
        "i'm going to ",
        "im going to ",
        "i am going to ",
        "i wanna ",
        "i want to ",
        "i'd like to ",
        "i got to ",
        "i gotta ",
    ]
    for p in patterns:
        if low.startswith(p):
            s = s[len(p):]
            break
    # Remove any leading 'to ' remnants
    s = re.sub(r"^(to\s+)+", "", s, flags=re.IGNORECASE)
    # Remove first-person possessives like 'my '
    s = re.sub(r"\bmy\s+", "", s, flags=re.IGNORECASE)
    s = s.strip().strip(".!")
    # Capitalize each word (simple title case)
    words = [w.capitalize() for w in re.split(r"\s+", s) if w]
    return " ".join(words)


def _strip_frequency_phrases(text: str) -> str:
    s = (text or "").strip()
    if not s:
        return s
    # Remove explicit cadence tokens
    removals = [
        r"\b(?:daily|nightly|weekly)\b",
        r"\b(?:every|each)\s+(?:day|night|morning|evening|week|weekend)\b",
        r"\bon\s+the\s+weekend\b",
    ]
    # Weekdays
    weekday = r"monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun"
    removals += [
        rf"\b(?:every|each)\s+(?:{weekday})s?\b",
        rf"\bon\s+(?:{weekday})s?\b",
    ]
    out = s
    for pat in removals:
        out = re.sub(pat, "", out, flags=re.IGNORECASE)
    # Remove leftover connectors like extra 'on', stray commas, and compress spaces
    out = re.sub(r"\b(?:on|every|each)\b", "", out, flags=re.IGNORECASE)
    out = re.sub(r"\s+,\s*", ", ", out)
    out = re.sub(r"\s+", " ", out).strip(" ,.-")
    return out.strip()


def _extract_keywords(tasks: List[str], max_k: int = 6) -> List[str]:
    # Simple keyword extractor: drop short/common words and keep salient terms from tasks
    stop = {
        "the", "and", "or", "for", "with", "to", "of", "a", "an", "on", "in", "at", "by",
        "every", "each", "day", "night", "morning", "evening", "daily", "weekly", "then", "&",
        "minutes", "minute", "min", "hour", "hours", "today", "tomorrow", "tonight",
        "finish", "complete", "do", "make", "my", "your", "our", "task", "tasks"
    }
    seen = set()
    out: List[str] = []
    for t in tasks or []:
        for w in re.split(r"[^A-Za-z]+", t.lower()):
            if len(w) < 3 or w in stop:
                continue
            if w not in seen:
                seen.add(w)
                out.append(w)
            if len(out) >= max_k:
                return out
    return out


def _synthesize_lore_title(keywords: List[str]) -> str:
    ks = [k.capitalize() for k in keywords if k]
    if not ks:
        return "A Modest Charge"
    if len(ks) >= 2:
        return f"{ks[0]} and {ks[1]} Oath"
    # Single keyword
    return f"The {ks[0]} Charge"


def _infer_frequency_from_text(text: str) -> str:
    s = (text or "").lower()
    # Daily hints
    daily_patterns = [
        r"\bdaily\b",
        r"\bevery\s+day\b",
        r"\beach\s+day\b",
        r"\bevery\s+morning\b",
        r"\bevery\s+evening\b",
        r"\bevery\s+night\b",
        r"\beach\s+night\b",
        r"\bnightly\b",
        r"\bmorning\s+routine\b",
        r"\bevening\s+routine\b",
        r"\bnight\s+routine\b",
    ]
    for pat in daily_patterns:
        if re.search(pat, s):
            return "daily"

    # Weekly hints (specific weekdays or weekly cadence)
    weekday = r"monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun"
    weekly_patterns = [
        r"\bweekly\b",
        r"\bevery\s+week\b",
        r"\beach\s+week\b",
        rf"\b(every|each)?\s*(on\s+)?({weekday})s?\b",
        r"\bevery\s+weekend\b",
    ]
    for pat in weekly_patterns:
        if re.search(pat, s):
            return "weekly"

    return "one_time"


def _infer_frequency(tasks: List[str]) -> str:
    # If any task indicates daily, return daily; else if any weekly, return weekly; else one_time.
    saw_weekly = False
    for t in tasks or []:
        f = _infer_frequency_from_text(t)
        if f == "daily":
            return "daily"
        if f == "weekly":
            saw_weekly = True
    return "weekly" if saw_weekly else "one_time"


def _looks_like_gibberish(text: str) -> bool:
    # Tokenize alphabetical words
    words = re.findall(r"[A-Za-z]+", text)
    if not words:
        return True

    normalized_words = [w.lower() for w in words]
    if not normalized_words:
        return True

    known_hits = sum(1 for w in normalized_words if w in KNOWN_TASK_WORDS)
    if known_hits >= max(1, len(normalized_words) // 2):
        return False

    letters = re.findall(r"[A-Za-z]", text)
    if len(letters) < 3:
        return True
    vowels = sum(1 for ch in letters if ch.lower() in "aeiou")
    if vowels == 0:
        return True

    unique_letters = {ch.lower() for ch in letters}
    if len(unique_letters) <= 1:
        return True

    consonant_runs = re.findall(r"(?i)[b-df-hj-np-tv-z]{4,}", text)
    if consonant_runs:
        return True

    if len(normalized_words) == 1 and len(normalized_words[0]) <= 3:
        # Single short word not in known list; likely unclear
        return True

    # Without clear known words, treat as unclear, but allow common short phrases like "go to gym"
    if known_hits == 0:
        distinct_words = set(normalized_words)
        # Allow short phrases with common patterns like "go to X" where X is a known task word
        if len(distinct_words) <= 3 and any(w in {"go", "to", "the"} for w in distinct_words):
            # If there is at least one word of length >= 3, accept the phrase
            if any(len(w) >= 3 for w in normalized_words):
                return False
        return True

    # Default to treating as unclear only if no strong signals of clarity appear
    return False


def _build_messages(tasks: List[str], difficulty_hint: Optional[str]) -> List[Dict[str, str]]:
    schema_json = json.dumps(SCHEMA_GUIDE, ensure_ascii=False)
    user_lines = [
        "Create a SINGLE quest object in JSON matching this guide exactly (keys and shape), but with real values:",
        schema_json,
        "Rules:",
        "- Output STRICT JSON only (no markdown).",
        "- Consolidate all tasks under this one quest.",
        "- Provide a reasonable 'difficulty'.",
        "- Use concise titles and descriptions; avoid any time constraints in the title or description.",
        "- Keep each task's wording strictly within the provided scope; avoid speculative details.",
        "- Tasks must omit frequency words (e.g., 'every', 'each', weekday names, 'daily', 'weekly'); capture cadence via the quest 'frequency' field instead.",
        "- Tasks must never use first person (no 'I', 'I'm', 'my'); use imperative verb-first phrasing (e.g., 'Finish Documentation').",
        "- Title style: evocative medieval D&D quest name (3-8 words), lore-like and atmospheric, but generic (no proper nouns or setting lore).",
        "- Description style: NPC quest-giver directive as a short medieval story (3-6 sentences) addressing 'you'; give brief background and context without adding new requirements.",
        "- Break compound items into multiple atomic tasks: one action per task.",
        "- If an item contains 'and', 'then', '&' or multiple verbs, split it into separate tasks.",
        "- Do not combine multiple actions in one task; prefer two shorter tasks instead.",
        "- Do NOT invent new tasks: only include tasks explicitly provided by the user; you may split compound items but must not add actions beyond them.",
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


def _restyle_title_and_description(
    quest: Dict[str, Any], host: str, model: str, base_temperature: float
) -> None:
    """
    Second-pass rewrite to ensure D&D NPC flavor for title/description.
    Only touches 'title' and 'description'.
    """
    title = (quest.get("title") or "").strip()
    description = (quest.get("description") or "").strip()
    tasks = [t.get("text") or "" for t in (quest.get("tasks") or [])]
    keywords = _extract_keywords(tasks)

    sys_txt = (
        "Rewrite only 'title' and 'description'. Output STRICT JSON with keys 'title' and 'description' only. "
        "Title: evocative medieval D&D quest name (3-8 words), lore-like and atmospheric, but generic (no proper nouns or setting lore). "
        "Description: NPC quest-giver directive written as a short medieval story (3-6 sentences). Provide brief background and establish context, address the player as 'you', and do NOT add requirements beyond the tasks. "
        "Anchor both title and description to the tasks by naturally incorporating at least one provided keyword. Avoid generic outputs; be specific to these tasks. "
        "Example: {\"title\": \"Quill and Quiet Resolve\", \"description\": \"You arrive at a dim-lit scriptorium, where an old scribe beckons. 'You,' he rasps, 'must set your thoughts in order upon the page, then set your body to motion, lest the day grow dull and your spirit heavy.'\"}."
    )
    user_lines = [
        "Current values:",
        json.dumps({"title": title, "description": description}, ensure_ascii=False),
        "Tasks:",
        "Keywords: " + ", ".join(keywords) if keywords else "Keywords:",
    ]
    for i, t in enumerate(tasks, 1):
        if t:
            user_lines.append(f"{i}. {t}")
    messages = [
        {"role": "system", "content": sys_txt},
        {"role": "user", "content": "\n".join(user_lines)},
    ]

    raw = call_ollama(messages, model=model, host=host, temperature=min(0.7, max(0.3, base_temperature)), max_tokens=240)
    try:
        obj = json.loads(_extract_json(raw))
        if isinstance(obj, dict):
            new_title = (obj.get("title") or title).strip()
            new_desc = (obj.get("description") or description).strip()
            # Fallback: ensure title contains at least one keyword; if not, synthesize a lore-like anchored title
            if keywords:
                low_title = new_title.lower()
                if not any(k in low_title for k in keywords):
                    new_title = _synthesize_lore_title(keywords)
            if new_title:
                quest["title"] = new_title
            if new_desc:
                quest["description"] = new_desc
    except Exception:
        pass


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
        "frequency": "one_time",
        "difficulty": "medium",
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
    q.setdefault("frequency", "one_time")
    q.setdefault("difficulty", "medium")
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
    for k in ["due_date", "prerequisites", "metadata", "category", "clues"]:
        if k in q:
            q.pop(k, None)
    if "rewards" in q:
        q.pop("rewards", None)
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
        if "clues" in t:
            t.pop("clues", None)
def _normalize_and_assign_ids(obj: Dict[str, Any]) -> None:
    quests = obj.get("quests") or []
    for q in quests:
        title = q.get("title") or q.get("name") or "Untitled Quest"
        qid = _stable_id(title, "Q")
        q["id"] = qid
        # Ensure fields exist
        q.setdefault("description", "")
        q.setdefault("difficulty", "medium")
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
            # Rewards removed from schema; ignore any incoming 'rewards'
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
        for k in ["due_date", "prerequisites", "category", "clues"]:
            if k in q:
                q.pop(k, None)
        # Remove rewards entirely
        if "rewards" in q:
            q.pop("rewards", None)
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
            if "clues" in t:
                t.pop("clues", None)


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
    p.add_argument(
        "--no-style",
        action="store_true",
        help="Skip the stylistic rewrite of title/description into D&D NPC dialogue",
    )
    p.add_argument(
        "--style-model",
        help="Optional model to use just for styling title/description; defaults to --model",
    )
    p.add_argument("--difficulty", help="Optional overall difficulty hint (e.g., easy, medium, hard)")
    # File output is deprecated; script always prints JSON to stdout.
    p.add_argument("--out", "-o", required=False, help="(Deprecated) Ignored. Script prints JSON to stdout.")
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

    # Enforce a minimum length for each task to avoid low-information prompts
    min_task_length = 3
    invalid_tasks = [t for t in tasks if len(t.strip()) < min_task_length]
    if invalid_tasks:
        print(f"Each task must be at least {min_task_length} characters long.", file=sys.stderr)
        for bad in invalid_tasks:
            print(f"- Too short: '{bad}'", file=sys.stderr)
        print("Please provide clearer input and try again.", file=sys.stderr)
        return 2

    unclear_tasks = [t for t in tasks if _looks_like_gibberish(t)]
    if unclear_tasks:
        print("Some tasks look unclear or like gibberish. Please clarify before generating a quest.", file=sys.stderr)
        for bad in unclear_tasks:
            print(f"- Needs clarification: '{bad}'", file=sys.stderr)
        print("Provide simple, meaningful task descriptions and retry.", file=sys.stderr)
        return 2

    # Split compound items into atomic tasks deterministically to avoid model inventing tasks
    atomic_raw = _split_atomic_tasks(tasks)
    # Build cleaned pairs (raw -> cleaned without frequency, imperative phrasing)
    pairs: List[Tuple[str, str]] = []
    for r in atomic_raw:
        c = _strip_frequency_phrases(r)
        c = c.strip()
        if not c:
            continue
        c = _normalize_task_phrase(c)
        pairs.append((r, c))
    # Fallback if all cleaned tasks disappeared
    if not pairs:
        pairs = [(r, _normalize_task_phrase(r)) for r in atomic_raw if r and r.strip()]
    atomic_tasks = [c for (_, c) in pairs]

    messages = _build_messages(atomic_tasks, args.difficulty)

    if args.show_prompt and tasks:
        # Print as a readable block
        sys.stdout.write("\n=== SYSTEM ===\n" + messages[0]["content"] + "\n\n")
        sys.stdout.write("=== USER ===\n" + messages[1]["content"] + "\n")
        return 0
    elif args.show_prompt and not tasks:
        print("--show-prompt requires tasks to be provided.", file=sys.stderr)
        return 2

    new_obj: Dict[str, Any] = {}
    output_root: Optional[Dict[str, Any]] = None
    if tasks:
        # Group by frequency using RAW tasks, but output CLEANED tasks
        grouped: Dict[str, List[str]] = {}
        group_order: List[str] = []
        for (raw_t, clean_t) in pairs:
            f = _infer_frequency_from_text(raw_t)
            if f not in grouped:
                grouped[f] = []
                group_order.append(f)
            grouped[f].append(clean_t)

        if len(grouped) <= 1:
            # Single-quest path
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
                print("\n----- RAW MODEL OUTPUT -----\n", file=sys.stderr)
                print(raw, file=sys.stderr)
                return 3

            quest = _coerce_to_single_quest(new_obj)
            quest["tasks"] = [{"text": t} for t in atomic_tasks]
            # Infer frequency from RAW tasks
            quest["frequency"] = _infer_frequency([r for (r, _) in pairs])
            _normalize_quest(quest)
            _prune_fields_one(quest)

            if not args.no_style:
                try:
                    style_model = getattr(args, "style_model", None) or selected_model
                    _restyle_title_and_description(quest, host=args.host, model=style_model, base_temperature=max(args.temperature, 0.4))
                except Exception:
                    pass

            # Always wrap in an array payload shape
            output_root = {"quests": [quest]}
        else:
            # Multi-quest path: call the model per group and assemble
            quests_out: List[Dict[str, Any]] = []
            for f in group_order:
                group_tasks = grouped[f]
                group_messages = _build_messages(group_tasks, args.difficulty)
                if args.backend == "ollama":
                    selected_model = args.model
                    selected_max_tokens = args.max_tokens
                    if args.fast and selected_max_tokens == 2048:
                        selected_max_tokens = 512
                    raw = call_ollama(
                        group_messages,
                        model=selected_model,
                        host=args.host,
                        temperature=args.temperature,
                        max_tokens=selected_max_tokens,
                    )
                else:
                    raise RuntimeError(f"Unsupported backend: {args.backend}")

                try:
                    json_text = _extract_json(raw)
                    obj = json.loads(json_text)
                except Exception as e:
                    print("Failed to parse model output as JSON:", file=sys.stderr)
                    print(str(e), file=sys.stderr)
                    print("\n----- RAW MODEL OUTPUT (group) -----\n", file=sys.stderr)
                    print(raw, file=sys.stderr)
                    return 3

                quest = _coerce_to_single_quest(obj)
                quest["tasks"] = [{"text": t} for t in group_tasks]
                quest["frequency"] = f
                _normalize_quest(quest)
                _prune_fields_one(quest)
                if not args.no_style:
                    try:
                        style_model = getattr(args, "style_model", None) or selected_model
                        _restyle_title_and_description(quest, host=args.host, model=style_model, base_temperature=max(args.temperature, 0.4))
                    except Exception:
                        pass
                quests_out.append(quest)

            output_root = {"quests": quests_out}

    # Always print JSON to stdout; never write files.
    if args.out:
        print("Note: --out is deprecated and ignored; printing to stdout", file=sys.stderr)
    # Ensure we always return an array of quests, even if single
    if output_root is None:
        output_root = {"quests": []}
    elif isinstance(output_root, dict) and "quests" not in output_root:
        output_root = {"quests": [output_root]}
    print(json.dumps(output_root, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
