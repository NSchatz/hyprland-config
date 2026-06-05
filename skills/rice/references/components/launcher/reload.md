# launcher — reload

**Launchers are stateless.** They are launched fresh on every `$menu` / `$dmenu` invocation,
read their config from disk, render, and exit. There is no long-running launcher process to
signal, and no D-Bus reload endpoint. **Config changes apply on the next launch — no reload
needed.**

This is true for every launcher this component covers:

| Tool | Process model | When changes apply |
|---|---|---|
| wofi | Spawn → render → exit on selection/escape. | Next `wofi --show drun`. |
| rofi | Spawn → render → exit. | Next `rofi -show drun`. |
| fuzzel | Spawn → render → exit. | Next `fuzzel`. |
| tofi | Spawn → render → exit. | Next `tofi-drun \| sh`. |
| walker | Spawn picker OR pre-started service (`walker --gapplication-service`). | Next picker invocation; **see below** for the service case. |
| vicinae | Tray/service + popup. | Next popup — vicinae re-reads on each open. |
| anyrun | Spawn → render → exit. | Next `anyrun`. |

## Engine `render-manifest` rows

The render manifest's per-component reload column is `:` (no-op) for every launcher row, since
there's nothing to signal. The engine still **renders the colors file and the style file** every
time — the no-op only applies to the post-render hook.

```
wofi    wofi.tmpl     ~/.config/wofi/colors.css       :
rofi    rofi.tmpl     ~/.config/rofi/colors.rasi      :
fuzzel  fuzzel.tmpl   ~/.config/fuzzel/fuzzel.ini     :   # merged section, not replaced
```

(The actual manifest assembly lives in `theming/engine.md`; this file just documents that the
hook column is `:` for launchers.)

## The walker service exception

Walker has a service mode (`walker --gapplication-service`) for instant startup. The service
keeps a warm GTK process around and the picker invocation (`walker`) connects via a UNIX
socket. The service re-reads its config on each picker invocation, so even in service mode,
**no signal is needed** — changes apply on the next popup.

If walker's service is hung after a config edit (rare; usually a config parse error),
restart with:

```bash
systemctl --user restart walker.service     # if the user set up a user unit
# or, if autostarted by Hyprland:
pkill -x walker && walker --gapplication-service &
```

This is failure-recovery, not the normal flow — the validation pass in `validation.md` should
catch the parse error before reload runs.

## What this component does NOT reload

- The `$menu` / `$dmenu` variables in `hyprland.conf` change → `hyprctl reload` is needed, but
  that's the **hyprland** component's reload, not this one.
- The `layerrule` blur block in `window-rules` change → `hyprctl reload`, again not here.
- The colors file is written by the rice engine → the engine's renderer handles it; the
  launcher's no-op reload hook means we don't double-fire anything.

## Cross-references

- Render manifest line format → `theming/engine.md`.
- Hyprland reload semantics → `hyprctl reload` (Hyprland topic files share the standard reload
  mechanism, no per-component `reload.md`).
