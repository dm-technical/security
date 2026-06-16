"""Locally hosted, Claude-powered solo D&D campaign.

Run:  ANTHROPIC_API_KEY=sk-ant-...  python app.py
Then open http://127.0.0.1:5000 in your browser.

Claude (claude-opus-4-8) is the Dungeon Master. Dice are rolled server-side for
fairness; a live character sheet is maintained as structured state. Campaigns
can be saved to and loaded from the ./saves directory, and the most recent turn
is always auto-saved so you can resume.
"""

from __future__ import annotations

import json
import os
import re
import time
import uuid

import anthropic
from flask import Flask, Response, jsonify, request, send_from_directory

import dm

HERE = os.path.dirname(os.path.abspath(__file__))
SAVE_DIR = os.path.join(HERE, "saves")
AUTOSAVE = os.path.join(SAVE_DIR, "_autosave.json")

os.makedirs(SAVE_DIR, exist_ok=True)

app = Flask(__name__, static_folder="static", template_folder="templates")

# In-memory campaigns: id -> {"messages": [...], "sheet": {...}, "title": str}
CAMPAIGNS: dict[str, dict] = {}

_client: anthropic.Anthropic | None = None


def client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic()
    return _client


def new_state(title: str = "New Campaign") -> dict:
    return {"messages": [], "sheet": {}, "title": title}


def transcript(state: dict) -> list[dict]:
    """Flatten the message history into renderable {role, text} lines for the UI."""
    out = []
    for msg in state["messages"]:
        content = msg["content"]
        if msg["role"] == "user":
            if isinstance(content, str):
                out.append({"role": "player", "text": content})
            # tool_result user turns carry no player-visible prose.
        else:  # assistant
            parts = []
            if isinstance(content, list):
                for block in content:
                    btype = block.get("type") if isinstance(block, dict) else None
                    if btype == "text":
                        parts.append(block.get("text", ""))
            elif isinstance(content, str):
                parts.append(content)
            text = "".join(parts).strip()
            if text:
                out.append({"role": "dm", "text": text})
    return out


def autosave(state: dict) -> None:
    try:
        with open(AUTOSAVE, "w", encoding="utf-8") as f:
            json.dump(state, f)
    except OSError:
        pass


def safe_name(name: str) -> str:
    name = re.sub(r"[^A-Za-z0-9 _-]", "", name or "").strip()
    return name[:60] or "campaign"


@app.route("/")
def index():
    return send_from_directory(app.template_folder, "index.html")


@app.route("/api/new", methods=["POST"])
def api_new():
    cid = uuid.uuid4().hex
    CAMPAIGNS[cid] = new_state()
    return jsonify({"id": cid})


@app.route("/api/send", methods=["POST"])
def api_send():
    data = request.get_json(force=True)
    cid = data.get("id")
    message = (data.get("message") or "").strip()
    state = CAMPAIGNS.get(cid)
    if state is None:
        return jsonify({"error": "Unknown campaign id. Start a new game."}), 404
    if not message:
        return jsonify({"error": "Empty message."}), 400

    state["messages"].append({"role": "user", "content": message})

    def generate():
        try:
            for event in dm.stream_dm_turn(client(), state):
                yield f"data: {json.dumps(event)}\n\n"
        except Exception as e:  # surface anything unexpected to the UI
            yield f"data: {json.dumps({'type': 'error', 'text': str(e)})}\n\n"
        autosave(state)
        yield f"data: {json.dumps({'type': 'done', 'sheet': state['sheet']})}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@app.route("/api/state/<cid>")
def api_state(cid):
    state = CAMPAIGNS.get(cid)
    if state is None:
        return jsonify({"error": "Unknown campaign id."}), 404
    return jsonify({"sheet": state["sheet"], "transcript": transcript(state), "title": state["title"]})


@app.route("/api/save", methods=["POST"])
def api_save():
    data = request.get_json(force=True)
    cid = data.get("id")
    state = CAMPAIGNS.get(cid)
    if state is None:
        return jsonify({"error": "Unknown campaign id."}), 404
    sheet_name = state["sheet"].get("name") if state["sheet"] else None
    name = safe_name(data.get("name") or sheet_name or "campaign")
    state["title"] = name
    path = os.path.join(SAVE_DIR, name + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    return jsonify({"ok": True, "name": name})


@app.route("/api/saves")
def api_saves():
    saves = []
    for fn in sorted(os.listdir(SAVE_DIR)):
        if fn.endswith(".json") and not fn.startswith("_"):
            path = os.path.join(SAVE_DIR, fn)
            saves.append({"name": fn[:-5], "mtime": os.path.getmtime(path)})
    has_autosave = os.path.exists(AUTOSAVE)
    saves.sort(key=lambda s: s["mtime"], reverse=True)
    return jsonify({"saves": saves, "autosave": has_autosave})


@app.route("/api/load", methods=["POST"])
def api_load():
    data = request.get_json(force=True)
    name = data.get("name")
    if name == "_autosave":
        path = AUTOSAVE
    else:
        path = os.path.join(SAVE_DIR, safe_name(name) + ".json")
    if not os.path.exists(path):
        return jsonify({"error": "Save not found."}), 404
    with open(path, encoding="utf-8") as f:
        state = json.load(f)
    state.setdefault("sheet", {})
    state.setdefault("title", name)
    cid = uuid.uuid4().hex
    CAMPAIGNS[cid] = state
    return jsonify({"id": cid, "sheet": state["sheet"], "transcript": transcript(state), "title": state["title"]})


if __name__ == "__main__":
    if not (os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")):
        print("\n  WARNING: ANTHROPIC_API_KEY is not set. The DM won't be able to respond.")
        print("  Set it first:  export ANTHROPIC_API_KEY=sk-ant-...\n")
    port = int(os.environ.get("PORT", "5000"))
    print(f"\n  ⚔️  Your D&D campaign is ready at  http://127.0.0.1:{port}\n")
    app.run(host="127.0.0.1", port=port, threaded=True, debug=False)
