# Integration: other tools

Stubs and pointers for coding agents not yet officially supported. Contributions welcome.

## Aider

[Aider](https://github.com/Aider-AI/aider) supports a `--notifications-command` flag and config-file option. Map it to the `stop` event:

```yaml
# ~/.aider.conf.yml — use an absolute path. Print yours with:
#   echo "$HOME/.claude/sounds/play-random.sh stop"
notifications-command: /Users/YOUR_USER/.claude/sounds/play-random.sh stop
```

This fires once per Aider turn completion. There's no separate awaiting-input event in Aider.

## Cursor / Continue / Cline (VSCode)

These tools don't currently expose user-defined post-turn hooks. Track upstream issues; in the meantime there's nothing to wire up.

## Generic agent

For any agent that lets you configure a "post-turn" shell command, wire it to an
absolute path (print yours with `echo "$HOME/.claude/sounds/play-random.sh stop"`):

```
/Users/YOUR_USER/.claude/sounds/play-random.sh stop
```

If the agent passes structured event data, write an adapter under `scripts/integrations/<tool>-notify.sh` modeled on `codex-notify.sh` and map its event types to the agent-sound-packs event enum (`stop | notification | subagent | session | compact`).
