# companion-daemons

Interview group 16 — the **Hypr ecosystem companion daemons** that live alongside `hyprland.conf` in
`~/.config/hypr/` but are read by their **own daemons**, not `source=`d into `hyprland.conf`. Each
daemon is launched separately (typically by `autostart`'s `exec-once` lines) and reads its own
config file in its own config language.

The three daemons in scope:

- **hyprlock** — the lock screen (visual config). Owned by [`lock-screen`](../lock-screen/); this
  component does **not** own `hyprlock.conf`. The flag `companion_configs.hyprlock` only confirms
  we should generate the lock companion at all (mirrors `lock_screen.enabled`).
- **hypridle** — the idle daemon (dim → lock → dpms-off → suspend ladder; `lock_cmd`,
  `before_sleep_cmd`). Owned **here**.
- **hyprpaper** — the wallpaper daemon. On 0.8+ a `wallpaper { … }` block (no more `preload`);
  on 0.7.x the legacy `preload =` / `wallpaper =` pair. `ipc` is on by default in both. Owned
  **here**.

This component is the **lifecycle wiring** that ties the three together: hypridle's `lock_cmd`
launches hyprlock (with a `pidof` guard so it doesn't stack), `before_sleep_cmd` locks the session
before suspend, hyprpaper's IPC socket (on by default since 0.7.x) lets
`hyprctl hyprpaper wallpaper` swap the image live when the rice engine re-themes.

> **Version note:** hyprpaper **v0.8.0** (Dec 2025) was a complete rewrite onto hyprtoolkit and
> **broke the config format** — `preload`, `wallpaper = MON, PATH`, and the `preload` / `unload` /
> `listloaded` / `listactive` IPC commands are all gone. Arch ships 0.8.4. The component's
> template emits the new `wallpaper { … }` block form by default; see `template.md`.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Group 16 single confirmation call + the hypridle idle-tier ladder sub-question (Balanced / Aggressive / Relaxed / Never). |
| `schema.md` | The `companion_configs.*` keys this component owns in `answers.json`. |
| `template.md` | The full `hypridle.conf` template (four listeners parameterized by the ladder choice) + the `hyprpaper.conf` template. Cross-links to `../lock-screen/template.md` for `hyprlock.conf`. |
| `gotchas.md` | Config-language differences, `pidof` guard, `before_sleep_cmd` (loginctl-vs-direct-call corpus split), lock-before-dpms ordering, desktop-drops-suspend, hyprpaper 0.8 config break, `inhibit_sleep` mode semantics, corpus disagreement on `inhibit_sleep`/`ignore_*_inhibit`, "popular rices don't ship `hyprpaper.conf`" (they generate or use swww), ML4W's Lua-format dispatchers (`hl.dsp.dpms`) vs the template's classic-string form, adjacent walker `ext-background-effect-v1` is compositor-served (not built-in), adjacent `wl-clip-persist` keeps cliphist alive after source quits, drop-listener-when-hyprlock-not-chosen. |
| `packages.md` | `hyprlock` / `hypridle` / `hyprpaper`. First-party Hypr ecosystem, all repo packages. |

## Where this component lands

- **hypridle config:** `~/.config/hypr/hypridle.conf`. Read by the `hypridle` daemon at startup;
  reload with `systemctl --user restart hypridle` (or kill + relaunch) — no `hyprctl reload`
  equivalent.
- **hyprpaper config:** `~/.config/hypr/hyprpaper.conf`. Read by `hyprpaper` at startup; live
  wallpaper swaps go through `hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'` on 0.8+
  (or the legacy `preload` + `wallpaper` pair on 0.7.x). IPC is on by default; `hyprctl
  hyprpaper reload` rereads the config on 0.8+ (no equivalent on 0.7.x).
- **hyprlock config:** `~/.config/hypr/hyprlock.conf`. Owned by
  [`lock-screen`](../lock-screen/template.md) — see that template, not this one.
- **Hyprland config:** nothing direct. The `exec-once` lines that launch these daemons live in
  [`autostart`](../autostart/) (`exec-once = hypridle`, `exec-once = hyprpaper`); the manual lock
  bind (`bind = $mainMod, X, exec, hyprlock`) lives in [`keybinds`](../keybinds/).

## Related components

- [`lock-screen`](../lock-screen/) — owns `hyprlock.conf` (the visual config: background, clock,
  input pill). This component owns the wiring (`lock_cmd`, `before_sleep_cmd`) that targets it.
- [`autostart`](../autostart/) — launches the daemons via `exec-once = hypridle` /
  `exec-once = hyprpaper`. If those `exec-once` lines aren't emitted, none of the configs here
  ever get read.
- [`wallpaper`](../../theming/wallpaper.md) — supplies the image path that `hyprpaper.conf`
  preloads. The rice engine's wallpaper-swap reload hook uses `hyprctl hyprpaper wallpaper`.
- [`laptop`](../laptop/) — laptops typically pick the **Aggressive** idle ladder (tighter timeouts
  + suspend); desktops pick **Balanced** or **Relaxed** and often drop the suspend tier.
- [`keybinds`](../keybinds/) — emits `bind = $mainMod, X, exec, hyprlock` (manual lock); unrelated
  to the idle path but cross-referenced because both eventually call `hyprlock`.
- [`launcher`](../launcher/) — adjacent: walker's `ext_background_effect_blur = true` is a
  Wayland-protocol blur request (compositor-served via `ext-background-effect-v1`, not built-in).
  Hyprland implemented the server in commit `7d1e481` (May 2026); on older Hyprland it silently
  no-ops and a `layerrule = blur, walker` block is required instead. See
  `../launcher/gotchas.md` and `../window-rules/`.
- [`look-feel`](../look-feel/) — corpus uses two dpms-dispatch forms in `hypridle.conf`: the
  classic-string `hyprctl dispatch dpms off` (binnewbs, Ax-Shell, JaKooLit, dusky, Matt-FTW —
  works on every Hyprland version) and the runtime-Lua form `hyprctl dispatch 'hl.dsp.dpms({
  action = "disable" })'` (ML4W, end-4 — requires Lua-enabled Hyprland). The template emits
  the classic form by default; see `gotchas.md`.
