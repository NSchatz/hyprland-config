# lock-screen — packages

Required: `hyprlock`. Optional: `fprintd` (only when `lock_screen.fingerprint = true`).

## Map

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| hyprlock (always, when `enabled = true`)             | `hyprlock` | repo (`extra`) | The lock daemon itself. Pulls in `hyprlang`, `hyprutils`, `hyprgraphics`, `cairo`, `libdrm`, `pam`. |
| fingerprint unlock (when `fingerprint = true`)       | `fprintd`  | repo (`extra`) | The PAM-integrated fingerprint daemon. Pulls in `libfprint` (which has the device drivers). |

`hyprlock` lives in Arch `extra` — no AUR fallback needed. It is also Hyprland's own first-party
locker; the version usually tracks Hyprland's release cadence (but the two are independent and
can be updated separately).

## Assembly rule

```bash
if [ "$(jq -r .lock_screen.enabled answers.json)" = "true" ]; then
    pkgs+=("hyprlock")
    if [ "$(jq -r .lock_screen.fingerprint answers.json)" = "true" ]; then
        pkgs+=("fprintd")
    fi
fi
```

The repo column is informational — `install.sh` auto-routes each name at runtime via `pacman -Si`,
so a package moving between `extra` and `community` doesn't break the install.

## Post-install steps the installer agent should NAME in its summary

When `fingerprint = true`, the install is not complete after `pacman -S fprintd`. The user still
has to:

1. Enrol a finger: `fprintd-enroll` (interactive — touches the reader several times).
2. Verify: `fprintd-list "$USER"` should list the enrolled finger.
3. (Optional, for sudo) wire `fprintd` into PAM via `/etc/pam.d/sudo`. **The installer agent must
   NOT edit `/etc/pam.d/*`** — it's a security-sensitive file and the user should opt in
   manually. Mention it in the summary as *"optional next step"*.

**Never run `fprintd-enroll` from the installer agent** — it's interactive, blocks on the reader,
and would silently fail in a non-tty context. The summary should print the command and let the
user run it themselves.

## What's NOT installed by this component

- **`hypridle`** is owned by [`../companion-daemons/`](../companion-daemons/); install logic lives
  there. The two are usually paired but the choice is independent.
- **`hyprpolkitagent`** (for authentication prompts) is owned by [`../env/`](../env/).
- **Wallpaper tool** (`hyprpaper` / `swww`) is owned by [`../env/`](../env/) — the `wallpaper`
  background option in 10b just **reads** the wallpaper path from `answers.json`, it doesn't
  install anything new.

## Cross-references

- Install-script shape → `skills/rice/scripts/` (the rice-init scaffold).
- The fingerprint-enrolment summary line → also referenced in [`gotchas.md`](./gotchas.md).
- Other components' package maps → `components/<x>/packages.md`.
