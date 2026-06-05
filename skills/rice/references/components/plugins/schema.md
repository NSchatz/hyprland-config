# plugins — answers.json slice

Keys this component owns under the top-level `plugins` key.

```json
{
  "plugins": {
    "enabled":  true,
    "selected": ["hyprexpo", "hy3", "split-monitor-workspaces",
                 "hyprbars", "pyprland", "borders-plus-plus",
                 "hyprtrails", "hyprwinwrap"]
  }
}
```

## Types

| Key | Type | Required | Notes |
|---|---|---|---|
| `plugins.enabled` | bool | **yes** (always) | The opt-in gate. `false` means "no plugins" — every downstream reader short-circuits and `plugins.conf` is **not** generated. |
| `plugins.selected` | string-array | yes | Which plugins are wired. Empty `[]` when `enabled == false`. Each element is a canonical plugin name from the catalog in `interview.md` 23b. |

### Enum semantics — `plugins.selected`

The canonical names the catalog uses. The installer / template readers branch on these strings:

| Name | What it is | Repo / source | Layout-setting? | Adds binds? |
|---|---|---|---|---|
| `hyprexpo` | Workspace overview (grid exposé). | `sandwichfarm/hyprexpo` (community fork — removed from official by PR #663). | no | yes (commented) |
| `hy3` | i3/sway tree tiling. | `outfoxxed/hy3`. | **yes** (`layout = hy3`) | yes (commented) |
| `split-monitor-workspaces` | Per-monitor workspaces (each display gets its own 1–10). | `zjeffer/split-monitor-workspaces` (the `Duckonaut/…` URL 301-redirects here). | no | yes (commented; rebinds 1–10) |
| `hyprbars` | Per-window CSD title bars. | `hyprwm/hyprland-plugins`. | no | no (uses `hyprbars-button` config keys) |
| `pyprland` | Dropdown scratchpads + expose / magnify. | `hyprland-community/pyprland`, installed via pip / AUR (NOT hyprpm). | no | yes (commented `pypr toggle …`) |
| `borders-plus-plus` | Extra window border rings. | `hyprwm/hyprland-plugins`. | no | no |
| `hyprtrails` | Motion trails. | community forks only (removed from official by PR #663 — no widely-blessed fork; user picks). | no | no |
| `hyprwinwrap` | Run an app as the wallpaper. | `gen3vra/hyprwinwrap` (community fork — removed from official by PR #663; needs Hyprland 0.54+). | no | optional (`hyprwinwrap_interactivity` dispatcher in the gen3vra fork) |

Unknown values in `plugins.selected` are dropped by the template writer with a warning — only the
catalog set above renders.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-interviewer` | Walks 23a → 23b. On `23a == No`, records `enabled=false` and skips 23b. |
| `hyprland-component-writer` (`plugins`) | Generates `~/.config/hypr/plugins.conf` only when `enabled == true`. One `plugin {}` block per element of `selected` (from `template.md`). |
| `hyprland-component-writer` (`hyprland`) | Adds `source = ~/.config/hypr/plugins.conf` to `hyprland.conf` only when `enabled == true`. |
| `hyprland-component-writer` (`keybinds`) | Reads `selected` and appends the per-plugin commented binds (`# bind = $mainMod, grave, hyprexpo:expo, toggle`, the `hy3:` binds, the `split-workspace` rebinds, the `pypr toggle` binds). |
| `hyprland-component-writer` (`look-feel`) | Reads `selected`. If `hy3` is in it, appends `# general { layout = hy3 }` (commented). |
| `hyprland-component-writer` (`autostart`) | Reads `enabled`. Adds `exec-once = hyprpm reload -n` when true. Also reads `selected`: adds `exec-once = pypr` when `pyprland` is in it. |
| `hyprland-package-installer` | Reads `enabled`. When true, adds the build toolchain (`cpio cmake meson git gcc` — the exact set listed in the official `wiki/Plugins/Using-Plugins.md`) from `packages.md`. Reads `selected`: when `pyprland` is in it, adds the AUR `pyprland` package. **No package is added for any hyprpm plugin** — they are not packages. |
| rice skill (Mode A) | Reads `enabled` + `selected` to print the **user-run** `hyprpm` command block (one `hyprpm add` per repo, one `hyprpm enable` per plugin on its own line, finished with `hyprpm reload`). No `mkdir` is needed — hyprpm creates its `/var/cache/hyprpm/<user>/` data dir itself via internal sudo. Claude does **not** execute these. |
| validator | Reads `selected`. If any element appears in a bind without a leading `#`, errors — plugin dispatchers must stay commented (see `_shared/dispatchers.md`). |

## Validation

- `plugins.enabled` must be a bool; missing → interview fails.
- `plugins.selected` must be an array (possibly empty).
- When `plugins.enabled == false`, `plugins.selected` **must be `[]`**. A non-empty `selected` with
  `enabled == false` is a contradiction and is rejected (the interview re-asks 23a).
- `plugins.selected` must **not** contain `scrolling` / `hyprscrolling` / `hyprscroller` — the
  scrolling layout is core in 0.53+ and belongs in `../look-feel/`, not here.
- `split-monitor-workspaces` is accepted only when `monitors.list | length > 1`.
