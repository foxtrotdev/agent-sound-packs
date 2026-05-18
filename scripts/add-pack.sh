#!/bin/bash
# add-pack.sh — Install a sound pack from the official repo or any git URL.
#
# Usage:
#   add-pack.sh <pack-name>                   # from official agent-sound-packs repo
#   add-pack.sh <git-url> <pack-name>         # from any repo containing packs/<name>/
#   add-pack.sh -f|--force <pack-name|...>    # overwrite even if pack already exists
#
# Examples:
#   add-pack.sh duke-nukem-cs
#   add-pack.sh https://github.com/me/my-packs.git my-pack
#
# Requires: git 2.25+ (for sparse-checkout).

set -euo pipefail

OFFICIAL_REPO="https://github.com/foxtrotdev/agent-sound-packs.git"
ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PACKS_DIR="$ROOT/packs"

FORCE=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) ARGS+=("$arg") ;;
  esac
done

[ ${#ARGS[@]} -ge 1 ] || { echo "usage: add-pack.sh [--force] <pack-name|git-url> [pack-name]" >&2; exit 1; }

A1="${ARGS[0]}"
A2="${ARGS[1]:-}"

if [[ "$A1" =~ ^(https?://|git@|file://|ssh://|git://) ]]; then
  REPO="$A1"
  NAME="$A2"
  [ -n "$NAME" ] || { echo "Pack name required as 2nd arg when using a custom repo URL" >&2; exit 1; }
else
  REPO="$OFFICIAL_REPO"
  NAME="$A1"
fi

DEST="$PACKS_DIR/$NAME"
if [ -d "$DEST" ] && [ "$FORCE" != 1 ]; then
  echo "Pack '$NAME' already installed at $DEST" >&2
  echo "Re-run with --force to overwrite, or use update-pack.sh $NAME to refresh." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

TMP=$(mktemp -d -t addpack-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo "Fetching $NAME from $REPO ..."
git clone --quiet --depth 1 --filter=blob:none --sparse "$REPO" "$TMP"
git -C "$TMP" sparse-checkout set --quiet "packs/$NAME" 2>/dev/null || \
  git -C "$TMP" sparse-checkout set "packs/$NAME"

if [ ! -d "$TMP/packs/$NAME" ]; then
  echo "Pack '$NAME' not found in $REPO under packs/" >&2
  exit 1
fi

# Resolve commit SHA for provenance
SHA=$(git -C "$TMP" rev-parse HEAD)

mkdir -p "$PACKS_DIR"
rm -rf "$DEST"
cp -r "$TMP/packs/$NAME" "$DEST"

# Record source so update-pack.sh knows where to re-fetch
cat > "$DEST/.source" <<EOF
repo=$REPO
commit=$SHA
fetched_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

WAVS=$(find "$DEST" -maxdepth 1 -name '*.wav' | wc -l | tr -d ' ')
echo "Installed $NAME ($WAVS wavs) -> $DEST"
echo "Source:   $REPO @ ${SHA:0:7}"
echo "Activate: $ROOT/switch-pack.sh $NAME"
