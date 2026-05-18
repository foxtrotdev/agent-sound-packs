#!/bin/bash
# update-pack.sh — Re-fetch installed sound packs from their original source.
#
# Usage:
#   update-pack.sh <pack-name>     # update one pack
#   update-pack.sh --all           # update every installed pack
#   update-pack.sh --check         # show which packs have new commits upstream (no fetch)
#   update-pack.sh --check <name>  # check one pack
#
# Each pack carries a .source file (written by add-pack.sh) recording the
# repo URL and commit SHA it was installed from. This script reads that and
# re-installs from the same source.

set -euo pipefail

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACKS_DIR="$ROOT/packs"
ADD_SCRIPT="$(dirname "$0")/add-pack.sh"
# When invoked via $ROOT/scripts/, add-pack.sh is in the same dir.
[ -x "$ADD_SCRIPT" ] || ADD_SCRIPT="$ROOT/scripts/add-pack.sh"
[ -x "$ADD_SCRIPT" ] || { echo "add-pack.sh not found alongside update-pack.sh" >&2; exit 1; }

CHECK_ONLY=0
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --all)   TARGETS=(__ALL__) ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) TARGETS+=("$arg") ;;
  esac
done
[ ${#TARGETS[@]} -ge 1 ] || { echo "usage: update-pack.sh <pack-name|--all> [--check]" >&2; exit 1; }

if [ "${TARGETS[0]}" = "__ALL__" ]; then
  TARGETS=()
  for d in "$PACKS_DIR"/*/; do
    [ -f "$d/.source" ] || continue
    TARGETS+=("$(basename "$d")")
  done
  [ ${#TARGETS[@]} -gt 0 ] || { echo "No packs with .source file found in $PACKS_DIR" >&2; exit 1; }
fi

remote_head() {
  # Print the current HEAD commit SHA of the given repo URL (default branch).
  git ls-remote "$1" HEAD 2>/dev/null | awk '{print $1; exit}'
}

for name in "${TARGETS[@]}"; do
  src="$PACKS_DIR/$name/.source"
  if [ ! -f "$src" ]; then
    echo "[$name] skipped — no .source file (pack installed manually?)"
    continue
  fi
  REPO=$(awk -F= '$1=="repo"{print $2}' "$src")
  LOCAL_SHA=$(awk -F= '$1=="commit"{print $2}' "$src")
  [ -n "$REPO" ] || { echo "[$name] .source missing repo="; continue; }

  REMOTE_SHA=$(remote_head "$REPO")
  if [ -z "$REMOTE_SHA" ]; then
    echo "[$name] unreachable: $REPO"
    continue
  fi

  if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    echo "[$name] up to date (${LOCAL_SHA:0:7})"
    continue
  fi

  echo "[$name] update available: ${LOCAL_SHA:0:7} -> ${REMOTE_SHA:0:7}"
  [ "$CHECK_ONLY" = 1 ] && continue

  if [ "$REPO" = "https://github.com/foxtrotdev/agent-sound-packs.git" ]; then
    "$ADD_SCRIPT" --force "$name"
  else
    "$ADD_SCRIPT" --force "$REPO" "$name"
  fi
done
