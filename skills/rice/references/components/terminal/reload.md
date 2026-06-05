# terminal — reload

Terminal config changes apply to **newly-launched terminal windows only**. There is no signal
broadcast that reliably re-renders a running shell session's font/opacity/palette across every
emulator, and rice does **not** try to fake one.

## Reload scope

| Surface | New terminals | Already-open terminals |
|---|---|---|
| Font family / size | applied | unchanged until restart |
| Background opacity | applied | unchanged until restart |
| Padding | applied | unchanged until restart |
| Cursor shape / blink | applied | unchanged until restart |
| 16-color palette | applied | **see below** |

The 16-color palette is the one knob some emulators **can** push to running sessions, but
behaviour varies enough that rice's default flow is "next window picks it up." Per-emulator
specifics:

| Emulator | Live-reload mechanism | rice behaviour |
|---|---|---|
| kitty | `kill -SIGUSR1 $KITTY_PID` reloads `kitty.conf`; or `kitten @ load-config`. Modern kitty also auto-reloads on save (controlled by the `auto_reload_config` option). | rice **does not** send `SIGUSR1` by default. New terminals pick up the new colors. |
| alacritty | `live_config_reload = true` (default) — re-reads on file save. | Live in already-open windows after save. No action required from rice. |
| foot | **No config-reload signal.** `SIGUSR1` switches to `[colors-dark]` and `SIGUSR2` to `[colors-light]` — both swap **between existing color blocks**, not reload the file from disk. For other key changes, restart. | rice does not send any signal. To live-swap themes, ship dual `[colors-dark]` / `[colors-light]` blocks and use `kill -SIGUSR1/2 $(pidof foot)`. |
| wezterm | `automatically_reload_config = true` (default). | Live in already-open windows on save. |
| ghostty | `ctrl+shift+,` in-app reload; otherwise restart. | New windows pick it up. |

The intentional default is **passive**: write the file, do nothing. The user's existing terminals
keep their old colors until they close, the new ones come up with the rice palette. Two reasons:

1. **No risk of broken state.** Sending `SIGUSR1` to kitty while it's mid-prompt or attached to
   `tmux` is safe in practice, but inconsistent across versions — kitty 0.30+ handles it cleanly,
   older builds occasionally corrupt the scrollback. Skipping the signal avoids the failure mode.
2. **Convergence is automatic.** Users close and reopen terminals constantly. Within a session or
   two the new theme is universal — without any extra step from rice and without the chance of
   touching an unrelated process.

If a user **wants** the immediate reload, the manual command is documented per emulator in
`styling.md` ("How colors are set" table). For kitty specifically:

```bash
kill -SIGUSR1 $(pidof kitty)        # blanket reload all kitty instances
# or, in a single kitty window:
#   ctrl+shift+f5
```

## What rice **does** do on `rice apply`

1. Renders the colors file (`~/.config/<emulator>/colors.<ext>` or the `[colors]` block of
   `foot.ini`).
2. Writes the emulator's main config (`kitty.conf` / `alacritty.toml` / `foot.ini` /
   `wezterm.lua` / `ghostty/config`) **only on first generate** — `rice apply` for re-theming
   touches the colors file only (engine guarantee, see `theming/engine.md`).
3. Logs `# terminal: new windows will pick up the new palette` and moves on.

## Failure modes

- **Stale running shell.** Expected — see above. Not an error.
- **Colors file missing.** The main config's `include colors.conf` / `import` / `require` line
  fails the emulator's own parse on next launch (kitty/foot/wezterm complain in stderr;
  alacritty/ghostty silently fall back to defaults). The validator checks the include target
  exists at generate-time.
- **Palette key mismatch.** If a renamed `_shared/colors-contract.md` variable lands without the
  matching template update, the emulator config either errors (alacritty's strict TOML) or
  silently un-themes (kitty drops unknown lines). Caught by `_shared/colors-contract.md` being
  the single source.

## Cross-references

- Engine reload-hook discipline → `theming/engine.md`
- Per-emulator live-reload UX → `styling.md` "How colors are set"
- Other components' reload behaviour → `components/<x>/reload.md`
