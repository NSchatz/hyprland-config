# `_shared/wallpaper-pointer.md` — the current-wallpaper symlink contract

Every wallpaper consumer in the rice references a single stable pointer:

```
~/.config/hypr-rice/current-wallpaper   # symlink to the active image
```

The symlink is maintained by `scripts/set-wallpaper.sh` on **every** successful set —
swww/awww, hyprpaper, swaybg paths included. Re-theme / re-pick changes one symlink, every
consumer follows it. No regeneration of consumer configs is needed for a wallpaper change.

## Consumers (must reference the symlink, not a literal path)

| Consumer | File | Reference |
|---|---|---|
| Autostart bootstrap (swww/awww) | `~/.config/hypr/autostart.conf` | `swww img ~/.config/hypr-rice/current-wallpaper` in the wallpaper-daemon block. See `components/autostart/template.md`. |
| hyprpaper | `~/.config/hypr/hyprpaper.conf` | `path = ~/.config/hypr-rice/current-wallpaper` in the `wallpaper { … }` block. See `components/companion-daemons/template.md`. |
| hyprlock | `~/.config/hypr/hyprlock.conf` | `path = ~/.config/hypr-rice/current-wallpaper` in the `background { … }` block (the `background = wallpaper` branch). See `components/lock-screen/template.md`. |
| Theme-restore hook | `~/.config/hypr/scripts/restore-theme.sh` (or engine equivalent) | `wp="$HOME/.config/hypr-rice/current-wallpaper"` — read once, no need to grep `palette.conf`. |
| Widgets (eww, quickshell, etc.) | per-shell | If a widget paints a thumbnail or blurs the wallpaper, it reads the symlink. |

## What the symlink is NOT

- It is **not** the source of truth for `palette.conf` — `palette.conf:wallpaper=<literal-path>`
  still stores the real path the user picked (so `rice save <name>` and `rice theme <name>` carry
  the wallpaper choice across profiles). The symlink is the *current* pointer, not the *recorded*
  choice.
- It is **not** owned by `theming/`'s post-set restore script. The restore script reads it; it
  does not write it. The single writer is `scripts/set-wallpaper.sh`.

## Generation-time invariant

The rice render-templates step (and the validator) **must not** emit a literal `.png` / `.jpg`
path under any wallpaper directory into `autostart.conf`, `hyprlock.conf`, or `hyprpaper.conf`.
A linter in `agents/hyprland-config-validator.md` greps for `(autostart|hyprpaper|hyprlock).conf`
files containing literal image extensions under common wallpaper roots and ERRORs if it finds
one — the only acceptable wallpaper reference in those files is the symlink.

## Why a symlink (not a small text file with the path)

- Symlinks resolve transparently in every config syntax (Hyprland INI, hyprlock INI, hyprpaper
  `wallpaper { path = … }`). A text file would need a sourcing helper in every consumer.
- `ln -sfn` is atomic on POSIX (the rename of the new symlink replaces the old one in a single
  syscall) so a consumer mid-read never sees a torn pointer.
- The previous design captured a literal path at generation, which left the lock screen and
  hyprpaper stuck on the generation-time image after every reboot — even when `set-wallpaper.sh`
  had successfully changed the live wallpaper. The symlink decouples "what's painted right now"
  from "what was selected at the last full generation."

## Cross-references

- The script that maintains the link → `scripts/set-wallpaper.sh`.
- The autostart bootstrap → `components/autostart/template.md` (`swww_any` row).
- The lock-screen consumer → `components/lock-screen/template.md` (`background = wallpaper` branch).
- The hyprpaper consumer → `components/companion-daemons/template.md` (`hyprpaper.conf` section).
- The persistence story (`palette.conf:wallpaper=`) → `theming/wallpaper.md`.
- Validator assertion → `agents/hyprland-config-validator.md`.
