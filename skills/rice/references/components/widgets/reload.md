# widgets — reload

How a re-rendered colors file is picked up by the running shell. Each shell has its own hook;
`rice apply` reads `widgets.system` and fires the right one. Hooks are **guarded** — a no-op if
the daemon / shell isn't running yet, so the first `rice apply` after install doesn't fail just
because the user hasn't started the shell.

## Hooks by `widgets.system`

| `widgets.system` | Reload command | Guard | Latency |
|---|---|---|---|
| `none` | (nothing) | — | — |
| `eww` | `eww reload` | `pgrep -x eww >/dev/null` | < 200 ms — recompiles SCSS in place; widgets re-skin without daemon restart, no flicker |
| `ags` | (none — file-monitor) | the shell's `Utils.monitorFile` / dart-sass watcher | < 500 ms after the file write |
| `quickshell` | (none — hot-reload on save) | the shell's `FileView { watchChanges: true }` or `pragma Singleton` reload | instant on save |
| `hyprpanel` | (GUI-driven) | — | Theming changes go through HyprPanel's settings dialog or matugen; the rice skill writes the matugen config, then runs `matugen run` |
| `turnkey` | per-project (`caelestia restart`, `dms reload`, …) — most just consume the matugen-regenerated colors.json | the shell's own file watcher | varies |

## eww — `eww reload`

The manifest line for eww:

```
eww  ~/.config/hypr-rice/templates/eww.tmpl  ~/.config/eww/colors.scss  eww reload
```

`eww reload` recompiles the SCSS and re-renders every open window. It does **not** restart the
daemon, so deflisten subscriptions and defpoll state are preserved — exactly the behavior gh0stzk
relies on for instant theme-switching.

Idempotency / guard:

```bash
if pgrep -x eww >/dev/null; then
  eww reload || true
fi
```

(`|| true` because eww returns non-zero if the daemon is in a wedged state — better to surface
that via the validator than to fail the whole `rice apply`.)

If the SCSS fails to compile (e.g. the `alpha($c, 0.8)` pitfall — see `gotchas.md`), `eww reload`
prints the grass error to stderr and the **widgets render unstyled**. The validator (`validation.md`)
greps for these patterns before the hook fires.

## AGS / Astal — file-monitor + `resetCss` / `applyCss`

The manifest line for AGS:

```
ags  ~/.config/hypr-rice/templates/ags.tmpl  ~/.config/ags/colors.scss
```

**No reload command** — but the file-watch is **not free**; the running shell must wire it in
user code. The exact mechanism depends on which generation is installed:

- **AGS v1** — `Utils.monitorFile(\`${App.configDir}/scss\`, () => { Utils.exec("sassc style.scss /tmp/style.css"); App.resetCss(); App.applyCss("/tmp/style.css"); })`.
- **Astal + Gnim / AGS v3** — the `app.start({ css })` field takes a **string** (the AGS docs:
  *"any css or scss file ... inlined as a string"*), so the v1-shaped pattern survives:
  `monitorFile` on the SCSS dir → re-read the file (or shell out to dart-sass) → call
  `app.apply_css(cssString)` / `app.reset_css()` (lowercase v3 methods). There is no automatic
  on-disk SCSS watcher in v3's app surface; the shell config wires it.

In both cases the rice engine relies on the shell's user-written watcher — there is no AGS-side
hook to fire from `rice apply`. If the user is *not* running AGS, the file write is harmless —
`colors.scss` is just a static file until the shell starts and re-reads it.

## Quickshell — hot-reload on save

The manifest line for Quickshell:

```
quickshell  ~/.config/hypr-rice/templates/quickshell.tmpl  ~/.config/quickshell/<name>/Colors.qml
```

**No reload command.** Quickshell's docs (quickshell.org): *"loads changes as soon as they're
saved."* Writing the new `Colors.qml` triggers a re-evaluation of every QML binding referencing
`Colors.<key>`, which repaints the shell. There's nothing to call — the QML runtime is the
reload mechanism.

(If you used the matugen → JSON → `FileView`/`JsonAdapter` path instead — see `styling.md` →
`## Quickshell` → "Theming flow" — the same applies: `FileView { watchChanges: true }` fires
`onFileChanged: reload()` and the singleton re-binds.)

## HyprPanel — GUI / matugen-driven

HyprPanel doesn't have a CLI reload — theming changes go through the GUI ("Dashboard → gear icon
→ Theming") or matugen. The rice skill's `rice apply` for a HyprPanel desktop:

1. **Writes matugen config** at `~/.config/matugen/config.toml` pointing at the active wallpaper.
2. **Runs matugen**: `matugen image "$wallpaper"`.
3. matugen writes color files (the location is configured per `matugen-themes/hyprpanel`); the
   user enables "Matugen Settings" in HyprPanel's dialog once at setup, and HyprPanel re-themes
   on the next matugen run.
4. If HyprPanel is running and its file-monitor doesn't catch the change (the GUI normally does),
   `pkill -SIGUSR1 hyprpanel` is the documented refresh — but version-dependent. The rice skill
   logs the matugen run and lets HyprPanel's normal refresh path handle it.

Guard:

```bash
if command -v matugen >/dev/null; then
  matugen image "$wallpaper" >/dev/null 2>&1 || true
fi
```

(The validator already ensured `matugen` is installed for this path — see `packages.md`.)

## Turnkey shells

Each project's installer provides its own reload mechanism, typically a CLI wrapping
`pkill -USR1` or a `qs ipc`. The rice skill doesn't hand-wire these — instead it re-runs
**matugen against the wallpaper** (every turnkey shell consumes matugen output) and lets the
shell's own watcher repaint:

| Shell | Matugen target | Notes |
|---|---|---|
| `end-4` | `~/.local/state/quickshell/.../generated/colors.json` (QML `FileView` watches) | Instant repaint via the singleton. |
| `caelestia` | `~/.config/caelestia/shell.json` (matugen template ships in the install script) | `caelestia shell -d` is the daemon; it watches `shell.json`. |
| `noctalia` | per-monitor `colors.json` (matugen) | Plugin-driven reload. |
| `dankmaterial` | `~/.config/dms/colors.json` (matugen) | Hot-reloads on file change. |

If repaint doesn't happen, the per-project CLI is the escape hatch: `caelestia restart`,
`dms reload`, etc. The rice skill logs the matugen run and leaves these to the user.

## Composite reload sequence (`rice apply`)

```bash
# Step 1: render-templates.sh has already written every output file from palette.conf.
#         The widget shell's colors file is among them.

# Step 2: per-shell reload hook (gated on widgets.system + matugen flags).
case "$(jq -r .widgets.system answers.json)" in
  none) ;;
  eww)
    pgrep -x eww >/dev/null && eww reload || true ;;
  ags|quickshell)
    : ;;                  # file-monitor handles it
  hyprpanel|turnkey)
    if command -v matugen >/dev/null; then
      wallpaper=$(jq -r .wallpaper.path answers.json)
      [ -f "$wallpaper" ] && matugen image "$wallpaper" >/dev/null 2>&1 || true
    fi ;;
esac
```

The `|| true` everywhere is deliberate — `rice apply` should never fail because a hot-reload
couldn't find a running daemon. The validator's job is to catch real problems (broken SCSS,
missing colors, parse errors) *before* the hook runs; the hook itself is best-effort.

## Cross-references

- The manifest format and render flow → `_shared/palette-schema.md` → "Render flow",
  `theming/engine.md` → "Widget-shell theming"
- Where each shell's colors file lands → `template.md`
- Validation (runs before the hook) → `validation.md`
- Matugen + the Material-You path → `gotchas.md` → "HyprPanel and Material-You-native shells"
