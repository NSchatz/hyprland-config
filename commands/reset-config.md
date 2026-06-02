---
description: Reset ~/.config/hypr to a minimal bare-bones Hyprland config (full backup + live-test + auto-rollback)
argument-hint: "[-y to skip the confirmation]"
allowed-tools: Bash, AskUserQuestion
---

# Reset Hyprland config to bare bones

Wipe the user's `~/.config/hypr` down to a single minimal, working `hyprland.conf` — backing up
the **entire** existing config first and live-testing the result with automatic rollback. Use this
to start over from a clean slate (e.g. after an experiment went sideways) without hand-deleting files.

This is **destructive but fully reversible**: a timestamped backup of the whole directory is taken
before anything is removed, and the script rolls back to it if the bare config fails to load.

## What gets reset

- **Wiped:** everything in `~/.config/hypr` — the modular `*.conf` files, plus companion configs
  read from this dir (`hyprlock.conf`, `hypridle.conf`, `hyprpaper.conf`) and any subdirs.
- **Left intact:** configs that live elsewhere (`~/.config/waybar`, `~/.config/rofi`,
  `~/.config/dunst`, etc.) — they are not under `~/.config/hypr`. Their daemons just won't be
  autostarted anymore, since the bare config has no `exec-once` lines.
- **Result:** the directory contains only a minimal `hyprland.conf` (monitor auto-detect, basic
  input, a small set of essential keybinds — terminal, close, exit, launcher, focus, workspaces 1–5,
  mouse move/resize). Enough to have a usable session and build back up from.

## Steps

1. **Confirm intent (unless forced).** If `$ARGUMENTS` contains `-y`, `--yes`, `yes`, or `force`,
   skip this. Otherwise, tell the user this wipes `~/.config/hypr` to a bare `hyprland.conf` (a full
   timestamped backup is taken and it auto-rolls-back on error) and confirm with `AskUserQuestion`
   before proceeding. Do not run the script until confirmed.

2. **Detect the user's terminal and launcher** so the bare config's keybinds point at tools they
   actually have. Pick the first installed of each (fallbacks: `kitty`, `wofi --show drun`):

   ```bash
   term=kitty
   for t in kitty alacritty foot wezterm ghostty; do command -v "$t" >/dev/null 2>&1 && { term="$t"; break; }; done
   menu="wofi --show drun"
   if   command -v wofi   >/dev/null 2>&1; then menu="wofi --show drun"
   elif command -v rofi   >/dev/null 2>&1; then menu="rofi -show drun"
   elif command -v fuzzel >/dev/null 2>&1; then menu="fuzzel"
   elif command -v tofi   >/dev/null 2>&1; then menu="tofi-drun"
   fi
   echo "BARE_TERMINAL=$term"; echo "BARE_MENU=$menu"
   ```

3. **Run the reset**, passing the detected tools (respect a `HYPR_DIR` override if the user set one):

   ```bash
   BARE_TERMINAL="$term" BARE_MENU="$menu" \
     bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/reset-config.sh"
   ```

4. **Relay the outcome** from the final `RESET=` line and the `BACKUP=` path:
   - `RESET=ok` — wiped, bare config written and reloaded clean. The settings are live, but note
     **`hyprctl reload` does not run `exec-once`** — any bar/wallpaper/daemon from the old config is
     still running this session and will simply be absent on next login (the bare config autostarts
     nothing). That is expected for a bare reset.
   - `RESET=installed-untested` — no running Hyprland to test against; bare config written, will
     apply on next login.
   - `RESET=rolled-back` / `errors-no-backup` — surface the printed errors (this should not happen
     for a minimal config; investigate before retrying).

5. **Tell the user how to restore and how to rebuild:**
   - Restore: `rm -rf ~/.config/hypr && cp -a <BACKUP> ~/.config/hypr && hyprctl reload`
   - Rebuild from scratch: `/hyprland-config:rice` (full interview), or extend the bare
     config piecemeal with `/hyprland-config:edit-config`.

## Notes

- Never skip the backup — the script always takes one before wiping; relay its path prominently.
- The reset only touches `~/.config/hypr` (or `$HYPR_DIR`). It does not uninstall packages or remove
  shell/terminal/theme configs elsewhere.
