#!/bin/bash
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

set -u

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACK=$(cat "$ROOT/active-pack" 2>/dev/null || echo "mortal-kombat")
DIR="$ROOT/packs/$PACK"
CONF="$DIR/pool.conf"

[ -f "$CONF" ] || exit 0

case "$1" in
  stop|notification|subagent|session|compact) EVENT=$(echo "$1" | tr '[:lower:]' '[:upper:]') ;;
  *) exit 1 ;;
esac

# Safe parser: extract one POOL_<EVENT>=( ... ) block, take only safe basenames.
# Awk reads the file byte-stream, flips a flag on the opening line, captures
# entries until the closing ')'. Never invokes shell.
pool=$(awk -v want="POOL_${EVENT}=(" '
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
' "$CONF" \
  | tr ' \t' '\n\n' \
  | grep -E '^[a-zA-Z0-9._-]+\.(wav|mp3|ogg|flac)$' \
  || true)

# To array (newline-separated)
IFS=$'\n' read -r -d '' -a entries < <(printf '%s\0' "$pool")
[ "${#entries[@]}" -eq 0 ] && exit 0

pick="${entries[$RANDOM % ${#entries[@]}]}"
FILE="$DIR/$pick"
[ -f "$FILE" ] || exit 0

# Auto-detect audio player. Backgrounded so the hook returns fast.
# Override with CCSP_PLAYER="my-player" to skip detection.
if   [ -n "${CCSP_PLAYER:-}" ];                 then $CCSP_PLAYER "$FILE" &
elif command -v afplay         >/dev/null 2>&1; then afplay  "$FILE" &
elif command -v pw-play        >/dev/null 2>&1; then pw-play "$FILE" &
elif command -v paplay         >/dev/null 2>&1; then paplay  "$FILE" &
elif command -v aplay          >/dev/null 2>&1; then aplay -q "$FILE" &
elif command -v ffplay         >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet "$FILE" &
elif command -v powershell.exe >/dev/null 2>&1; then
  WPATH=$(wslpath -w "$FILE" 2>/dev/null || echo "$FILE")
  powershell.exe -c "(New-Object Media.SoundPlayer '$WPATH').PlaySync()" &
else
  echo "[agent-sound-packs] no audio player found (tried afplay, pw-play, paplay, aplay, ffplay, powershell.exe)" >&2
fi
exit 0
