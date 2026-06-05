# window-rules — interview

**This component has NO dedicated interview group.** It owns `windowrules.conf`, but every
sub-question that feeds it lives in a sibling component's interview, because the user is
already thinking about those neighbouring concerns when the question naturally arises.

Do **not** ask anything from this file. The interview walker skips straight past `window-rules`
to the next component. The data lands in `answers.json` under the sibling components' keys, and
this component's `template.md` reads those keys at render time.

## Where the sub-questions live

| Sub-question | Asked in | Records under |
|---|---|---|
| **1e** Workspace rules (bind 1–5→primary, persistent workspaces, smart gaps, named scratchpad) | `../monitors/interview.md` | `monitors.workspace_rules` |
| **1f** Pin apps to workspaces (class + target workspace, optional `silent`) | `../monitors/interview.md` | `monitors.pin_apps` |
| **11i** Per-app window rules (float / pin / opacity / send-to-workspace beyond the shipped defaults) | `../look-feel/interview.md` | `look_feel.per_app_rules` |
| **11j** Runtime blur-toggle keybind (`SUPER+SHIFT+B`) | `../look-feel/interview.md` | `look_feel.blur_toggle` — emits a **bind** (in `binds.conf`, owned by `keybinds`), not a window rule. Mentioned here only because users often conflate it with layer-rule blur. |

The chosen-tool flags that drive the `layerrule` blur blocks (waybar yes/no, launcher namespace,
notification daemon namespace) come from the respective tool components' own interview groups —
this component just reads them at template time.

## Why no group here

A "window-rules" group in isolation would force the user to context-switch back to "what apps do I
own" mid-interview. Group **11i** asks for per-app rules while the user is already deep in
look-and-feel ("how does this thing feel?"); groups **1e/1f** ask while the user is already deep in
monitors and workspaces ("which screen does what?"). Both placements honour the
**strict-no-defaulting** rule in `_interview-protocol.md` — every sub-question is still asked, just
under the component the user is currently thinking about.

## Cross-references

- Protocol (asking discipline, strict no-defaulting) → `../../_interview-protocol.md`
- Schema slices this component reads → `schema.md`
- The rendered template (where the picks land) → `template.md`
- Version branches for the rule syntax → `../../_shared/version-matrix.md`
