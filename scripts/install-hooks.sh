#!/usr/bin/env bash
# install-hooks.sh — Wire agent-sound-packs into your agent's config, safely.
#
# Instead of pasting a scary one-liner, this shows EXACTLY what will change,
# backs up the file first, and asks before writing.
#
# Usage:
#   install-hooks.sh [claude|codex|all] [--dry-run] [-y]
#
#   claude       Merge the 5 sound hooks into ~/.claude/settings.json (default).
#   codex        Add the notify line to ~/.codex/config.toml.
#   all          Do both (whichever config dirs exist).
#   --dry-run    Show the diff and stop — change nothing.
#   -y, --yes    Skip the confirm prompt (assume Yes).
#   -h, --help   This help.
#
# Always: makes a timestamped .bak before touching a file, and is idempotent
# (re-running won't duplicate hooks). Env: CCSP_ROOT overrides the install dir.

set -euo pipefail

ROOT="${CCSP_ROOT:-$HOME/.claude/sounds}"
PLAYER="$ROOT/play-random.sh"
CODEX_HOOK="$ROOT/scripts/integrations/codex-notify.sh"

TARGET="claude"
DRY=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    claude|codex|all) TARGET="$arg" ;;
    --dry-run|-n)     DRY=1 ;;
    -y|--yes)         ASSUME_YES=1 ;;
    -h|--help)        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'install-hooks.sh: unknown arg %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

# ---- colour -----------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; X=$'\033[0m'
else
  B=; D=; R=; G=; Y=; C=; X=
fi
ok()   { printf '  %s✓%s %s\n' "$G" "$X" "$1"; }
info() { printf '  %s•%s %s\n' "$C" "$X" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$X" "$1"; }
head() { printf '\n%s%s%s\n' "$B" "$1" "$X"; }

# ---- shared: backup + confirm-and-replace -----------------------------------
# show_diff <current-file> <proposed-file>
show_diff() {
  local cur="$1" new="$2"
  if [ -f "$cur" ]; then
    if command -v diff >/dev/null 2>&1; then
      diff -u "$cur" "$new" 2>/dev/null | sed -e "s/^+.*/$(printf '%s' "$G")&$(printf '%s' "$X")/" \
                                              -e "s/^-.*/$(printf '%s' "$R")&$(printf '%s' "$X")/" \
        || true
    else
      printf '%s--- proposed result ---%s\n' "$D" "$X"; cat "$new"
    fi
  else
    printf '  %s(file does not exist yet — it will be created)%s\n' "$D" "$X"
    printf '%s--- new file ---%s\n' "$D" "$X"; cat "$new"
  fi
}

# commit_change <target-file> <proposed-file> <label>
commit_change() {
  local cur="$1" new="$2" label="$3"
  if [ -f "$cur" ] && cmp -s "$cur" "$new"; then
    ok "$label already wired — nothing to change."
    return 0
  fi
  head "Proposed change → $cur"
  show_diff "$cur" "$new"
  if [ "$DRY" = 1 ]; then
    printf '\n  %s(dry-run — no changes written)%s\n' "$Y" "$X"
    return 0
  fi
  if [ "$ASSUME_YES" != 1 ]; then
    if [ ! -t 0 ]; then
      warn "Not a TTY and no -y given — skipping write for $label."
      return 0
    fi
    printf '\n%sApply this change?%s [%sY%s/n] ' "$B" "$X" "$G" "$X"
    read -r ans || ans=""
    case "$ans" in n|N|no|NO|No) warn "Skipped $label."; return 0 ;; esac
  fi
  if [ -f "$cur" ]; then
    local bak="$cur.bak.$(date +%Y%m%d%H%M%S)"
    cp "$cur" "$bak"
    ok "backup → $bak"
  else
    mkdir -p "$(dirname "$cur")"
  fi
  mv "$new" "$cur"
  ok "$label wired → $cur"
}

# ---- CLAUDE: merge 5 hooks into settings.json -------------------------------
install_claude() {
  local settings="$HOME/.claude/settings.json"
  [ -f "$PLAYER" ] || { warn "play-random.sh not found at $PLAYER — run ./install.sh first."; return 0; }

  local tmp
  tmp="$(mktemp -t cc-hooks-XXXXXX)"

  if command -v jq >/dev/null 2>&1; then
    { [ -f "$settings" ] && cat "$settings" || printf '{}'; } | jq --arg pr "$PLAYER" '
      def addhook(ev; arg):
        (($pr + " " + arg)) as $c
        | if ([ (.hooks[ev] // [])[].hooks[]?.command ] | index($c)) then .
          else .hooks[ev] = ((.hooks[ev] // [])
            + [{matcher:"",hooks:[{type:"command",command:$c}]}]) end;
      (.hooks //= {})
      | addhook("Stop";"stop")
      | addhook("Notification";"notification")
      | addhook("SubagentStop";"subagent")
      | addhook("SessionStart";"session")
      | addhook("PreCompact";"compact")
    ' > "$tmp" || { rm -f "$tmp"; warn "jq merge failed for $settings."; return 1; }
  elif command -v python3 >/dev/null 2>&1; then
    SETTINGS="$settings" PR="$PLAYER" python3 - "$tmp" <<'PY'
import json, os, sys
out = sys.argv[1]
path = os.environ["SETTINGS"]; pr = os.environ["PR"]
try:
    with open(path) as f: data = json.load(f)
except (FileNotFoundError, ValueError):
    data = {}
hooks = data.setdefault("hooks", {})
events = {"Stop":"stop","Notification":"notification","SubagentStop":"subagent",
          "SessionStart":"session","PreCompact":"compact"}
for ev, arg in events.items():
    cmd = f"{pr} {arg}"
    arr = hooks.setdefault(ev, [])
    have = any(h.get("command") == cmd for entry in arr for h in entry.get("hooks", []))
    if not have:
        arr.append({"matcher":"","hooks":[{"type":"command","command":cmd}]})
with open(out,"w") as f:
    json.dump(data, f, indent=2); f.write("\n")
PY
  else
    rm -f "$tmp"
    warn "Need jq or python3 to merge JSON safely. Install one, or paste $ROOT/suggested-hooks.json by hand."
    return 1
  fi

  commit_change "$settings" "$tmp" "Claude Code hooks"
  rm -f "$tmp"
}

# ---- CODEX: notify = ["bash", "<abs>/codex-notify.sh"] in config.toml -------
install_codex() {
  local toml="$HOME/.codex/config.toml"
  local line="notify = [\"bash\", \"$CODEX_HOOK\"]"
  [ -f "$CODEX_HOOK" ] || { warn "codex-notify.sh not found at $CODEX_HOOK — run ./install.sh first."; return 0; }

  local tmp
  tmp="$(mktemp -t codex-toml-XXXXXX)"
  if [ -f "$toml" ]; then
    if grep -qE '^[[:space:]]*notify[[:space:]]*=' "$toml"; then
      # Replace the existing top-level notify line.
      awk -v repl="$line" '
        !done && /^[[:space:]]*notify[[:space:]]*=/ { print repl; done=1; next }
        { print }
      ' "$toml" > "$tmp"
    else
      cp "$toml" "$tmp"
      printf '%s\n' "$line" >> "$tmp"
    fi
  else
    printf '%s\n' "$line" > "$tmp"
  fi

  commit_change "$toml" "$tmp" "Codex notify hook"
  rm -f "$tmp"
}

# ---- run --------------------------------------------------------------------
printf '\n%s  Wire sound hooks%s  %s(%s)%s\n' "$B" "$X" "$D" "$TARGET" "$X"
case "$TARGET" in
  claude) install_claude ;;
  codex)  install_codex ;;
  all)
    [ -d "$HOME/.claude" ] && install_claude || warn "~/.claude not found — skipping Claude."
    install_codex
    ;;
esac

head "Next"
info "Restart your agent (Claude Code / Codex) to load the hooks."
info "Test now: $ROOT/scripts/sound.sh test"
