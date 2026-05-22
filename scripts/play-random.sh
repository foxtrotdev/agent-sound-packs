#!/usr/bin/env bash
# play-random.sh — Pick a random sound from the active pack's event pool and play it.
#
# Usage: play-random.sh <event>
# Events: stop | notification | subagent | session | compact
#
# SECURITY: pool.conf is NEVER `source`d. It is parsed as plain text,
# extracting only basenames matching ^[a-zA-Z0-9._-]+\.(wav|mp3|ogg|flac)$
# from POOL_<EVENT>=(...) blocks. Any shell code, command substitution,
# pipes, redirects, or paths with slashes are silently ignored.
# This means a malicious / corrupted pool.conf cannot execute code.
#
# CONFIG (precedence: env var > config file > built-in default):
#   CCSP_ENABLED      1|0           mute switch (default 1)
#   CCSP_VOLUME       0..100        playback volume (default 100; not all players honor)
#   CCSP_DEBOUNCE_MS  int           debounce window (default 2000)
#   CCSP_PLAYER       cmd           override audio player
#   CCSP_ROOT         path          install dir (default ~/.claude/sounds)
#
# Config file (JSON, optional):
#   ${XDG_CONFIG_HOME:-$HOME/.config}/agent-sound-packs/config.json
#   { "enabled": 1, "volume": 70 }
# Only digits are accepted; no shell eval. Missing file = use env or defaults.

set -u

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sound-packs"
CFG_FILE="$CFG_DIR/config.json"

# Safe JSON int extractor: returns digits only, ignores quoted/string values.
# Pattern: "key" : <digits>   — anything else is dropped.
_cfg_int() {
  [ -f "$CFG_FILE" ] || return 0
  grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9]+" "$CFG_FILE" 2>/dev/null \
    | grep -oE '[0-9]+$' | head -1
}

# Safe JSON string extractor: only [a-zA-Z0-9._-] characters, max 64 chars.
# Pattern: "key" : "<safe-chars>"   — anything else is dropped.
_cfg_str() {
  [ -f "$CFG_FILE" ] || return 0
  grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[a-zA-Z0-9._-]{1,64}\"" "$CFG_FILE" 2>/dev/null \
    | grep -oE '"[a-zA-Z0-9._-]{1,64}"$' | tr -d '"' | head -1
}

# Resolve config: env > file > default.
CFG_ENABLED=$(_cfg_int enabled)
CFG_VOLUME=$(_cfg_int volume)
CFG_PACK=$(_cfg_str pack)

ENABLED="${CCSP_ENABLED:-${CFG_ENABLED:-1}}"
VOLUME="${CCSP_VOLUME:-${CFG_VOLUME:-100}}"

# Mute switch.
case "$ENABLED" in 0|false|no|off) exit 0 ;; esac

# Clamp volume to 0..100.
case "$VOLUME" in *[!0-9]*|"") VOLUME=100 ;; esac
[ "$VOLUME" -gt 100 ] 2>/dev/null && VOLUME=100

# Pack resolution: config "pack" > $ROOT/active-pack file > "mortal-kombat".
# Config-file pack lets plugin-installed users switch packs without writing
# to the (often read-only) plugin install dir.
PACK="${CFG_PACK:-$(cat "$ROOT/active-pack" 2>/dev/null || echo "mortal-kombat")}"
DIR="$ROOT/packs/$PACK"
CONF="$DIR/pool.conf"

[ -f "$CONF" ] || exit 0

case "$1" in
  stop|notification|subagent|session|compact) EVENT=$(echo "$1" | tr '[:lower:]' '[:upper:]') ;;
  *) exit 1 ;;
esac

# Debounce: skip play if the previous play fired < CCSP_DEBOUNCE_MS ago.
# Prevents Stop+SubagentStop double-trigger and Notification permission-prompt spam.
# Set CCSP_DEBOUNCE_MS=0 to disable. Default 2000 ms.
DEBOUNCE_MS="${CCSP_DEBOUNCE_MS:-2000}"
LOCK="${TMPDIR:-/tmp}/.ccsp_last_play"
# Cross-platform ms epoch: GNU date → perl → seconds*1000 fallback.
NOW_MS=$(date +%s%3N 2>/dev/null)
case "$NOW_MS" in
  *N|*[!0-9]*|"") NOW_MS=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000' 2>/dev/null || echo $(($(date +%s) * 1000))) ;;
esac
LAST_MS=$(cat "$LOCK" 2>/dev/null)
case "$LAST_MS" in *[!0-9]*|"") LAST_MS=0 ;; esac
if [ "$DEBOUNCE_MS" -gt 0 ] 2>/dev/null && [ $((NOW_MS - LAST_MS)) -lt "$DEBOUNCE_MS" ]; then
  exit 0
fi

# Safe parser: extract one POOL_<EVENT>=( ... ) block, take only safe basenames.
# Awk reads the file byte-stream, flips a flag on the opening line, captures
# entries until the closing ')'. Never invokes shell.
pool=$(tr -d '\r' < "$CONF" | awk -v want="POOL_${EVENT}=(" '
  BEGIN { in_block = 0 }
  {
    line = $0
    # Look for the opener anywhere on the line.
    pos = index(line, want)
    if (in_block == 0 && pos > 0) {
      in_block = 1
      line = substr(line, pos + length(want))
    }
    if (in_block == 0) next

    # Close at first ")" — emit everything before it then stop.
    cpos = index(line, ")")
    if (cpos > 0) {
      print substr(line, 1, cpos - 1)
      exit
    }
    print line
  }
' \
  | tr ' \t' '\n\n' \
  | grep -E '^[a-zA-Z0-9._-]+\.(wav|mp3|ogg|flac)$' \
  || true)

# To array (newline-separated)
IFS=$'\n' read -r -d '' -a entries < <(printf '%s\0' "$pool")
[ "${#entries[@]}" -eq 0 ] && exit 0

pick="${entries[$RANDOM % ${#entries[@]}]}"
FILE="$DIR/$pick"
[ -f "$FILE" ] || exit 0

# Update debounce lock — only when we actually play.
echo "$NOW_MS" > "$LOCK" 2>/dev/null || true

# Volume mapping per player. 0..100 → player-native scale.
#   afplay  -v 0.0..1.0          → VOLUME/100 (awk for float)
#   pw-play --volume 0.0..1.0    → VOLUME/100
#   paplay  --volume 0..65536    → VOLUME*655 (rounded)
#   ffplay  -volume 0..100       → VOLUME (direct)
#   aplay / powershell           → no volume support, ignored
VOL_FLOAT=$(awk -v v="$VOLUME" 'BEGIN { printf "%.3f", v/100 }')
VOL_PAPLAY=$(( VOLUME * 65536 / 100 ))

# Auto-detect audio player. Backgrounded so the hook returns fast.
# Override with CCSP_PLAYER="my-player" to skip detection.
if   [ -n "${CCSP_PLAYER:-}" ];                 then $CCSP_PLAYER "$FILE" &
elif command -v afplay         >/dev/null 2>&1; then afplay  -v "$VOL_FLOAT" "$FILE" &
elif command -v pw-play        >/dev/null 2>&1; then pw-play --volume="$VOL_FLOAT" "$FILE" &
elif command -v paplay         >/dev/null 2>&1; then paplay  --volume="$VOL_PAPLAY" "$FILE" &
elif command -v aplay          >/dev/null 2>&1; then aplay -q "$FILE" &
elif command -v ffplay         >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet -volume "$VOLUME" "$FILE" &
elif command -v powershell.exe >/dev/null 2>&1; then
  WPATH=$(wslpath -w "$FILE" 2>/dev/null || echo "$FILE")
  powershell.exe -c "(New-Object Media.SoundPlayer '$WPATH').PlaySync()" &
else
  echo "[agent-sound-packs] no audio player found (tried afplay, pw-play, paplay, aplay, ffplay, powershell.exe)" >&2
fi
exit 0
