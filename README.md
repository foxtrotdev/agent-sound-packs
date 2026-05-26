<p align="center">
  <img src="logo.png" alt="agent-sound-packs" width="280">
</p>

<h1 align="center">agent-sound-packs</h1>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Platform: macOS / Linux / WSL" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg">
  <img alt="Packs: 15" src="https://img.shields.io/badge/packs-15-success.svg">
  <a href="https://claude.com/claude-code"><img alt="Claude Code" src="https://img.shields.io/badge/Claude_Code-supported-D97757.svg"></a>
  <a href="https://github.com/openai/codex"><img alt="Codex CLI" src="https://img.shields.io/badge/Codex_CLI-supported-10A37F.svg"></a>
</p>

<p align="center"><strong>Your AI coding agent talks back.</strong></p>

---

## What it does

Your AI coding agent (Claude Code, Codex, …) plays a short sound when it finishes a
reply, needs your input, or hits another moment in its work. Pick a theme — Mortal
Kombat, Futurama, a Warcraft peon — and you *hear* what your agent is doing without
watching the screen.

A **pack** is a theme: a folder of short audio clips. You can switch packs in one
command, or make your own. 15 packs ship in the box.

Sounds fire on these moments (**events**):

| Event | When it plays |
|-------|---------------|
| `stop` | The agent finished its reply |
| `notification` | The agent needs you (a permission prompt, or it went idle) |
| `subagent` | A background sub-task finished |
| `session` | A new session started |
| `compact` | The conversation is about to be summarized |

Each event picks a random clip from that pack, so it stays fresh.

---

## Install

### Claude Code (recommended — no files to edit)

Type these two lines inside Claude Code:

```text
/plugin marketplace add foxtrotdev/agent-sound-packs
/plugin install agent-sound-packs@agent-sound-packs
```

Done. Sounds wire up automatically and the next reply ends with one. Starts on the
`peon-en` pack (a Warcraft III orc peon) — change it any time (see [Use it](#use-it)).

### Codex CLI

Codex has no plugin system, so it uses a small installer + one config line.

```bash
git clone https://github.com/foxtrotdev/agent-sound-packs.git
cd agent-sound-packs
./install.sh
```

Then add the `notify` line to `~/.codex/config.toml`. Codex needs an absolute path
and TOML won't expand `$HOME` — so let the shell write it for you (no username to
type):

```bash
echo "notify = [\"bash\", \"$HOME/.claude/sounds/scripts/integrations/codex-notify.sh\"]" >> ~/.codex/config.toml
```

Restart Codex. You'll get a "task done" chime on each turn. (Codex only exposes the
`stop` event — full details in [`docs/codex.md`](docs/codex.md).)

### Other agents

Aider, Cursor, Cline, or any CLI with a post-turn shell hook → [`docs/other-tools.md`](docs/other-tools.md).

**Requirements:** macOS, Linux, or Windows via **WSL** (not PowerShell/cmd — it's a
Bash toolkit). The player auto-detects on every platform; no audio setup needed on a
standard machine.

---

## Use it

Inside your agent, one slash command does everything:

| Command | What it does |
|---------|--------------|
| `/sound-pack` | List packs + show the active one |
| `/sound-pack switch <name>` | Switch theme |
| `/sound-pack volume <0-100>` | Set playback volume |
| `/sound-pack mute` · `unmute` | Silence / re-enable all sounds |
| `/sound-pack test` | Play one clip from each event |
| `/sound-pack add <name>` | Install another pack from the catalog |
| `/sound-pack remote` | Browse the catalog |
| `/sound-pack new <name>` | Start your own pack |
| `/sound-pack update [--all]` | Refresh installed packs |
| `/sound-pack validate <name>` | Check a pack is well-formed |

> Slash commands need a one-time copy: Claude Code `examples/commands-claude/sound-pack.md` → `~/.claude/commands/`; Codex `examples/commands-codex/sound-pack.md` → `~/.codex/prompts/`.

Prefer the terminal? The same actions are plain scripts (standalone/Codex install):

```bash
~/.claude/sounds/switch-pack.sh                 # list / show active
~/.claude/sounds/switch-pack.sh futurama        # switch theme
~/.claude/sounds/scripts/test-sounds.sh         # play one of each event
~/.claude/sounds/scripts/add-pack.sh dbz        # install another pack
```

Or source `~/.claude/sounds/scripts/aliases.sh` from your shell rc for `sp`, `sp-test`,
`sp-play <event>`, `sp-new <name>`.

### Volume & mute

Easiest: `/sound-pack volume 70`, `/sound-pack mute`, `/sound-pack unmute` (or the
`sp` alias). These write the config file for you.

Prefer editing by hand? It all lives in `~/.config/agent-sound-packs/config.json`:

```json
{ "enabled": 1, "volume": 70, "pack": "futurama" }
```

`enabled: 0` mutes. Or per-shell: `CCSP_ENABLED=0 claude`. Full options in
[`docs/claude-code.md`](docs/claude-code.md).

---

## Make your own pack

A pack is just a folder of clips plus a `pool.conf` that says which clip plays for which
event. No coding required.

```bash
~/.claude/sounds/scripts/new-pack.sh my-pack            # 1. scaffold the folder
cp ~/Downloads/*.wav ~/.claude/sounds/packs/my-pack/    # 2. drop in your clips
open ~/.claude/sounds/packs/my-pack/pool.conf           # 3. list clips per event
~/.claude/sounds/switch-pack.sh my-pack                 # 4. use it
```

`pool.conf` looks like this — leave a list empty for silence on that event:

```bash
POOL_STOP=(done-1.wav done-2.wav)
POOL_NOTIFICATION=(hey.wav)
POOL_SUBAGENT=()
POOL_SESSION=(hello.wav)
POOL_COMPACT=(oh-no.wav)
```

Tips: keep clips 1–3 seconds; list several per event for variety. Full rules and how to
publish a pack for others to `add-pack.sh`: [`PACK_RULES.md`](PACK_RULES.md).

---

## More docs

- [`docs/claude-code.md`](docs/claude-code.md) — Claude Code events, config, manual hook setup
- [`docs/codex.md`](docs/codex.md) — Codex integration + the approval-prompt gap
- [`docs/other-tools.md`](docs/other-tools.md) — Aider / Cursor / generic CLIs
- [`PACK_RULES.md`](PACK_RULES.md) — pack format + safety rules
- [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`AGENTS.md`](AGENTS.md) — contributing / conventions

<details>
<summary>Where things install + how a sound fires</summary>

Everything lands in `$CCSP_ROOT` (default `~/.claude/sounds`): `play-random.sh` (called
by the hook), `switch-pack.sh`, helper scripts under `scripts/`, and `packs/<name>/`.
The active pack name is a one-line file, `active-pack`.

On each event: the tool's hook runs `play-random.sh <event>` → it reads `active-pack` →
opens that pack's `pool.conf` → picks a random clip from `POOL_<EVENT>` → plays it in the
background. `pool.conf` is parsed as plain text (never executed), so a malformed or
malicious pack can't run code. Community packs are validated before install (flat layout,
audio only, no symlinks, size caps).
</details>

---

## Non-commercial fan project — no monetization

Hobbyist open-source utility. The maintainer earns nothing from it. Bundled clips are
short excerpts from games, cartoons, and films, reused only as functional UI cues
(~1–3 s each, like a notification chime). All copyrights stay with their original
creators; no ownership claimed. Use is intended as fair use / non-commercial only.

**Rightsholder and want a pack removed?** Open an issue or email the maintainer — it's
pulled on first request, no questions asked. **Forking to redistribute publicly?** Swap
the bundled clips for audio you own; the system only needs short audio files and a
`pool.conf`.

---

## License

MIT — see [`LICENSE`](LICENSE). Scripts and pack definitions are MIT. Audio you place in
pack folders stays under its original copyright (`.gitignore` excludes it; don't commit
audio you can't redistribute).
