#!/usr/bin/env bash
# sound.sh — Single entry point for all sound-pack management.
#
# Usage: sound.sh <subcommand> [args...]
#
#   (no args) | list        Show current pack + available packs.
#   switch <name>           Activate a pack (plays a test sound).
#   update [name|--all]     Refresh installed packs from source (default: --all).
#                           Also: update --check [name]  (no fetch, just report).
#   test                    Play one random sound from each event pool.
#   new <name>              Scaffold a new pack folder with a pool.conf template.
#   add <name|git-url>      Install a pack from the catalog or a git repo.
#   remote                  Browse the official pack catalog (nothing downloaded).
#   validate <name>         Check a pack's pool.conf + wav files.
#   volume <0-100>          Set playback volume (writes config.json).
#   mute | unmute           Silence / re-enable all sounds.
#   help                    Show this help.
#
# Backward compat: `sound.sh <pack-name>` (a bare existing pack) switches to it.

set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACKS_DIR="$ROOT/packs"

# Resolve a sibling script across both layouts: installed (switch-pack.sh at
# root, others under scripts/) and repo (everything under scripts/).
find_script() {
  local name="$1" d
  for d in "$SELFDIR" "$SELFDIR/scripts" "$SELFDIR/.." "$SELFDIR/../scripts"; do
    [ -f "$d/$name" ] && { printf '%s\n' "$d/$name"; return 0; }
  done
  echo "sound.sh: cannot find $name" >&2
  return 1
}

run() {
  local s
  s="$(find_script "$1")" || exit 1
  shift
  CCSP_ROOT="$ROOT" bash "$s" "$@"
}

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

CFG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sound-packs/config.json"

# cfg_get <key> — print the value (number or bare string), empty if unset.
cfg_get() {
  [ -f "$CFG_FILE" ] || return 0
  grep -oE "\"$1\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[0-9]+)" "$CFG_FILE" 2>/dev/null \
    | head -1 | sed -E 's/.*:[[:space:]]*//; s/"//g' || true
}

# cfg_set <enabled> <volume> [pack] — rewrite config.json (same shape play-random reads).
cfg_set() {
  mkdir -p "$(dirname "$CFG_FILE")"
  {
    printf '{\n  "enabled": %s,\n  "volume": %s' "$1" "$2"
    [ -n "${3:-}" ] && printf ',\n  "pack": "%s"' "$3"
    printf '\n}\n'
  } > "$CFG_FILE"
}

sub="${1-}"
[ $# -gt 0 ] && shift || true

case "$sub" in
  ""|list|ls|packs)            run switch-pack.sh ;;
  switch|use|set)              run switch-pack.sh "$@" ;;
  update|up)
    if [ $# -eq 0 ]; then run update-pack.sh --all; else run update-pack.sh "$@"; fi ;;
  test|t)                      run test-sounds.sh "$@" ;;
  new|create)                  run new-pack.sh "$@" ;;
  add|install)                 run add-pack.sh "$@" ;;
  remote|catalog|available)    run list-remote.sh "$@" ;;
  validate)
    # validate-pack.sh wants a directory path; accept a bare pack name too.
    if [ $# -ge 1 ] && [ -d "$PACKS_DIR/$1" ]; then
      run validate-pack.sh "$PACKS_DIR/$1"
    else
      run validate-pack.sh "$@"
    fi ;;
  volume|vol)
    v="${1:-}"
    case "$v" in ''|*[!0-9]*) echo "usage: sound.sh volume <0-100>" >&2; exit 1 ;; esac
    if [ "$v" -gt 100 ]; then v=100; fi
    e="$(cfg_get enabled)"; p="$(cfg_get pack)"
    cfg_set "${e:-1}" "$v" "$p"
    echo "volume set to $v" ;;
  mute)
    vv="$(cfg_get volume)"; p="$(cfg_get pack)"
    cfg_set 0 "${vv:-100}" "$p"
    echo "muted — all sounds off" ;;
  unmute)
    vv="$(cfg_get volume)"; p="$(cfg_get pack)"
    cfg_set 1 "${vv:-100}" "$p"
    echo "unmuted" ;;
  help|-h|--help)              usage ;;
  *)
    # Backward compat: bare existing pack name → switch to it.
    if [ -d "$PACKS_DIR/$sub" ]; then
      run switch-pack.sh "$sub"
    else
      echo "Unknown subcommand: $sub" >&2
      echo "" >&2
      usage >&2
      exit 1
    fi ;;
esac
