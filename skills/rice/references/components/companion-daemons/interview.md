# companion-daemons — interview

Group 16 is **generate-only** — every companion config is determined by earlier-group picks
(`lock_screen.enabled`, `autostart_env.wallpaper_tool == "hyprpaper"`). The interview pass is
therefore a single confirmation call that wraps the hypridle idle-ladder choice.

Two sub-questions, one `AskUserQuestion` call (≤ 4 sub-qs cap respected).

## Sub-questions

**16a. Generate companion configs?** → Confirm that the hyprlock / hypridle / hyprpaper companion
configs should be generated alongside `hyprland.conf`. Defaults:

- `companion_configs.hyprlock` ← `lock_screen.enabled` (yes if the user picked a lock screen in
  group 10).
- `companion_configs.hyprpaper` ← `autostart_env.wallpaper_tool == "hyprpaper"` (yes if the user
  picked hyprpaper in group 15 over `swww` / `none`).

Both default lines are **starting positions only** — the question still gets asked. If the user
already has hand-written companion configs, this is their chance to say "skip — keep mine."

**16b. hypridle idle ladder** → which timeout tier maps to the four `listener` blocks. Always
asked; never silently defaulted (even on desktops where Aggressive is implausible).

| Option | dim | lock | dpms-off | suspend |
|---|---|---|---|---|
| **Balanced** *(default)* | 2m 30s | 5m | 6m | 30m |
| **Aggressive** *(laptop battery)* | 1m | 2m | 3m | 10m |
| **Relaxed** | 5m | 15m | 20m | — *(no suspend)* |
| **Never** | — | — | — | — *(no listeners; hypridle still runs for `before_sleep_cmd`)* |

The four columns map 1:1 onto the four `listener {}` blocks in `template.md`. **Desktops**
typically pick Balanced or Relaxed *and* drop the suspend tier — see `gotchas.md` for the rule.

## Record paths

After the user answers, record with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" companion_configs.hyprlock --json true
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" companion_configs.hypridle_ladder balanced
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" companion_configs.hyprpaper --json true
```

If the user opts out of either companion (already have a hand-written one, or picked `swww` /
`none` for wallpaper), record `false`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" companion_configs.hyprpaper --json false
```

If the user picked **Never** for the idle ladder, downstream still records the string:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" companion_configs.hypridle_ladder never
```

## Cross-references

- Schema → `schema.md`
- The `hypridle.conf` + `hyprpaper.conf` templates (with the ladder values substituted) →
  `template.md`
- The `hyprlock.conf` template → [`../lock-screen/template.md`](../lock-screen/template.md)
- The `exec-once = hypridle` / `exec-once = hyprpaper` lines → [`../autostart/`](../autostart/)
- Gotchas (config-language differences, `pidof` guard, `before_sleep_cmd`, dpms ordering,
  desktop-no-suspend, hyprpaper `ipc = on`) → `gotchas.md`
- Packages → `packages.md`
