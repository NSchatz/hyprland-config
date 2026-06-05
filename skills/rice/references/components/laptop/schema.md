# laptop — answers.json slice

Keys this component owns under the top-level `laptop` key.

```json
{
  "laptop": {
    "enabled":      true,
    "lid_action":   "suspend | lock | clamshell | nothing | null",
    "power_tool":   "ppd | tlp | auto-cpufreq | none | null",
    "charge_limit": 80
  }
}
```

## Types

| Key | Type | Required | Notes |
|---|---|---|---|
| `laptop.enabled` | boolean | yes | The gate (21a). `false` means the rest of the component is skipped; downstream readers branch on this key first. |
| `laptop.lid_action` | string \| null | yes | One of `"suspend"`, `"lock"`, `"clamshell"`, `"nothing"`. **`null` when `enabled == false`** (so downstream `jq` does not fault on missing key). |
| `laptop.power_tool` | string \| null | yes | One of `"ppd"`, `"tlp"`, `"auto-cpufreq"`, `"none"`. **`null` when `enabled == false`**. The three non-`none` values are mutually exclusive — only one daemon may be enabled (see `gotchas.md`). |
| `laptop.charge_limit` | integer \| null | yes | Percentage in `[50, 100]` (only `80` and `null` are surfaced by the interview; manual edits may use other values). **`null` when no limit** OR when `enabled == false`. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`keybinds` / this folder) | Emits the `bindl = , switch:on:Lid Switch, …` line into `binds.conf` based on `lid_action`. Skipped entirely when `enabled == false` or `lid_action == "nothing"`. |
| `hyprland-component-writer` (this folder, install-output channel) | Prints the `/etc/systemd/logind.conf` `HandleLidSwitch*=ignore` instructions, the `systemctl enable --now <daemon>` line, and the charge-limit `.service` + `sudo install` command to the user. **Does not write to `/etc` or run `sudo`.** |
| `hyprland-component-writer` (`waybar`) | Reads `power_tool` to decide whether the `power-profiles-daemon` waybar module is enabled (only when `power_tool == "ppd"`). |
| `hyprland-package-installer` | Reads `power_tool` against `packages.md` and adds **one** of `power-profiles-daemon` / `tlp` / `auto-cpufreq` to the install batch (skipped on `"none"` or `null`). |
| `hyprland-config-validator` | (a) Errors if `enabled == true` and any sub-key is `null`. (b) Errors if `power_tool` is non-`none` and the waybar module set names a *different* power tool. (c) Errors if `lid_action == "clamshell"` and `monitors.list` shows only one monitor (no externals to fall through to). |

## Validation rules

1. `enabled` is required and boolean.
2. If `enabled == false`: `lid_action`, `power_tool`, `charge_limit` **must** all be `null`. (The
   `record-answer.sh` calls in `interview.md` enforce this; the validator double-checks.)
3. If `enabled == true`: `lid_action` and `power_tool` are required strings from the enumerations
   above. `charge_limit` is either `null` or an integer in `[50, 100]`.
4. Detection facts (`IS_LAPTOP`, `POWER_TOOL`) **do not** appear in `answers.json` — they only
   shape interview defaults. Re-running `rice apply` on a different machine reads the recorded
   answers, not the new hardware.

## Cross-references

- Interview that records these keys → `interview.md`
- Where each value lands → `template.md`
- Why `power_tool` is single-valued (mutual exclusivity) → `gotchas.md`
- Package map keyed off `power_tool` → `packages.md`
