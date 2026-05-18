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

1. Run the project installer:
   ```bash
   ./install.sh
   ```
2. Open `~/.claude/settings.json` and merge the `hooks` block from `examples/settings.json`. Replace `YOUR_USER` with your macOS username.
3. (Optional) Drop your `.wav` files into `~/.claude/sounds/packs/<pack-name>/`.
4. Restart not required — Claude Code re-reads `settings.json` on each event fire.

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
- The `&` at the end of the afplay invocation is important — hooks should return fast, and afplay otherwise blocks until playback ends.
