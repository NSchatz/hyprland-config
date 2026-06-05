# plugins

The **community-plugin layer** — `hyprpm`-built plugins that bolt onto Hyprland: a workspace
overview (`hyprexpo`, community fork), an i3/sway tree layout (`hy3`), per-monitor workspaces
(`split-monitor-workspaces`), CSD-style title bars (`hyprbars`, official), motion trails
(`hyprtrails`, community), an extra border ring (`borders-plus-plus`, official), an
app-as-wallpaper hack (`hyprwinwrap`, community fork), and pyprland's dropdown scratchpads (the
pip/AUR exception — **not** hyprpm).

This component is **OPT-IN**. The interview opens with one yes/no gate (23a); on **No** the rest of
the component is skipped and `plugins.enabled = false` is recorded. On **Yes** a multi-select (23b)
names the plugins to wire up. A non-plugin user never sees the catalog.

## What this component owns

- `~/.config/hypr/plugins.conf` — the file `source`d from `hyprland.conf` that holds the
  `plugin {}` configuration blocks (one per selected plugin).
- The **commented-out** plugin-dispatcher binds in `binds.conf` (the `keybinds` component appends
  them) and the **commented-out** `general:layout = hy3` line in `looknfeel.conf` (the `look-feel`
  component appends it). These stay commented until the user has actually built and enabled the
  plugin — uncommented plugin dispatchers HARD-ERROR the reload.
- The print-out of exact `hyprpm` install commands the **user** runs in their own terminal. Claude
  **never runs `hyprpm`** — it shells out to `sudo` (verified in
  `hyprwm/Hyprland:hyprpm/src/core/PluginManager.cpp` — `install will run as sudo: …`) to write the
  built artifacts to root-owned `/var/cache/hyprpm/<username>/` (verified in `DataState.cpp` →
  `getDataStatePath()`), and `sudo` needs a TTY Claude doesn't have.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 23a (opt-in gate, always asked) and 23b (multi-select of plugins, only on Yes). Record paths. |
| `schema.md` | The `plugins.{enabled, selected}` slice of `answers.json` + validation rules. |
| `template.md` | The `plugins.conf` per-plugin block catalog + the commented binds + the commented `general:layout = hy3` line for hy3. References `_shared/dispatchers.md` for the hard-error rule. |
| `gotchas.md` | The version-pinning rule (every Hyprland upgrade breaks every plugin), why Claude can't run `hyprpm`, the `scrolling`-is-core-not-a-plugin reminder, the PR #663 unmaintained-plugin removal (hyprexpo / hyprtrails / hyprscrolling / hyprwinwrap / xtra-dispatchers), the plugin-dispatcher hard-error rule, the `general:layout = hy3` corollary, the pyprland-is-pip-not-hyprpm exception, and the no-chained-`enable` rule. (The `~/.local/share/hyprpm` directory is **not** a real path — hyprpm uses `/var/cache/hyprpm/<user>/` and `$XDG_RUNTIME_DIR/hyprpm/` and creates them itself.) |
| `packages.md` | The build toolchain (`cpio cmake meson git gcc`) + the AUR `pyprland` exception. The plugins themselves are **not** package-manager-installable — `hyprpm` builds them from source. |

## Where this component lands

- **`plugins.conf`** — own file, generated only when `plugins.enabled == true`. Sourced from
  `hyprland.conf` (`source = ~/.config/hypr/plugins.conf`) — that `source =` line is added by the
  `hyprland` component, gated on `plugins.enabled`.
- **`binds.conf`** — plugin-dispatcher binds (`hyprexpo:expo`, `hy3:makegroup`, `split-workspace`,
  …) land here, **commented-out**. Owned by the `keybinds` component; this component just supplies
  the list.
- **`looknfeel.conf`** — `# general { layout = hy3 }` lands here, commented. Owned by `look-feel`.
- **Install batch** — only the build toolchain (`cpio cmake meson git gcc` — the exact deps the
  wiki lists at `wiki/content/Plugins/Using-Plugins.md`) and the AUR `pyprland` package (when
  pyprland is selected). The plugins themselves are not packages.
- **User-run command print-out** — the rice skill emits a block of `hyprpm` commands the user copies
  into their terminal (`hyprpm update`, one `hyprpm add` per repo, one `hyprpm enable` per plugin
  **on its own line**, `hyprpm reload`). These commands are **not** stored in a file the engine
  reads — they're a print-out. hyprpm creates its `/var/cache/hyprpm/<user>/` data dir itself on
  first run (via its internal `sudo`); no `mkdir` is required.

## Related components

- [`keybinds`](../keybinds/) — owns the bind table. This component supplies the commented plugin
  dispatcher binds it appends.
- [`look-feel`](../look-feel/) — owns `looknfeel.conf` and `general:layout`. The hy3 layout line
  (`# general { layout = hy3 }`) lives there, commented.
- [`monitors`](../monitors/) — `split-monitor-workspaces` is only offered when
  `monitors.list | length > 1`.
- [`widgets`](../widgets/) — a full widget shell often provides its own workspace overview with
  live previews; `hyprexpo` is offered as a fallback when the user is on plain waybar.
- [`autostart`](../autostart/) — owns `exec-once = hyprpm reload -n` (added when
  `plugins.enabled == true`) and `exec-once = pypr` (added when pyprland is selected).
- [`_shared/dispatchers.md`](../../_shared/dispatchers.md) — the canonical rule that plugin
  dispatchers hard-error the reload until loaded.
- [`_shared/version-matrix.md`](../../_shared/version-matrix.md) — the **0.53+** cliff where
  `scrolling` became core (and why this component does NOT offer it as a plugin).
