#!/bin/bash
# validate-pack.sh — Check a sound pack directory against the strict format rules.
#
# Usage: validate-pack.sh <pack-dir>
# Exit 0 = safe to install. Exit non-zero = at least one rule violated.
#
# Rules enforced (see PACK_RULES.md for the canonical spec):
#   1. Directory must contain pool.conf.
#   2. Allowed entries inside the pack dir (flat — no subdirectories):
#        pool.conf  transcripts.txt  .source  *.wav  *.mp3  *.ogg  *.flac
#   3. No symbolic links anywhere in the pack dir.
#   4. No file may exceed MAX_FILE_SIZE (default 5 MiB).
#   5. Whole pack may not exceed MAX_PACK_SIZE (default 200 MiB).
#   6. pool.conf grammar (two equivalent styles, both accepted):
#
#      MULTI-LINE:
#        POOL_<EVENT>=(
#          filename1.wav
#          filename2.mp3
#        )
#
#      SINGLE-LINE:
#        POOL_<EVENT>=(filename1.wav filename2.mp3 filename3.ogg)
#
#      Allowed characters in filenames: a-z A-Z 0-9 . _ - (no slashes, no spaces,
#      no shell metacharacters). Allowed extensions: .wav .mp3 .ogg .flac.
#      Anything outside this grammar (command substitution, backticks,
#      variable expansion, shell pipes, &&, ||, ;, redirects) is rejected.
#   7. Every basename listed in pool.conf must exist as a real audio file
#      in the same directory.
#
# This script never `source`s or evaluates the pack — it only reads + greps.

set -euo pipefail

DIR="${1:?usage: validate-pack.sh <pack-dir>}"
MAX_FILE_SIZE=${MAX_FILE_SIZE:-$((5 * 1024 * 1024))}    # 5 MiB
MAX_PACK_SIZE=${MAX_PACK_SIZE:-$((200 * 1024 * 1024))}  # 200 MiB

[ -d "$DIR" ] || { echo "validate-pack: not a directory: $DIR" >&2; exit 2; }

errs=()
err() { errs+=("$1"); }

# --- Rule 1: pool.conf exists -------------------------------------------------
[ -f "$DIR/pool.conf" ] || err "missing pool.conf"

# --- Rule 3: no symlinks ------------------------------------------------------
while IFS= read -r -d '' link; do
  err "symlink not allowed: ${link#$DIR/}"
done < <(find "$DIR" -type l -print0 2>/dev/null || true)

# --- Rule 2: only flat dir + whitelisted extensions ---------------------------
# Find any nested directories first
while IFS= read -r -d '' sub; do
  [ "$sub" = "$DIR" ] && continue
  err "subdirectory not allowed: ${sub#$DIR/}/"
done < <(find "$DIR" -mindepth 1 -type d -print0 2>/dev/null || true)

# Find any non-whitelisted files
while IFS= read -r -d '' f; do
  base=$(basename "$f")
  case "$base" in
    pool.conf|transcripts.txt|.source) continue ;;
    *.wav|*.mp3|*.ogg|*.flac)          continue ;;
    *) err "disallowed file type: $base" ;;
  esac
done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null || true)

# --- Rule 4 + 5: size caps ----------------------------------------------------
pack_size=0
while IFS= read -r -d '' f; do
  sz=$(wc -c < "$f")
  pack_size=$((pack_size + sz))
  if [ "$sz" -gt "$MAX_FILE_SIZE" ]; then
    err "file too large ($(( sz / 1024 / 1024 )) MiB > $((MAX_FILE_SIZE / 1024 / 1024)) MiB): $(basename "$f")"
  fi
done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null || true)

if [ "$pack_size" -gt "$MAX_PACK_SIZE" ]; then
  err "pack too large ($(( pack_size / 1024 / 1024 )) MiB > $((MAX_PACK_SIZE / 1024 / 1024)) MiB total)"
fi

# --- Rule 6 + 7: pool.conf grammar + referenced files exist -------------------
# Strategy: read whole file, allow single-line OR multi-line arrays.
# Entries inside a POOL block must match the safe-basename regex.
# After stripping legal arrays + comments + blanks, NOTHING else may remain.
ENTRY_RE='[a-zA-Z0-9._-]+\.(wav|mp3|ogg|flac)'

if [ -f "$DIR/pool.conf" ]; then
  conf=$(cat "$DIR/pool.conf")

  # Collect referenced filenames first (used to confirm they exist on disk).
  while read -r fname; do
    [ -z "$fname" ] && continue
    [ -f "$DIR/$fname" ] || err "pool.conf — referenced file missing: $fname"
  done < <(
    # Strip comments
    printf '%s\n' "$conf" \
      | sed -E 's/#.*$//' \
      | tr '\n' ' ' \
      | grep -oE 'POOL_[A-Z]+=\([^)]*\)' \
      | sed -E 's/^POOL_[A-Z]+=\(//; s/\)$//' \
      | tr ' \t' '\n\n' \
      | grep -E "^${ENTRY_RE}$" || true
  )

  # Strict grammar check: after removing valid arrays, comments, blanks,
  # nothing should remain. If anything does, it's foreign content.
  residue=$(printf '%s\n' "$conf" \
    | sed -E 's/#.*$//' \
    | tr '\n' '\f' \
    | sed -E "s/POOL_[A-Z]+=\([[:space:]\f]*(${ENTRY_RE}[[:space:]\f]*)*\)//g" \
    | tr '\f' '\n' \
    | tr -d '[:space:]')
  if [ -n "$residue" ]; then
    err "pool.conf — disallowed content (possible code injection?): $(printf '%s' "$residue" | head -c 80)"
  fi

  # Catch dangerous tokens in NON-comment lines only (comments may freely mention them).
  conf_nocomments=$(sed -E 's/#.*$//' "$DIR/pool.conf")
  if printf '%s' "$conf_nocomments" | grep -qE '\$\(|`|\$\{|\|\||&&|;|>|<|\beval\b|\bsource\b'; then
    err "pool.conf — contains shell metacharacters outside comments (\$(...), backticks, |, &&, ;, >, <) — not allowed"
  fi
fi

# --- Report -------------------------------------------------------------------
if [ ${#errs[@]} -eq 0 ]; then
  exit 0
fi

echo "Pack at '$DIR' failed validation:" >&2
for e in "${errs[@]}"; do echo "  - $e" >&2; done
exit 1
