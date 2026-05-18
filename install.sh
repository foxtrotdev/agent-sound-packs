#!/bin/bash
# install.sh — Install claude-sound-packs into ~/.claude/sounds/.
# Copies scripts and pack definitions. Does NOT copy *.wav (you provide audio).
# Does NOT patch settings.json automatically — prints suggested hook config.

set -e
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${CCSP_ROOT:-$HOME/.claude/sounds}"

echo "Installing claude-sound-packs"
echo "  source: $SRC_DIR"
echo "  dest:   $DEST"
echo ""

mkdir -p "$DEST/scripts" "$DEST/packs"

# Scripts
cp "$SRC_DIR/scripts/play-random.sh" "$DEST/play-random.sh"
cp "$SRC_DIR/scripts/switch-pack.sh" "$DEST/switch-pack.sh"
cp "$SRC_DIR/scripts/transcribe.sh"  "$DEST/scripts/transcribe.sh"
chmod +x "$DEST/play-random.sh" "$DEST/switch-pack.sh" "$DEST/scripts/transcribe.sh"

# Pack definitions (pool.conf + transcripts.txt) — not wavs
for pack_dir in "$SRC_DIR/packs"/*/; do
  name=$(basename "$pack_dir")
  mkdir -p "$DEST/packs/$name"
  [ -f "$pack_dir/pool.conf" ]       && cp "$pack_dir/pool.conf"       "$DEST/packs/$name/"
  [ -f "$pack_dir/transcripts.txt" ] && cp "$pack_dir/transcripts.txt" "$DEST/packs/$name/"
  echo "  pack: $name (pool.conf installed — drop .wav files in $DEST/packs/$name/)"
done

# Default active pack
if [ ! -f "$DEST/active-pack" ]; then
  first_pack=$(ls "$SRC_DIR/packs" | head -1)
  echo "$first_pack" > "$DEST/active-pack"
  echo "  active-pack initialized: $first_pack"
fi

echo ""
echo "Done. Next steps:"
echo "  1) Drop .wav files into $DEST/packs/<pack-name>/"
echo "  2) Add hooks to ~/.claude/settings.json (see examples/settings.json)"
echo "  3) Switch packs: $DEST/switch-pack.sh <pack-name>"
