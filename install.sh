#!/bin/bash
# install.sh — Install agent-sound-packs into ~/.claude/sounds/ (or $CCSP_ROOT).
# Copies scripts, pool.conf, transcripts.txt, and any *.wav bundled in the repo.
# Does NOT patch settings.json automatically — prints suggested hook config.
#
# Flags:
#   --no-wavs   Skip copying bundled *.wav files (for re-runs that only refresh configs).

set -e
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${CCSP_ROOT:-$HOME/.claude/sounds}"

COPY_WAVS=1
for arg in "$@"; do
  [ "$arg" = "--no-wavs" ] && COPY_WAVS=0
done

echo "Installing agent-sound-packs"
echo "  source: $SRC_DIR"
echo "  dest:   $DEST"
echo "  wavs:   $([ "$COPY_WAVS" = 1 ] && echo "yes" || echo "no (--no-wavs)")"
echo ""

mkdir -p "$DEST/scripts" "$DEST/packs"

# Scripts
cp "$SRC_DIR/scripts/play-random.sh" "$DEST/play-random.sh"
cp "$SRC_DIR/scripts/switch-pack.sh" "$DEST/switch-pack.sh"
cp "$SRC_DIR/scripts/transcribe.sh"  "$DEST/scripts/transcribe.sh"
[ -f "$SRC_DIR/scripts/test-sounds.sh" ] && cp "$SRC_DIR/scripts/test-sounds.sh" "$DEST/scripts/test-sounds.sh"
# Pack management (add / update / list-remote / validate)
for s in add-pack.sh update-pack.sh list-remote.sh validate-pack.sh; do
  [ -f "$SRC_DIR/scripts/$s" ] && cp "$SRC_DIR/scripts/$s" "$DEST/scripts/$s"
done
chmod +x "$DEST/play-random.sh" "$DEST/switch-pack.sh" "$DEST"/scripts/*.sh

# Pack definitions + bundled wavs
for pack_dir in "$SRC_DIR/packs"/*/; do
  name=$(basename "$pack_dir")
  mkdir -p "$DEST/packs/$name"
  [ -f "$pack_dir/pool.conf" ]       && cp "$pack_dir/pool.conf"       "$DEST/packs/$name/"
  [ -f "$pack_dir/transcripts.txt" ] && cp "$pack_dir/transcripts.txt" "$DEST/packs/$name/"
  wav_count=0
  if [ "$COPY_WAVS" = 1 ]; then
    for w in "$pack_dir"*.wav; do
      [ -f "$w" ] || continue
      cp "$w" "$DEST/packs/$name/"
      wav_count=$((wav_count + 1))
    done
  fi
  echo "  pack: $name (pool.conf + $wav_count wavs)"
done

# Default active pack — prefer mortal-kombat if present, else first
if [ ! -f "$DEST/active-pack" ]; then
  if [ -d "$DEST/packs/mortal-kombat" ]; then
    echo "mortal-kombat" > "$DEST/active-pack"
  else
    ls "$DEST/packs" | head -1 > "$DEST/active-pack"
  fi
  echo "  active-pack initialized: $(cat "$DEST/active-pack")"
fi

# Emit ready-to-paste hooks JSON with the actual install path baked in
HOOKS_FILE="$DEST/suggested-hooks.json"
cat > "$HOOKS_FILE" <<JSON
{
  "_comment": "Merge this 'hooks' block into ~/.claude/settings.json (Claude Code). Paths already point at your install.",
  "hooks": {
    "Stop":         [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh stop"}]}],
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh notification"}]}],
    "SubagentStop": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh subagent"}]}],
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh session"}]}],
    "PreCompact":   [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh compact"}]}]
  }
}
JSON
echo ""
echo "  hooks JSON written: $HOOKS_FILE"

echo ""
echo "Done. Next steps:"
echo "  1) Test playback:  $DEST/scripts/test-sounds.sh"
echo "  2) Merge hooks into ~/.claude/settings.json:"
echo "       jq -s '.[0] * .[1]' ~/.claude/settings.json $HOOKS_FILE > /tmp/cc.json && mv /tmp/cc.json ~/.claude/settings.json"
echo "     Or copy/paste the contents of $HOOKS_FILE manually."
echo "  3) Switch packs:        $DEST/switch-pack.sh <pack-name>"
echo "  4) Browse remote packs: $DEST/scripts/list-remote.sh"
echo "  5) Install a pack:      $DEST/scripts/add-pack.sh <name>"
echo "  6) Update packs:        $DEST/scripts/update-pack.sh --all"
