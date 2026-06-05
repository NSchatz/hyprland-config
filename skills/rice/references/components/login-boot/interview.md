# login-boot — interview

Group 19. The login screen, the boot splash, and the GRUB menu — the chrome around the desktop
that lives under `/etc`, `/usr`, and `/boot`.

This is an **opt-in component with a gate**. Per `_interview-protocol.md` → "Strict — ask every
question" / "Opt-in gate questions": **the gate is always asked**, never silently defaulted from
detection. Detection (which DM is active, whether Plymouth/GRUB are present) reorders the option
list and pre-fills the matching pick — it does **not** answer the gate.

The gate has two real branches:

- **Off** (default — root-side, most users skip it) → record `login_boot.greeter = "none"`,
  `login_boot.plymouth = false`, `login_boot.grub_theme = false` and move on.
- **On** → ask 19a (multi-select: greeter / Plymouth / GRUB) and record each.

On a re-theme (Mode B), this whole component is **skipped** — re-theming only walks `look-feel`,
palette, fonts, wallpaper. The login chrome doesn't re-render on `rice apply` (see `gotchas.md`
→ "Coarse re-themes").

## Detection (for option order only, not for the gate)

Run before asking 19:

```bash
# Active display manager. is-enabled prints the state ("enabled", "disabled", "masked", ...)
# and exits 0 only when enabled, so we test the state string rather than chaining `&&`
# (which would also fire on "static" units).
detect_dm() {
  for u in greetd sddm gdm lightdm; do
    state=$(systemctl is-enabled "$u.service" 2>/dev/null) || continue
    case "$state" in
      enabled|enabled-runtime) echo "$u"; return ;;
    esac
  done
  echo none
}
ACTIVE_DM=$(detect_dm)

# Plymouth / GRUB presence
HAVE_PLYMOUTH=$(command -v plymouth-set-default-theme >/dev/null 2>&1 && echo 1 || echo 0)
HAVE_GRUB=$(    [ -d /boot/grub ] && echo 1 || echo 0)
```

The detected DM determines which greeter option is **listed first**, not whether the gate is asked.
`HAVE_PLYMOUTH` / `HAVE_GRUB` annotate the options ("not detected — will be installed if you pick
it") but don't hide them.

## Skip-silently rule

If the user has already told the interviewer they only want the per-user desktop (e.g. via
`$ARGUMENTS` like "just my user config, don't touch system stuff", or by answering an earlier
gate to that effect), **skip this component entirely** and record:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.greeter none
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.plymouth --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.grub_theme --json false
```

No `AskUserQuestion` call in that path. Otherwise, ask 19 unconditionally.

## AskUserQuestion shape

Group 19 splits into **up to 2 calls** (≤ 4 sub-questions per call):

- **Call 1** (always asked, unless skip-silently fires): 19 — the gate.
  Single yes/no, two options ("Theme the login screen and boot?" / "No, leave them as-is").
- **Call 2** (only if 19 == yes): 19a — multi-select over **greeter**, **Plymouth**, **GRUB**.
  Each as its own sub-question in the call (3 sub-qs total, under the 4-cap).

## Sub-questions

### 19. Theme the login screen and boot?  *(always asked — opt-in gate)*

Single-select. Default off because everything here needs root.

- **No, leave them as-is** *(default)* — most users skip this. Records the three keys as off and
  stops the component. The per-user desktop is fully themed without touching `/etc`.
- **Yes, generate the files and give me the sudo commands** — proceeds to 19a. The plugin will
  stage files under `<staging>/_login/` and emit a "run these commands" report at the end. Claude
  never sudos; the user runs the commands.

### 19a. What to theme  *(only when 19 == yes)*

Three sub-questions, packed into one `AskUserQuestion` call (`multiSelect` per sub-q where
sensible).

**19a-i. Greeter** *(single-select; pre-filled from detected DM)*

- **greetd + tuigreet** — CLI greeter, in-terminal, themed via flags on the `command =` line
  in `/etc/greetd/config.toml`. Lightest option; no GTK runtime. Colors are named (not hex) —
  the template maps `accent`/`bg`/`fg` to the closest named ANSI color.
- **greetd + ReGreet** — GTK4 greeter for greetd, runs inside a nested `cage` compositor
  (`dbus-run-session cage -s -mlast -d -- regreet`). Inherits the user's GTK theme via the
  `[GTK]` block in `/etc/greetd/regreet.toml` (which ReGreet applies through GTK's settings
  API at runtime). Background image matches the wallpaper.
- **SDDM** — Qt greeter. Theme via `theme.conf` of `sddm-astronaut` / `sugar-candy` /
  `catppuccin-sddm`. Pulls the Qt runtime as a dep — see `packages.md`.
- **None** — don't touch the greeter. (Pick this if the user only wants Plymouth or GRUB themed.)

If detection says GDM is active, list it as a separate footnote-option ("**Switch to greetd**
— GDM is not theme-friendly; see `gotchas.md`") rather than offering GDM theming.

**19a-ii. Plymouth boot splash?** *(yes/no)*

- **Yes** — generate a palette-matched theme dir under `<staging>/_login/plymouth/<name>/` and
  emit `sudo plymouth-set-default-theme -R <name>`. If `HAVE_PLYMOUTH=0`, the install command
  is added to the commented sudo block in `install.sh`.
- **No** *(default)* — leave the existing splash (or no splash) untouched.

**19a-iii. GRUB theme?** *(yes/no)*

- **Yes** — generate a palette-matched theme dir under `<staging>/_login/grub/themes/<name>/`,
  emit the `GRUB_THEME=` line for `/etc/default/grub`, and emit the `sudo grub-mkconfig -o
  /boot/grub/grub.cfg` regen command. If `HAVE_GRUB=0`, skip silently (the user doesn't boot
  via GRUB — could be systemd-boot, rEFInd, etc.).
- **No** *(default)* — leave the boot menu untouched.

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh` (see `_interview-protocol.md`
→ "Recording answers"):

```bash
# 19 (always)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.greeter none
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.plymouth   --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.grub_theme --json false

# 19a (only when 19 == yes) — overwrite the keys above with the real picks
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.greeter    greetd-tuigreet
# or: greetd-regreet | sddm | none
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.plymouth   --json true
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" login_boot.grub_theme --json true
```

The record paths are flat — there is no nested object per sub-tool. The three keys
(`greeter`, `plymouth`, `grub_theme`) capture everything the writer needs.

## Cross-references

- Strict-ask discipline + opt-in-gate rule → `_interview-protocol.md`
- Schema slice + value enums → `schema.md`
- Per-tool generation recipes (greetd / SDDM / Plymouth / GRUB) → `template.md`
- Root-side discipline, DM detection, GDM caveat → `gotchas.md`
- Packages (the **commented** sudo block in `install.sh`) → `packages.md`
- Palette source for greeter / Plymouth / GRUB color values → `_shared/palette-schema.md`
