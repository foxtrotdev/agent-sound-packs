# AGENTS.md

Machine-readable conventions for coding agents (Claude Code, Cursor, Copilot, etc.) extending this repo. Read before generating PRs.

## Scope

This repo provides audible feedback for Claude Code lifecycle events. The architecture is intentionally tiny: two scripts, per-pack config files, no runtime.

## Repository map

```
/                         project root
├── install.sh            installs into $CCSP_ROOT (default ~/.claude/sounds)
├── scripts/
│   ├── play-random.sh    hook entrypoint; called by Claude Code on events
│   ├── switch-pack.sh    CLI: read/write ~/.claude/sounds/active-pack
│   ├── transcribe.sh     whisper.cpp helper for pack curation
│   └── test-sounds.sh    QA: play one from each event pool
├── packs/<name>/
│   ├── pool.conf         REQUIRED — bash arrays mapping event → wav files
│   └── transcripts.txt   optional — TSV (filename<TAB>spoken text)
├── examples/settings.json sample Claude Code hooks block
├── README.md             human docs
├── AGENTS.md             this file
├── CONTRIBUTING.md       human-facing contribution guide
├── LICENSE               MIT
└── .gitignore            excludes *.wav and other audio formats
```

## Invariants — do NOT change without justification

1. **Event name enum.** Exactly five events are supported, all lowercase:
   `stop | notification | subagent | session | compact`.
   These map 1:1 onto Claude Code hook events `Stop | Notification | SubagentStop | SessionStart | PreCompact`. Changing names breaks every installed user's `settings.json`.

2. **Pool variable names.** `POOL_STOP`, `POOL_NOTIFICATION`, `POOL_SUBAGENT`, `POOL_SESSION`, `POOL_COMPACT`. Upper-snake. Match the event enum.

3. **`active-pack` file format.** Plain text, single line, pack folder name, no trailing newline-only file, no JSON.

4. **Install paths.** Players land at `$CCSP_ROOT/play-random.sh` and `$CCSP_ROOT/switch-pack.sh` (TOP LEVEL — not under `scripts/`). Settings.json hooks reference absolute paths; nesting them breaks installs.

5. **File naming convention** for wav files inside a pack: lowercase, kebab-case, numeric suffixes with dash. Validated implicitly by pool.conf references. See `README.md#file-naming-convention`.

6. **No audio committed.** `*.wav`, `*.mp3`, `*.aiff`, `*.m4a`, `*.ogg`, `*.flac` are gitignored. Pack contributions ship `pool.conf` + optional `transcripts.txt` only; users supply their own audio.

7. **No-spam events.** `PreToolUse`, `PostToolUse`, `UserPromptSubmit` are deliberately unmapped. Do not add support unless explicitly requested.

## pool.conf grammar

```bash
# Comments start with '#'. Blank lines OK.
POOL_<EVENT>=(
  file-1.wav
  file-2.wav
  ...
)
```

- Five `POOL_*` arrays expected. Any may be empty (`POOL_X=()`) — that event will be silent.
- Filenames are resolved relative to the pack folder.
- No subdirectories inside a pack; flat layout only.
- File must be `source`-able by POSIX `bash` — keep it pure data, no logic.

## Extension points

| Want to... | Edit |
|------------|------|
| Add a new pack | `packs/<new-name>/pool.conf` (+ optional `transcripts.txt`). Update `README.md` pack table if listing. |
| Add a new event | Edit `play-random.sh` case statement, `pool.conf` template in all packs, `examples/settings.json`, README event table, this file's invariant #1. Coordinate as a single PR. |
| Support non-macOS player | Branch on `uname` in `play-random.sh` final line. See `README.md#adapting-the-player`. |
| Add a new pack source format | Write a converter under `scripts/` that emits a valid `pool.conf`. Do not change the in-tree pack format. |

## Adding a pack — step-by-step (for agents)

```bash
# 1. Create pack folder
mkdir -p packs/<pack-name>

# 2. Write pool.conf — must include all five POOL_* arrays
cat > packs/<pack-name>/pool.conf <<'EOF'
POOL_STOP=()
POOL_NOTIFICATION=()
POOL_SUBAGENT=()
POOL_SESSION=()
POOL_COMPACT=()
EOF

# 3. (Optional) Document what the audio should sound like in transcripts.txt
#    Format: filename<TAB>description

# 4. Validate: bash should source pool.conf without error
bash -n packs/<pack-name>/pool.conf
( source packs/<pack-name>/pool.conf && \
  echo "stop:$#POOL_STOP[@] notification:$#POOL_NOTIFICATION[@] ..." )

# 5. Update README.md pack list (if maintaining a catalog)
```

## Testing changes locally

```bash
# Install into a sandboxed root so you don't clobber your real install
export CCSP_ROOT=/tmp/ccsp-sandbox
./install.sh
mkdir -p $CCSP_ROOT/packs/<pack>/  # drop dummy wavs here if needed
$CCSP_ROOT/scripts/test-sounds.sh
```

## What an agent should NOT do

- Do not auto-commit `.wav` files even if the user has them locally. Always verify gitignore catches them.
- Do not edit `~/.claude/settings.json` programmatically without explicit user consent — it's a sensitive, user-owned config file. Print suggested edits instead.
- Do not rename pool variable names or event enum values without bumping a major version and migrating consumers.
- Do not introduce a runtime (Node, Python, etc.) for this — the whole point is "two bash scripts + a config file."
- Do not add network calls. Hook scripts must run offline.
- Do not block: the `afplay ... &` background fork is load-bearing. Hook scripts should return in <50ms.

## Quick health check

A correctly installed setup satisfies:

```bash
[ -x ~/.claude/sounds/play-random.sh ]
[ -x ~/.claude/sounds/switch-pack.sh ]
[ -f ~/.claude/sounds/active-pack ]
[ -f ~/.claude/sounds/packs/$(cat ~/.claude/sounds/active-pack)/pool.conf ]
grep -q play-random.sh ~/.claude/settings.json
```

If all five exit 0, the install is wired correctly. Audio playback still depends on the user dropping actual `.wav` files into the active pack folder.
