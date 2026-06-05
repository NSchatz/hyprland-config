# Interview protocol

How the rice interview is conducted. Component-specific question banks live in
`components/<name>/interview.md`; this file holds the cross-cutting rules every component follows.

The rice skill (Mode A) walks every component's `interview.md` in order via the
**`hyprland-interviewer`** agent. Mode B (re-theme) walks only `look-feel`, palette/fonts/wallpaper
(`theming/`), and skips the rest.

## The asking discipline

Ask with `AskUserQuestion`, **one component per pass, in order**. The tool accepts **at most 4
questions per call**, so a component with more than four sub-questions **must be split across
consecutive calls** — never drop, merge, or silently skip a sub-question just to fit the cap.
Walk every component and **ask every sub-question**.

### Strict — ask every question. Never silently default.

The `(default)` marker on an option means "put this option first in the list" — it does **not**
authorize skipping the question. The user has explicitly said they don't want the interview
collapsed to a few presses; a short interview is a failed interview. The hard rules:

- **Every sub-question gets an `AskUserQuestion` call.** No exceptions for "obvious" picks.
- **`$ARGUMENTS` and an existing config reorder the option list** (so the matching pick is first
  and the user can confirm with one press); they do not answer the question. Vague hints like
  "no animations" or "make it nice" don't even reorder — they're not option selectors.
- **Opt-in gate questions** (widgets, login-boot, gaming, laptop, accessibility, plugins) are
  **always asked**. Detection (e.g. `IS_LAPTOP=1`) decides which option is listed first in the
  gate, not the gate's answer.
- A from-scratch run produces roughly **28–38 `AskUserQuestion` calls**. Single-digit call counts
  mean the interview was collapsed — go back and ask the rest.

### Detection is for defaults, not filters

Run `scripts/detect-version.sh` + `scripts/detect-theme-tools.sh` first for **factual** context
(Hyprland version, GPU driver, monitor count, chassis, uwsm session, current gsettings), but
**do not** filter or reorder the menu by what's already installed — every user is offered the same
options. Whatever the user picks lands in the install batch (each component's `packages.md` is
walked by the installer agent) and the install step puts it on disk.

`HAVE_<tool>=1`/`MISSING_<tool>=1` flags from detection are used only to annotate the install batch
(`# installed` comments + idempotent `--needed`); they do not reorder, hide, or default-bias the
options.

Use `multiSelect` for the genuinely multi-choice questions (bar modules, autostart, env vars,
utilities, plugins).

## Components walked (in order)

| # | Component | Mode A | Mode B | Splits into |
|---|---|---|---|---|
| 1 | [monitors](components/monitors/interview.md) | ✓ | | 1–2 calls |
| 2 | [input](components/input/interview.md) | ✓ | | 1–2 calls |
| 3 | [keybinds](components/keybinds/interview.md) | ✓ | | 1–2 calls |
| 4 | [default-apps](components/default-apps/interview.md) | ✓ | | 1 call |
| 5 | [terminal](components/terminal/interview.md) | ✓ | | 1–2 calls |
| 6 | [waybar](components/waybar/interview.md) | ✓ | | 4 calls |
| 7 | [widgets](components/widgets/interview.md) | ✓ | | 0–2 calls (opt-in gate) |
| 8 | [launcher](components/launcher/interview.md) | ✓ | | 1–2 calls |
| 9 | [notifications](components/notifications/interview.md) | ✓ | | 1 call |
| 10 | [lock-screen](components/lock-screen/interview.md) | ✓ | | 1 call |
| 11 | [look-feel](components/look-feel/interview.md) | ✓ | ✓ | 3 calls |
| 12 | palette (see [theming/palettes.md](theming/palettes.md)) | ✓ | ✓ | 1–2 calls + accent pick |
| 13 | fonts (see [theming/fonts.md](theming/fonts.md)) | ✓ | ✓ | 1 call |
| 14 | wallpaper (see [theming/wallpaper.md](theming/wallpaper.md)) | ✓ | ✓ | 1 call |
| 15 | [env / autostart-env](components/env/interview.md) | ✓ | | 2 calls |
| 16 | [companion-daemons](components/companion-daemons/interview.md) | ✓ | | 1 call |
| 17 | [shell-prompt](components/shell-prompt/interview.md) | ✓ | | 1–2 calls |
| 18 | [utilities](components/utilities/interview.md) | ✓ | | 1 call |
| 19 | [login-boot](components/login-boot/interview.md) | ✓ | | 1 call (opt-in gate) |
| 20 | [gaming](components/gaming/interview.md) | ✓ | | 1–2 calls (opt-in gate) |
| 21 | [laptop](components/laptop/interview.md) | ✓ | | 1 call (opt-in gate) |
| 22 | [accessibility](components/accessibility/interview.md) | ✓ | | 0–1 call (opt-in gate) |
| 23 | [plugins](components/plugins/interview.md) | ✓ | | 0–2 calls (opt-in gate) |

The opt-in gates always start with a yes/no question. On "no" the component records its `enabled:
false` (or equivalent) into `answers.json` and the rest of the component is skipped.

## Recording answers

The interview is long enough — **28–38 `AskUserQuestion` calls** — that natural-language answers
scattered through chat history get garbled by the time downstream steps (file generation, package
list, component writers) try to use them. The fix: **persist every answer to
`<staging>/answers.json` as it comes in**, then every downstream step reads it with `jq`. The
model never has to recall a pick.

**After every `AskUserQuestion`**, immediately call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" <answers-file> <key.path> <value>
# or for arrays / objects / numbers / bools:
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" <answers-file> <key.path> --json '<jsonval>'
```

`record-answer.sh` `setpath`s the value into the JSON file (creating it if absent), idempotently —
re-asking a question and re-recording just overwrites the key, no duplicate state. The file lives
at `<staging>/answers.json` (e.g. `/tmp/hypr-gen-abc123/answers.json`); it's the single source of
truth the rest of Mode A reads from. **Never invent a key after-the-fact** — if a downstream step
needs something the interview didn't capture, go back and ask, then re-record.

Each component owns its slice of `answers.json` — see `components/<name>/schema.md` for the exact
keys and types that component writes. Sibling-component slices aren't visible to a component's
`schema.md`; they live in their own component folder.

The top-level keys `version`, `staging_dir`, `hypr_version` are seeded by the interviewer agent
before walking the components.

## Review pass

Once all components are answered, the interviewer runs **one** `AskUserQuestion` with a structured
summary of the key picks (palette, fonts, bar strategy, launcher, terminal, shell — the things
users usually double-check). The user can:

- **Approve** → done; downstream steps proceed.
- **Fix one or more components** → re-walk just the chosen components and re-record (records
  overwrite via `setpath`).
- **Start over** → reset `answers.json` and re-walk from monitors.

Capped at 3 review cycles. After that the interviewer returns; the user can hand-edit
`answers.json` or run `edit-config` later.
