# Integration: OpenAI Codex CLI

[Codex CLI](https://github.com/openai/codex) is OpenAI's open-source coding agent. It supports a single `notify` hook configured via `~/.codex/config.toml`. The hook program receives a JSON event string as its first argument.

## Event mapping

Codex currently emits one notification event type (subject to change as Codex evolves):

| Codex `type`           | agent-sound-packs event |
|------------------------|-------------------------|
| `agent-turn-complete`  | `stop`                  |

That's it. Codex doesn't (yet) expose hooks for session start, awaiting-input, or context compaction. You'll get a "task done" chime, nothing else, until upstream adds more event types — at which point extend `scripts/integrations/codex-notify.sh`.

## Install

1. Run the project installer:
   ```bash
   ./install.sh
   ```
2. Edit `~/.codex/config.toml` (create if missing) and add:
   ```toml
   notify = ["bash", "/Users/YOUR_USER/.claude/sounds/scripts/integrations/codex-notify.sh"]
   ```
   Replace `YOUR_USER` with your macOS username, or point at wherever `$CCSP_ROOT` resolves.
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
- If you run Codex CLI on Linux, replace `afplay` in `~/.claude/sounds/play-random.sh` with `paplay` / `aplay` / `pw-play` — see `README.md#adapting-the-player`.
