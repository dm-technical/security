#!/usr/bin/env bash
# Convenience launcher: sets up a venv, installs deps, and starts the game.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d .venv ]; then
  echo "Creating virtual environment..."
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo
  echo "  Set your API key first:  export ANTHROPIC_API_KEY=sk-ant-..."
  echo "  (get one at https://console.anthropic.com)"
  echo
fi

exec python app.py
