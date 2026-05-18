#!/bin/bash
# play-random.sh — Pick random sound from event pool of active pack.
# Usage: play-random.sh <event>
# Events: stop | notification | subagent | session | compact

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACK=$(cat "$ROOT/active-pack" 2>/dev/null || echo "mortal-kombat")
DIR="$ROOT/packs/$PACK"

[ -f "$DIR/pool.conf" ] || exit 0
# shellcheck source=/dev/null
source "$DIR/pool.conf"

case "$1" in
  stop)          pool=("${POOL_STOP[@]}") ;;
  notification)  pool=("${POOL_NOTIFICATION[@]}") ;;
  subagent)      pool=("${POOL_SUBAGENT[@]}") ;;
  session)       pool=("${POOL_SESSION[@]}") ;;
  compact)       pool=("${POOL_COMPACT[@]}") ;;
  *)             exit 1 ;;
esac

[ "${#pool[@]}" -eq 0 ] && exit 0
pick="${pool[$RANDOM % ${#pool[@]}]}"
FILE="$DIR/$pick"
[ -f "$FILE" ] || exit 0

# Auto-detect audio player. Backgrounded so hook returns fast.
# Override with CCSP_PLAYER="my-player" to skip detection.
if   [ -n "${CCSP_PLAYER:-}" ];          then $CCSP_PLAYER "$FILE" &
elif command -v afplay   >/dev/null 2>&1; then afplay  "$FILE" &
elif command -v pw-play  >/dev/null 2>&1; then pw-play "$FILE" &
elif command -v paplay   >/dev/null 2>&1; then paplay  "$FILE" &
elif command -v aplay    >/dev/null 2>&1; then aplay -q "$FILE" &
elif command -v ffplay   >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet "$FILE" &
elif command -v powershell.exe >/dev/null 2>&1; then
  WPATH=$(wslpath -w "$FILE" 2>/dev/null || echo "$FILE")
  powershell.exe -c "(New-Object Media.SoundPlayer '$WPATH').PlaySync()" &
else
  echo "[agent-sound-packs] no audio player found (tried afplay, pw-play, paplay, aplay, ffplay, powershell.exe)" >&2
  exit 0
fi
exit 0
