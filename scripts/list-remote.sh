#!/bin/bash
# list-remote.sh — Show every pack you can install from the official catalog.
#
# Just run it:
#   list-remote.sh
#
# Prints a small table: name, language, type (voice or sfx), number of clips,
# one-line description. Nothing is downloaded — this is just for browsing.
# Copy a name from the NAME column, then run:
#   add-pack.sh <that-name>

set -euo pipefail

REGISTRY_RAW="https://raw.githubusercontent.com/foxtrotdev/agent-sound-packs/main/packs.json"
API_DIR="https://api.github.com/repos/foxtrotdev/agent-sound-packs/contents/packs"

fetch() { curl -sfL --max-time 15 "$1"; }

if MAN=$(fetch "$REGISTRY_RAW") && [ -n "$MAN" ]; then
  if command -v jq >/dev/null 2>&1; then
    echo "$MAN" | jq -r '
      .packs | sort_by(.name)[] |
      "\(.name)\t\(.language // "?")\t\(if .voice then "voice" else "sfx" end)\t\(.wav_count // "?")\t\(.description // "")"
    ' | awk -F'\t' 'BEGIN{
      printf "%-26s %-4s %-5s %5s  %s\n", "NAME", "LANG", "TYPE", "WAVS", "DESCRIPTION"
      printf "%-26s %-4s %-5s %5s  %s\n", "----", "----", "----", "----", "-----------"
    }
    {printf "%-26s %-4s %-5s %5s  %s\n", $1, $2, $3, $4, $5}'
    echo ""
    echo "Install:  add-pack.sh <name>"
    echo "Update:   update-pack.sh <name>   |   update-pack.sh --all"
    exit 0
  else
    echo "(jq not installed — raw packs.json follows)"
    echo "$MAN"
    exit 0
  fi
fi

# Fallback: GitHub contents API
echo "packs.json unreachable; falling back to GitHub contents API"
fetch "$API_DIR" | grep -oE '"name": *"[^"]+"' | head -200 | sed 's/.*"name": *"\(.*\)"/\1/' | sort -u
