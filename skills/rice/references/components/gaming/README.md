# gaming

**OPT-IN** — the latency/perf tweaks competitive and gaming users expect and a generator usually
omits: screen tearing, VRR / adaptive sync, fullscreen effect-stripping, and a runtime "game mode"
toggle bound to `SUPER+F1`. Gated behind a single yes/no question (20a) so non-gamers never see
the sub-questions. On `no`, only `enabled: false` lands in `answers.json` and nothing in this
folder generates output.

Most of what this component does is *tweak existing files* — it doesn't own its own `.conf`. It
appends to `looknfeel.conf`, `windowrules.conf`, `monitors.conf`, and `binds.conf`, and copies
one shell script into `~/.config/hypr/scripts/`. It **does not** touch `env.conf` (older
revisions tried to emit a kernel-gated `WLR_DRM_NO_ATOMIC` line, but Hyprland has used
aquamarine — not wlroots — since v0.42; the var is a no-op and was removed).

The biggest single perf win — `misc:vfr = true` — is **not** gated by this component; it's a
default in the `look-feel` template for every user, gamer or not.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Gate (20a) + four sub-questions (20b–20e) asked only on yes. |
| `schema.md` | The `gaming.{enabled, tearing_classes, vrr_mode, strip_fullscreen_effects, gamemode_toggle}` slice. |
| `template.md` | The lines emitted *into other components' files* — `allow_tearing`, per-class `immediate` rules, per-monitor `vrr` field, fullscreen effect-strip rules, and the `SUPER+F1` bind. No env line is emitted — Hyprland's aquamarine backend ignores `WLR_*` vars and `AQ_NO_ATOMIC` is upstream-flagged "not recommended". |
| `gotchas.md` | Why no `WLR_DRM_NO_ATOMIC` is emitted (aquamarine since 0.42), per-monitor VRR placement, `gamemode.sh` ships as a copy-not-render template, where the fullscreen rules actually go (and the `no_border` non-field trap), where to source tearing classes, and the `misc:vfr` non-gate. |
| `packages.md` | None (Hyprland-internal). Optional `gamemoded` if the user wants the system service. |

## Where this component lands

- **`looknfeel.conf`** (owned by `look-feel`): adds `general:allow_tearing = true` when any
  tearing classes were given. The unconditional `misc:vfr = true` is set there too, but as a
  baseline — not via this component.
- **`windowrules.conf`** (owned by `window-rules`): per-class `immediate = true` rules (one per
  entry in `gaming.tearing_classes`) and the four fullscreen effect-strip rules when
  `strip_fullscreen_effects` is true.
- **`monitors.conf`** (owned by `monitors`): the `, vrr, <N>` field appended to every `monitor =`
  line when `vrr_mode != 0`. The monitors component owns the line; this component supplies the
  integer.
- **`binds.conf`** (owned by `keybinds`): the `bind = $mainMod, F1, exec, ~/.config/hypr/scripts/gamemode.sh`
  line when `gamemode_toggle` is true.
- **`env.conf`** (owned by `env`): **nothing** — Hyprland is aquamarine-based since 0.42, so
  the legacy `WLR_DRM_NO_ATOMIC` is a no-op and the aquamarine equivalent (`AQ_NO_ATOMIC`) is
  upstream-flagged "not recommended". No kernel gate, no emission.
- **`~/.config/hypr/scripts/gamemode.sh`**: copy (`cp` + `chmod +x`) of
  `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/gamemode.sh`. No template substitution.

## Related components

- [`look-feel`](../look-feel/) — owns `looknfeel.conf` (`allow_tearing` lands there; `misc:vfr` is
  its baseline).
- [`window-rules`](../window-rules/) — owns `windowrules.conf` (per-class tearing + fullscreen
  effect-strip rules land there). The video-player class-based `idle_inhibit = focus` pattern
  that fufexan and linuxmobile use for `mpv` / browser-YouTube lives in **window-rules**, not
  here — see `gotchas.md`.
- [`monitors`](../monitors/) — owns `monitors.conf` (per-monitor `vrr` field). Note: most
  corpus rices set VRR globally via `misc:vrr = N` in `look-feel`, not per-monitor — see
  `gotchas.md`. Per-monitor is the safer multi-display form; the global form is the
  single-monitor shortcut.
- [`keybinds`](../keybinds/) — owns `binds.conf` (`SUPER+F1` lands there).
- [`env`](../env/) — owns `env.conf`. This component intentionally emits **nothing** there; see
  the env component's `gotchas.md` for why `WLR_DRM_NO_ATOMIC` / `AQ_NO_ATOMIC` are excluded
  from the slim recommended set.
- [`utilities`](../utilities/) — the copy-not-render script install pattern is shared with this
  component's `gamemode.sh`.

## What the corpus says about gaming-as-theming

Short version: **gaming is "just don't break the desktop" for every rice in the corpus**. No
top rice in `/workspace/.research/corpus.md`:

- pins games to a `workspace = special:gaming, on-created-empty:…` — that pattern is not used
  in any of the 19 surveyed rices,
- ships a MangoHud config rendered from the theming engine — `mangohud %command%` is a Steam
  launch option only,
- ships a themed gamescope wrapper — gamescope is its own micro-compositor so the host rice's
  blur / colors / decorations don't reach inside it.

The only theming-side moves popular rices make are the same three this component already
emits: `immediate true` on game classes (end-4, caelestia, fufexan), `idle_inhibit` while
fullscreen (caelestia, JaKooLit), and decoration-strip on fullscreen (JaKooLit's tag-based
`no_blur on`). See `gotchas.md` for the per-class regex variants used by each rice.
