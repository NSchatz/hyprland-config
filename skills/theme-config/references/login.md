# Login / Display Manager Theming

The login screen is part of a full rice. Unlike the per-user configs, these live under `/etc` and
`/usr`, so changes need **root** — the plugin provides the content and the exact `sudo` commands,
but the user runs them (Claude does not sudo). Detect the active DM with
`systemctl is-enabled greetd sddm gdm 2>/dev/null` or check `~/.config`/process list.

## greetd (this user's DM)

greetd is a minimal login daemon that launches a *greeter*. Config: `/etc/greetd/config.toml`.
Common greeters and how they theme:

- **tuigreet** (CLI, in-terminal) — minimal theming via flags in the `command` line:
  ```toml
  [default_session]
  command = "tuigreet --time --remember --theme 'border=accent;text=white;prompt=accent;greet=white;action=blue;button=accent'"
  ```
  Colors are named terminal colors, not hex. Edit with `sudo`.
- **ReGreet** (GTK, graphical) — themed by the **GTK theme/icon/cursor/font** it runs under, plus
  its own `/etc/greetd/regreet.toml` (background image, etc.). Point its GTK settings at the same
  theme you use (`/etc/greetd/.config/gtk-3.0/settings.ini` or the greeter user's config), and set
  a background that matches the wallpaper. Provide the file; user installs it with `sudo`.
- **gtkgreet** — GTK greeter styled via a CSS file referenced in its command
  (`gtkgreet -s /etc/greetd/gtkgreet.css`).

To match the desktop palette, generate the greeter's colors from `~/.config/hypr-rice/palette.conf`
and hand the user the `sudo cp`/`sudoedit` commands to place them under `/etc/greetd/`.

## SDDM (installed on this system)

Config: `/etc/sddm.conf` or `/etc/sddm.conf.d/*.conf`. Select a theme:
```ini
[Theme]
Current=<theme-name>
```
Themes live in `/usr/share/sddm/themes/`. Many (e.g. `sddm-astronaut`, `sugar-candy`,
`catppuccin-sddm`) expose colors/background in a `theme.conf` you can edit to match the palette.
Install a theme to `/usr/share/sddm/themes/` and set `Current=` — both need `sudo`. Preview a
theme without logging out: `sddm-greeter --test-mode --theme /usr/share/sddm/themes/<name>`.

## Boot theming (optional, deeper)

- **Plymouth** (boot splash): themes in `/usr/share/plymouth/themes/`; set with
  `plymouth-set-default-theme -R <theme>` (root).
- **GRUB**: a theme in `/boot/grub/themes/` referenced by `GRUB_THEME=` in `/etc/default/grub`,
  then `grub-mkconfig -o /boot/grub/grub.cfg` (root).

These are coarse (palette-matched backgrounds, not live-generated) and entirely root-side — offer
them as suggestions, generate the files, and provide the `sudo` commands; never run them silently.

## Safety

- Editing `/etc`/`/usr` needs `sudo`/`sudoedit` — present the commands, let the user run them.
- A broken greeter can lock the user out of the GUI. Always back up the file first
  (`sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak`) and tell the user how to reach a
  TTY (Ctrl+Alt+F2) to fix it.
