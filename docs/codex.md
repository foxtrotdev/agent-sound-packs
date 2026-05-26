# Integration: OpenAI Codex CLI

[Codex CLI](https://github.com/openai/codex) is OpenAI's open-source coding agent. It supports a single `notify` hook configured via `~/.codex/config.toml`. The hook program receives a JSON event string as its first argument.

## Event mapping

Codex currently emits one notification event type (subject to change as Codex evolves):

| Codex `type`           | agent-sound-packs event |
|------------------------|-------------------------|
| `agent-turn-complete`  | `stop`                  |

That's it. Codex doesn't (yet) expose hooks for session start, awaiting-input, or context compaction. You'll get a "task done" chime, nothing else, until upstream adds more event types — at which point extend `scripts/integrations/codex-notify.sh`.

### No sound on permission/approval prompts

When Codex stops mid-turn to ask for command approval, **no sound plays**. Codex CLI does not emit a `notify` event for approval prompts — the TUI handles them inline. Compare to Claude Code, which fires `Notification` for permission prompts and idle waits (mapped to the `notification` pool).

Workarounds, none clean:
- File an upstream feature request at [`openai/codex`](https://github.com/openai/codex) for a `notify` event like `approval-request` / `awaiting-input`. Once added, extend `codex-notify.sh` to map it to `notification`.
- Run Codex with `--auto` / non-interactive mode where no approval is needed (defeats the point if you actually want to gate commands).

## Install

1. Run the project installer:
   ```bash
   ./install.sh
   ```
2. Add the `notify` line to `~/.codex/config.toml`. Codex execs the program
   directly (no shell), so the path must be absolute — TOML won't expand `$HOME`.
   Let the shell fill it in for you instead of typing your username:
   ```bash
   echo "notify = [\"bash\", \"$HOME/.claude/sounds/scripts/integrations/codex-notify.sh\"]" >> ~/.codex/config.toml
   ```
   (`$HOME` expands at write time, so the file ends up with the real absolute
   path. Already have a `notify =` line? Replace it instead of appending.)
3. (Optional) Drop your `.wav` files into `~/.claude/sounds/packs/<pack-name>/`.
4. Restart Codex CLI to pick up the new config.

## Verifying

Simulate a Codex event:

```bash
~/.claude/sounds/scripts/integrations/codex-notify.sh \
  '{"type":"agent-turn-complete","last-assistant-message":"test"}'
```

You should hear a random sound from `POOL_STOP`.

Run Codex on a quick task — when the turn completes, the same sound fires.

## Notes

- The adapter parses JSON without `jq`. If you add support for more Codex event types, keep the parser dependency-free (or document `jq` as a soft requirement).
- Codex `notify` is fired once per agent turn completion. There is no per-tool-call hook — which is exactly what we want (no spam).
- On Linux/WSL no edits needed — `play-random.sh` auto-detects `pw-play` / `paplay` / `aplay` / `ffplay` / Windows `powershell.exe` at runtime. Override with `CCSP_PLAYER="my-tool"`. See `README.md#adapting-the-player`.
