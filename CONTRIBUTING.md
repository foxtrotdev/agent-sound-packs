# Contributing

Thanks for considering a contribution. The project is deliberately small — most useful contributions are new packs, new tool integrations, and platform ports.

## Quick rules

- **Never commit audio files.** `.gitignore` excludes `*.wav` and friends. Audio is user-supplied; the repo ships definitions and transcripts only.
- **Keep it bash 3.2 compatible.** macOS ships bash 3.2. No associative arrays. No `mapfile`. Run `bash -n` on every script you touch.
- **Keep hooks fast.** Hook scripts run on every event fire. Anything > 50ms is a regression. Background long work with `&`.
- **No runtime dependencies.** No Node, Python, Ruby, jq. Plain POSIX/bash + standard macOS/Linux utilities only.
- **Don't break the event enum.** `stop | notification | subagent | session | compact`. Adding a new event is a coordinated change across `play-random.sh`, every pack's `pool.conf`, `examples/settings.json`, `README.md`, `AGENTS.md`, and every `docs/<tool>.md`.

## Adding a new pack

1. Create `packs/<your-pack>/` and add a `pool.conf` (see `README.md#pack-format`).
2. (Optional but recommended) Run `scripts/transcribe.sh` to generate `transcripts.txt` and pick wavs by what they actually say.
3. Add an entry to the README's pack table (if one exists at the time).
4. Open a PR with a one-paragraph description: what the pack's theme is, where the audio comes from, and whether the audio is freely redistributable. Audio itself stays out of the repo.

## Adding a new tool integration

1. Add `scripts/integrations/<tool>-notify.sh` if the tool passes structured event data, modeled on `codex-notify.sh`. Map the tool's event types to the agent-sound-packs event enum.
2. Add `docs/<tool>.md` covering: install instructions, event mapping table, verification commands, known caveats.
3. Link the new doc from `README.md` and `docs/other-tools.md` if applicable.

## Adding platform support

1. Detect platform at the top of `play-random.sh` (`uname -s`).
2. Branch the final playback line by platform — keep one canonical script, not per-OS forks.
3. Document the dependency in `README.md#adapting-the-player`.

## Testing changes

```bash
export CCSP_ROOT=/tmp/ccsp-sandbox
./install.sh
mkdir -p $CCSP_ROOT/packs/sandbox-pack
# write a minimal pool.conf, drop a dummy wav
$CCSP_ROOT/scripts/test-sounds.sh
```

For shell-script changes, also run:

```bash
bash -n scripts/*.sh scripts/integrations/*.sh install.sh
shellcheck scripts/*.sh scripts/integrations/*.sh install.sh  # if installed
```

## PR checklist

- [ ] No `.wav` (or other audio) files added
- [ ] Scripts pass `bash -n`
- [ ] New integration includes `docs/<tool>.md` and example config snippet
- [ ] New pack includes `pool.conf` covering all five `POOL_*` arrays (empty allowed)
- [ ] `README.md` and `AGENTS.md` updated if you changed structure or invariants
- [ ] No new runtime dependencies introduced

## Code of conduct

Be decent to other contributors. That's it.
