---
description: Manage sound packs — list, switch, volume, mute, test, add, new, update, remote
argument-hint: "[switch <name>|volume <0-100>|mute|unmute|test|add <name>|new <name>|update|remote]"
---

Run this via the Bash tool, then report the result concisely (a few lines max — current/active pack, the catalog table, or a confirmation). No commentary, no fluff — just the relevant output:

```bash
R="$HOME/.claude/sounds"; CCSP_ROOT="$R" "$R/scripts/sound.sh" $ARGUMENTS
```

Subcommands: `(none)`/`list`, `switch <name>`, `volume <0-100>`, `mute`, `unmute`, `update [name|--all]`, `test`, `new <name>`, `add <name>`, `remote`, `validate <name>`, `help`.
