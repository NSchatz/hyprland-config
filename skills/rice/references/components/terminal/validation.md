# terminal — validation

Parse + sanity checks the writer (or `validate.sh`) runs on the emitted terminal configs
**before** the reload hook fires. kitty's parser is the strictest of the bunch — it reads
everything after the key as the value, so a trailing `# comment` on `background_blur 1` is
silently treated as part of the value and the setting goes inactive on every launch. That class
of defect is what these checks exist to catch.

## kitty — `~/.config/kitty/kitty.conf` (+ `colors.conf`)

### 1. No trailing inline comments on typed value lines (HARD FAIL)

kitty has no comment-stripping on value lines. Every explanatory comment must be on its own line
above the setting — never `<key> <value>  # comment`. The lint is a single grep against the
emitted `kitty.conf`:

```bash
# Reject lines of the form: `<key> <value...> # ...`
# Allow: pure comment lines (`# foo`), and key/value lines without a trailing comment.
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[^#[:space:]].*[[:space:]]+#' \
     "$HOME/.config/kitty/kitty.conf"; then
  echo "ERROR: kitty.conf has trailing inline comments on typed value lines" >&2
  echo "       move the comment to its own line above the setting" >&2
  exit 1
fi
```

The same lint applies to `colors.conf` — but the engine template (`kitty.tmpl`) has no value-line
comments by construction, so this guards against drift if the template is hand-edited.

### 2. kitty load-test (full parse)

The authoritative check is kitty itself parsing the file. Run when kitty is installed:

```bash
if command -v kitty >/dev/null; then
  kitty +runpy "
from kitty.config import load_config
from kitty.constants import config_dir
import os
load_config(os.path.join(config_dir, 'kitty.conf'))
print('OK')
" || { echo "ERROR: kitty rejected kitty.conf" >&2; exit 1; }
fi
```

If kitty isn't available in the rice-render environment (CI, headless validator), the grep lint
in check (1) is the minimum acceptable substitute — it catches the dominant defect class (trailing
inline comments) without needing the binary.

## foot — `~/.config/foot/foot.ini`

foot's INI parser also rejects trailing `# comment` on `key=value` lines under `[main]` / `[cursor]`
/ `[bell]` — comments must live on their own line. Same lint as kitty, scoped to the foot config:

```bash
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=[^#]*[[:space:]]+#' \
     "$HOME/.config/foot/foot.ini"; then
  echo "ERROR: foot.ini has trailing inline comments on key=value lines" >&2
  exit 1
fi
```

## ghostty — `~/.config/ghostty/config`

Ghostty's documented rule (`ghostty.org/docs/config`) is *"Comments must be on their own line.
Comments cannot be at the end of a line containing a configuration setting."* Same lint shape:

```bash
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=[^#]*[[:space:]]+#' \
     "$HOME/.config/ghostty/config"; then
  echo "ERROR: ghostty config has trailing inline comments on setting lines" >&2
  exit 1
fi
```

## alacritty / wezterm — informational only

TOML (alacritty) and Lua (wezterm) tolerate trailing `# …` / `-- …` on value lines, so the
strict lint above does not apply. The kitty load-test, foot.ini lint, and ghostty lint cover the
comment-strict cases; alacritty/wezterm need only their normal TOML/Lua parse check.

## Cross-references

- The comment hazard itself → `gotchas.md` (kitty section).
- Per-emulator parser quirks → `template.md` per-emulator subsections.
- The contract between `kitty.conf` (look) and `colors.conf` (palette) → `template.md`,
  `../../_shared/colors-contract.md`.
