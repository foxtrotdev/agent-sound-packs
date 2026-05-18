#!/bin/bash
# transcribe.sh — Transcribe all .wav files in a pack folder using whisper.cpp.
# Saves transcripts.txt (filename<TAB>text). Helper for curating new packs.
#
# Usage: transcribe.sh <pack-dir> [model-path]
#   pack-dir   directory containing .wav files
#   model-path path to ggml model (default: ~/.cache/whisper/ggml-small.en.bin)
#
# Requirements: whisper-cli (brew install whisper-cpp), ggml model file.

set -e
DIR="${1:?usage: transcribe.sh <pack-dir> [model-path]}"
MODEL="${2:-$HOME/.cache/whisper/ggml-small.en.bin}"

if ! command -v whisper-cli >/dev/null 2>&1; then
  echo "whisper-cli not found. Install: brew install whisper-cpp" >&2
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "Model not found: $MODEL" >&2
  echo "Download from: https://huggingface.co/ggerganov/whisper.cpp/tree/main" >&2
  exit 1
fi

OUT="$DIR/transcripts.txt"
: > "$OUT"

shopt -s nullglob
for f in "$DIR"/*.wav; do
  name=$(basename "$f")
  text=$(whisper-cli -m "$MODEL" -f "$f" 2>/dev/null \
    | grep -E "^\[" \
    | sed -E 's/^\[[^]]+\][[:space:]]+//' \
    | tr '\n' ' ' \
    | sed 's/[[:space:]]*$//')
  printf "%s\t%s\n" "$name" "$text" >> "$OUT"
  printf "%-30s -> %s\n" "$name" "$text"
done

echo ""
echo "Saved: $OUT"
