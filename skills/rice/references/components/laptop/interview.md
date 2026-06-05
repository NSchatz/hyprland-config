# laptop — interview

Group 21. Lid handling, power-profile daemon, and an optional battery charge limit.

This is an **opt-in component with a gate**. Per `_interview-protocol.md` → "Strict — ask every
question" / "Opt-in gate questions": **the gate (21a) is always asked**, never silently defaulted
from the chassis detector. `IS_LAPTOP=1` only puts **Yes** first in the list so the user can
confirm with one press; it does **not** answer the gate. A short interview is a failed interview.

Touchpad behavior was already covered in group 2 (`input`); brightness/volume/media keys are
already in the default `binds.conf` block (`keybinds`); per-monitor dock/undock profiles are part
of group 1 (`monitors`). None of those are re-asked here.

## AskUserQuestion shape

Group 21 splits into **up to 2 calls** (≤ 4 sub-questions per call):

- **Call 1** (always asked): 21a — the opt-in gate. On `no`, stop here.
- **Call 2** (only if 21a == `yes`): 21b (lid action), 21c (power tool), 21d (charge limit). Three
  sub-questions, one call.

On a re-theme (Mode B), this whole component is **skipped** — laptop hardware policy is not a
theming concern.

## Sub-questions

### 21a. Set up laptop options?  *(always asked — opt-in gate)*

The chassis detector's result reorders the option list — it does **not** answer the gate:

- If `IS_LAPTOP=1` (detected from `/sys/class/dmi/id/chassis_type ∈ {8,9,10,14}` or
  `/proc/acpi/button/lid/*` present) → list **Yes** first.
- If `IS_LAPTOP=0` (detected as desktop / not laptop / unknown) → list **No** first.

Options:

- **Yes — set up lid handling, power profile, and charge limit.**
- **No — skip the laptop component.** Records `laptop.enabled = false`. Stops the interview at 21a.

On `no`, also record `lid_action`, `power_tool`, `charge_limit` as `null` so downstream readers
branch cleanly on `enabled == false || lid_action == null`.

### 21b. Lid close action  *(only when 21a == yes)*

Single-select. Each option lands as a `bindl = , switch:on:Lid Switch, …` line in `binds.conf`
(see `template.md`).

| Option | Default | What the bind does |
|---|---|---|
| **Suspend** | yes | `bindl = , switch:on:Lid Switch, exec, systemctl suspend` |
| **Lock (hyprlock)** | | `bindl = , switch:on:Lid Switch, exec, loginctl lock-session` (hyprlock listens via the lock-screen component's `hypridle` config). |
| **Clamshell — blank the internal panel, keep externals** | | `bindl = , switch:on:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"` + a `bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, preferred, auto, 1"` to restore on open. Good when docked. |
| **Nothing** | | No bind emitted. The desktop ignores the lid; logind may still act unless `HandleLidSwitch*=ignore` is set. |

The actual internal-panel name (`eDP-1` above) is **detected at generate-time** from
`hyprctl monitors -j` — the template should not hardcode it. If detection fails, fall back to a
commented placeholder line and add a TODO in the install output.

**Always warn about double-handling** (see `gotchas.md` § a): if systemd-logind is also configured
to handle the lid, the user will get *two* suspend actions. The fix is `HandleLidSwitch*=ignore`
in `/etc/systemd/logind.conf`, documented as a `sudo` command — never run by the agent.

### 21c. Power-profile tool  *(only when 21a == yes)*

Single-select. Pre-filled from `POWER_TOOL=<…>` if detected by `scripts/detect-theme-tools.sh`
(list the matching pick first); the user can override. **The three are mutually exclusive — never
enable two together.** The chosen tool's package lands in the install batch; enabling its daemon
is root-side (the install step prints the `systemctl enable --now` command).

| Option | Default | Notes |
|---|---|---|
| **power-profiles-daemon (PPD)** | yes | D-Bus `net.hadess.PowerProfiles`. **Pairs with the waybar `power-profiles-daemon` module** — the waybar template enables that module only when `laptop.power_tool == "ppd"`. Repo package. |
| **TLP** | | Heavier policy engine (per-device tunables, charge thresholds via `STOP_CHARGE_THRESH`). If picked, 21d's charge-limit can be routed through TLP instead of a one-shot. Repo package. |
| **auto-cpufreq** | | Adaptive CPU governor on top of cpufreq. AUR package. |
| **None** | | No power-profile management. Records `power_tool = "none"`. |

### 21d. Battery charge limit?  *(only when 21a == yes)*

Single-select. Root-side regardless: the kernel attribute lives at
`/sys/class/power_supply/BAT*/charge_control_end_threshold`, owned by root.

| Option | Default | Recorded value |
|---|---|---|
| **No** | yes | `charge_limit = null` |
| **Yes, 80% (longevity)** | | `charge_limit = 80` |

The generator emits a systemd one-shot unit (`battery-charge-limit.service`) to the staging dir
**and** the exact `sudo install … && sudo systemctl enable --now battery-charge-limit.service`
command in the install output. **Never run by the agent.** When `power_tool == "tlp"`, the
preferred path is `STOP_CHARGE_THRESH=80` in `/etc/tlp.conf` instead — also documented, not run.

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh` (see `_interview-protocol.md`
→ "Recording answers"):

```bash
# 21a (always)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.enabled --json true
# or: --json false

# 21b–21d (only if laptop.enabled == true)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.lid_action suspend
# or: lock | clamshell | nothing

bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.power_tool ppd
# or: tlp | auto-cpufreq | none

bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.charge_limit --json 80
# or: --json null
```

When 21a is `no`, record the gate and **skip 21b–21d**, writing nulls so downstream readers branch
cleanly on `laptop.enabled == false`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.enabled --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.lid_action --json null
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.power_tool --json null
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" laptop.charge_limit --json null
```

## Cross-references

- Strict-ask discipline + opt-in-gate rule → `../../_interview-protocol.md`
- Schema slice + types → `schema.md`
- Emitted bind line + root-side commands → `template.md`
- Double-handling warning + power-tool exclusivity → `gotchas.md`
- Packages → `packages.md`
- Touchpad (NOT here) → `../input/interview.md`
- Brightness / volume binds (NOT here) → `../keybinds/interview.md`
- Per-monitor dock/undock profiles (NOT here) → `../monitors/interview.md`
- `bindl` flag semantics + `switch:on:` syntax → `../../_shared/dispatchers.md`
