# Integration: Claude Code

[Claude Code](https://claude.com/claude-code) is Anthropic's official coding agent CLI. It supports first-class hooks for lifecycle events — five of them map directly onto agent-sound-packs events.

## Event mapping

| Claude Code hook   | agent-sound-packs event | When |
|--------------------|-------------------------|------|
| `Stop`             | `stop`                  | Claude finishes a reply |
| `Notification`     | `notification`          | Permission prompt, idle wake |
| `SubagentStop`     | `subagent`              | Agent-tool subagent completes |
| `SessionStart`     | `session`               | Session boots |
| `PreCompact`       | `compact`               | Context auto-summarization about to run |

Deliberately not mapped: `PreToolUse`, `PostToolUse`, `UserPromptSubmit` (spam-prone). See `README.md` if you want to add them anyway.

## Install

1. Run the project installer (copies scripts, configs, and bundled `.wav` files):
   ```bash
   ./install.sh
   ```
   The installer writes `~/.claude/sounds/suggested-hooks.json` with **your real install path already baked in** — no `YOUR_USER` placeholder to edit.

2. Merge the hooks into `~/.claude/settings.json`:
   ```bash
   # If you have jq:
   jq -s '.[0] * .[1]' ~/.claude/settings.json ~/.claude/sounds/suggested-hooks.json \
     > /tmp/cc.json && mv /tmp/cc.json ~/.claude/settings.json

   # If settings.json doesn't exist yet:
   cp ~/.claude/sounds/suggested-hooks.json ~/.claude/settings.json

   # Or manually paste the "hooks" block from suggested-hooks.json.
   ```

3. (Optional) Drop more `.wav` files into `~/.claude/sounds/packs/<pack-name>/`.

4. No restart needed — Claude Code re-reads `settings.json` on each event fire.

## Verifying

```bash
# Active pack + available packs
~/.claude/sounds/switch-pack.sh

# Confirm hooks are registered
grep play-random.sh ~/.claude/settings.json

# Force-play each event
~/.claude/sounds/scripts/test-sounds.sh
```

If Claude Code is running, the next reply ends with a `stop` sound. If you grant a tool permission interactively, you hear a `notification` sound.

## Notes

- Claude Code passes no event payload to the hook command — it just runs the configured shell command. The five hook events are distinguished by their **JSON key in `settings.json`**, not by an env var or argument the script reads.
- `play-random.sh` auto-detects the audio player (`afplay` / `pw-play` / `paplay` / `aplay` / `ffplay` / `powershell.exe`) so the same hook config works on macOS, Linux, and WSL. Override with `CCSP_PLAYER="my-tool"`.
- The trailing `&` on the player invocation is important — hooks should return fast, and most players block until playback ends.
