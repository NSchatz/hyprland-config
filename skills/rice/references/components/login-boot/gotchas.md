# login-boot — gotchas

## Root-side, never sudo'd by Claude

Every file this component touches lives under `/etc`, `/usr`, or `/boot`. The plugin's contract
is: **generate the files, print the commands, hand off.** Claude does not run `sudo`. The
writer's outputs are staged under `<staging>/_login/` (see `template.md` for the layout) and the
rice skill's wrap-up emits a `README.run-these-as-root.md` with the exact commands.

The user runs them — under their own audit trail, with their own pacman/sudo prompts. A broken
greeter can lock the user out of the GUI; we don't want that landing silently from an agent run.
This matches the user's memory note: **`login-boot` is opt-in and root-side; Claude never sudos.**

Always back up first. The run-these report should begin with:

```
# Back up the existing files BEFORE running anything else:
sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak  2>/dev/null || true
sudo cp /etc/sddm.conf          /etc/sddm.conf.bak           2>/dev/null || true
sudo cp /etc/default/grub       /etc/default/grub.bak        2>/dev/null || true
# If anything breaks, reach a TTY with Ctrl+Alt+F2, restore the .bak, reboot.
```

## Coarse re-themes — the login chrome does not follow `rice apply`

`rice apply` re-renders per-user configs from `palette.conf` in under a second. The login
greeter, Plymouth, and GRUB **do not** follow that loop. They were generated against the palette
that existed at interview time; re-theming the desktop later leaves the greeter / splash / boot
menu on the **old** palette until the user re-runs the sudo commands.

This is deliberate:

- Touching `/etc` / `/usr` / `/boot` on every theme switch would be a sudo storm.
- A Plymouth re-theme triggers an initramfs rebuild (`plymouth-set-default-theme -R` →
  `mkinitcpio -P`) — too expensive for a re-theme.
- A GRUB re-theme runs `grub-mkconfig` and rewrites `/boot/grub/grub.cfg` — too coarse.

If the user re-themes and asks "why does my login screen still look like the old palette?", the
answer is: re-run the login-boot component's sudo commands. The skill prints them again on
demand (`edit-config login-boot` re-emits the report).

## SDDM is Qt — name the runtime deps

SDDM is a Qt application; picking it pulls the whole Qt runtime. The package list under
`packages.md` lists `qt6-base`, `qt6-declarative`, `qt6-svg`, and (for `sddm-astronaut`)
`qt6-virtualkeyboard`, `qt6-multimedia-ffmpeg`. The `catppuccin-sddm` theme adds
`qt5-quickcontrols2`. Don't omit these — the theme silently renders blank when a Qt module is
missing.

`sddm-sugar-candy` (Kangie fork) is **Qt5** and needs `qt5-graphicaleffects` instead. The writer
picks Qt5 vs Qt6 deps based on which SDDM theme it picked.

Preview without logging out:

```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/<name>
```

Tell the user about this in the run-these report — it's the fastest way to validate the theme
before next reboot.

## GDM is not theme-friendly — recommend switching DM

GDM's theming is locked behind gresource hacks (extracting and rebuilding
`/usr/share/gnome-shell/gnome-shell-theme.gresource`). It works, but it's brittle, breaks on
every GDM update, and is not what a rice plugin should hand a user.

If detection says `gdm` is the active DM and the user says yes at 19, the greeter sub-question
in 19a-i lists **greetd** as the recommended switch-target, not GDM theming. The run-these report
includes the DM swap commands:

```
sudo systemctl disable gdm
sudo systemctl enable greetd
```

Note this clearly — switching DM affects auto-login, user-list, and (on GNOME systems) the
GNOME session boot path. Tell the user to reboot to verify before disabling GDM permanently.

## Detect first — `systemctl is-enabled` is the source of truth

The active DM determines what the user actually sees at boot:

```bash
systemctl is-enabled greetd  sddm  gdm  lightdm 2>/dev/null
```

Exactly one of those should return `enabled`. If multiple, the user is in an inconsistent state
and the writer should refuse to emit a greeter file (print a warning to the report instead).
If none, the user is on text-login → greeter recommendations are advisory and the install
commands include `sudo systemctl enable <chosen-dm>`.

Detection feeds the *order* of options at 19a-i (matching DM first), per `_interview-protocol.md`
→ "Detection is for defaults, not filters". It does not gate the question.

## Skip silently if the user only wants per-user

Per `interview.md` → "Skip-silently rule": when the user has told the interviewer (via
`$ARGUMENTS` or an earlier answer) that they only want the per-user desktop, the entire group 19
is skipped — no `AskUserQuestion` call. The three keys are recorded as
`greeter = "none"`, `plymouth = false`, `grub_theme = false`.

This is the **only** silently-defaulted question in the interview. It's allowed because the
user explicitly opted out of root-side changes, and the strict "ask every question" rule yields
to an explicit user instruction. Document the skip in the run summary so the user knows it
happened.

## Plymouth theme dir naming must be unique

`plymouth-set-default-theme` looks up the theme by directory name under
`/usr/share/plymouth/themes/`. The writer uses `hypr-rice-<scheme>` (e.g.
`hypr-rice-catppuccin-mocha`) so the generated theme doesn't collide with a stock theme
(`spinner`, `bgrt`, `details`) and survives `plymouth` package upgrades (which leave
`/usr/share/plymouth/themes/` alone for non-stock entries).

On re-theme to a different scheme, the writer emits a *new* theme dir
(`hypr-rice-tokyo-night`); the old one stays until the user `rm -rf`s it manually. Note this
in the report — accumulation isn't bad, but the user should know.

## GRUB regen is the slowest step — warn the user

`grub-mkconfig -o /boot/grub/grub.cfg` re-scans every installed kernel, OS prober output,
microcode update, and `/etc/grub.d/` snippet. On systems with multiple kernels + Windows dual
boot it takes 10–30 seconds. That's fine, but tell the user so they don't `Ctrl-C` thinking
it hung.

## Cross-references

- The opt-in gate rule + skip-silently rule → `interview.md`
- Schema enum values → `schema.md`
- Recipe details (which files, what content) → `template.md`
- Packages (the **commented** sudo block in `install.sh`) → `packages.md`
- Strict-ask discipline (and the explicit exception this component leans on) →
  `_interview-protocol.md`
