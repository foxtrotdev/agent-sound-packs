#!/usr/bin/env bash
# add-pack.sh — Download a sound pack and install it on this machine.
#
# Easiest:
#   add-pack.sh duke-nukem-cs            Install a pack from the official catalog.
#                                        Use list-remote.sh first to see names.
#
# From someone else's repo:
#   add-pack.sh <git-url> <pack-name>    The git URL points to a repo that has
#                                        packs/<pack-name>/ inside it.
#
# Re-install (overwrite existing):
#   add-pack.sh --force duke-nukem-cs
#
# Needs git 2.25 or newer on your machine. That's all.

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
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) ARGS+=("$arg") ;;
  esac
done

[ ${#ARGS[@]} -ge 1 ] || { echo "usage: add-pack.sh [--force] <pack-name|git-url> [pack-name]" >&2; exit 1; }

A1="${ARGS[0]}"
A2="${ARGS[1]:-}"

# --- Safety: classify A1 as repo URL or bare pack name ----------------------
URL_RE='^(https?://|ssh://|git://|git@[A-Za-z0-9._-]+:|file://)'
if [[ "$A1" =~ $URL_RE ]]; then
  REPO="$A1"
  NAME="$A2"
  [ -n "$NAME" ] || { echo "ERROR: pack name required as 2nd arg when using a custom repo URL." >&2; exit 1; }
else
  REPO="$OFFICIAL_REPO"
  NAME="$A1"
fi

# --- Safety: validate the URL (must be a recognizable git URL) --------------
if ! [[ "$REPO" =~ $URL_RE ]]; then
  echo "ERROR: '$REPO' does not look like a git URL (https://, ssh://, git@host:, file://)." >&2
  exit 1
fi
# Reject obvious shell injection in URL even if regex would not match. Belt + braces.
case "$REPO" in
  *' '*|*';'*|*'|'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$'*)
    echo "ERROR: URL contains shell metacharacters; refusing." >&2; exit 1 ;;
esac

# --- Safety: validate pack name (no path traversal, no shell chars) ---------
if ! [[ "$NAME" =~ ^[a-zA-Z0-9_-]{1,64}$ ]]; then
  echo "ERROR: pack name must match ^[a-zA-Z0-9_-]{1,64}\$ (got: '$NAME')." >&2
  echo "       This protects against path traversal and shell injection." >&2
  exit 1
fi

DEST="$PACKS_DIR/$NAME"
if [ -d "$DEST" ] && [ "$FORCE" != 1 ]; then
  echo "Pack '$NAME' already installed at $DEST" >&2
  echo "Re-run with --force to overwrite, or use update-pack.sh $NAME to refresh." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "ERROR: git is required (not found in PATH)." >&2; exit 1; }

TMP=$(mktemp -d -t addpack-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $NAME from $REPO ..."
# Suppress harmless "filtering not recognized by server" warning on file:// / older servers.
git clone --quiet --depth 1 --filter=blob:none --sparse "$REPO" "$TMP" 2> >(grep -v 'filtering not recognized' >&2)
git -C "$TMP" sparse-checkout set --quiet "packs/$NAME" 2>/dev/null || \
  git -C "$TMP" sparse-checkout set "packs/$NAME" >/dev/null 2>&1

if [ ! -d "$TMP/packs/$NAME" ]; then
  echo "ERROR: pack '$NAME' does not exist in $REPO (looked for packs/$NAME/)." >&2
  echo "Run list-remote.sh to see available pack names." >&2
  exit 1
fi

# --- Safety: run validate-pack.sh BEFORE copying anything into $PACKS_DIR ---
VALIDATOR="$(dirname "$0")/validate-pack.sh"
[ -x "$VALIDATOR" ] || VALIDATOR="$ROOT/scripts/validate-pack.sh"
if [ -x "$VALIDATOR" ]; then
  echo "Validating pack structure ..."
  if ! "$VALIDATOR" "$TMP/packs/$NAME"; then
    echo "" >&2
    echo "ERROR: pack failed safety validation — refusing to install." >&2
    echo "       The downloaded pack violates PACK_RULES.md (run validate-pack.sh on a clean copy" >&2
    echo "       to see the full list, or file an issue with the pack author)." >&2
    exit 1
  fi
else
  echo "WARN: validate-pack.sh not found alongside add-pack.sh — installing without safety check." >&2
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
echo ""
echo "✓ Installed: $NAME ($WAVS sound files)"
echo "  Location:  $DEST"
echo "  Source:    $REPO @ ${SHA:0:7}"
echo ""
echo "To start using it now:"
echo "  $ROOT/switch-pack.sh $NAME"
