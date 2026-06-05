# login-boot

The login screen (display manager / greeter), the Plymouth boot splash, and the GRUB theme.
**Opt-in by default; root-side end-to-end.** Most rice generators skip this entirely — HyDE and
Omarchy theme it because a real full-system rice ends at the BIOS handoff, not the desktop.

Three crucial properties of this component:

1. **It's opt-in.** The user is asked a gate question first. Off by default — the per-user desktop
   already works without theming these surfaces.
2. **It's root-side.** Every file this component writes lands under `/etc` or `/usr` or `/boot`.
   That means **sudo**, which means **the user runs the commands, not Claude**.
3. **It's coarse.** The login chrome does **not** follow `rice apply`. A palette change
   re-renders per-user configs immediately, but the greeter / Plymouth / GRUB only re-theme
   when the user re-runs the `sudo` commands this component prints. Treat it as a slow path.

The plugin's job here is to **generate the files into a staging directory** and **emit a
"run these commands" report**. Claude never `sudo`s and never touches `/etc`, `/usr`, or `/boot`
directly — those edits belong to the user with their own audit trail.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Group 19's gate + multi-select call (greeter / Plymouth / GRUB). Detection of the active DM, skip-silently rule. |
| `schema.md` | The `login_boot.{greeter, plymouth, grub_theme}` keys this component owns. |
| `template.md` | Generation recipes per tool: greetd+tuigreet, greetd+ReGreet, SDDM, Plymouth, GRUB. Staging layout for `<staging>/_login/`. |
| `gotchas.md` | Root-side discipline, coarse re-theming, SDDM-is-Qt, GDM is not theme-friendly, DM detection, skip-on-per-user, `sddm.conf.d/` ordering, Astronaut sub-theme filenames, virtual-keyboard double-set, greetd `restart=false` for autologin. |
| `packages.md` | greetd / tuigreet / ReGreet / SDDM / Plymouth. **Commented `sudo` block** in `install.sh`, never in the main `PKGS` list. |
| `styling.md` | Corpus survey of how the top community Hyprland rices ship login-boot (only 6 of 19 do). Three archetypes: bundled tarballs (HyDE), scripted theme-repo clone (ML4W), ship-your-own-greeter (DMS/HyprYou/fufexan). Battle-tested techniques with citations. |

## Where this component lands

Nothing this component writes goes under `~/.config`. Generated artifacts stage to
`<staging>/_login/`, and the rice skill emits a follow-up report ("run these sudo commands") at
the end of Mode A. Final destinations on disk:

| Tool | Generated file(s) | Final path | Install command |
|---|---|---|---|
| greetd + tuigreet | `_login/greetd/config.toml` | `/etc/greetd/config.toml` | `sudo install -m 644 …` (or `sudoedit`) |
| greetd + ReGreet | `_login/greetd/config.toml`, `_login/greetd/regreet.toml` | `/etc/greetd/{config.toml,regreet.toml}` (ReGreet applies GTK theme via its own `[GTK]` keys — no `/var/lib/greetd/.config/gtk-3.0/settings.ini` is written) | `sudo install …` per file |
| SDDM | `_login/sddm.conf.d/10-rice.conf`, theme dir | `/etc/sddm.conf.d/10-rice.conf`, `/usr/share/sddm/themes/<name>/theme.conf` | `sudo install …` |
| Plymouth | `_login/plymouth/<theme>/` | `/usr/share/plymouth/themes/<theme>/`, set via `plymouth-set-default-theme -R <theme>` | `sudo cp -r …` + `sudo plymouth-set-default-theme -R <theme>` |
| GRUB | `_login/grub/themes/<theme>/`, `_login/grub/default-grub.patch` | `/boot/grub/themes/<theme>/`, `GRUB_THEME=` in `/etc/default/grub`, then `grub-mkconfig -o /boot/grub/grub.cfg` | `sudo cp -r …` + `sudoedit /etc/default/grub` + `sudo grub-mkconfig …` |

None of these are auto-installed. The skill writes them to staging, prints the commands, and
stops.

## Related components

- [`theming/palettes.md`](../../theming/palettes.md) — the same palette that feeds every per-user
  colors file also drives the greeter colors, Plymouth background, and GRUB theme background. The
  login chrome reads `palette.conf` at generate-time, not at runtime — so a later re-theme on the
  per-user side does **not** propagate here until the user re-runs the sudo commands.
- [`look-feel`](../look-feel/) — the GTK theme the user picks there is what ReGreet inherits when
  ReGreet is the greeter (its GTK settings file points at the same theme).
- [`companion-daemons`](../companion-daemons/) (`hyprlock`) — `hyprlock` is the *session* lock
  screen, not the *login* greeter. They look similar; don't conflate them. The lock screen runs
  inside a user session; the greeter runs before any user session exists.
- `_shared/palette-schema.md` — the canonical color keys the greeter / Plymouth / GRUB templates
  pull from.
