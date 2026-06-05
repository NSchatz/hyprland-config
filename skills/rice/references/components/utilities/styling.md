# utilities — styling

Only one surface in this component is visually themed: **wlogout**. The screenshot/screen-record/OCR
/color-picker/clipboard/emoji/calculator/wifi/bluetooth/night-light entries are functional shell
binds — they have no `style.css` of their own. Themed pickers (rofi power menu, rofi clipboard
prompt) live under `components/launcher/styling.md`.

If a future researcher adds a daemon with a visible surface (e.g. `swayosd` did not appear in any
top corpus rice during the 2026-06 sweep — see `gotchas.md`), append a new section here rather
than spreading the styling around.

## wlogout

### How the community styles it

The corpus converges on a small set of choices. Quoted CSS is verbatim from the cited file.

**Anatomy** — wlogout is a single fullscreen GTK layer-shell window (or `xdg` fallback) with one
or more rows of buttons, each rendered from a JSON-lines `layout` entry. The button's `label` is
the CSS `#name` selector; the `text` is the visible label string; the `keybind` is the bare keysym
that selects it from the keyboard.

**Three styling archetypes the corpus uses:**

1. **Translucent backdrop + rounded button grid** — the modern default. `window` gets
   `background-color: rgba(…, 0.5)` (or `alpha(@bg, 0.5)` when wired to a palette); buttons get
   `border-radius` between 20 and 80px, transparent or surface-colored fill, and a hover state
   that fills with the accent.
   - `linuxmobile/hyprland-dots:.config/wlogout/style.css` —
     `window { background-color: rgba(30, 30, 46, 0.5); }`, buttons with `background-color:
     rgba(30, 30, 46, 0)` and `button:focus { background-color: #cba6f7; color: #1e1e2e; }` (the
     accent-on-focus pattern, Catppuccin mauve).
   - `JaKooLit/Hyprland-Dots:config/wlogout/style.css` — `border-radius: 80px;` (large pill),
     `background-color: rgba(30, 30, 46, 0.8);` on the window, `@import
     '../../.config/waybar/wallust/colors-waybar.css';` to reuse waybar's colors.
   - `binnewbs/arch-hyprland:.config/wlogout/style.css` — `border-radius: 20px;` (rounded-rect),
     `@import '../../.config/waybar/colors.css';`, accent applied via `background-color:
     @on_secondary_fixed_variant;` on hover.

2. **Sliding-pill row with adjacent-button radius coordination** —
   `prasanthrangan/hyprdots:Configs/.config/wlogout/style_1.css` shapes each button so the
   leftmost has `border-radius: ${button_rad}px 0 0 ${button_rad}px;` and the rightmost
   `0 ${button_rad}px ${button_rad}px 0`, with middle buttons square. On `:hover` each button
   gets its own `border-radius: ${active_rad}px` and a margin shift — the visual effect is a
   pill that "lifts" out of a continuous bar. HyDE substitutes the radius / margin / button-color
   values at install time via `wallbash`, not at runtime via CSS variables — the resulting CSS
   is plain.

3. **Minimal monochrome icon-grid** —
   `end-4/dots-hyprland:dots/.config/wlogout/style.css` strips all color theming. Buttons use the
   Material Symbols Outlined font glyph as their entire visible content (`font-family: 'Material
   Symbols Outlined'; font-size: 10rem;`), text comes from the `layout` `text` field (e.g.
   `"text": "power_settings_new"` — the icon's codepoint name, not a label). No `colors.css`
   import. This is the "shell-style" wlogout that pairs with a Quickshell rice; if the user picks
   Material-You-native shells, expect this aesthetic.

### Battle-tested techniques

- **`@import "colors.css";` at the top of `style.css`.** This is the *only* way a re-theme reaches
  wlogout without re-rendering the whole `style.css`. The engine writes `colors.css` from
  `wlogout.tmpl`; the `style.css` is stable user-owned (or rice-shipped) markup. Both JaKooLit
  and binnewbs do this — they import the *waybar* `colors.css`, which works because waybar's
  contract is a strict superset of wlogout's (`bg fg accent surface muted` ⊂ waybar). The
  shipped recipe (`template.md`) writes a wlogout-local `colors.css` so rices without waybar
  (HyprPanel, AGS shells) still theme correctly.

- **The hover-overshoot ease curve `cubic-bezier(.55, 0.0, .28, 1.682)`.** Appears verbatim in
  `prasanthrangan/hyprdots`, `JaKooLit/Hyprland-Dots`, and `binnewbs/arch-hyprland`. Pair it
  with `transition: all 0.3s …` so size, color, and border-radius animate together when the user
  arrows through the buttons.

- **`background-size: 20%` → `background-size: 30-50%` on hover.** This is how every styled
  rice in the corpus signals the focused button: the icon-PNG inside the button is rendered at
  20% of the button size at rest and 30-50% on `:hover/:focus`, producing a "zoom" without any
  transform math. The PNG itself doesn't need to change.

- **Triple-source icon `image(url(…), url(…), url(…))` fallback.** HyDE writes
  `image(url("$HOME/.config/wlogout/icons/lock_${BtnCol}.png"),
  url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"))` so
  custom icons override the system set, with `/usr/local/share` as a meson-install fallback.
  For the default recipe we ship the two system paths only — keeps installation portable.

- **Sourcing waybar's `colors.css` directly** (instead of writing a wlogout-specific one). Two
  corpus rices do this:
  - `JaKooLit/Hyprland-Dots:config/wlogout/style.css` line 5 —
    `@import '../../.config/waybar/wallust/colors-waybar.css';`
  - `binnewbs/arch-hyprland:.config/wlogout/style.css` line 7 —
    `@import '../../.config/waybar/colors.css';`

  Our engine writes a wlogout-local `colors.css` because not every user runs waybar (Quickshell /
  AGS / HyprPanel rices don't), but the var-name overlap is intentional: `bg/fg/accent/surface`
  is exactly the wlogout slice of the waybar contract — see `_shared/colors-contract.md`.

- **`transparency = "real"`** (rofi power-menu flavor only). When the user picks the
  `powermenu.sh` rofi flavor, the rofi theme needs `transparency: "real";` in its `window {}`
  block to honor a layerrule blur — HyDE's `Configs/.config/rofi/clipboard.rasi` does this. The
  bind itself is owned by `keybinds`, but the rofi styling is `launcher`-component territory.

### Cross-surface coherence

- **Button hover color** must equal waybar's active-workspace fill — both signal "focused
  thing". `_shared/colors-contract.md` makes this automatic: both use `@accent`.

- **Border radius** should match the launcher's button radius (when the rofi power-menu flavor
  is chosen). Mismatched corner radii on `SUPER+SHIFT+M` (wlogout) vs `SUPER+Escape` (rofi power
  menu) look unintentional. The `look-feel` component owns the rice-wide `radius` token; both
  surfaces should read from it.

- **Backdrop opacity** (the wlogout `window` `alpha(@bg, X)`) should be loud enough that the
  buttons read as a foregrounded modal, not as floating chips over the desktop. The corpus
  cluster is **0.5 – 0.85**; we default to 0.85 in `template.md` for accessibility (lower
  contrast risk on light wallpapers). HyDE goes lower (`rgba(17, 17, 17, 0.45)`) because the
  bigger pill buttons compensate.

### Layout quirks worth knowing

- **`hibernate` is not universally supported.** Systems without a swap partition or large
  enough swapfile will silently fail `systemctl hibernate`. The corpus still ships the button;
  the upstream `ArtsyMacaw/wlogout` `layout` file (master) keeps it. Leaving it in is the
  expected behavior — the systemd command itself surfaces the error.

- **`soft-reboot` is a dusky-only addition** (`dusklinux/dusky:.config/wlogout/layout` line 26)
  using `keybind: "q"`. It triggers `systemctl soft-reboot` (kexec-style userspace restart). Not
  on the standard recipe — it requires systemd ≥ 254 and won't work in containers / VMs without
  configuration.

- **`logout` action varies.** Three valid forms across the corpus:
  - `hyprctl dispatch exit 0` — JaKooLit, binnewbs, linuxmobile, ML4W (via `power.sh exit`),
    end-4 (custom). **Corpus majority; our recipe default.**
  - `loginctl terminate-user $USER` — upstream wlogout default (master), fufexan.
  - `loginctl kill-session $XDG_SESSION_ID` — binnewbs's layout file.

  All three log the user out of Hyprland; the loginctl variants also end other sessions
  for the same user (TTY, SSH). Prefer `hyprctl` unless the rice is greetd-managed.
