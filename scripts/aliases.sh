#!/bin/bash
# aliases.sh — Source from your shell rc to get sound-pack CLI shortcuts
# that work regardless of which AI agent you're using.
#
# Add to ~/.zshrc or ~/.bashrc:
#   source ~/.claude/sounds/scripts/aliases.sh

CCSP_ROOT_DEFAULT="${CCSP_ROOT:-$HOME/.claude/sounds}"

# Quick pack switch / list
sp() {
  "$CCSP_ROOT_DEFAULT/switch-pack.sh" "$@"
}

# Test all events of the active pack
sp-test() {
  "$CCSP_ROOT_DEFAULT/scripts/test-sounds.sh"
}

# Scaffold a new pack
sp-new() {
  "$CCSP_ROOT_DEFAULT/scripts/new-pack.sh" "$@"
}

# Manually fire one event
sp-play() {
  "$CCSP_ROOT_DEFAULT/play-random.sh" "$@"
}
