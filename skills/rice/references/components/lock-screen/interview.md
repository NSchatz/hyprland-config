# lock-screen — interview

Group 10 — five sub-questions, **one `AskUserQuestion` call** (≤ 4 sub-qs cap respected by holding
10e back into a separate paired call when 10a is "Yes"; when 10a is "No", 10b–10e are skipped
entirely and the rest of `lock_screen.*` is recorded as `null`).

Per the [interview protocol](../../_interview-protocol.md): every sub-question gets asked. The
`(default)` marker just reorders the option list — it does **not** authorize skipping.

## Sub-questions

**10a. Enable a lock screen?** → **Yes, hyprlock (default)** · No.

If **No**: record `lock_screen.enabled = false` and skip 10b–10e — record the rest as `null` so
downstream writers (companion-daemons' `lock_cmd`, keybinds' `bind = …, X, exec, hyprlock`) drop
their lock entries. Done.

If **Yes**, continue with 10b–10d in one `AskUserQuestion` call (3 sub-qs), then 10e in a second
call (so the gate question and the styling questions stay in two clean batches):

**10b. Background** → **Blurred screenshot (default)** · The wallpaper · Solid palette color.

**10c. Clock** → **Large time + date (default)** · Time only · None.

**10d. Input pill style** → **Accent-outlined, centered (default)** · Minimal underline · Hidden
until typing. (See `gotchas.md` — even the "minimal underline" pick is implemented as a visible
thin pill, NOT as a 6 px sliver with no outline.)

**10e. Fingerprint unlock?** — offer regardless of detection (per the protocol's strict rule); put
"Yes" first when `IS_LAPTOP=1` from `scripts/detect-version.sh`, otherwise put "No" first. →
**No (default)** · Yes — emits hyprlock's `auth { fingerprint { enabled = true } }` block so an
enrolled finger unlocks alongside the password. Requires `fprintd` + an enrolled finger
(`fprintd-enroll`, root/user-side — name it in the install summary, **never run it**); the lock
falls back to password if no reader is present.

## Record paths

After each `AskUserQuestion`, record immediately with `record-answer.sh`:

```bash
# 10a — always asked
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.enabled --json true

# When disabled, null the rest and stop
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.background  --json null
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.clock       --json null
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.input_pill  --json null
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.fingerprint --json false

# Otherwise — 10b/10c/10d (one call)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.background  blurred-screenshot
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.clock       large
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.input_pill  accent-outlined

# 10e (second call)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" lock_screen.fingerprint --json false
```

Allowed string values mirror `schema.md`:

- `background` ∈ `blurred-screenshot` | `wallpaper` | `solid`
- `clock` ∈ `large` | `time-only` | `none`
- `input_pill` ∈ `accent-outlined` | `underline` | `hidden`
- `fingerprint` is a boolean.

## Cross-references

- Schema → [`schema.md`](./schema.md).
- The generated `hyprlock.conf` → [`template.md`](./template.md).
- The lock bind in `binds.conf` → [`../keybinds/template.md`](../keybinds/template.md).
- The `lock_cmd` in `hypridle.conf` → [`../companion-daemons/`](../companion-daemons/).
- Fingerprint packaging / enrolment note → [`packages.md`](./packages.md), [`gotchas.md`](./gotchas.md).
