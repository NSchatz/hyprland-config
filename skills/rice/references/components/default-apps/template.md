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

## What does NOT belong here

- The terminal emulator. That's `components/terminal/` (themed, gets a colors file).
- The launcher invocation (`$menu` / `$dmenu`). That's `components/launcher/`.
