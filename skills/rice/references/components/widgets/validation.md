# widgets — validation

After the widgets component renders, the relevant `~/.config/{eww,ags,quickshell,hyprpanel}/` is
parseable / compilable before any reload hook runs. The validation step is **per-shell**, gated on
`widgets.system`.

## Validation matrix

| `widgets.system` | Validator | Tool | Hard-fails on |
|---|---|---|---|
| `none` | nothing to validate | — | — |
| `eww` | yuck + SCSS parse | `eww` (CLI) | invalid yuck S-expression, SCSS compile error, unknown widget type |
| `ags` | TS compile + SCSS parse | `tsc` (in `ags` CLI) / `dart-sass` | TS type errors, SCSS unknown-variable, missing `@use` target |
| `quickshell` | QML parse | `qmllint` | unbalanced braces, unknown type, missing import |
| `hyprpanel` | JSON parse only | `jq` | malformed `~/.config/hyprpanel/config.json` |
| `turnkey` | none (the project's installer owns validation) | — | — |

## eww

eww's CLI doubles as a linter — yuck and SCSS errors surface on any `eww` command (not just
`reload`). The cleanest no-side-effect check is to ask the daemon to parse the config without
opening any windows:

```bash
# Parse-only: eww logs errors to stderr and exits non-zero on parse failure.
EWW_CONFIG_DIR="$staging/eww"  eww --restart inspector --close
# or simpler — let `eww reload` do the parse and discard its output:
EWW_CONFIG_DIR="$staging/eww" eww reload 2>&1 | tee "$staging/eww-validate.log"
```

Treat a non-zero exit as a hard fail. The two recurring categories per `gotchas.md` →
"eww quirks":

- **`alpha($color, 0.8)` errors** (grass SCSS — one-arg only). Message includes "Only 1 argument
  allowed, but 2 were passed". Fix: use `rgba($color, 0.8)`.
- **`:height "auto"` errors.** Message: "Failed to parse 'auto' as a length value". Fix: use a
  concrete length.

A handy assertion the validator can run pre-reload:

```bash
if grep -RE 'alpha\([^,]+,[^)]+\)' "$staging/eww/"*.scss; then
  echo "ERROR: alpha() with two args — use rgba() (grass-SCSS pitfall)" >&2
  exit 1
fi
if grep -RE ':(height|width) +"auto"' "$staging/eww/"*.yuck; then
  echo "ERROR: :height/:width 'auto' — use a concrete length" >&2
  exit 1
fi
```

## AGS / Astal

The Astal / AGS v3 CLI compiles + bundles TypeScript on `ags run` / `ags bundle`; there is
**no documented `--check` / parse-only flag** in v3 — `ags bundle` always emits a bundle (with
an optional `-o /tmp/...` output path), and a TS / SCSS error makes it exit non-zero, which is
what we use for validation. The v1 path (`Aylur/ags` ≤ v1.x) doesn't have a bundle step at all
— fall back to `node --check` on the JS entrypoint plus a `sassc style.scss /dev/null` SCSS
parse.

```bash
# AGS v3 (the plugin's installed version — aylurs-gtk-shell)
cd "$HOME/.config/ags"
ags bundle -o /tmp/ags-validate.js >"$staging/ags-validate.log" 2>&1 || {
  echo "ERROR: ags bundle failed; see $staging/ags-validate.log" >&2
  exit 1
}
rm -f /tmp/ags-validate.js
```

Validator-level checks the rice can run regardless of which generation is installed:

- **The colors-file `$var` names** in `~/.config/ags/colors.scss` are referenced by `style.scss` —
  any rename silently un-themes the shell. Diff the var-name set against
  `_shared/colors-contract.md` → `ags / astal` row.
- **AGS v1 vs v3 class-prop drift.** AGS v1 (GJS / `Widget.*`) used `className`; **AGS v3 (Gnim
  JSX) renamed it to `class`** (see Aylur/ags migration guide → "className -> class"). If a v1
  snippet is pasted into a v3 project, the warning cascades on every widget. The validator can
  grep `className=` against the `ags/gtk4` import line.

## Quickshell

`qmllint` is the standard parser (ships with Qt 6). Run it across the user's Quickshell config
directory:

```bash
QML_DIR="$HOME/.config/quickshell"
# qmllint takes a list of files; recurse with find:
find "$QML_DIR" -name '*.qml' -print0 | xargs -0 qmllint --strict \
  >"$staging/qml-validate.log" 2>&1 || {
    echo "ERROR: qmllint failed; see $staging/qml-validate.log" >&2
    exit 1
  }
```

`--strict` raises warnings to errors (unused properties, type-narrowing missteps). Plain
`qmllint` is parse-only and won't fail on style nits.

Validator-level checks:

- **`Colors.qml` is a singleton.** Per the Quickshell QML-overview docs the file should have
  **both** `pragma Singleton` *and* the Quickshell `Singleton` type as its root item; the `qmldir`
  beside it must contain `singleton Colors Colors.qml`. Missing either leg means every
  `Colors.accent` reference is an undefined-type error.
- **Required Quickshell modules.** Greppable imports: `import Quickshell`, `import
  Quickshell.Wayland` (for `WlrLayershell`), `import Quickshell.Io` (for `FileView` /
  `JsonAdapter`). Missing modules raise "module 'X' is not installed" at runtime.
- **No literal hex in `shell.qml`** (or wherever widgets live) — every color reference should be a
  `Colors.<key>` lookup. A grep for `color: "#[0-9a-fA-F]"` on non-`Colors.qml` files surfaces the
  drift (same intent as eww's "no hardcoded hex" rule).
- **QTBUG-137166 workaround** — flag any `Rectangle { color: "transparent"; border. … }` that
  lacks an explicit `border.width: 0` (or a positive border width).

## HyprPanel

HyprPanel reads `~/.config/hyprpanel/config.json` (and `~/.config/hyprpanel/modules.json` in newer
builds). Validation is JSON-shape only — the rice skill doesn't re-render this file:

```bash
jq empty "$HOME/.config/hyprpanel/config.json" >"$staging/hyprpanel-validate.log" 2>&1 || {
  echo "ERROR: hyprpanel config.json is not valid JSON" >&2
  exit 1
}
```

If the user picked `widgets.look == material-you`, also validate the matugen config:

```bash
matugen --version >/dev/null 2>&1 || {
  echo "ERROR: matugen not installed; required for widgets.look == material-you" >&2
  exit 1
}
```

## Turnkey shells

Validation lands on the project's installer (`caelestia install`, `dms init`, the end-4 install
script, etc.). The rice skill verifies:

- The shell's autostart command (`caelestia shell -d`, `dms run`, …) is on `$PATH`.
- The shell's config directory (`~/.config/quickshell/<name>/`) exists.
- `matugen` is installed (every turnkey shell uses it).

Past that, the shell's own startup logs are the source of truth — the rice skill points the user
at them on failure.

## Cross-references

- The eww pitfalls catalog → `gotchas.md` / `styling.md` → `## eww` → "Pitfalls"
- The Quickshell pitfalls catalog → `styling.md` → `## Quickshell` → "Pitfalls"
- The AGS v1↔v2 incompatibility list → `gotchas.md` / `styling.md` → `## AGS / Astal`
- The colors-file variable contract → `_shared/colors-contract.md`
- Per-shell reload hooks (fired only after validation passes) → `reload.md`
