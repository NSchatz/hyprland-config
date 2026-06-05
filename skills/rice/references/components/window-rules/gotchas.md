# window-rules — gotchas

## `layerrule` 0.54+ is a HARD BREAK (specific old form)

On Hyprland **0.53+** the bare single-line form

```ini
layerrule = blur, waybar
```

is **rejected at parse time**:

```
Config error: invalid field blur: missing a value
... special category's first value must be the key. Key for <layerrule> is <name>
```

The problem is that `blur` is now a typed effect that takes a value (`blur on` or `blur = true`),
so the parser sees `blur` without a value and bails. A single bad `layerrule =` line **fails the
whole reload** (and `safe-apply.sh` rolls back). The fix is either the block form (with the
required `name` key) or the modern single-line form with `match:` and an explicit value:

```ini
# Block form (recommended)
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
}

# Modern single-line form (also valid)
layerrule = blur on, match:namespace waybar
```

The same parsing rules apply to `windowrule` — the bare-keyword v1 form
(`windowrule = float, class:^(x)$`) errors with `invalid field type class:^(x)$` because matchers
now require the `match:` prefix. Detect the version (`scripts/detect-version.sh` →
`HYPR_VERSION`) and emit the block form on 0.53+ to match the shipped default. See
`_shared/version-matrix.md` for the full cliff table.

## `windowrule` block form is preferred on 0.53+

The shipped 0.54 default ships block-form `windowrule { match:class = …; … }` rules and the rice
templates follow that. The legacy v1 single-line `windowrule = float, class:^(x)$` **stopped
parsing in 0.53** — the matcher must be `match:class kitty` (no `^()$` wrappers, no `:` separator;
just space-separated `field value`). `windowrulev2 = …` is now hard-rejected with
`windowrulev2 is deprecated. Correct syntax can be found on the wiki.` Use the block form on a
fresh config. On **pre-0.53** targets, fall back to the legacy `windowrule` / `windowrulev2`
single-line forms (see `template.md`'s fallback section).

## Verified 0.54.3 `layerrule` block fields

Verified by reading
`src/desktop/rule/layerRule/LayerRuleEffectContainer.cpp` on the `v0.54.3` tag:

| Field | Type | Notes |
|---|---|---|
| `blur` | bool (`true` / `false`) | Enable layer blur. |
| `blur_popups` | bool | Enable blur on layer popups. |
| `no_anim` | bool | Skip enter/exit animation. |
| `ignore_alpha` | float `0.0`–`1.0` | Pixels with alpha < this value are ignored by blur. Replaces the legacy `ignorezero` keyword. |
| `xray` | bool | "See-through" blur (blurs what's behind the surface, not the surface itself). |
| `dim_around` | bool | Dim everything behind the layer. |
| `animation` | string | Named animation style (e.g. `slide`, `popin`). |
| `order` | integer | Override the layer's stacking order within its level. |
| `above_lock` | bool | Render this layer above the lock screen. |
| `no_screen_share` | bool | Hide the layer from screen-share captures. |

**No `ignore_zero` field exists in the block form.** The legacy `layerrule = ignorezero, …`
keyword was renamed to `ignore_alpha = <0-1>` in the block transition. There is also **no
`unique` field**. If a generated config has `ignore_zero` or `unique` inside a `layerrule { }`,
it will be rejected by the special-category parser (every key in a `layerrule { }` block must be
either `name`, `enable`, `match:<prop>`, or one of the registered effect names above).

## `match:` prefix on matchers (block form)

Inside a `windowrule { … }` or `layerrule { … }` block (and on the modern single-line form),
every matcher key takes the **`match:` prefix** — that is what distinguishes a matcher from a
rule property. The canonical matcher names come from
`src/desktop/rule/Rule.cpp`'s `MATCH_PROP_STRINGS` map (verified on `v0.54.3` and current main):

| Matcher | Use |
|---|---|
| `match:class` | Window class regex. |
| `match:title` | Window title regex. |
| `match:initial_class` / `match:initial_title` | Initial values (before the app renames its window). **snake_case, not camelCase.** |
| `match:namespace` | Layer-shell namespace (for `layerrule` only — see `hyprctl layers`). |
| `match:xwayland` | `true` / `false` — match XWayland windows. |
| `match:float` | `true` / `false` — match floating windows. **The matcher is `float`, NOT `floating`.** |
| `match:fullscreen` | `true` / `false`. |
| `match:pin` | `true` / `false` — match pinned windows. |
| `match:focus` | `true` / `false` — currently focused. |
| `match:group` | `true` / `false` — grouped windows. |
| `match:modal` | `true` / `false` — modal popups ("Are you sure…"). |
| `match:workspace` | Workspace selector (`w[tv1]`, `f[1]`, numeric, name:foo, etc.). **This is the `RULE_PROP_ON_WORKSPACE` selector — there is no `match:onworkspace`.** |
| `match:tag` | Tag name (matches windows with that tag set via `tag +foo` rule). |
| `match:content` | `none` / `photo` / `video` / `game`. |
| `match:xdg_tag` | XDG toplevel tag regex. |
| `match:fullscreen_state_internal` / `match:fullscreen_state_client` | Integer fullscreen-state codes. |

In the deprecated `windowrulev2 = …` form the matchers were `class:`, `title:`, `xwayland:1`,
`floating:1`, `onworkspace:N`, etc. The prefix change (`class:` → `match:class`), the rename
(`floating` → `float`, `onworkspace` → `workspace`), and the case change
(`initialClass` → `initial_class`) are the most common breakage points when copy-pasting old
dotfiles. The validator flags bare `class:` / `title:` / `match:floating` / `match:onworkspace`
/ `match:initialClass` inside a block.

## Property renames to watch for

Verified against `src/desktop/rule/windowRule/WindowRuleEffectContainer.cpp` on `v0.54.3`:

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
| `noshadow` | `no_shadow` |
| `nodim` | `no_dim` |
| `bordersize` | `border_size` |
| `bordercolor` | `border_color` |
| `dimaround` | `dim_around` |
| `forcergbx` | `force_rgbx` |
| `stayfocused` | `stay_focused` |
| `noscreenshare` | `no_screen_share` |
| `nomaxsize` | `no_max_size` |
| `nofollowmouse` | `no_follow_mouse` |
| `noshortcutsinhibit` | `no_shortcuts_inhibit` |
| `nearestneighbor` | `nearest_neighbor` |
| `focusonactivate` | `focus_on_activate` |
| `renderunfocused` | `render_unfocused` |

Mixing legacy property keywords inside a block (`windowrule { match:class = …; nofocus = yes }`)
fails to register the property — the block form is a Hyprlang special category whose only
recognized property names are the snake_case effect strings above. The validator flags this.

**There is no `no_border` / `noborder` effect.** To remove the border on a class, use
`border_size = 0` (verified — `border_size` is in the effect list; `no_border` is not).
Likewise there is no `nofullscreenrequest` effect — `sync_fullscreen = false` is the nearest
equivalent.

## `idle_inhibit` valid values

`idle_inhibit` is a string-valued effect, not a bool. Accepted values (per the wiki and source):
`none`, `always`, `focus`, `fullscreen`. Use `fullscreen` to inhibit only when the matched window
is fullscreen (the typical "don't lock during video" rule).

## App-to-workspace pins should always be `silent`

When emitting `windowrule { workspace = N silent; match:class = … }` from `monitors.pin_apps`,
keep the `silent` suffix unconditionally. Without it, launching the pinned app **yanks focus** to
its target workspace — surprising and rarely wanted (the user wanted "open Spotify on 9", not
"jump to 9 every time Spotify launches"). `silent` is part of the `workspace` effect's value
(the wiki documents it as: "Can also be `unset` or suffixed with ` silent`"); it is not a
separate effect keyword.

## XWayland drag-fix rule looks weird but is intentional

The shipped 0.54.3 `fix-xwayland-drags` rule has an empty-string class **and** empty-string title
match with `match:xwayland = true`, `match:float = true`, `match:fullscreen = false`,
`match:pin = false`, and `no_focus = true`. That combination targets the short-lived, unnamed
floating XWayland surfaces (drag overlays) that would otherwise steal focus mid-drag and drop the
operation. Inherit it verbatim — don't try to "simplify" the matchers.

## Workspace rules belong in `monitors.conf`, not here

`workspace = N, monitor:DP-1, persistent:true, default:true, on-created-empty:CMD`,
`workspace = w[tv1], gapsout:0, gapsin:0` and friends are **workspace rules**, owned by the
`monitors` component. This component only emits the **windowrule** half of paired rules (e.g.
the `border_size = 0` / `rounding = 0` windowrules that pair with the smart-gaps workspace rule).
See `template.md` "What does NOT belong here".

## Layer-shell namespace cliffs (the theming-relevant ones)

The `layerrule blur` block is what makes a translucent waybar/launcher/notification look
right. It only fires when `match:namespace = X` matches the actual layer-shell namespace the
app sets on its surface. Most cross-rice copy-paste breakage in this component is one of
these surfaces being targeted by the wrong name.

### fuzzel's namespace is `launcher`, **not** `fuzzel`

Verified against fuzzel upstream (`doc/fuzzel.ini.5.scd`, key `namespace`):

> **namespace**
> Namespace for the spawned layer shell surface. … Default: _launcher_

So the correct blur rule for a stock fuzzel install is:

```ini
layerrule {
    name = blur-launcher
    match:namespace = launcher
    blur = true
}
```

end-4/dots-hyprland (`dots/.config/hypr/hyprland/rules.lua`) and
caelestia-dots/caelestia (`hypr/hyprland/rules.conf`) both blur fuzzel as
`namespace = launcher`. Older HyDE-derived / community configs that pasted in
`layerrule = blur, fuzzel` blur **nothing** — fuzzel never broadcasts that namespace. If
the user overrode fuzzel's `namespace =` in `fuzzel.ini` (e.g. `namespace = fuzzel`),
emit that override instead — but never assume `fuzzel` as the default.

### swaync exposes TWO namespaces — blur BOTH

Verified against SwayNotificationCenter upstream:
`src/controlCenter/controlCenter.vala`:

```vala
GtkLayerShell.set_namespace (this, "swaync-control-center");
```

`src/notificationWindow/notificationWindow.vala`:

```vala
GtkLayerShell.set_namespace (this, "swaync-notification-window");
```

The control-center panel and the individual notification popups are **separate layer
surfaces** with separate namespaces. A rule that blurs only one looks like a half-applied
theme: the popup is glassy and the panel is opaque (or vice versa). Both prasanthrangan/
hyprdots (`Configs/.config/hypr/windowrules.conf`) and binnewbs/arch-hyprland
(`.config/hypr/configs/windowrules.conf`) emit paired rules for both. JaKooLit/
Hyprland-Dots ships swaync but blurs only the generic `notifications` namespace (dunst's
name) — verified gap in `config/hypr/configs/WindowRules-config-v3.conf`, so a swaync
user gets no blur from that template.

Recipe: when `notifications.tool == "swaync"`, emit **two** layerrule blocks —
`blur-swaync-control-center` and `blur-swaync-notification-window`. When the tool is
`mako`/`dunst`, emit one block on `match:namespace = notifications` (that's both
daemons' shared default).

### `layer-shell-cover-screen` is the backdrop alternative

Matt-FTW/dotfiles (`.config/swaync/config.json`) sets:

```jsonc
"layer-shell": true,
"layer-shell-cover-screen": true,
```

swaync's `configSchema.json` documents this key as:

> Whether or not the windows should cover the whole screen when layer-shell is used …
> Fixes animations in compositors like Hyprland.

The side-effect: the control-center surface stretches to the full output, so a tap
outside the panel still hits the layer, giving a free click-outside-to-dismiss backdrop
without a `dim_around` layerrule. If a user picks `layer-shell-cover-screen: true` in
notifications interview, the `dim_around = true` line is redundant — flag it
non-fatally in validation, but don't insert it.

### Launcher → namespace map (per chosen tool)

`launcher.tool` answer | layer-shell namespace | source
:---|:---|:---
`rofi` (`rofi-wayland`) | `rofi` | rofi-wayland source `source/wayland/display.c` line 1589: `zwlr_layer_shell_v1_get_layer_surface(…, "rofi")`. Used by HyDE / JaKooLit / dusky / linuxmobile / binnewbs.
`fuzzel` | `launcher` | `fuzzel.ini(5)` default (see above). Used by end-4 and caelestia.
`wofi` | `wofi` | Community-standard string; widely cited but not verified against wofi source in this pass.
`anyrun` | `anyrun` | Community-standard string; end-4's `rules.lua` uses `namespace = "anyrun"`.
`walker` | `walker` | end-4's `rules.lua` uses `namespace = "walker"`.

`launcher.namespace` in the schema slice MUST be one of these strings — there is no
"guess from the tool". If the user customized it (rare), capture the override at
interview time.

### `decoration:blur:enabled = false` makes every `layerrule blur` a no-op

Verified against `src/render/OpenGL.cpp`:

```cpp
static auto PBLUR = CConfigValue<Config::INTEGER>("decoration:blur:enabled");
…
if (!*PBLURNEWOPTIMIZE || !pMonitor->m_blurFBDirty || !*PBLUR)
    return;
```

The master blur switch is the look-feel "Blur on/off" toggle (group 11 in
`../look-feel/interview.md`). If the user picks **Blur: off**, every `layerrule { blur =
true }` we emit silently does nothing — the bar/launcher/notifications fall back to
their raw alpha. That's intentional (the master toggle is a master toggle), but it means
the "translucent panel" look the visual-component agents tuned for is **only** as good
as the user's blur answer. The recipe still emits the `layerrule` blocks unconditionally
(so flipping blur back on later just works) — there's nothing for this component to
gate.

Likewise, `windowrule = no_blur` per-class always overrides the layer master — that's
how gaming/video apps opt out of the FBO bloom (HyDE, caelestia, fufexan all do this
for steam_app, gamescope, krita/blender, mpv).

### Modern single-line `layerrule = blur on, match:namespace waybar` parses on 0.54+

Verified against `v0.54.3/src/config/ConfigManager.cpp::handleLayerrule` — tokens are
comma-split, then each token space-split. A token starting with `match:` is a matcher
(field after `match:` looked up in `MATCH_PROP_STRINGS`); any other token is treated as
`<effect> <value>`. So `layerrule = blur on, match:namespace waybar` parses cleanly,
because `blur on` → effect `blur` value `on`, and `match:namespace waybar` →
matcher `namespace` = `waybar`.

JaKooLit's `config/hypr/configs/WindowRules-config-v3.conf` uses this modern single-line
form (`layerrule = match:namespace rofi, blur on`); caelestia's `hypr/hyprland/rules.conf`
uses it for windowrules too. The rice templates emit the **block form** because the
shipped Hyprland default does and that is where the wiki points users, but if a user
hand-edits `windowrules.conf` to drop in a single-line modern rule, it parses on the
same 0.54+ targets the block form does. Pre-0.53 / pre-0.54 fall back to the legacy
form per `_shared/version-matrix.md`.

## 0.55+ additions

The following windowrule effects only exist on `HYPR_VERSION >= 0.55` (verified absent in
`v0.54.3/src/desktop/rule/windowRule/WindowRuleEffectContainer.cpp`, present on main and
`v0.55.0`):

- `confine_pointer` — trap cursor inside the window (game-on-one-monitor use case).
- `scrolling_width` — starting column width for the scrolling layout.
- `no_auto_hdr` — (main, 0.55.x) opt a window out of automatic HDR passthrough.

The scrolling-layout layoutmsg arguments `expel`, `consume`, `consume_or_expel`, the
`rotatesplit` dwindle layoutmsg, the `auto_consuming` binds flag, and `groupbar:middle_click_close`
are also 0.55+ — but these belong in `keybinds` / `look-feel`, not here. Only emit
`confine_pointer` / `scrolling_width` when `HYPR_VERSION >= 0.55`. See
`_shared/version-matrix.md` and `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/deprecations.md`.
