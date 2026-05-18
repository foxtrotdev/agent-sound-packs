# Pack rules — the format every sound pack must follow

This is the canonical spec for what a valid `agent-sound-packs` pack looks like. Both the bundled packs and any third-party / community pack you want users to install with `add-pack.sh` must follow these rules.

`scripts/validate-pack.sh` enforces every rule on this page. `add-pack.sh` refuses to install any pack that fails validation.

## Why these rules exist

The player runs as a shell hook on every reply, notification, and session start. A malicious or buggy pack must not be able to:

1. Execute arbitrary code on the user's machine.
2. Read or overwrite files outside its own pack directory.
3. Eat disk by sneaking in huge files.
4. Pull in formats the player can't play, leaving the user in confused silence.

Rules below are written so that a strict, no-`source` text parser can verify a pack in milliseconds.

---

## Rule 1 — Folder layout

```
packs/
└── <pack-name>/
    ├── pool.conf            (required)
    ├── transcripts.txt      (optional)
    ├── .source              (written by add-pack.sh; do not commit)
    ├── sound-1.wav
    ├── sound-2.wav
    ├── …
    └── sound-N.wav
```

- The pack directory is **flat**. No subdirectories of any kind.
- The pack directory **must** contain `pool.conf`.
- `<pack-name>` matches `^[a-zA-Z0-9_-]{1,64}$`. No spaces, no dots, no leading dash.

## Rule 2 — File types

Only these are allowed inside the pack directory:

| Entry              | Purpose                                          |
|--------------------|--------------------------------------------------|
| `pool.conf`        | Maps events → sound files. Required.             |
| `transcripts.txt`  | TSV of `filename<TAB>transcript`. Optional.      |
| `.source`          | Provenance file written by `add-pack.sh`.        |
| `*.wav`            | Audio.                                           |
| `*.mp3`            | Audio.                                           |
| `*.ogg`            | Audio.                                           |
| `*.flac`           | Audio.                                           |

Anything else (`.sh`, `.py`, `.exe`, `.bin`, `Makefile`, README, dotfiles other than `.source`) is rejected.

## Rule 3 — No symbolic links

The pack must not contain any symlinks. Symlinks could point at `/etc/passwd`, the user's SSH keys, etc., and copy them when the pack is installed. `validate-pack.sh` rejects all `find -type l` hits.

## Rule 4 — Size caps

| Limit                | Default        | Override env var      |
|----------------------|----------------|-----------------------|
| Per-file maximum     | 5 MiB          | `MAX_FILE_SIZE`       |
| Total pack maximum   | 200 MiB        | `MAX_PACK_SIZE`       |

Sounds for UI feedback are short. Anything bigger is almost certainly a mistake (or an attack).

## Rule 5 — `pool.conf` format

The file is read by `play-random.sh` using a strict text parser. It is **never** `source`d. The parser only extracts basenames from `POOL_<EVENT>=( ... )` blocks. Everything else is treated as a hard error by the validator.

### Allowed grammar

Two equivalent styles. Mix them per-block if you want.

**Multi-line** (recommended for readability):

```bash
POOL_STOP=(
  first.wav
  second.wav
  third.mp3
)
```

**Single-line**:

```bash
POOL_STOP=(first.wav second.wav third.mp3)
```

Also allowed:

- Comments — any line beginning with `#`, including the comment-only header.
- Empty lines.

### Forbidden

The validator rejects pool.conf if it contains any of these **outside comments**:

| Token              | Why                                |
|--------------------|------------------------------------|
| `` ` ``            | Command substitution               |
| `$(`               | Command substitution               |
| `${`               | Variable expansion                 |
| `\|`, `\|\|`, `&&`, `;` | Command chaining             |
| `>`, `<`           | Redirects                          |
| `eval`, `source`   | Code-loading builtins              |

Filenames inside arrays must match exactly:

```
^[a-zA-Z0-9._-]+\.(wav|mp3|ogg|flac)$
```

That means: **no slashes, no spaces, no shell metacharacters, no absolute paths**. Audio files live next to `pool.conf`, period.

### Five canonical pool names

```
POOL_STOP
POOL_NOTIFICATION
POOL_SUBAGENT
POOL_SESSION
POOL_COMPACT
```

Any pool may be empty — that just means "silence for that event".

## Rule 6 — Every referenced file must exist

If `pool.conf` lists `headshot.wav`, then `headshot.wav` must be a real file in the pack directory. Otherwise the player would fire silently when that entry is picked.

The validator emits one error per missing file.

---

## Verifying your pack before you publish

```bash
# Clone or build your pack folder somewhere, then:
~/.claude/sounds/scripts/validate-pack.sh path/to/my-pack

# Exit 0 = pack passes every rule. Exit non-zero = rules violated, errors printed.
```

If `validate-pack.sh` is happy, `add-pack.sh` will install your pack on any user's machine.

## Publishing a community pack

1. Put your pack at `packs/<name>/` inside any public git repo.
2. Make sure `validate-pack.sh` passes locally.
3. Tell users to install it with:
   ```bash
   ~/.claude/sounds/scripts/add-pack.sh <your-git-url> <name>
   ```
4. Optional: ship a top-level `packs.json` in the same shape as this repo's so catalog-style tools can list your packs with metadata.

## A note for pack authors

Yes, the rules feel strict. They're strict because **every other user trusts you not to brick their machine** when they type `add-pack.sh your-repo your-pack`. A pack that follows the rules can't read the user's home dir, can't run code, can't fill their disk. That's the entire point.
