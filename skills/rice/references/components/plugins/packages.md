# plugins — packages

**The plugins themselves are NOT package-manager installable.** `hyprpm` builds them from source
against the running Hyprland headers; there is no `pacman -S hyprexpo`. So this file lists only:

1. The **build toolchain** `hyprpm` needs to compile a plugin.
2. The **AUR `pyprland`** package (the one exception — pyprland is pip/AUR, not hyprpm).

The installer agent reads this file when assembling the global `PKGS` list, keyed off
`plugins.enabled` and the contents of `plugins.selected`.

## Map

### Build toolchain (added when `plugins.enabled == true`)

| Package | Repo | Why |
|---|---|---|
| `base-devel` | repo | `gcc`, `make`, etc. The catch-all build group. |
| `cmake` | repo | Most hyprpm plugins are CMake projects (`hy3`, `hyprexpo`, `hyprbars`, …). |
| `meson` | repo | A few plugins (and Hyprland's own optional builds) prefer meson. |
| `cpio` | repo | Required by `hyprpm` itself for extracting upstream Hyprland source tarballs during header sync. **Missing-`cpio` is the single most common "hyprpm update fails" cause.** |

These four are **always** added when `plugins.enabled == true`, regardless of which plugins are in
`selected` — the user might later add more plugins via `hyprpm` and the toolchain needs to be there.

### pyprland (added when `"pyprland"` is in `selected`)

| Package | Repo / AUR | Notes |
|---|---|---|
| `pyprland` | AUR | The Python daemon. Maintained AUR package; tracks upstream `hhmm/pyprland` releases. |

Alternate path (not the package map, but flag in the print-out): `pipx install pyprland` works too,
but on Arch the AUR package is preferred for consistency with the rest of the install batch.

### What is NOT a package

Every other plugin (`hyprexpo`, `hy3`, `split-monitor-workspaces`, `hyprbars`,
`borders-plus-plus`, `hyprtrails`, `hyprwinwrap`) is **built from source by `hyprpm`** at the user's
request. There is no pacman / AUR package for these — the user runs the `hyprpm` print-out (see
`template.md`) and `hyprpm` git-clones the repo, compiles, and drops the `.so` into
`/var/cache/hyprpm/$USER/<repo>/`.

So **do not** try to map `hyprexpo` → an AUR package. There isn't one. (If a community member
publishes one, it would be a "git clone the source and run a custom build script" wrapper around
`hyprpm` — the canonical path is `hyprpm` directly.)

## Assembly rule

```bash
if [ "$(jq -r .plugins.enabled answers.json)" == "true" ]; then
  pkgs+=(base-devel cmake meson cpio)
  # pyprland is the only plugin-name that maps to a package
  if jq -e '.plugins.selected | index("pyprland")' answers.json > /dev/null; then
    pkgs+=(pyprland)
  fi
fi
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos / AURs doesn't break the install.

## Why this list is so short

Every other component's `packages.md` is a per-pick map (browser → firefox/brave/qutebrowser,
launcher → wofi/rofi/fuzzel, …). This one is mostly empty because `hyprpm` deliberately bypasses the
distro packaging model — plugins are pinned to the running Hyprland build, which the distro can't
encode. The toolchain is the package-manager's whole job here; the rest is `hyprpm`'s.

## Cross-references

- Why plugin compilation has to happen via `hyprpm` (and why Claude never runs it) → `gotchas.md`
- The exact `hyprpm` print-out the user runs in their terminal → `template.md` → "The user-run
  `hyprpm` print-out"
- The cross-component package assembly rule → the installer agent's prompt and
  `skills/rice/scripts/install.sh`.
