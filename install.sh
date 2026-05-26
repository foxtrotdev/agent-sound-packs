#!/usr/bin/env bash
# install.sh — Install agent-sound-packs into ~/.claude/sounds/ (or $CCSP_ROOT).
#
# Interactive by default: shows a PLAN of exactly what it will do, then asks
# before touching anything. Copies scripts, pool.conf, transcripts.txt, and any
# bundled audio (*.wav *.mp3 *.ogg *.flac).
#
# On a fresh install it lets you pick the starting pack with ↑/↓ arrows
# (peon-en pre-selected). Non-interactive runs default to peon-en.
#
# Flags:
#   -y, --yes      Skip the confirmation prompt + pack picker (non-interactive / CI).
#   --pack=NAME    Preset the active pack, skip the picker.
#   --no-audio     Skip copying audio files; refresh configs/scripts only.
#                  (--no-wavs is accepted as an alias.)
#   --no-intro     Don't play a sound at the end.
#   -h, --help     Show this help.
#
# Env: CCSP_ROOT=/path overrides the install dir. NO_COLOR disables colour.

set -e
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${CCSP_ROOT:-$HOME/.claude/sounds}"

COPY_AUDIO=1
ASSUME_YES=0
WANT_INTRO=1
PRESET_PACK=""
for arg in "$@"; do
  case "$arg" in
    -y|--yes)            ASSUME_YES=1 ;;
    --pack=*)            PRESET_PACK="${arg#*=}" ;;
    --no-audio|--no-wavs) COPY_AUDIO=0 ;;
    --no-intro)          WANT_INTRO=0 ;;
    -h|--help)           sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'install.sh: unknown flag %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

# ---- colour (only on a TTY, honour NO_COLOR) --------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'
  Y=$'\033[33m'; C=$'\033[36m'; M=$'\033[35m'; X=$'\033[0m'
else
  B=; D=; R=; G=; Y=; C=; M=; X=
fi
ok()   { printf '  %s✓%s %s\n' "$G" "$X" "$1"; }
info() { printf '  %s•%s %s\n' "$C" "$X" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$X" "$1"; }
head() { printf '\n%s%s%s\n' "$B" "$1" "$X"; }
rule() { printf '%s────────────────────────────────────────────────────────%s\n' "$D" "$X"; }

# count audio files (wav/mp3/ogg/flac) in a dir, print integer
count_audio() {
  local d="$1" n=0 ext f
  for ext in wav mp3 ogg flac; do
    for f in "$d"*."$ext"; do [ -f "$f" ] && n=$((n + 1)); done
  done
  printf '%s' "$n"
}

# Arrow-key pack picker. Args: pack names. Sets REPLY_PACK to the chosen one.
# ↑/↓ or k/j to move, Enter to pick. Defaults the cursor to $DEFAULT_PACK.
choose_pack() {
  local items=("$@") n=$# sel=0 i key rest
  for i in $(seq 0 $((n - 1))); do
    [ "${items[$i]}" = "$DEFAULT_PACK" ] && sel=$i
  done
  printf '%s  Pick the starting pack — %s↑/↓%s move, %sEnter%s select:%s\n' "$B" "$C" "$X$B" "$C" "$X$B" "$X"
  printf '\033[?25l'  # hide cursor
  while true; do
    for i in $(seq 0 $((n - 1))); do
      if [ "$i" -eq "$sel" ]; then
        printf '  %s▸ %s%s\033[K\n' "$G$B" "${items[$i]}" "$X"
      else
        printf '    %s%s%s\033[K\n' "$D" "${items[$i]}" "$X"
      fi
    done
    IFS= read -rsn1 key
    if [ "$key" = $'\033' ]; then IFS= read -rsn2 rest; key="$key$rest"; fi
    case "$key" in
      $'\033[A'|k) sel=$(( (sel - 1 + n) % n )) ;;
      $'\033[B'|j) sel=$(( (sel + 1) % n )) ;;
      '') break ;;   # Enter
    esac
    printf '\033[%dA' "$n"   # move cursor back up to repaint
  done
  printf '\033[?25h'  # restore cursor
  REPLY_PACK="${items[$sel]}"
}

# ---- gather facts (read-only) -----------------------------------------------
PACK_COUNT=0; AUDIO_TOTAL=0; PACK_LINES=""; PACK_NAMES=""
for pack_dir in "$SRC_DIR/packs"/*/; do
  [ -d "$pack_dir" ] || continue
  name=$(basename "$pack_dir")
  n=$(count_audio "$pack_dir")
  PACK_COUNT=$((PACK_COUNT + 1)); AUDIO_TOTAL=$((AUDIO_TOTAL + n))
  PACK_NAMES="$PACK_NAMES $name"
  PACK_LINES="$PACK_LINES$name|$n
"
done

DEFAULT_PACK=peon-en
[ -d "$SRC_DIR/packs/$DEFAULT_PACK" ] || DEFAULT_PACK=$(basename "$(ls -d "$SRC_DIR/packs"/*/ 2>/dev/null | head -1)" 2>/dev/null)

MODE="fresh install"
[ -e "$DEST/play-random.sh" ] && MODE="update existing install"

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sound-packs"
CFG_FILE="$CFG_DIR/config.json"

# which audio player will be auto-detected at play time?
PLAYER="(none found — install ffmpeg or a backend)"
for p in afplay pw-play paplay aplay ffplay powershell.exe; do
  command -v "$p" >/dev/null 2>&1 && { PLAYER="$p"; break; }
done

# ---- PLAN preview ------------------------------------------------------------
printf '\n%s  agent-sound-packs installer%s\n' "$B$M" "$X"
printf '%s  your AI coding agent talks back%s\n' "$D" "$X"
rule
head "Plan ($MODE)"
info "Install dir:   ${B}$DEST${X}"
info "Source:        $SRC_DIR"
info "Audio player:  $PLAYER"
printf '\n'
info "Will copy:"
printf '      %s· 9 scripts%s (play-random, switch-pack, sound dispatcher, helpers)\n' "$D" "$X"
if [ "$COPY_AUDIO" = 1 ]; then
  printf '      %s· %s packs%s with %s%s audio files%s (wav/mp3/ogg/flac)\n' "$D" "$PACK_COUNT" "$X" "$B" "$AUDIO_TOTAL" "$X"
else
  printf '      %s· %s packs%s — %sconfigs only, no audio (--no-audio)%s\n' "$D" "$PACK_COUNT" "$X" "$Y" "$X"
fi
info "Will write:    suggested-hooks.json (ready to paste)"
if [ -f "$CFG_FILE" ]; then
  info "Config:        keep existing $CFG_FILE"
else
  info "Config:        seed $CFG_FILE (volume/mute)"
fi
if [ -f "$DEST/active-pack" ]; then
  info "Active pack:   keep current ($(cat "$DEST/active-pack" 2>/dev/null))"
elif [ -n "$PRESET_PACK" ]; then
  info "Active pack:   set to ${B}$PRESET_PACK${X} (--pack)"
elif [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
  info "Active pack:   ${B}pick with arrows below${X} (default $DEFAULT_PACK)"
else
  info "Active pack:   set to ${B}$DEFAULT_PACK${X}"
fi
printf '\n'
info "Packs:"
printf '%s' "$PACK_LINES" | while IFS='|' read -r pname pn; do
  [ -z "$pname" ] && continue
  mark=""; [ "$pname" = "$DEFAULT_PACK" ] && [ ! -f "$DEST/active-pack" ] && mark=" ${G}(default)${X}"
  printf '      %s· %-22s%s %s%s files%s%s\n' "$D" "$pname" "$X" "$D" "$pn" "$X" "$mark"
done
printf '\n'
warn "Does NOT touch ~/.claude/settings.json yet — a separate step wires the hooks (with a diff + backup + confirm)."
rule

# ---- confirm -----------------------------------------------------------------
if [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
  printf '%sProceed?%s [%sY%s/n] ' "$B" "$X" "$G" "$X"
  read -r answer || answer=""
  case "$answer" in
    n|N|no|NO|No) printf '%sAborted — nothing was changed.%s\n' "$Y" "$X"; exit 0 ;;
  esac
fi

# ---- pick the starting pack (fresh installs only) ---------------------------
CHOSEN_PACK=""
if [ ! -f "$DEST/active-pack" ]; then
  if [ -n "$PRESET_PACK" ]; then
    CHOSEN_PACK="$PRESET_PACK"
  elif [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
    head "Starting pack"
    choose_pack $PACK_NAMES
    CHOSEN_PACK="$REPLY_PACK"
  else
    CHOSEN_PACK="$DEFAULT_PACK"
  fi
  case " $PACK_NAMES " in
    *" $CHOSEN_PACK "*) : ;;
    *) printf '  %s!%s pack "%s" not found — using %s\n' "$Y" "$X" "$CHOSEN_PACK" "$DEFAULT_PACK"; CHOSEN_PACK="$DEFAULT_PACK" ;;
  esac
fi

# ---- execute -----------------------------------------------------------------
head "Installing"
mkdir -p "$DEST/scripts" "$DEST/packs"
ok "created $DEST"

cp "$SRC_DIR/scripts/play-random.sh" "$DEST/play-random.sh"
cp "$SRC_DIR/scripts/switch-pack.sh" "$DEST/switch-pack.sh"
cp "$SRC_DIR/scripts/transcribe.sh"  "$DEST/scripts/transcribe.sh"
[ -f "$SRC_DIR/scripts/test-sounds.sh" ] && cp "$SRC_DIR/scripts/test-sounds.sh" "$DEST/scripts/test-sounds.sh"
for s in sound.sh add-pack.sh update-pack.sh list-remote.sh validate-pack.sh new-pack.sh install-hooks.sh; do
  [ -f "$SRC_DIR/scripts/$s" ] && cp "$SRC_DIR/scripts/$s" "$DEST/scripts/$s"
done
if [ -f "$SRC_DIR/scripts/integrations/codex-notify.sh" ]; then
  mkdir -p "$DEST/scripts/integrations"
  cp "$SRC_DIR/scripts/integrations/codex-notify.sh" "$DEST/scripts/integrations/codex-notify.sh"
fi
chmod +x "$DEST/play-random.sh" "$DEST/switch-pack.sh" "$DEST"/scripts/*.sh
[ -f "$DEST/scripts/integrations/codex-notify.sh" ] && chmod +x "$DEST/scripts/integrations/codex-notify.sh"
ok "scripts installed"

# Detect repo + commit so update-pack.sh can refresh bundled packs later.
SRC_REPO=""; SRC_COMMIT=""
if command -v git >/dev/null 2>&1 && git -C "$SRC_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  SRC_REPO=$(git -C "$SRC_DIR" config --get remote.origin.url 2>/dev/null || true)
  SRC_COMMIT=$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || true)
fi
SRC_REPO="${SRC_REPO:-https://github.com/foxtrotdev/agent-sound-packs.git}"

installed_audio=0
for pack_dir in "$SRC_DIR/packs"/*/; do
  [ -d "$pack_dir" ] || continue
  name=$(basename "$pack_dir")
  mkdir -p "$DEST/packs/$name"
  [ -f "$pack_dir/pool.conf" ]       && cp "$pack_dir/pool.conf"       "$DEST/packs/$name/"
  [ -f "$pack_dir/transcripts.txt" ] && cp "$pack_dir/transcripts.txt" "$DEST/packs/$name/"
  if [ "$COPY_AUDIO" = 1 ]; then
    for ext in wav mp3 ogg flac; do
      for f in "$pack_dir"*."$ext"; do
        [ -f "$f" ] || continue
        cp "$f" "$DEST/packs/$name/"
        installed_audio=$((installed_audio + 1))
      done
    done
  fi
  if [ -n "$SRC_COMMIT" ]; then
    {
      echo "repo=$SRC_REPO"
      echo "commit=$SRC_COMMIT"
      echo "installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$DEST/packs/$name/.source"
  fi
done
ok "$PACK_COUNT packs ($installed_audio audio files)"

# Active pack — use the one chosen above (fresh install), else keep current
if [ ! -f "$DEST/active-pack" ]; then
  if [ -n "$CHOSEN_PACK" ] && [ -d "$DEST/packs/$CHOSEN_PACK" ]; then
    echo "$CHOSEN_PACK" > "$DEST/active-pack"
  elif [ -d "$DEST/packs/$DEFAULT_PACK" ]; then
    echo "$DEFAULT_PACK" > "$DEST/active-pack"
  else
    ls "$DEST/packs" | head -1 > "$DEST/active-pack"
  fi
  ok "active pack → $(cat "$DEST/active-pack")"
else
  info "active pack kept → $(cat "$DEST/active-pack")"
fi

# Ready-to-paste hooks JSON with the real install path baked in
HOOKS_FILE="$DEST/suggested-hooks.json"
cat > "$HOOKS_FILE" <<JSON
{
  "_comment": "Merge this 'hooks' block into ~/.claude/settings.json (Claude Code). Paths already point at your install.",
  "hooks": {
    "Stop":         [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh stop"}]}],
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh notification"}]}],
    "SubagentStop": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh subagent"}]}],
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh session"}]}],
    "PreCompact":   [{"matcher": "", "hooks": [{"type": "command", "command": "$DEST/play-random.sh compact"}]}]
  }
}
JSON
ok "hooks JSON → $HOOKS_FILE"

# Seed a default config file if absent
if [ ! -f "$CFG_FILE" ]; then
  mkdir -p "$CFG_DIR"
  cat > "$CFG_FILE" <<'JSON'
{
  "_comment": "agent-sound-packs config. enabled: 0|1, volume: 0..100, pack: pack-name (overrides active-pack file).",
  "enabled": 1,
  "volume": 100
}
JSON
  ok "config seeded → $CFG_FILE"
else
  info "config kept → $CFG_FILE"
fi

# ---- next steps --------------------------------------------------------------
head "Done ✓  Next steps"
printf '  %s1.%s Hear it:        %s%s/scripts/sound.sh test%s\n' "$B" "$X" "$C" "$DEST" "$X"
printf '  %s2.%s Wire the hooks:  %s%s/scripts/sound.sh install-hooks%s\n' "$B" "$X" "$C" "$DEST" "$X"
printf '       %sshows a diff, backs up your config, asks before writing. Add %scodex%s or %sall%s for Codex.%s\n' "$D" "$C" "$D" "$C" "$D" "$X"
printf '  %s3.%s Switch theme:    %s%s/scripts/sound.sh switch <name>%s   (browse: %ssound.sh remote%s)\n' "$B" "$X" "$C" "$DEST" "$X" "$C" "$X"
printf '  %s4.%s Volume / mute:   %s%s/scripts/sound.sh volume 70%s | %smute%s | %sunmute%s\n' "$B" "$X" "$C" "$DEST" "$X" "$C" "$X" "$C" "$X"
rule

# ---- offer to wire hooks right now ------------------------------------------
if [ "$ASSUME_YES" != 1 ] && [ -t 0 ] && [ -x "$DEST/scripts/install-hooks.sh" ]; then
  printf '\n%sWire the hooks into ~/.claude/settings.json now?%s [%sY%s/n] ' "$B" "$X" "$G" "$X"
  read -r wire || wire=""
  case "$wire" in
    n|N|no|NO|No) info "Skipped — run 'sound.sh install-hooks' whenever you're ready." ;;
    *) CCSP_ROOT="$DEST" bash "$DEST/scripts/install-hooks.sh" claude || true ;;
  esac
fi

# ---- first-run intro ---------------------------------------------------------
if [ "$WANT_INTRO" = 1 ] && [ -t 1 ]; then
  printf '%s♪ playing intro from '"'"'%s'"'"' …%s\n' "$D" "$(cat "$DEST/active-pack" 2>/dev/null)" "$X"
  CCSP_ROOT="$DEST" CCSP_DEBOUNCE_MS=0 "$DEST/play-random.sh" session 2>/dev/null || true
  sleep 1 || true
fi
