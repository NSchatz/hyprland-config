# browser — validation

Parse + sanity checks the writer (or `validate.sh`) runs on the emitted browser-theming
artifacts **before** the reload hook fires. The userChrome route ships only CSS + JS, both
silent-failure prone — a typo in user.js drops every pref without a diagnostic; a malformed
selector in userChrome.css is ignored without an error. Catch both at generate-time.

## Checks

### 1. `firefox.tmpl` renders to valid CSS

Strip the `:root` block from the rendered `rice-colors.css` and pass it through a CSS parser.
There's no GNU/Linux-canonical headless CSS linter, but `csstree-validator` (`npm install -g
csstree-validator`) or a hand-rolled `python3 tinycss2` check both work:

```bash
python3 -c "
import sys, re
src = open('$out/chrome/rice-colors.css').read()
# minimal validity: balanced braces, every property has a colon + a non-empty value.
if src.count('{') != src.count('}'):
    sys.exit('ERROR: rice-colors.css braces unbalanced')
for line in src.splitlines():
    line = line.strip()
    if not line or line.startswith('/*') or line.endswith('*/'):
        continue
    if line in ('{', '}') or line.endswith('{') or line.endswith('}'):
        continue
    if not re.match(r'^[a-z-]+\s*:\s*\S.*;$', line):
        sys.exit(f'ERROR: bad CSS line: {line}')
print('OK')
" || exit 1
```

The render template is small (12 lines of `--rice-*: #hex;`) — any failure here is a real
defect in `firefox.tmpl`, not in the renderer.

### 2. `user.js` syntactic check

Firefox doesn't lint `user.js` — invalid lines silently fail. The shape is rigid:

```bash
if grep -nvE '^[[:space:]]*(//|/\*|\*|$|user_pref\(".*",.*\);)' \
     "$out/user.js" | grep -v '^[[:space:]]*\*/$'; then
    echo "ERROR: user.js has lines that aren't comments or user_pref() calls" >&2
    exit 1
fi
```

This catches the dominant defect: a key with the wrong syntax (e.g. `user_pref("foo", bar)`
missing the closing `);`) silently drops every pref AFTER the malformed line, leaving the
profile half-configured.

### 3. The bootstrap script's emitted profile path exists

`firefox-bootstrap.sh` prints `FIREFOX_PROFILE=<absolute-path>` on success. The install step
that calls it must check the dir exists and is writable — otherwise the templates.list
manifest line will write to a non-existent path and `rice apply` will SKIP it silently:

```bash
ff_profile="$(grep ^FIREFOX_PROFILE= "$staging/firefox-bootstrap.log" | cut -d= -f2-)"
[ -n "$ff_profile" ] || { echo "ERROR: bootstrap script didn't emit FIREFOX_PROFILE" >&2; exit 1; }
[ -d "$ff_profile" ] || { echo "ERROR: $ff_profile does not exist" >&2; exit 1; }
[ -w "$ff_profile" ] || { echo "ERROR: $ff_profile not writable" >&2; exit 1; }
```

### 4. `legacyUserProfileCustomizations.stylesheets` pref is locked

The single biggest "I followed the recipe and nothing changed" failure is the pref being off
— see `gotchas.md`. Grep for it in user.js post-install:

```bash
if ! grep -q '^user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' \
       "$ff_profile/user.js"; then
    echo "ERROR: $ff_profile/user.js is missing the legacy-stylesheets pref" >&2
    echo "       userChrome.css will be silently ignored without it" >&2
    exit 1
fi
```

### 5. `browser.startup.page = 3` is locked

If the restart hook is enabled (`browser_theming.restart_hook == true`), the session-restore
pref must be set, or every `rice apply` will lose tabs:

```bash
if grep -q '^user_pref("toolkit.legacyUserProfileCustomizations' "$ff_profile/user.js" && \
   ! grep -q '^user_pref("browser.startup.page", 3);' "$ff_profile/user.js"; then
    echo "WARN: browser.startup.page is not 3; firefox-restart.sh will lose tabs on restart" >&2
fi
```

## Lint targets the validator doesn't run

Two things the validator does **not** check (intentionally):

- **Whether `userChrome.css` produces a visually-coherent result.** That's a render-correctness
  question, not a parser-correctness question. Manual inspection in `about:profiles` →
  "Open in new browser" is the only way.
- **Whether `pywalfox` is set up correctly when `route == "pywalfox"`.** Pywalfox is out-of-band
  (its native-messaging host + the add-on), the rice doesn't manage it. The validator emits
  an INFO note saying so.

## Cross-references

- The two prefs' role → `gotchas.md`.
- The bootstrap script's `profiles.ini` resolution → `assets/scripts/firefox-bootstrap.sh`.
- The manifest-completeness assertion → `agents/hyprland-config-validator.md`.
