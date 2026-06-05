# default-apps — template

This component doesn't own its own `.conf` file. Its outputs are two `$var` lines that the
**hyprland** component's `hyprland.conf` template injects into the variables block. Keep them
together with `$terminal`/`$menu`/`$dmenu` so a user reading the top of `hyprland.conf` sees every
app variable in one place.

## Lines emitted into `hyprland.conf`

```ini
$browser     = {{browser}}
{{#if files}}$fileManager = {{files}}{{/if}}
```

- `{{browser}}` ← `default_apps.browser` from `answers.json`.
- `{{files}}` ← `default_apps.files` from `answers.json`; **omit the line entirely** when null.

The fully-stitched variables block in `hyprland.conf` (with all components feeding it) is in
`components/keybinds/template.md` — that component owns `hyprland.conf` because the bulk of the
file is its workload (the bind table).

## Lines emitted into `binds.conf` (cross-reference)

Owned by the `keybinds` component, but listed here so it's clear where default-apps land:

```ini
bind = $mainMod, B, exec, $browser
{{#if files}}bind = $mainMod, E, exec, $fileManager{{/if}}
```

## Lines emitted into `env.conf` (cross-reference)

When `browser == "firefox"`, the `env` component adds:

```ini
env = MOZ_ENABLE_WAYLAND,1
```

This is a **no-op on Firefox 121+** (Wayland default since Dec 2023). Kept as a documentation
marker / safety net for older Firefox builds; do **not** describe it as "required for Wayland
Firefox" in any user-facing copy. Setting it to `0` (not done here) would force XWayland. See
[`../env/gotchas.md`](../env/gotchas.md) → "MOZ_ENABLE_WAYLAND".

When `browser` is `chromium` / `brave` (or any Electron app is in scope), the `env` component's
`env = ELECTRON_OZONE_PLATFORM_HINT,auto` line is what enables native Wayland — no per-browser
flag in `$browser`.

## What does NOT belong here

- The terminal emulator. That's `components/terminal/` (themed, gets a colors file).
- The launcher invocation (`$menu` / `$dmenu`). That's `components/launcher/`.
