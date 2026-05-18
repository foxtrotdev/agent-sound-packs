#!/usr/bin/env bash
# switch-pack.sh — Switch active sound pack.
# Usage: switch-pack.sh [pack-name]
#   no args   → show current + list available
#   <name>    → activate pack, play test sound

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACK_FILE="$ROOT/active-pack"
PACKS_DIR="$ROOT/packs"

if [ -z "$1" ]; then
  current=$(cat "$PACK_FILE" 2>/dev/null || echo "(none)")
  echo "Current pack: $current"
  echo "Available packs:"
  if [ -d "$PACKS_DIR" ]; then
    for d in "$PACKS_DIR"/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      echo "  - $name"
    done
  fi
  exit 0
fi

if [ ! -d "$PACKS_DIR/$1" ]; then
  echo "Pack not found: $1" >&2
  echo "Looked in: $PACKS_DIR/$1" >&2
  exit 1
fi

echo "$1" > "$PACK_FILE"
echo "Active pack: $1"
"$ROOT/play-random.sh" stop 2>/dev/null
