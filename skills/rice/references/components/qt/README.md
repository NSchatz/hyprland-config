# qt

Qt application theming: the `qt6ct` colors file the rice engine renders so Qt apps (Dolphin, the
KDE file pickers, qBittorrent, VLC's Qt UI) match the rest of the desktop instead of rendering in
stock Fusion grey.

## Contents

- Why this folder has no interview
- Files in this folder
- Where this lands
- Related

## Why this folder has no interview

Nothing is asked for Qt directly. The component is driven entirely by answers that belong to
other components:

| Trigger | Set by |
|---|---|
| any Qt default app is picked (e.g. Dolphin as file manager) | `default_apps.*` |
| `env.qt_platformtheme == "qt6ct"` | the `env` component |

When either holds, the render manifest gains a `qt6ct` row (see
[`../../theming/engine.md`](../../theming/engine.md) → "Manifest format" and the mandatory-rows
matrix in [`../../modes/apply.md`](../../modes/apply.md) → A4), and `rice apply` renders
`qt6ct.tmpl` into `~/.config/qt6ct/colors/rice.conf` on every theme change.

So this folder is template-only on purpose. It has no `interview.md` or `schema.md` because it
owns no answers, and no `packages.md` because `qt6ct` is installed by the `env` component's
slice when the platform theme is selected.

## Files in this folder

| File | What it holds |
|---|---|
| `template.md` | What to emit, the Kvantum-vs-Fusion decision, and the coherence rule that a Qt file-picker left unthemed puts a grey hole in an otherwise complete rice. |
| `qt6ct.tmpl` | The engine colors template rendered to `~/.config/qt6ct/colors/rice.conf`. |

## Where this lands

- `~/.config/qt6ct/colors/rice.conf` — rendered by the engine from `qt6ct.tmpl`.
- `~/.config/qt6ct/qt6ct.conf` — the user's own Qt config, which must reference that colors file.
  Not owned by this component.

## Related

- [`../env/`](../env/) — sets `QT_QPA_PLATFORMTHEME`, without which none of this is read.
- [`../default-apps/`](../default-apps/) — whether a Qt app is in play at all.
- [`../../theming/gtk-qt.md`](../../theming/gtk-qt.md) — the cross-toolkit theming guide,
  including why Dolphin without the Qt route is coherence-dead.
