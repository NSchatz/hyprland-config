# plugins — gotchas

The hyprpm plugin layer has a denser collection of footguns than any other component. Read these
before writing the user-run command block or any plugin-dispatcher bind.

## Plugins are pinned to the exact Hyprland build — every upgrade breaks every plugin

A hyprpm plugin is a `.so` compiled against the **headers of the running Hyprland**. The moment the
user upgrades Hyprland (`pacman -Syu`, a fresh `hyprland-git` build, anything that changes the
binary), every previously-built plugin is **ABI-incompatible** — Hyprland refuses to load them and
they silently disappear from the running session.

The fix is **always**: rebuild against the new headers.

```bash
hyprpm update    # refetches headers for the running Hyprland and rebuilds every added repo
hyprpm reload    # reloads the freshly built .so files into the running compositor
```

**Print this warning prominently** to the user at install time:

```text
Warning: hyprpm plugins are pinned to the exact Hyprland build. Every Hyprland upgrade BREAKS every
plugin until you re-run `hyprpm update && hyprpm reload`. Add this to your post-upgrade routine.
```

The `autostart` component adds `exec-once = hyprpm reload -n` so the plugins reload on every
session start, but **that doesn't help on the upgrade-day session that's already running** — the
old `.so` is loaded, Hyprland is new, the next `hyprctl reload` rolls back. Only `hyprpm update`
(rebuild) + `hyprpm reload` recovers.

## Claude never runs `hyprpm` — it needs TTY sudo

This is **non-negotiable**. `hyprpm` writes built artifacts to root-owned
`/var/cache/hyprpm/<username>/` and internally shells out to `sudo` / `doas` / `run0` for the writes.
That internal sudo prompts for the user's password on a **TTY** — Claude doesn't have one. Trying
to run `hyprpm` from an agent leaves the process hanging on a password prompt that never gets
typed; eventually it times out and nothing is built.

The rice skill therefore **prints** the `hyprpm` command block (see `template.md` → "The user-run
`hyprpm` print-out") and asks the user to run it in their own terminal. Do **not** wrap it in `bash
-c` and exec it; do **not** pipe it through anything; do **not** try to detect "well, I'll just
write to `/var/cache/hyprpm` directly" — the directory is root-owned for a reason.

### No-root alternative — `hyprctl plugin load`

Once a plugin is built (by the user running `hyprpm`), its `.so` lives at
`/var/cache/hyprpm/<user>/<repo>/<plugin>.so` and is **world-readable**. The running compositor can
be told to load it over its IPC socket — **no root needed**:

```bash
hyprctl plugin load /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so
```

This is **non-persistent** (gone on logout) but useful for testing / demoing without re-prompting
for sudo, and for an in-session "uncomment the binds and verify they work" pass. For persistence,
the user still needs `hyprpm enable` (which writes to root-owned config) + the `exec-once =
hyprpm reload -n` autostart line.

## `scrolling` is CORE in Hyprland 0.53+ — do NOT offer it here

The single biggest mistake new plugin guides make in 2026 is offering `hyprscrolling` or
`hyprscroller`. Both are **deprecated** — the upstream `hyprscrolling` README literally says

> *DEPRECATED: see wiki Configuring/Scrolling-Layout*

As of Hyprland 0.53+, `scrolling` is a **native core layout**. No hyprpm, no plugin, no install. It
belongs in `../look-feel/` (`general:layout = scrolling` + a top-level `scrolling {}` block) and is
**safe to emit uncommented** because `layoutmsg` is a core dispatcher.

This component's catalog (`interview.md` 23b) **must not** list it. The validator rejects
`plugins.selected` containing `scrolling` / `hyprscrolling` / `hyprscroller`. See
`../../_shared/version-matrix.md` → 0.53+ cliff.

## `hyprexpo` / `hyprtrails` / `hyprscrolling` were removed from the official repo

The official `hyprwm/hyprland-plugins` repo now ships **only** four plugins:

- `borders-plus-plus`
- `csgo-vulkan-fix`
- `hyprbars`
- `hyprfocus`

`hyprexpo`, `hyprtrails`, and `hyprscrolling` were **removed**. The community pickup:

- **`hyprexpo`** → use the maintained community fork `https://github.com/sandwichfarm/hyprexpo`
  (alternate: `colonelpanic8/hyprexpo`). Config and dispatcher names are unchanged from the
  upstream version, only the `hyprpm add` URL changes.
- **`hyprtrails`** → community forks only. Treat as optional / unmaintained-risk; flag it for the
  user in the print-out.
- **`hyprscrolling`** → **don't** — use the core layout (see the previous gotcha).

Don't blindly emit `hyprpm add https://github.com/hyprwm/hyprland-plugins` for hyprexpo — that
repo no longer has it, and `hyprpm enable hyprexpo` will fail with "plugin not found in any
enabled repo".

## Plugin dispatchers HARD-ERROR the reload — emit binds COMMENTED-OUT

This is **the** plugin-config footgun. A bind to an unloaded plugin dispatcher is **not** a silent
no-op:

```ini
bind = $mainMod, grave, hyprexpo:expo, toggle    # WRONG — uncommented
```

If `hyprexpo` isn't loaded (plugin not built, plugin built but `hyprpm enable` not yet run, plugin
broken by a Hyprland upgrade), `hyprctl reload` reports:

```
Invalid dispatcher
```

The **entire reload FAILS** and rolls back under safe-apply. The user's whole config gets
rejected — not just the bind line.

Same for a non-core layout reference:

```ini
general { layout = hy3 }    # WRONG — uncommented when hy3 isn't loaded
```

The `general:layout` line is processed at the same parse time; an unloaded layout fails the same
way.

**Fix:** emit every plugin dispatcher bind and every plugin layout line with a leading `#`:

```ini
# bind = $mainMod, grave, hyprexpo:expo, toggle
# general { layout = hy3 }
```

The user uncomments them by hand (or via `edit-config`) **after** running `hyprpm enable` (and
verifying with `hyprctl plugins list`). The `plugin {}` block itself is safe uncommented — Hyprland
silently ignores config for a plugin it didn't load.

The validator catches uncommented plugin dispatchers — see `../../_shared/dispatchers.md`.

## `general:layout = hy3` follows the same rule

A natural mistake: "the dispatcher binds are commented, but `general:layout = hy3` is a *config*
line, not a dispatcher — surely it's safe?" **No.** The layout name lookup happens at reload time
against the loaded plugin registry. An unloaded `hy3` layout name fails the same way an unloaded
dispatcher does, and the same rollback happens.

The `look-feel` component appends `# general { layout = hy3 }` (commented) when `hy3` is in
`plugins.selected`. The user uncomments it after enabling the plugin. The **only** layout names
safe uncommented for a generated config are the core ones: `dwindle`, `master`, and `scrolling`
(0.53+).

## `pyprland` is pip / AUR, NOT hyprpm

pyprland is a **Python daemon** (separate process from Hyprland) — not a `.so` plugin. It does not
go through `hyprpm`; it goes through `pip` / AUR:

```bash
yay -S pyprland       # AUR — preferred
pipx install pyprland # alternate
```

It has its own config file `~/.config/hypr/pyprland.toml` (NOT `plugins.conf`), its own autostart
line `exec-once = pypr` (NOT `exec-once = hyprpm reload -n`), and its own dispatcher pattern (`exec,
pypr toggle <name>` — those binds also start commented until the user verifies pyprland is
running).

So `pyprland` in `plugins.selected` triggers a *different* code path from every other plugin:

- `template.md` does **not** emit a `plugin {}` block for it.
- `template.md` does emit a `pyprland.toml` skeleton.
- `packages.md` adds the AUR `pyprland` package (not the hyprpm build toolchain — those are
  separate).
- `autostart` adds `exec-once = pypr`.
- The user-run print-out has a separate `pyprland` section.

## `~/.local/share/hyprpm` must exist — don't chain enables

Two operational footguns the user *will* hit unless the print-out warns them:

1. **The data dir must exist before the first `hyprpm update`.** `hyprpm update` errors with
   `✖ Failed to write plugin state` if `~/.local/share/hyprpm/` doesn't exist. The print-out's
   **first line** is always:

   ```bash
   mkdir -p ~/.local/share/hyprpm
   ```

2. **Never chain `hyprpm enable` calls with `&&`.** If `hyprpm enable A` fails (a plugin that didn't
   build, a typo'd name), `&&` aborts the rest:

   ```bash
   hyprpm enable hyprbars && hyprpm enable hy3 && hyprpm enable hyprexpo    # WRONG
   ```

   If `hyprbars` fails to build, `hy3` and `hyprexpo` are silently never enabled — the user thinks
   they enabled all three and only discovers the partial state when binds don't work. Emit each
   `hyprpm enable <name>` on its **own line** with no chaining:

   ```bash
   hyprpm enable hyprbars
   hyprpm enable hy3
   hyprpm enable hyprexpo
   ```

   Each failure is then visible and the others still succeed.

## `ecosystem:enforce_permissions` may gate hyprpm

On Hyprland 0.45+ with `ecosystem:enforce_permissions = true`, plugin loading is permission-gated.
If the user has turned this on (or a future default flips it), `hyprpm reload` may be silently
refused. The user needs a permission line in `hyprland.conf`:

```ini
permission = /usr/(bin|local/bin)/hyprpm, plugin, allow
```

The rice skill doesn't enable `enforce_permissions` by default, so this rarely fires — but if the
user reports "I ran `hyprpm enable` but the plugin isn't loading", check this setting.

## Cross-references

- Dispatcher hard-error rule + canonical core dispatcher list → `../../_shared/dispatchers.md`
- Why `scrolling` is core not plugin → `../../_shared/version-matrix.md`
- Build toolchain + pyprland AUR → `packages.md`
- The exact print-out shape → `template.md` → "The user-run `hyprpm` print-out"
- Where the commented binds / layout lines land → `../keybinds/template.md`,
  `../look-feel/template.md`
- Where the autostart lines land → `../autostart/template.md`
