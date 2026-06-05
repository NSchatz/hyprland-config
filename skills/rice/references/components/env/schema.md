# env — answers.json slice

This component owns one key: `autostart_env.env`. The sibling keys under `autostart_env`
(`wallpaper_tool`, `polkit`, `autostart`) belong to [`../autostart/`](../autostart/).

```json
{
  "autostart_env": {
    "env": [
      "XCURSOR_SIZE,24",
      "HYPRCURSOR_SIZE,24",
      "QT_QPA_PLATFORM,wayland;xcb",
      "GDK_BACKEND,wayland,x11,*",
      "XDG_CURRENT_DESKTOP,Hyprland",
      "MOZ_ENABLE_WAYLAND,1"
    ]
  }
}
```

## Types

- `autostart_env.env` — **array of strings**. Each entry is a `"NAME,value"` pair (exactly one
  comma between key and value; the value itself may contain commas — `GDK_BACKEND,wayland,x11,*`
  has three). The generator splits on the **first** comma only.
- Empty array `[]` is valid — means the user opted out of every env line; `env.conf` is then
  generated with a header comment and nothing else.
- The key is required (the generator errors on missing `autostart_env.env`); the array can be
  empty but must exist.

## Validation

- Each entry must contain at least one `,`.
- No duplicate `NAME` (case-sensitive) — the second `env = NAME,…` line in `env.conf` wins, so
  duplicates are a silent override; flag them.
- The NVIDIA set (`LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`) is valid only
  when `NVIDIA_PROPRIETARY=1` from `detect-version.sh`. The validator checks the combination;
  see `gotchas.md`.
- `ELECTRON_OZONE_PLATFORM_HINT` is **not** part of the NVIDIA gate — the Hyprland NVIDIA wiki
  presents it as a generic Electron-flicker fix, "safe on any GPU". The validator does **not**
  warn on it under mesa.
- `XCURSOR_THEME` and `HYPRCURSOR_THEME` must appear **as a pair** if either is present (one
  half makes XWayland/GTK and native-Hyprland disagree — see `gotchas.md` and `gtk-qt.md`).
- `GTK_THEME` in this list is a smell: GTK theming should go through `gsettings` (the engine
  writes that) and the `gtk-4.0/gtk.css` `@define-color` block. The validator flags it but does
  not reject — Matt-FTW ships `env = GTK_THEME,catppuccin-…` because their rice is a single
  hand-curated theme; under matugen/wallust the value would be stale on the next palette flip.
- `GBM_BACKEND`, `WLR_NO_HARDWARE_CURSORS`, `WLR_DRM_NO_ATOMIC`, and `AQ_NO_ATOMIC` must
  **not** appear — they're explicitly out of the 2026 slim NVIDIA set. The `WLR_*` ones are
  no-ops on modern Hyprland (aquamarine, not wlroots). The validator flags them as a warning
  with a pointer to `gotchas.md`.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (env) | Emits one `env = NAME,value` line per entry into `~/.config/hypr/env.conf`. |
| `hyprland-component-writer` (env, uwsm path) | When `UWSM_SESSION=1`, also writes cursor / GTK / toolkit entries into `~/.config/uwsm/env` as `export NAME=value` lines (POSIX shell sourced — `=` not `,`, and with the `export` prefix per the Hyprland env-vars wiki and the uwsm README). See `gotchas.md`. |
| `hyprland-validator` | Checks the NVIDIA gate (`NVIDIA_PROPRIETARY=1`), no-duplicates, no banned `GBM_BACKEND`/`WLR_NO_HARDWARE_CURSORS`. |
| `hyprland-package-installer` | Reads no keys from this component (env-only — `packages.md` is empty). Reads `autostart_env.polkit` / `.wallpaper_tool` / `.autostart` from the sibling `autostart` component. |

## Cross-references

- Sibling keys under `autostart_env` → [`../autostart/schema.md`](../autostart/schema.md).
- The Firefox-Wayland gate on `default_apps.browser` → [`../default-apps/schema.md`](../default-apps/schema.md).
- `NVIDIA_PROPRIETARY` / `GPU_DRIVER` / `UWSM_SESSION` flags → `_shared/version-matrix.md` and
  `scripts/detect-version.sh`.
