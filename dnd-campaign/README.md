# ⚔️ Claude's Dungeon — a locally hosted, Claude-powered solo D&D campaign

A self-contained web app you run on your own machine. **Claude (claude-opus-4-8)
is your Dungeon Master**: it narrates the world, voices every NPC, runs combat,
and adjudicates the rules of a D&D 5e-style solo adventure. You play in your
browser.

Features:

- 🎭 **Claude as DM** — streaming, in-character narration with adaptive thinking.
- 🎲 **Fair dice** — rolls happen server-side with real randomness; Claude
  requests them via tool use (attacks, skill checks, saving throws, damage),
  and every roll shows up in the dice log.
- 📜 **Live character sheet** — HP bar, ability scores, inventory, conditions,
  gold. Claude keeps it up to date as the story unfolds (structured tool use).
- 💾 **Save & resume** — name and save campaigns to `./saves`; the last turn is
  always auto-saved so you can pick up where you left off.
- 🖥️ **100% local** — a small Flask server on `127.0.0.1`. Your only outbound
  calls are to the Anthropic API with your own key.

## Quick start

You need Python 3.9+ and an Anthropic API key (https://console.anthropic.com).

```bash
cd dnd-campaign
export ANTHROPIC_API_KEY=sk-ant-...
./run.sh
```

`run.sh` creates a virtualenv, installs dependencies, and launches the server.
Then open **http://127.0.0.1:5000** and start playing.

### Manual start (no script)

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
python app.py
```

## How to play

- A new campaign starts automatically. The DM walks you through character
  creation (name → race → class → background → ability scores), then opens the
  adventure.
- Type what you want to do in the box and press **Enter** (Shift+Enter for a
  newline). Speak in first person or describe your action — e.g.
  *"I search the desk for hidden compartments"* or *"I attack the goblin."*
- When an action could fail, the DM rolls dice for you and narrates the result.
- Use **Save** to name and store your campaign, **Load** to resume one (or
  resume the auto-saved session), and **New Campaign** to start fresh.

## How it works

| Piece | What it does |
|-------|--------------|
| `app.py` | Flask server: serves the UI and streams DM turns over Server-Sent Events; handles save/load/autosave. |
| `dm.py` | The DM engine: the system prompt, the `roll_dice` and `update_character_sheet` tools, and the Claude streaming + tool-use loop. |
| `templates/index.html`, `static/` | The browser UI (chat, dice log, character sheet). |
| `saves/` | Saved campaigns (JSON). Auto-save lives in `saves/_autosave.json`. |

The DM loop streams Claude's narration token-by-token. When Claude calls a tool,
the server executes it (rolling real dice or recording the sheet), streams a UI
event, feeds the result back to Claude, and lets it narrate the outcome.

## Configuration

- `ANTHROPIC_API_KEY` (or `ANTHROPIC_AUTH_TOKEN`) — required.
- `PORT` — change the port (default `5000`).
- Model is `claude-opus-4-8`, set in `dm.py` (`MODEL`). Swap to
  `claude-sonnet-4-6` there for lower cost.

## Notes

- This is a single-player app meant for `localhost`; it has no authentication.
  Don't expose it to the open internet as-is.
- API usage is billed to your Anthropic account.
