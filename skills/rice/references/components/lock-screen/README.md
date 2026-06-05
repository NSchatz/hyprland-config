# lock-screen

Interview group 10 — the **hyprlock** lock screen (background, clock, input pill, optional
fingerprint). hyprlock is a dedicated daemon launched fresh per lock; it does **not** sit in the
session. This component owns `hyprlock.conf` and the look knobs that drive it.

Companion daemons (hypridle's `lock_cmd`, the autostart `exec-once`) live in
[`companion-daemons`](../companion-daemons/); the bind that triggers a manual lock
(`bind = $mainMod, X, exec, hyprlock`) lives in [`keybinds`](../keybinds/). This component just
generates the config.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 10a–10e (enable, background, clock, input pill, fingerprint). One `AskUserQuestion` call. |
| `schema.md` | The `lock_screen.*` keys this component owns in `answers.json`. |
| `template.md` | The full `hyprlock.conf` template — `background`, `input-field`, `label`s, optional `auth { fingerprint {} }`. Colors are filled at generate-time. |
| `styling.md` | Full hyprlock design library (palette, layout, technique catalog). Verbatim copy of `hyprland-reference/styling/hyprlock.md`. |
| `gotchas.md` | Keep-input-visible rule, literal-hex colors, fingerprint enrolment, `pidof` guard for hypridle's `lock_cmd`, phantom `general {}` keys (per-rice citations). |
| `validation.md` | Brace balance + required-block checks for `hyprlock.conf` (background, input-field). |
| `packages.md` | `hyprlock` (repo) + optional `fprintd` (repo, fingerprint). |
| `reload.md` | hyprlock is launched fresh per lock — there's no running daemon to signal. Config changes apply on next lock. |

**No `.tmpl` in this folder.** Unlike waybar / notifications / launcher / terminal / etc., lock-screen
does **not** ship a separate `<app>.tmpl` color file. hyprlock cannot read Hyprland `$vars`, so the
engine substitutes palette literals (`{{accent}}`, `{{surface}}`, `{{fg}}`, `{{bg}}`, `{{green}}`,
`{{red}}`) directly into `hyprlock.conf` at `rice apply` time. The community's two alternatives
(`source = hyprlock-colors.conf` written by matugen, e.g. end-4 / ml4w / Ax-Shell / dusky; or
`source = mocha.conf` palette-var file, e.g. catppuccin / Matt-FTW / omarchy) are documented in
[`styling.md`](./styling.md) but not used by the rice — one less file to track per the v0.13
design. See [`gotchas.md`](./gotchas.md) → "Colors are LITERAL hex".

## Where this component lands

- **hyprlock config:** `~/.config/hypr/hyprlock.conf`. Read only when the daemon is launched
  (i.e. on lock); no live reload.
- **Hyprland config:** nothing direct. The lock bind is in `binds.conf` (owned by `keybinds`); the
  `lock_cmd` is in `hypridle.conf` (owned by `companion-daemons`).
- **Cursor / fonts:** UI font family is pulled from `palette.conf` (`font_ui` family name only —
  no size suffix in hyprlock's `font_family`). Colors are pulled from `palette.conf` as **literal
  hex** (hyprlock can't read Hyprland `$vars`; see `gotchas.md`).

## Related components

- [`companion-daemons`](../companion-daemons/) — owns `hypridle.conf`; its `lock_cmd` points at
  `hyprlock` and **must** be guarded with `pidof hyprlock || hyprlock` to avoid stacking lockers.
  If this component is disabled (`lock_screen.enabled = false`), the `lock_cmd` and the lock-class
  listener are dropped from `hypridle.conf`.
- [`keybinds`](../keybinds/) — emits `bind = $mainMod, X, exec, hyprlock` when this component is
  enabled; omits it otherwise.
- [`accessibility`](../accessibility/) — the fingerprint sub-question (10e) is mirrored there for
  the broader auth/biometric story (it's the same `fprintd` stack).
- [`palette`](../../theming/palettes.md) + [`fonts`](../../theming/fonts.md) — supply the literal
  hex (`accent`, `surface`, `fg`, `green`, `red`) and the UI font family that the template
  substitutes at generate-time.
- [`look-feel`](../look-feel/) — unrelated to the lock screen itself; flagged here so it's clear
  blur/rounding from `looknfeel.conf` do **not** propagate to hyprlock.
