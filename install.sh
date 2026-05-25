#!/usr/bin/env bash
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
# Pack management (dispatcher + add / update / list-remote / validate / new)
for s in sound.sh add-pack.sh update-pack.sh list-remote.sh validate-pack.sh new-pack.sh; do
  [ -f "$SRC_DIR/scripts/$s" ] && cp "$SRC_DIR/scripts/$s" "$DEST/scripts/$s"
done
chmod +x "$DEST/play-random.sh" "$DEST/switch-pack.sh" "$DEST"/scripts/*.sh

# Detect repo + commit so update-pack.sh can refresh bundled packs later.
# (Without a .source file, update-pack.sh treats a pack as manually installed and skips it.)
SRC_REPO=""
SRC_COMMIT=""
if command -v git >/dev/null 2>&1 && git -C "$SRC_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  SRC_REPO=$(git -C "$SRC_DIR" config --get remote.origin.url 2>/dev/null || true)
  SRC_COMMIT=$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || true)
fi
SRC_REPO="${SRC_REPO:-https://github.com/foxtrotdev/agent-sound-packs.git}"

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
  # Write .source so update-pack.sh can later refresh this pack from upstream.
  if [ -n "$SRC_COMMIT" ]; then
    {
      echo "repo=$SRC_REPO"
      echo "commit=$SRC_COMMIT"
      echo "installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$DEST/packs/$name/.source"
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

# Seed a default config file if absent, so users have a discoverable knob.
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sound-packs"
CFG_FILE="$CFG_DIR/config.json"
if [ ! -f "$CFG_FILE" ]; then
  mkdir -p "$CFG_DIR"
  cat > "$CFG_FILE" <<'JSON'
{
  "_comment": "agent-sound-packs config. enabled: 0|1, volume: 0..100, pack: pack-name (overrides active-pack file).",
  "enabled": 1,
  "volume": 100
}
JSON
  echo ""
  echo "  config seeded: $CFG_FILE"
fi

echo ""
echo "Done. Next steps (all via one dispatcher — sound.sh <subcommand>):"
echo "  1) Test playback:       $DEST/scripts/sound.sh test"
echo "  2) Merge hooks into ~/.claude/settings.json:"
echo "       jq -s '.[0] * .[1]' ~/.claude/settings.json $HOOKS_FILE > /tmp/cc.json && mv /tmp/cc.json ~/.claude/settings.json"
echo "     Or copy/paste the contents of $HOOKS_FILE manually."
echo "  3) Switch packs:        $DEST/scripts/sound.sh switch <pack-name>"
echo "  4) Browse remote packs: $DEST/scripts/sound.sh remote"
echo "  5) Install a pack:      $DEST/scripts/sound.sh add <name>"
echo "  6) Update packs:        $DEST/scripts/sound.sh update --all"
echo ""
echo "Config (volume + mute):"
echo "  File:   $CFG_FILE       → { \"enabled\": 0|1, \"volume\": 0..100 }"
echo "  Env:    CCSP_ENABLED=0  (mute)   CCSP_VOLUME=50  (half)"
echo "  Env > config file. Both honored by play-random.sh."

# First-run intro: play one sound from active pack so user hears it works.
# Skipped on --no-intro (CI / non-interactive re-runs).
WANT_INTRO=1
for arg in "$@"; do
  [ "$arg" = "--no-intro" ] && WANT_INTRO=0
done
if [ "$WANT_INTRO" = 1 ] && [ -t 1 ]; then
  echo ""
  echo "Playing intro from active pack '$(cat "$DEST/active-pack" 2>/dev/null)' ..."
  CCSP_ROOT="$DEST" CCSP_DEBOUNCE_MS=0 "$DEST/play-random.sh" session 2>/dev/null || true
  # Give the backgrounded player a moment before the shell exits.
  sleep 1 || true
fi
