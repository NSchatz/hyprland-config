# Detected binary names (cross-cutting registry)

Rolling Arch (and the AUR) gives the rice no stable promise that a logical tool maps to a fixed
binary name. The canonical example: upstream `swww` is archived, the maintained fork is `awww`
(declares `provides=swww`), and its binaries are `awww` / `awww-daemon` — NOT `swww` / `swww-daemon`.
A writer that hard-codes `swww-daemon` ships a config that emits a daemon that doesn't exist.

**Every writer that emits a literal binary name** consumes this registry — the writer takes the
detected binary from `detect-version.sh`'s key/value dump and substitutes it into the template.
When detection happens *before* the install (the normal Mode A flow), the binary is not yet on
disk; in that case writers emit a **binary-agnostic launcher** that picks whichever variant
exists at first run.

## Binary registry

| Logical name | Detection key (from `scripts/detect-version.sh`) | Possible binaries | Owner writer(s) | Agnostic launcher (used pre-install) |
|---|---|---|---|---|
| wallpaper daemon | `SWWW_DAEMON_BIN` | `swww-daemon` (upstream, archived) / `awww-daemon` (fork) | autostart, theming engine | `sh -c 'command -v swww-daemon >/dev/null && exec swww-daemon \|\| exec awww-daemon'` |
| wallpaper client | `SWWW_CLIENT_BIN` | `swww` / `awww` | theming engine (restore-theme.sh), set-wallpaper.sh | `sh -c 'command -v swww >/dev/null && exec swww "$@" \|\| exec awww "$@"' _` |
| polkit (Hyprland) | (probed by `command -v` on user choice) | `hyprpolkitagent` (newer) — invoked as `systemctl --user start hyprpolkitagent` | autostart | (no fallback — user picked it) |
| polkit (GNOME) | (path probe) | `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1` | autostart | (no fallback) |
| polkit (KDE) | (path probe) | `/usr/lib/polkit-kde-authentication-agent-1` | autostart | (no fallback) |
| screen recorder (CLI/SW) | `HAVE_wf_recorder` | `wf-recorder` | utilities scripts | — |
| screen recorder (HW) | `HAVE_wl_screenrec` | `wl-screenrec` | utilities scripts (opt-in) | — |
| screenshot | `HAVE_grimblast` / `HAVE_hyprshot` / `HAVE_grim` | `grimblast` / `hyprshot` / `grim`+`slurp` | utilities scripts | — |
| AUR helper | (`command -v paru` / `yay`) | `paru` / `yay` | installer agent | first paru, then yay, else bootstrap |

## Rules for writers

1. **No writer may emit a literal `swww-daemon` / `swww img …` / `awww-daemon` / `awww img …`
   string** anywhere in a generated config except through the registry above. The validator agent
   greps emitted files for these literals and fails the build if they appear outside the
   contract.
2. **Every writer that uses `SWWW_DAEMON_BIN` from detection must fall back to the agnostic
   launcher** when detection reports `MISSING_swww=1`. Detection runs before the install batch,
   so a clean Arch box has neither variant present at generate-time — the rendered autostart line
   needs to resolve at runtime.
3. **The AUR-helper bootstrap probes that the helper actually runs** (`paru --version`), not just
   that the binary exists — `paru-bin` from the AUR routinely installs cleanly but fails at
   runtime when libalpm's ABI moves under it.

## Cross-references

- `scripts/detect-version.sh` — the detection authoritative source; every `HAVE_*` /
  `SWWW_*_BIN` line is produced there.
- `components/autostart/template.md` — the autostart writer reads `SWWW_DAEMON_BIN` and falls
  back to the agnostic launcher when missing.
- `theming/engine.md` → "Theme-restore on login" — the generated `restore-theme.sh` uses
  `SWWW_CLIENT_BIN` for the `img` call (agnostic launcher when missing).
- `agents/hyprland-package-installer.md` — uses `paru --version` to probe the helper before
  trusting it, builds `paru` from source (not `paru-bin`) when bootstrapping.
- `agents/hyprland-config-validator.md` — lint #1 (no hard-coded `swww-daemon`/`awww-daemon`
  outside the registry).
