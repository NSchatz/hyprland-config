# window-rules — gotchas

## `layerrule` 0.54+ is a HARD BREAK

On Hyprland **0.54+** the single-line form

```ini
layerrule = blur, waybar
```

is **rejected at parse time**:

```
Config error: invalid field blur: missing a value
... special category's first value must be the key. Key for <layerrule> is <name>
```

A single bad `layerrule =` line **fails the whole reload** (and `safe-apply.sh` rolls back). This
is unlike `windowrule`, where the single-line form still parses for back-compat. The fix is the
block form, emitted with the required `name` key:

```ini
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
}
```

Detect the version (`scripts/detect-version.sh` → `HYPR_VERSION`) and branch the emission. Pre-0.54
targets use the single-line form; 0.54+ uses the block form. See `_shared/version-matrix.md` for
the full cliff table.

## `windowrule` block form is preferred on 0.53+

The shipped 0.54 default ships block-form `windowrule { match:class = …; … }` rules and the rice
templates follow that. The single-line `windowrule = float, class:^(x)$` still parses on 0.53+ for
back-compat, but emit the block form on a fresh config so the user's file matches the upstream
tutorial / dotfile world. On **pre-0.53** targets, fall back to `windowrule` / `windowrulev2`
single-line forms (see `template.md`'s fallback section).

## Verified 0.54.3 `layerrule` block fields

| Field | Type | Notes |
|---|---|---|
| `blur` | bool (`true` / `false`) | Enable layer blur. |
| `no_anim` | bool | Skip enter/exit animation. |
| `ignore_alpha` | float `0.0`–`1.0` | Pixels with alpha < this value are ignored by blur. Replaces the legacy `ignorezero` keyword. |
| `xray` | bool | "See-through" blur (blurs what's behind the surface, not the surface itself). |
| `animation` | string | Named animation style (e.g. `slide`, `popin`). |

**No `ignore_zero` field exists in the block form.** The legacy `layerrule = ignorezero, …`
keyword was renamed to `ignore_alpha = <0-1>` in the block transition. If a generated config has
`ignore_zero = …` inside a `layerrule { }`, it will silently no-op (or, on stricter parsers, reject
the block) — use `ignore_alpha`.

## `match:` prefix on matchers (block form)

Inside a `windowrule { … }` or `layerrule { … }` block, every matcher key takes the **`match:`
prefix** — that is what distinguishes a matcher from a rule property:

| Matcher | Use |
|---|---|
| `match:class` | Window class regex (block form). |
| `match:title` | Window title regex. |
| `match:initialClass` / `match:initialTitle` | Initial values (before the app renames its window). |
| `match:namespace` | Layer-shell namespace (for `layerrule` only). |
| `match:xwayland` | `true` / `false` — match XWayland windows. |
| `match:float` / `match:fullscreen` / `match:pin` | Window state booleans. |
| `match:workspace` / `match:onworkspace` | Workspace selectors (`w[tv1]`, etc.). |
| `match:focus` | Focused / not-focused. |

In the legacy single-line `windowrulev2 = …` form the matchers were `class:`, `title:`,
`xwayland:1`, `floating:1`, etc. The prefix change (`class:` → `match:class`) is one of the most
common breakage points when copy-pasting old dotfiles. The validator flags bare `class:` /
`title:` inside a block.

## Property renames to watch for

| Legacy single-line | Block form (0.53+) |
|---|---|
| `ignorezero` | `ignore_alpha = <0-1>` |
| `keepaspectratio` | `keep_aspect_ratio` |
| `noinitialfocus` | `no_initial_focus` |
| `nofocus` | `no_focus` |
| `suppressevent` | `suppress_event` |
| `idleinhibit` | `idle_inhibit` |
| `noblur` | `no_blur` |
| `noanim` | `no_anim` |
| `bordersize` | `border_size` |

Mixing legacy property keywords inside a block (`windowrule { match:class = …; nofocus = yes }`)
silently no-ops the property — the block form expects `no_focus`. The validator flags this.

## App-to-workspace pins should always be `silent`

When emitting `windowrule { workspace = N silent; match:class = … }` from `monitors.pin_apps`,
keep the `silent` suffix unconditionally. Without it, launching the pinned app **yanks focus** to
its target workspace — surprising and rarely wanted (the user wanted "open Spotify on 9", not
"jump to 9 every time Spotify launches").

## XWayland drag-fix rule looks weird but is intentional

The shipped `fix-xwayland-drags` rule has an empty-string class **and** empty-string title match
with `match:xwayland = true; match:float = true`. That combination targets the short-lived,
unnamed floating XWayland surfaces (drag overlays) that would otherwise steal focus mid-drag and
drop the operation. Inherit it verbatim — don't try to "simplify" the matchers.

## 0.55+ additions

`confine_pointer` (trap cursor inside window) and `scrolling_width` (column width for the
scrolling layout) are new in 0.55. Only emit when `HYPR_VERSION >= 0.55`. See
`_shared/version-matrix.md` and `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/deprecations.md`.
