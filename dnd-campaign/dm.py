"""Dungeon Master engine — wraps the Claude API with dice + character-sheet tools.

The DM is Claude (model claude-opus-4-8). Dice are rolled server-side so the
outcomes are genuinely random and fair; Claude requests them via tool use. The
character sheet is structured state that Claude maintains via a second tool, so
the UI can render a live sheet alongside the narration.
"""

from __future__ import annotations

import json
import random
import re

import anthropic

MODEL = "claude-opus-4-8"

SYSTEM_PROMPT = """\
You are the Dungeon Master (DM) for a single-player, solo tabletop role-playing \
campaign in the spirit of Dungeons & Dragons 5th Edition. The player is the lone \
hero of this story. You narrate the world, voice every non-player character, \
adjudicate the rules, and keep the adventure moving with vivid, evocative prose.

# Your responsibilities
- Set scenes richly but concisely (2-5 short paragraphs). Use sensory detail.
- Present meaningful choices. End most turns by inviting the player to act —
  but never put words in the player's mouth or decide their actions for them.
- Voice NPCs with distinct personalities. Use dialogue.
- Adjudicate fairly. When an action has a meaningful chance of failure (combat
  attacks, skill checks, saving throws, contested rolls), call the `roll_dice`
  tool rather than inventing a number. Tell the player what they rolled and what
  it means. Set sensible DCs (Easy 10, Medium 15, Hard 20).
- Run combat in rounds: describe enemy actions, roll attacks and damage, track
  hit points. Make it tense and cinematic.
- Reward clever play. Let the dice create drama, including failure — failure is
  interesting, not a dead end.

# Character sheet
At the very start of a NEW game, guide the player through quick character
creation: ask for a name, then help them pick a race, a class, and a short
background in a few exchanges. Roll or assign ability scores. THEN call
`update_character_sheet` to record the finished character, and begin the
adventure with an opening scene.

Whenever the character's state changes (takes damage, heals, levels up, gains
or loses an item, gains a condition like "poisoned"), call
`update_character_sheet` with the FULL updated sheet so the player's screen
stays accurate. Always keep `hp` within 0 and `max_hp`.

# Tone & pacing
- Second person ("You step into the tavern...").
- Keep the spotlight on the player. This is their story.
- Don't lecture about rules; just play. Don't break character except for brief,
  clearly-marked [DM: ...] asides when genuinely needed.
- Never decide the player's choices for them. Stop and let them act.

Begin by welcoming the player and starting character creation, unless a campaign
is already in progress (the conversation history will show this).
"""

TOOLS = [
    {
        "name": "roll_dice",
        "description": (
            "Roll dice using standard notation and get a fair random result. "
            "Use this for any attack roll, ability check, saving throw, damage "
            "roll, or random determination. Always narrate the outcome to the "
            "player after rolling."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "notation": {
                    "type": "string",
                    "description": "Dice notation, e.g. '1d20', '2d6+3', '1d20+5', '4d6'.",
                },
                "reason": {
                    "type": "string",
                    "description": "Short reason for the roll, e.g. 'Stealth check (DC 15)' or 'Longsword damage'.",
                },
            },
            "required": ["notation", "reason"],
        },
    },
    {
        "name": "update_character_sheet",
        "description": (
            "Create or update the player's character sheet. Call this at "
            "character creation and any time the character's state changes "
            "(HP, level, inventory, conditions). Always provide the COMPLETE "
            "current sheet, not a partial update."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "race": {"type": "string"},
                "char_class": {"type": "string", "description": "Class, e.g. 'Fighter'."},
                "level": {"type": "integer"},
                "hp": {"type": "integer", "description": "Current hit points."},
                "max_hp": {"type": "integer", "description": "Maximum hit points."},
                "ac": {"type": "integer", "description": "Armor class."},
                "stats": {
                    "type": "object",
                    "description": "Ability scores.",
                    "properties": {
                        "STR": {"type": "integer"},
                        "DEX": {"type": "integer"},
                        "CON": {"type": "integer"},
                        "INT": {"type": "integer"},
                        "WIS": {"type": "integer"},
                        "CHA": {"type": "integer"},
                    },
                },
                "inventory": {"type": "array", "items": {"type": "string"}},
                "conditions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Active conditions, e.g. ['poisoned'].",
                },
                "gold": {"type": "integer"},
                "notes": {"type": "string", "description": "Short notes: quest, location, etc."},
            },
            "required": ["name", "char_class", "level", "hp", "max_hp"],
        },
    },
]

_DICE_RE = re.compile(r"^\s*(\d*)\s*d\s*(\d+)\s*([+-]\s*\d+)?\s*$", re.IGNORECASE)


def roll_dice(notation: str):
    """Parse simple dice notation and roll it with real randomness.

    Returns a dict describing the roll, or an error dict on bad notation.
    """
    m = _DICE_RE.match(notation or "")
    if not m:
        return {"error": f"Could not parse dice notation: {notation!r}"}
    count = int(m.group(1)) if m.group(1) else 1
    sides = int(m.group(2))
    modifier = int(m.group(3).replace(" ", "")) if m.group(3) else 0

    # Guardrails against absurd requests.
    count = max(1, min(count, 100))
    sides = max(2, min(sides, 1000))

    rolls = [random.randint(1, sides) for _ in range(count)]
    total = sum(rolls) + modifier
    return {
        "notation": notation,
        "rolls": rolls,
        "modifier": modifier,
        "total": total,
        "sides": sides,
    }


def run_tool(name: str, tool_input: dict, state: dict):
    """Execute a tool call. Returns (result_for_model, ui_event_or_None)."""
    if name == "roll_dice":
        result = roll_dice(tool_input.get("notation", ""))
        result["reason"] = tool_input.get("reason", "")
        ui_event = {"type": "roll", **result}
        return result, ui_event
    if name == "update_character_sheet":
        state["sheet"] = tool_input
        return {"ok": True}, {"type": "sheet", "sheet": tool_input}
    return {"error": f"Unknown tool: {name}"}, None


def stream_dm_turn(client: anthropic.Anthropic, state: dict):
    """Run one DM turn, looping over tool calls, yielding UI events.

    Yields dicts: {"type": "text", "text": ...}, {"type": "roll", ...},
    {"type": "sheet", ...}, {"type": "error", ...}.
    `state` holds {"messages": [...], "sheet": {...}} and is mutated in place.
    """
    messages = state["messages"]

    while True:
        try:
            with client.messages.stream(
                model=MODEL,
                max_tokens=4000,
                system=SYSTEM_PROMPT,
                thinking={"type": "adaptive"},
                tools=TOOLS,
                messages=messages,
            ) as stream:
                for text in stream.text_stream:
                    yield {"type": "text", "text": text}
                final = stream.get_final_message()
        except anthropic.APIError as e:
            yield {"type": "error", "text": f"API error: {getattr(e, 'message', str(e))}"}
            return

        # Record the assistant turn verbatim (preserves thinking + tool_use
        # blocks). Store as plain dicts so the whole campaign stays
        # JSON-serializable for saving; the API accepts dicts on replay.
        assistant_content = [block.model_dump() for block in final.content]
        messages.append({"role": "assistant", "content": assistant_content})

        if final.stop_reason != "tool_use":
            return

        tool_results = []
        for block in final.content:
            if block.type == "tool_use":
                result, ui_event = run_tool(block.name, block.input, state)
                if ui_event is not None:
                    yield ui_event
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                    }
                )
        messages.append({"role": "user", "content": tool_results})
        # Loop again so Claude can narrate the tool outcomes.
