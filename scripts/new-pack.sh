#!/usr/bin/env bash
# new-pack.sh — Scaffold a new sound pack.
# Creates packs/<name>/ with an empty pool.conf template ready to fill in.
#
# Usage: new-pack.sh <pack-name>

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
NAME="${1:?usage: new-pack.sh <pack-name>}"
DIR="$ROOT/packs/$NAME"

if [ -d "$DIR" ]; then
  echo "Pack already exists: $DIR" >&2
  exit 1
fi

mkdir -p "$DIR"

cat > "$DIR/pool.conf" <<EOF
# $NAME sound pack — event → wav pool.
# Each POOL_<EVENT> is a bash array of wav filenames inside this folder.
# Empty array = silence for that event. Add filenames one per line.

POOL_STOP=(
  # task done / victory sounds
)

POOL_NOTIFICATION=(
  # "hey, I need you" / awaiting-input sounds
)

POOL_SUBAGENT=(
  # small wins / subagent finished
)

POOL_SESSION=(
  # session start / greeting
)

POOL_COMPACT=(
  # negative / context-bloat / "you've been long-winded"
)
EOF

echo "Created: $DIR"
echo ""
echo "Next steps:"
echo "  1) Drop your .wav files into $DIR/"
echo "  2) Edit $DIR/pool.conf and list the filenames under each event"
echo "  3) Activate: $ROOT/switch-pack.sh $NAME"
