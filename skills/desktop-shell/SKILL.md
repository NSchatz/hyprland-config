---
name: Configure Desktop Shell
description: This skill should be used when the user runs "/hyprland-config:desktop-shell" or asks to set up or change the desktop shell components around Hyprland — e.g. "set up my waybar", "configure my status bar", "add modules to waybar", "set up wofi/rofi", "configure mako/dunst notifications", or "give me a working bar". Writes the functional config for the bar (waybar config.jsonc + style.css), launcher (wofi/rofi), and notification daemon (mako/dunst) — backing up and reloading each. For the colors of these components, use theme-config; for autostarting them, use generate-config.
argument-hint: "[request, e.g. 'set up waybar with battery and tray']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Configure Desktop Shell

Set up the functional configs for the Wayland shell around Hyprland — status bar, launcher, and
notification daemon. This skill owns **structure and behavior** (modules, layout, keybind-free
behavior); **colors** are owned by the **theme-config** skill (each config `@import`s/includes the
generated colors file), and **autostart** (`exec-once = waybar`…) is owned by **generate-config**.
Treat `$ARGUMENTS` as the request.

Read `references/components.md` for concrete waybar / wofi / rofi / mako / dunst configs, module
options, reload commands, and the Nerd-Font note.

## Workflow

### 1. Detect what's installed

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh"
```

Use the `HAVE_*` lines for `waybar/hyprpanel/wofi/rofi/mako/dunst`. Configure the tools the user
has (or asks for); for a tool that isn't installed, note the package rather than installing it.
Also check for a Nerd Font (`fc-list | grep -i nerd`) since the bar/notification glyphs need one.

### 2. Decide components & content (ask)

Confirm which components to set up and key choices:

- **Bar** (waybar): which modules (workspaces, window, clock, audio, network, cpu, memory,
  battery, tray) — default to a sensible set, dropping `battery` on desktops. Position/height.
- **Launcher** (wofi or rofi): drun mode, icons.
- **Notifications** (mako or dunst): timeouts, position, size.

### 3. Back up existing configs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" \
  ~/.config/waybar ~/.config/wofi ~/.config/rofi ~/.config/mako ~/.config/dunst
```

(Only the paths being changed.) Record the `BACKUP` lines.

### 4. Write the functional configs

From `components.md`, write each component's config file(s) with `Write`/`Edit`:

- waybar: `~/.config/waybar/config.jsonc` + `style.css` (with `@import "colors.css";` at the top
  of `style.css` so theme-config can color it).
- wofi: `~/.config/wofi/config` + `style.css` (`@import "colors.css";`).
- rofi: `~/.config/rofi/config.rasi` (+ a theme that `@import`s `colors.rasi`).
- mako: `~/.config/mako/config` / dunst: `~/.config/dunst/dunstrc` (leave color keys to
  theme-config, or set neutral defaults the user can re-theme).

Keep modules aligned to installed tools (e.g. only add the `network` on-click if
`nm-connection-editor` exists; `pulseaudio` on-click → `pavucontrol`). Do not hardcode theme
colors — reference the colors file.

### 5. Reload + sanity-check

Reload the affected running apps:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/apply-theme.sh"
```

(It reloads waybar via `SIGUSR2`, mako via `makoctl reload`, dunst via `dunstctl reload` — only if
running.) For **waybar specifically**, a malformed `config.jsonc` makes the bar fail to appear, so
validate it first. **Generate `config.jsonc` as strict, comment-free JSON** (waybar does not
require `//` comments) so a plain parser works directly:

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" ~/.config/waybar/config.jsonc \
  && echo "config.jsonc OK" || echo "config.jsonc has a JSON error — fix before reloading"
```

If you must validate a file that contains `//` comments, strip them into a temp copy first
(`sed -E 's@//.*$@@' file > /tmp/x.json`) and parse that. If waybar didn't come back after reload,
run `waybar` once in the foreground to read the error.

### 6. Report

Summarize components configured, files written, backup paths, reload results, and any package the
user should install (a missing tool, or a Nerd Font for glyphs). Remind them that **colors** come
from `theme-config` and **autostart** from `generate-config` if those aren't set up yet.

## Safety rules

- Back up before writing; keep the backup paths.
- Validate `config.jsonc` JSON before reloading waybar (a broken bar just disappears).
- Reference the theme colors file; never hardcode hex here.
- Don't install packages or fonts — suggest them.

## Resources

- **`references/components.md`** — waybar/wofi/rofi/mako/dunst configs, modules, reloads, fonts.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/apply-theme.sh`** — reload running apps.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh`** — tool probe.
