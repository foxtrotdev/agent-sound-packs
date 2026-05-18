#!/usr/bin/env bash
# test-sounds.sh — Play one random sound from each event pool of the active pack.
# Useful for verifying installation and pack curation.

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PLAYER="$ROOT/play-random.sh"

if [ ! -x "$PLAYER" ]; then
  echo "Player not found or not executable: $PLAYER" >&2
  exit 1
fi

PACK=$(cat "$ROOT/active-pack" 2>/dev/null || echo "(none)")
echo "Testing pack: $PACK"
echo ""

for event in session stop notification subagent compact; do
  echo "  Event: $event"
  "$PLAYER" "$event"
  sleep 1.8
done

echo ""
echo "Done."
