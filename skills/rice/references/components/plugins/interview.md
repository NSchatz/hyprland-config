# plugins — interview

Group 23. The community-plugin layer most generators skip: workspace overview, tree tiling, per-monitor
workspaces, title bars, dropdown scratchpads, decorative effects. Gated behind one opt-in so the user
who doesn't want plugins never sees the catalog.

This is an **opt-in component with a gate**. Per `_interview-protocol.md` → "Strict — ask every
question" / "Opt-in gate questions": **the gate is always asked**, never silently defaulted from
detection or `$ARGUMENTS`. Detection only reorders the option list (e.g. a multi-monitor system can
list `split-monitor-workspaces` first) — it does **not** answer the gate. A short interview is a
failed interview; ask 23a unconditionally.

On a re-theme (Mode B), this whole component is **skipped** — re-theming doesn't touch plugin choice.

## AskUserQuestion shape

Group 23 splits into **up to 2 calls**:

- **Call 1** (always asked): 23a — the opt-in gate. On **No**, stop here and record
  `plugins.enabled = false`, `plugins.selected = []`.
- **Call 2** (only if 23a == Yes): 23b — `multiSelect` of plugins, none pre-checked.

## Sub-questions

### 23a. Set up Hyprland plugins?  *(always asked — opt-in gate)*

Single-select. The user is told the plugins are user-installed via `hyprpm` (Claude can't run it
headless) and that every Hyprland upgrade requires a `hyprpm update && hyprpm reload`.

- **No, skip** *(default)* — record `plugins.enabled = false` and stop the component.
- **Yes** — proceed to 23b.

### 23b. Which plugins?  *(only when 23a == Yes)*

**`multiSelect`**, none pre-checked. Order: most-used first. Each option names the plugin, what it
does, and any conditional gating.

| Plugin | Notes |
|---|---|
| **Workspace overview — `hyprexpo`** | Grid exposé, `SUPER+\`` toggle. **Removed from the official `hyprwm/hyprland-plugins` repo by PR #663 (2026-05-12)** — now the community fork `sandwichfarm/hyprexpo`. Skip if a full widget shell (group 7) already provides an overview. |
| **i3/sway tree tiling — `hy3`** | Manual split tree with tabbed groups (`outfoxxed/hy3`, still maintained). Sets `general:layout = hy3` and adds `hy3:` dispatchers (`hy3:makegroup`, `hy3:changegroup`, `hy3:movefocus`, `hy3:movewindow`, `hy3:setephemeral`, etc.). Both the layout and the binds are emitted **commented-out** until the user builds + enables the plugin. |
| **Per-monitor workspaces — `split-monitor-workspaces`** | Each monitor gets its own 1–10. Offer **only when `monitors.list | length > 1`**. Repo: `zjeffer/split-monitor-workspaces` (the original `Duckonaut/split-monitor-workspaces` repo is now a 301 redirect to this transfer). Rebinds the workspace keys (`split-workspace, N` / `split-movetoworkspacesilent, N`), again commented-out until loaded. |
| **Window title bars — `hyprbars`** | Per-window CSD-like title bars with min/close buttons. Themable from the palette. (Official `hyprwm/hyprland-plugins`.) |
| **Dropdown scratchpads — `pyprland`** | Quake terminal + `expose` / `magnify`. **pip / AUR, not hyprpm** — has its own config file and needs `exec-once = pypr`. Repo: `hyprland-community/pyprland` (NOT `hyprwm/pyprland` — that's a 404). Core Hyprland's `special:` workspace already covers a single scratchpad; offer pyprland when the user wants **multiple named** dropdowns. |
| **Extra border ring — `borders-plus-plus`** | A second / third window border ring. Pure decoration, no binds. (Official `hyprwm/hyprland-plugins`.) |
| **Motion trails — `hyprtrails`** | Smooth motion trail behind moving windows (eye-candy, GPU cost). **Removed from the official repo by PR #663**; community forks only — flag as optional / unmaintained-risk and do not ship a default URL. |
| **App as wallpaper — `hyprwinwrap`** | Run any windowed app *as* the wallpaper (animated wallpapers). **Removed from the official repo by PR #663** — use the community fork `gen3vra/hyprwinwrap` (requires Hyprland 0.54+). |

**Do NOT offer `hyprscrolling` / `hyprscroller`.** The scrolling layout is **native core in Hyprland
0.53+** — it belongs in `../look-feel/` (`general:layout = scrolling` + a `scrolling {}` block), NOT
here. See `../../_shared/version-matrix.md` → 0.53+ cliff.

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh` (see `_interview-protocol.md` →
"Recording answers"):

```bash
# 23a (always)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" plugins.enabled --json false
# or, on Yes:
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" plugins.enabled --json true

# 23b — array (only when 23a == Yes)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" plugins.selected \
  --json '["hyprexpo","hy3"]'
```

When 23a is **No**, also record an empty `selected` so downstream readers don't have to branch on
key presence:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" plugins.enabled --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" plugins.selected --json '[]'
```

## Cross-references

- Strict-ask discipline + opt-in-gate rule → `_interview-protocol.md`
- Schema slice + types → `schema.md`
- Per-plugin `plugin {}` blocks + the commented binds → `template.md`
- Why every plugin-dispatcher bind is commented-out → `../../_shared/dispatchers.md`
- Why `scrolling` is NOT in this catalog (it's core in 0.53+) → `../../_shared/version-matrix.md`
- The "Claude never runs hyprpm" rule + per-upgrade refresh → `gotchas.md`
- Packages → `packages.md`
