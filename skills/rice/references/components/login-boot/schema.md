# login-boot — answers.json slice

Keys this component owns under the top-level `login_boot` key.

```json
{
  "login_boot": {
    "greeter":    "greetd-tuigreet | greetd-regreet | sddm | none",
    "plymouth":   false,
    "grub_theme": false
  }
}
```

All three keys are always present in `answers.json` once the interview is done — the gate "no"
path records each as off (`greeter = "none"`, `plymouth = false`, `grub_theme = false`) rather
than omitting them. Downstream code reads `.login_boot.greeter` with `jq` and branches on the
string; it never has to check for key presence.

## Types

| Key | Type | Values | Meaning |
|---|---|---|---|
| `login_boot.greeter` | string (enum) | `greetd-tuigreet`, `greetd-regreet`, `sddm`, `none` | Which greeter to theme. `none` means "don't touch the greeter" (the user said no at the gate, or said yes-to-19 but no-to-greeter at 19a-i). |
| `login_boot.plymouth` | boolean | `true`, `false` | Whether to generate + recommend a palette-matched Plymouth theme. `false` means "leave the existing splash (or no splash) alone." |
| `login_boot.grub_theme` | boolean | `true`, `false` | Whether to generate + recommend a palette-matched GRUB theme. `false` on a non-GRUB system (systemd-boot, rEFInd) — detection records this automatically when `/boot/grub` is absent. |

### Greeter enum values

- `greetd-tuigreet` — greetd as the DM with the **tuigreet** CLI greeter. Files generated:
  `/etc/greetd/config.toml`. Theming via flags on the `command =` line.
- `greetd-regreet` — greetd as the DM with the **ReGreet** GTK greeter (in `cage`). Files
  generated: `/etc/greetd/config.toml`, `/etc/greetd/regreet.toml`, and the GTK 3 settings file
  the greeter user reads. Theming via the matching GTK theme + background image.
- `sddm` — SDDM as the DM with a `theme.conf`-editable theme (`sddm-astronaut`, `sugar-candy`,
  or `catppuccin-sddm`). Files generated: `/etc/sddm.conf.d/10-rice.conf` setting `Current=` to
  the chosen theme, plus a patched `theme.conf` under the theme dir.
- `none` — don't touch the greeter. The other two booleans may still be `true` (the user wanted
  Plymouth or GRUB without changing the DM).

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`login-boot` topic) | Generates the staged files under `<staging>/_login/` per the picked greeter / Plymouth / GRUB. Reads `palette.conf` at the same time for the color values. |
| `hyprland-package-installer` | Reads `login_boot.greeter` / `login_boot.plymouth` / `login_boot.grub_theme` and adds the corresponding packages to the **commented sudo block** in `install.sh` (never the main `PKGS` list — see `packages.md`). |
| Rice skill (Mode A wrap-up) | Reads all three keys and emits the "run these sudo commands" report when any of them is non-`none`/`true`. |

## Validation

- `login_boot.greeter` is required. Must be one of the four enum values. The writer fails closed
  if it sees anything else (typo, hand-edit gone wrong).
- `login_boot.plymouth` is required, boolean.
- `login_boot.grub_theme` is required, boolean.
- Cross-key constraint: when **all three** are `none`/`false`/`false` the writer emits nothing
  under `<staging>/_login/` and the rice skill omits the sudo-commands report. This is the
  default state after the gate "no" path; it is also reachable by saying yes at the gate and
  then declining all three sub-questions (rare but valid).
- No constraint links `greeter` to `plymouth`/`grub_theme`. The three are independent: a user
  can theme just GRUB, just Plymouth, just the greeter, or any combination.

## Cross-references

- Sub-question prose + record paths → `interview.md`
- Generation recipes the writer follows → `template.md`
- Why these are root-side and never auto-applied → `gotchas.md` → "Root-side, never sudo'd by
  Claude"
- Palette keys consumed by the generated files → `_shared/palette-schema.md`
