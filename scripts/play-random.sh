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
afplay "$DIR/$pick" &
