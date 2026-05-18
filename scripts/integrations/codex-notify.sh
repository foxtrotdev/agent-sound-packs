#!/bin/bash
# codex-notify.sh — OpenAI Codex CLI notify-hook adapter.
#
# Codex CLI calls the `notify` program with a single JSON-string argument
# describing the event, e.g.:
#   {"type":"agent-turn-complete","input-messages":[...],"last-assistant-message":"..."}
#
# This adapter maps Codex event types to agent-sound-packs events and calls
# play-random.sh.
#
# Install into ~/.codex/config.toml:
#   notify = ["bash", "/Users/YOU/.claude/sounds/scripts/integrations/codex-notify.sh"]

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PLAYER="$ROOT/play-random.sh"
JSON="${1:-}"

[ -x "$PLAYER" ] || exit 0
[ -n "$JSON" ]   || exit 0

# Extract "type" field from JSON without requiring jq.
TYPE=$(printf '%s' "$JSON" | grep -oE '"type"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')

case "$TYPE" in
  agent-turn-complete)
    "$PLAYER" stop
    ;;
  *)
    # Unknown event — stay silent.
    exit 0
    ;;
esac
