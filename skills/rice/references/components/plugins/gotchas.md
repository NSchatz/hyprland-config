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
`/var/cache/hyprpm/<username>/` (verified in `hyprwm/Hyprland:hyprpm/src/core/DataState.cpp` →
`getDataStatePath()` returns `/var/cache/hyprpm/ + m_szUsername`) and internally shells out to
`sudo` for the writes (verified in `hyprwm/Hyprland:hyprpm/src/core/PluginManager.cpp` —
`progress.printMessageAbove(verboseString("install will run as sudo: {}", cmd))`). That internal
sudo prompts for the user's password on a **TTY** — Claude doesn't have one. Trying to run
`hyprpm` from an agent leaves the process hanging on a password prompt that never gets typed;
eventually it times out and nothing is built.

The rice skill therefore **prints** the `hyprpm` command block (see `template.md` → "The user-run
`hyprpm` print-out") and asks the user to run it in their own terminal. Do **not** wrap it in `bash
-c` and exec it; do **not** pipe it through anything; do **not** try to detect "well, I'll just
write to `/var/cache/hyprpm` directly" — the directory is root-owned for a reason.

### No-root alternative — `hyprctl plugin load`

Once a plugin is built (by the user running `hyprpm`), its `.so` lives under
`/var/cache/hyprpm/<user>/…` and is world-readable. The running compositor can be told to load it
over its IPC socket — no root needed. Verified in the official `Using-Plugins` wiki:

> To load plugins manually, use `hyprctl plugin load path`.
> You can unload plugins with `hyprctl plugin unload path`.
> Path has to be absolute!

```bash
hyprctl plugin load /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so
hyprctl plugin unload /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so
hyprctl plugin list
```

This is **non-persistent** (gone on logout) but useful for testing / demoing without re-prompting
for sudo, and for an in-session "uncomment the binds and verify they work" pass. For persistence,
the user still needs `hyprpm enable` (which writes to root-owned config) + the `exec-once =
hyprpm reload -n` autostart line.

## `scrolling` is CORE in Hyprland 0.54+ — do NOT offer it here

The single biggest mistake new plugin guides make in 2026 is offering `hyprscrolling` or
`hyprscroller`. Both are **dead upstream** as of June 2026:

- `dawsers/hyprscroller` — **ARCHIVED** 2026-06-02 (the upstream README still says
  *"DEPRECATED: see wiki Configuring/Scrolling-Layout"*).
- `hyprscrolling` — the original `zakk4223/hyprscrolling` repo is gone; only orphan community
  forks remain (e.g. `vaguesyntax/hyprscrolling`, last update 2026-02), and `hyprscrolling` was
  one of the five plugins dropped from the official `hyprwm/hyprland-plugins` repo by PR #663
  (2026-05-12).

As of Hyprland 0.54+, `scrolling` is a **native core layout** (verified absent at v0.53.0
`src/config/ConfigManager.cpp`, present at v0.54.0 — see `../../_shared/version-matrix.md`). No
hyprpm, no plugin, no install. It belongs in `../look-feel/` (`general:layout = scrolling` + a
top-level `scrolling {}` block) and is **safe to emit uncommented** because `layoutmsg` is a core
dispatcher. The wiki page is at
`hyprwm/hyprland-wiki:content/Configuring/Layouts/Scrolling-Layout.md`.

> **Field sighting:** `Matt-FTW/dotfiles:.config/hypr/configs/plugins.conf` (HEAD as of 2026-06)
> still ships an uncommented `exec-once = hyprpm enable hyprscrolling` line — this is a stale
> config that breaks on 0.54+. If you're porting from Matt-FTW's plugin block, **drop the
> hyprscrolling source line and use the core layout instead.**

This component's catalog (`interview.md` 23b) **must not** list it. The validator rejects
`plugins.selected` containing `scrolling` / `hyprscrolling` / `hyprscroller`. See
`../../_shared/version-matrix.md` → 0.54+ cliff.

## 0.55+ cliff — hyprlang is "deprecated", lua is the default, plugin custom-keyword API broke

Hyprland 0.55.0 (released 2026-05-09) ships **lua as the config language**:
`~/.config/hypr/hyprland.lua` is the new entry point, and it is loaded *instead of*
`hyprland.conf`. Hyprlang `.conf` files still parse, but only for **1 - 2 releases starting from
0.55**, after which hyprlang is dropped. The **plugin custom-keyword API was rebuilt at the same
time**, and the old `plugin { name { … } }` block syntax now has a caveat: the upstream
sandwichfarm/hyprexpo docs explicitly warn

> *Hyprland 0.55 deprecated the custom keyword API that older HyprExpo configs used. HyprExpo no
> longer registers `hyprexpo_gesture` or `hyprexpo_workspace_method`. Use
> `plugin:hyprexpo:workspace_method` for workspace placement and the Lua API for gestures.*

(verified at `sandwichfarm/hyprexpo:docs/configuration/options.md` HEAD).

This means **any plugin that exposed a Hyprland-side keyword via the pre-0.55 API silently stops
parsing on 0.55+** — the user gets a parse-error popup on first reload and the plugin's old
config block becomes inert until the plugin maintainer ports to the new API. Many community
plugins haven't ported yet (June 2026). Footgun for users who upgrade Hyprland: their plugin
config breaks even after `hyprpm update`.

The rice still emits a `.conf` (`plugins.conf`) on 0.55+ because the standard `plugin:<name>:<key>
= value` config-value syntax is preserved. But:

- The user-run print-out should remind 0.55+ users that **`hyprpm update` is mandatory after the
  Hyprland upgrade** — the rebuilt plugin is the one written against 0.55's headers.
- If a plugin's block silently disappears from effect, check whether it used a custom
  `addConfigKeyword` (the pre-0.55 API). The bar's `hyprbars-button` keyword **is** registered via
  the still-supported `addConfigKeyword` path (verified in `hyprland-plugins:hyprbars/main.cpp` →
  `HyprlandAPI::addConfigKeyword(PHANDLE, "plugin:hyprbars:hyprbars-button", …)`).

See `../../_shared/version-matrix.md` → 0.55+ row.

## `hyprexpo` / `hyprtrails` / `hyprscrolling` / `hyprwinwrap` were removed from the official repo

PR #663 ("all: drop unmaintained plugins", merged 2026-05-12,
`https://github.com/hyprwm/hyprland-plugins/pull/663`) dropped five subdirs at once: `hyprexpo`,
`hyprscrolling`, `hyprtrails`, `hyprwinwrap`, and `xtra-dispatchers`. The official
`hyprwm/hyprland-plugins` repo now ships **only four** plugins (verified via
`gh api repos/hyprwm/hyprland-plugins/contents/`):

- `borders-plus-plus`
- `csgo-vulkan-fix`
- `hyprbars`
- `hyprfocus`

(`hyprfocus` is the flashfocus replacement that landed *with* the drop; previously the repo had
~9 plugins.) Community pickup:

- **`hyprexpo`** → the maintained community fork
  `https://github.com/sandwichfarm/hyprexpo` (the README literally says "After [the upstream
  plugin was retired] from official plugins, this fork signaled continuation"). Confirmed
  active — pushed 2026-05-30. The repo name in `hyprpm.toml` is `hyprexpo`, so
  `hyprpm enable hyprexpo` still works. Alternate fork: `colonelpanic8/hyprexpo`.
- **`hyprtrails`** → community forks only (no widely-blessed maintained one as of June 2026).
  Treat as optional / unmaintained-risk; flag it for the user in the print-out, do **not** ship
  a default URL.
- **`hyprwinwrap`** → maintained community fork `https://github.com/gen3vra/hyprwinwrap`
  (pushed 2026-05-29, requires Hyprland 0.54+; its README adds `pos_x`/`pos_y`/`size_x`/`size_y`
  percentage args and a `hyprwinwrap_interactivity` dispatcher beyond the original `class`).
- **`hyprscrolling`** → **don't** — use the core layout (see the previous gotcha).

Don't blindly emit `hyprpm add https://github.com/hyprwm/hyprland-plugins` for hyprexpo or
hyprwinwrap — that repo no longer has them, and `hyprpm enable hyprexpo` will fail with
"plugin not found in any enabled repo".

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
(0.54+).

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

## Don't chain `hyprpm enable` calls — and don't pre-mkdir the cache

Two operational footguns:

1. **Do NOT pre-`mkdir ~/.local/share/hyprpm`.** That path is **not** a hyprpm directory. Verified
   in `hyprwm/Hyprland:hyprpm/src/core/DataState.cpp`: hyprpm's actual data root is
   `/var/cache/hyprpm/<username>/` (root-owned, created via `NSys::root::createDirectory` on first
   run — hyprpm runs `sudo` and makes it itself) and its temp state lives in
   `$XDG_RUNTIME_DIR/hyprpm/` (user-owned, created with plain `mkdir` by hyprpm itself). The user
   should not pre-create either; hyprpm handles it.

   The legacy print-out that emitted `mkdir -p ~/.local/share/hyprpm` was wrong: the resulting
   empty `~/.local/share/hyprpm/` is **unused** by hyprpm and the user still hits the same first-run
   sudo prompt for `/var/cache/hyprpm`. Drop the `mkdir` line entirely.

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

## `exec-once = hyprpm enable …` (Matt-FTW pattern) vs. `hyprpm reload -n` (ours)

`Matt-FTW/dotfiles:.config/hypr/configs/plugins.conf` uses a per-plugin enable-on-startup pattern:

```ini
exec-once = hyprpm enable hyprtrails
source = ~/.config/hypr/plugins/hyprtrails.conf
…
exec-once = hyprpm reload -n
```

That's a defensible alternative to our `autostart` component's single `exec-once = hyprpm reload
-n` line — it re-asserts the enabled set every session, which can recover from `hyprpm` state
drift (a stale `state.toml` left after a botched upgrade). But it has two drawbacks:

1. **`hyprpm enable <name>` shells out to sudo** (verified in
   `hyprwm/Hyprland:hyprpm/src/core/PluginManager.cpp`) just like the install path, so every
   session start prompts for a password unless the user has hyprpm in their sudoers rules.
   `hyprpm reload -n` does **not** shell to sudo — it loads already-enabled `.so` files via
   the running compositor's IPC.
2. If the user is on a fresh Hyprland upgrade and the plugin hasn't been rebuilt (`hyprpm update`
   not yet run), the `exec-once = hyprpm enable foo` line will silently fail and the session
   starts up plugin-less — without any error popping in the user's face.

We stick with the `autostart`-component-owned `exec-once = hyprpm reload -n` model. If a user
asks "why doesn't Matt-FTW's pattern work for me", the answer is "it does, but it
costs a sudo prompt per session and hides upgrade failures."

## `ecosystem:enforce_permissions` may gate hyprpm

`ecosystem:enforce_permissions` is **default `false`** (verified in
`hyprwm/Hyprland:src/config/values/ConfigValues.cpp` — `MS<Bool>("ecosystem:enforce_permissions",
…, false)`). If the user has turned it on, the official `Using-Plugins` wiki advises:

> If you are using permission management, you should allow hyprpm to load plugins by adding this
> to your config:
> ```ini
> permission = /usr/(bin|local/bin)/hyprpm, plugin, allow
> ```
> otherwise you'll get a popup asking for permission every time hyprpm tries to load a plugin.

The rice skill doesn't set `enforce_permissions = true` by default, so this rarely fires — but if
the user reports "I ran `hyprpm enable` but the plugin isn't loading", check this setting.

## Corpus observation — top rices ship NO plugins by default

A theming-relevant data point from the v0.13 corpus pass (top 19 actively-maintained Hyprland
rices on `github.com/topics/hyprland`, sorted by stars):

| Rice | Plugins shipped? | Notes |
|---|---|---|
| `end-4/dots-hyprland` | none | lua-entry hypr config, no `plugin {}` blocks |
| `caelestia-dots/caelestia` | none | sources a `scrolling.conf` — uses the **core** scrolling layout, not the plugin |
| `prasanthrangan/hyprdots` (HyDE) | none | `userprefs.conf` is plugin-empty |
| `JaKooLit/Hyprland-Dots` | none | UserConfigs split — no plugins.conf |
| `mylinuxforwork/dotfiles` (ML4W) | none | `.lua` entry, no plugin block |
| `dusklinux/dusky` | **commented-out only** | `source/plugins.lua` ships a hyprexpo example block entirely commented out |
| `Matt-FTW/dotfiles` | **YES — opt-in catalog** | `.config/hypr/configs/plugins.conf` sources `plugins/{hyprtrails,hyprexpo,hyprsplit,hyprtasking,hyprspace,dynamic-cursors,hycov,hyprbars,hyprscrolling}.conf` — six of seven commented out, only one active |
| `binnewbs/arch-hyprland` | none | |
| `linuxmobile/hyprland-dots` | none | |
| `Axenide/Ax-Shell` | none | |
| `koeqaife/hyprland-material-you` | none | |

**Corpus archetype: opt-in catalog, default disabled.** Only **one** of the top 19 rices ships any
plugin uncommented (Matt-FTW), and even that one runs only one plugin at a time with the others
sourced-but-commented. This validates our gate-on-`enabled=false`-by-default design: a popular
rice that "looks coherent" doesn't depend on plugins at all. Plugins are eye-candy add-ons, not
load-bearing surface theming.

> **Takeaway for `template.md`:** the per-plugin `plugin {}` block catalog is correct, but the
> recipe should not pad the default `plugins.selected = []` set with "popular" plugins — popularity
> is **low** across the corpus. The interview should keep all options unchecked-by-default (already
> the case per `interview.md` 23b).

## Cross-surface coherence — hyprbars must reuse the waybar/look-feel palette

`hyprbars` paints a per-window title bar that lives **between** the window content and the
hyprland border. The user perceives it as part of the same "chrome" stack as the waybar and the
window border. If the hyprbars `bar_color` / `col.text` / button colors don't reuse the same
palette keys waybar uses for its `background` / `foreground` / accent buttons, the desktop reads
as two disjoint UIs.

Three coherence rules (verified against `hyprwm/hyprland-plugins:hyprbars/main.cpp`):

1. **`hyprbars:bar_color` must reuse `{{surface}}` or `{{bg}}`** — same key the waybar background
   uses. `Matt-FTW/dotfiles:.config/hypr/plugins/hyprbars.conf` uses `bar_color = $mantle` (the
   catppuccin surface key) — analogous to our `{{surface}}`.
2. **`hyprbars:col.text` must reuse `{{fg}}`** — same key waybar / kitty / mako foregrounds use.
3. **Button colors should reuse the named palette** (`{{red}}`, `{{yellow}}`, `{{green}}`) for
   kill/maximize/minimize — NOT literal hex. Matt-FTW's config uses `rgb(ff4040)` /
   `rgb(eeee11)` (literal hex), which is the **anti-pattern** — it survives a wallpaper
   swap silently wrong. Our `template.md` uses `rgb({{red}})` / `rgb({{yellow}})`, which is the
   correct shape.

Same coherence rule for `borders-plus-plus`: `col.border_1 = rgb({{accent}})` reuses the same
accent waybar uses for its active workspace pill — matches the rest of the chrome.

For `hyprtrails`: `color = rgba({{accent}}aa)` (the 0.5x opacity suffix is a Hyprland color-syntax
convention — see `../../_shared/colors-contract.md`).

## Cross-references

- Dispatcher hard-error rule + canonical core dispatcher list → `../../_shared/dispatchers.md`
- Why `scrolling` is core not plugin → `../../_shared/version-matrix.md`
- Build toolchain + pyprland AUR → `packages.md`
- The exact print-out shape → `template.md` → "The user-run `hyprpm` print-out"
- Where the commented binds / layout lines land → `../keybinds/template.md`,
  `../look-feel/template.md`
- Where the autostart lines land → `../autostart/template.md`
