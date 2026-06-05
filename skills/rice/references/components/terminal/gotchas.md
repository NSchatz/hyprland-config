# terminal — gotchas

## Font **family** ≠ font **size** — keep them apart

The colors file (`colors.conf`, `colors.toml`, `colors.lua`, the `[colors]` block of `foot.ini`,
the `palette = …` lines of `ghostty/config`) holds **palette only**. It does **not** include
`font_family` and **does not** include `font_size`. Both font keys live in the emulator's main
config (`kitty.conf`, `alacritty.toml`, etc.) and are written **once** at generate-time.

Why this matters: re-theming runs `rice apply`, which rewrites the colors file and **only** the
colors file. If the colors file carried `font_size 11`, every re-theme would silently revert the
user's `font_size 13` edit. Treat the colors file as palette-pure; the main config owns sizing
and the family resolves from `fonts.mono` (group 13).

The contract is enforced by `_shared/colors-contract.md`: kitty's `colors.conf` exports exactly
`background foreground cursor selection_background selection_foreground color0..color15` — no
font keys, no opacity.

## Window-swallowing needs two ingredients

If the user picks `swallow` in `terminal.extras`, both lines have to land in
`look-feel/looknfeel.conf` (the **look-feel** component owns these — not this one):

```ini
misc {
    enable_swallow = true
    swallow_regex  = ^(<terminal-class>)$
}
```

The `<terminal-class>` map (from `hyprctl clients` on a running system):

| emulator | window class (regex literal) |
|---|---|
| kitty | `kitty` |
| alacritty | `Alacritty` |
| foot | `foot` |
| wezterm | `org.wezfurlong.wezterm` |
| ghostty | `com.mitchellh.ghostty` |

Missing the regex → swallowing never triggers (Hyprland has no class to match). Missing
`enable_swallow` → the regex is dead config. Both must ship together, gated on
`terminal.swallow == true`. See the **look-feel** component for the actual block.

## `$terminal` in `hyprland.conf` must match the chosen emulator

The variables block at the top of `hyprland.conf` declares `$terminal = <command>`. The
`keybinds` component's `bind = $mainMod, Return, exec, $terminal` line is the **only** path users
launch a new terminal — so if `terminal.emulator` is `alacritty` but `$terminal = kitty`, the bind
opens kitty and the rest of the rice (themed alacritty config, palette in `alacritty.toml`) is
invisible.

The rule: `terminal.emulator` from `answers.json` is the single source. The `hyprland`-component
writer reads it and emits `$terminal = <emulator>` verbatim (no aliases, no `$TERM`, no shell
wrappers).

## Alacritty TOML vs YAML history

Alacritty migrated from YAML to **TOML at 0.13** (Dec 2023). Stale copy-paste from old guides will
hand you `alacritty.yml` with snake_case nesting; current alacritty silently ignores it. The rice
template emits **TOML only** (`alacritty.toml`), and the install step warns if a pre-existing
`alacritty.yml` is detected alongside (offer to run `alacritty migrate`).

Other TOML-era gotchas worth flagging:
- `[cursor.style]` is `{ shape = "Beam", blinking = "On" }` (capitalized values: `Block`/
  `Underline`/`Beam` for shape, `Never`/`Off`/`On`/`Always` for blinking) — **not** under
  `[colors]` (a common port mistake).
- `transparent_background_colors = true` lives under **`[colors]`**, not `[window]`. It is
  required for `[window].opacity` to actually look transparent — without it, the theme's solid
  background paints every cell and opacity is dead. (alacritty/alacritty docs section is
  `[colors]`.)
- `[window].blur` is **macOS-only**; on Wayland the blur comes from Hyprland's decoration block,
  not alacritty. Don't waste a key on it.
- `import = [...]` and `live_config_reload = true` both live under the `[general]` table in
  ≥0.13, not at the top level. The 0.13 release was 2023-12-27 (`alacritty/alacritty` v0.13.0).
- `[font] size` is typed `<float>`; render integer answers as `11.0` (not `11`) so strict TOML
  parses without an `invalid type: integer` error.
- Per-terminal shell override lives at `[terminal] shell = "/usr/bin/fish"` or
  `[terminal] shell = { program = "/usr/bin/fish", args = ["-l"] }`.

## Opacity below ~0.8 is unreadable

The interview offers `1.0` / `0.95` / `0.85` / custom. The validator warns if the user types a
custom value below `0.7` — over a busy wallpaper, text legibility collapses. See
`styling.md` "Pitfalls" for the full reasoning. If the user insists, write the value and move on
(the warning is non-blocking).

## foot uses bare hex; the other four want `#`

The rice engine's per-emulator colors writer branches on this. kitty/alacritty/wezterm/ghostty get
`#1e1e2e`; foot's `[colors]` block takes `1e1e2e` (no `#`, alpha lives in `alpha=` not in the hex).
Easy to get wrong by reusing kitty's writer for foot — foot then silently rejects every color.

## foot bell config is in `[bell]`, not `[main]`

Stale snippets put `bell=none` under `[main]`; foot silently drops unknown keys, so the bell
stays on. The real keys live in their own section (`foot.ini(5)`):

```ini
[bell]
system=no       # default yes — ring the system bell
urgent=no       # default no  — signal urgency to the compositor
visual=no       # default no  — flash the terminal window
notify=no       # default no  — emit a desktop notification
command=        # default empty — run a command on BEL
```

To silence the bell completely, set `system=no` (the others default off). There is **no
`bell=none`** shortcut.

## foot cursor `style` values

`[cursor] style` accepts `block | beam | underline | hollow` — exactly four values per
`foot.ini(5)`. `bar` (alacritty/ghostty's name for beam) is **not** a valid foot value.

## Per-emulator `shell` directive vs `chsh`

Each emulator has its own way of overriding the user's login shell. Rice writes **none of these
by default** — `chsh` is the source of truth and the per-emulator overrides exist only as
opt-ins for users who want, say, fish in their terminal and bash everywhere else.

| Emulator | Directive | Default behaviour |
|---|---|---|
| kitty | `shell /usr/bin/fish` (top-level kitty.conf) | `shell .` → `$SHELL` or login shell |
| alacritty | `[terminal] shell = "/usr/bin/fish"` or `{ program = "...", args = [...] }` | uses `$SHELL` |
| foot | `shell=/usr/bin/fish` (top-level / `[main]`) | uses `$SHELL` or login shell |
| wezterm | `config.default_prog = { '/usr/bin/fish', '-l' }` | uses login shell |
| ghostty | `command = /usr/bin/fish` | uses login shell |

## Version branch — none today

No Hyprland-version cliffs touch this component's templates (the swallow keys have been stable
since 0.30). See `_shared/version-matrix.md` for the cliffs other components branch on; nothing
here on the terminal side.
