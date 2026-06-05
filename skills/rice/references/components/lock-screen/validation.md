# lock-screen — validation

What `hyprland-config-validator` checks for the lock-screen output. Runs only when
`lock_screen.enabled = true` in `answers.json`; on `false`, the validator asserts that
`hyprlock.conf` was **not** written and skips the rest.

## Checks on `~/.config/hypr/hyprlock.conf`

### 1. Brace balance

The file is hyprlang nested blocks (`general {}`, `background {}`, `input-field {}`, `label {}`,
`auth { fingerprint {} }`). Every `{` must have a matching `}`. The cheap text check:

```bash
opens=$(grep -c '{' "$file")
closes=$(grep -c '}' "$file")
[ "$opens" = "$closes" ] || die "hyprlock.conf: brace mismatch — $opens '{' vs $closes '}'"
```

A mismatch always points at a missing `}` inside the last-edited block (usually the optional
`auth { fingerprint {} }` when the engine forgot to close `fingerprint`).

### 2. Required: a `background` block

Without a `background` block, hyprlock renders **transparent** on top of whatever surface was last
active — on some compositors that's a fully clear screen with only the input field floating,
which looks like a render bug. Even the `solid` background option emits a `background { color = … }`
block; assert one exists:

```bash
grep -q '^background\s*{' "$file" || die "hyprlock.conf: missing background block"
```

### 3. Required: an `input-field` block

**This is the lockout check.** Without an `input-field` block hyprlock has no way to accept a
password — the user is locked in (the lock screen is up, but nothing types). On a real session
this means the only recovery is `Ctrl+Alt+F2` → TTY → `pkill hyprlock`. The validator must
**hard-error** when this block is missing:

```bash
grep -q '^input-field\s*{' "$file" \
  || die "hyprlock.conf: missing input-field — the lock will accept no password (lockout risk)"
```

The error message must explicitly say *"lockout risk"* so the user understands why it's worth
fixing before testing.

### 4. Warn: `input-field` height < 30 px (sliver-pill smell test)

The keep-input-visible rule from [`gotchas.md`](./gotchas.md). Parse the `size = W, H` line inside
the `input-field` block and warn (not error) if `H < 30`:

```bash
size_h=$(awk '/^input-field/,/^}/ { if ($1=="size" && $2=="=") print $4 }' "$file" | tr -d ',')
if [ -n "$size_h" ] && [ "$size_h" -lt 30 ]; then
    warn "hyprlock.conf: input-field height $size_h px is below the 30 px floor — users report 'nothing happens when I type'"
fi
```

Same warning fires if `outline_thickness = 0` is combined with `fade_on_empty = true` (the
6 px-sliver pattern).

### 5. Warn: `grace = …` inside `general {}`

`grace` is a CLI flag (`hyprlock --grace N`), **not** a config key — silently ignored in the file.
Detection: look for `grace` on the LHS of `=` between `^general` and the matching `}`:

```bash
if awk '/^general\s*{/,/^}/ { if ($1=="grace" && $2=="=") found=1 } END { exit !found }' "$file"; then
    warn "hyprlock.conf: 'grace' inside general{} is silently ignored; use 'hyprlock --grace N' in the launcher instead (see gotchas.md)"
fi
```

Same pattern catches the other silently-ignored `general {}` keys: `no_fade_in`, `no_fade_out`,
`disable_loading_bar`, `pam_module`.

### 6. Warn: `font_family` carries a size suffix

`font_family = Inter 11` silently falls back to system default. The trailing space + digits is the
detection rule:

```bash
if grep -E '^\s*font_family\s*=\s*\S+\s+[0-9]+' "$file" >/dev/null; then
    warn "hyprlock.conf: font_family appears to carry a size suffix; hyprlock wants family only (set font_size on each widget)"
fi
```

### 7. Warn: fingerprint block without `fprintd` in the install batch

When `lock_screen.fingerprint = true` is recorded but `fprintd` is missing from the resolved
package list (cross-check `packages.md`):

```bash
if [ "$(jq -r .lock_screen.fingerprint answers.json)" = "true" ] \
   && ! grep -q '\bfprintd\b' "$staging/pkg-list"; then
    warn "lock_screen.fingerprint=true but fprintd is not in the install list — block will be a no-op"
fi
```

### 8. Cross-component: hypridle's `lock_cmd` is guarded

If [`../companion-daemons/`](../companion-daemons/) generated `hypridle.conf`, the validator also
checks that `lock_cmd = hyprlock` appears **only** as part of `pidof hyprlock || hyprlock` (or
equivalent). A bare `lock_cmd = hyprlock` triggers the stacking bug from
[`gotchas.md`](./gotchas.md):

```bash
if [ -f "$HOME/.config/hypr/hypridle.conf" ] \
   && grep -E '^\s*lock_cmd\s*=\s*hyprlock\s*$' "$HOME/.config/hypr/hypridle.conf" >/dev/null; then
    die "hypridle.conf: bare 'lock_cmd = hyprlock' — must be 'pidof hyprlock || hyprlock' to avoid stacking lockers"
fi
```

## Severity legend

- **die** — hard error; rice apply aborts before the file is moved into place.
- **warn** — prints a yellow `[warn]` line in the apply log; does not block.

## Cross-references

- The keep-input-visible rationale → [`gotchas.md`](./gotchas.md).
- The hypridle `lock_cmd` rule → [`../companion-daemons/`](../companion-daemons/).
- Schema → [`schema.md`](./schema.md).
