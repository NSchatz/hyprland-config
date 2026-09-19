# rofi - launcher

Everything this plugin knows about authoring **rofi** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation

---

## Template


`config.rasi` (behavior + theme pointer):

```rasi
configuration {
    modi: "drun";              /* "drun,run" for run-drun */
    show-icons: true;           /* from icons=true; omit when false */
    icon-theme: "Papirus";
    drun-display-format: "{name}";
    drun-match-fields: "name,generic,exec,keywords";  /* dusky: drop "categories"
                                                         so Firefox stops matching
                                                         every Network/WebBrowser
                                                         query */
    kb-cancel: "Escape";

    /* Single-click activation — rofi's default is double-click, which feels
       broken to anyone reaching for the mouse. Clear me-select-entry first
       (MousePrimary is bound there by default; rofi refuses to bind the same
       event twice). Idiom from dusky, ML4W, Matt-FTW. */
    me-select-entry: "";
    me-accept-entry: "MousePrimary";

    /* Frecency-aware fuzzy search — rofi maintains ~/.cache/rofi3.druncache
       launch counts; these three options consult it (sort by match quality,
       launch history breaks ties; PowerToys/Albert style). Dusky idiom. */
    sort: true;
    sorting-method: "fzf";
    matching: "fuzzy";
}
@theme "~/.config/rofi/theme.rasi"
```

`theme.rasi` (look; `@import`s the engine colors file at the top):

```rasi
@import "colors.rasi"        /* * { bg: …; bg-alt: …; fg: …; muted: …; accent: …; accent2: …; red: …; green: …; } */

/* GLOBAL DEFAULT — rofi overlays the user theme on top of its bundled base theme. Any selector
   NOT explicitly themed here inherits the base theme's (usually light) colors — the
   widely-reported "white list with black text on a dark rice" symptom. The `*` block sets a
   transparent background + palette `text-color` so every unstyled widget at least picks up the
   palette. Defect #4 (the validator agent now lints rofi themes for this `*` block). */
* {
    background-color: transparent;
    text-color:       @fg;
    border-color:     @accent;
}

window {
  width: 700px;
  border-radius: 14px;
  border: 1px solid;
  border-color: @accent;
  background-color: @bg;
  padding: 12px;
}
mainbox   { background-color: transparent;
            children: [ inputbar, listview ]; }
inputbar  { spacing: 8px; padding: 8px; margin: 0 0 8px 0;
            background-color: @bg-alt; border-radius: 10px;
            children: [ prompt, entry ]; }
prompt    { text-color: @accent;        background-color: transparent; }
entry     { text-color: @fg;            background-color: transparent;
            placeholder: "Search…"; placeholder-color: @muted; }

/* listview & elements must explicitly set background, or the base theme paints them white. */
listview  { background-color: transparent; lines: 8; columns: 1;
            spacing: 4px; scrollbar: false; }
scrollbar { background-color: @bg-alt; handle-color: @accent; }

element        { padding: 7px 10px; border-radius: 8px; }
element-text   { background-color: transparent; text-color: inherit; }
element-icon   { background-color: transparent; size: 22px; }

/* visible-modifier.state syntax per rofi-theme(5) — period (not space) is the dominant
   community form (HyDE, JaKooLit, ML4W, dusky, Matt-FTW, binnewbs all use this). Cover the
   full 9-state matrix or the un-named states inherit the base theme. Pattern: bg/fg for
   "normal" rows, surface for "alternate", accent for "selected". */
element normal.normal    { background-color: transparent; text-color: @fg; }
element normal.urgent    { background-color: transparent; text-color: @red; }
element normal.active    { background-color: transparent; text-color: @green; }

element alternate.normal { background-color: @bg-alt;     text-color: @fg; }
element alternate.urgent { background-color: @bg-alt;     text-color: @red; }
element alternate.active { background-color: @bg-alt;     text-color: @green; }

element selected.normal  { background-color: @accent;     text-color: @bg; }
element selected.urgent  { background-color: @red;        text-color: @bg; }
element selected.active  { background-color: @green;      text-color: @bg; }

/* When the same theme is reused for rofi `dmenu` mode (clipboard, power menu), the message bar
   appears for status lines; theme it explicitly or the dmenu prompts render unstyled. */
message   { background-color: @bg-alt; border-radius: 8px; padding: 6px 10px; margin: 4px 0 0 0; }
textbox   { background-color: transparent; text-color: @fg; }
```

`colors.rasi` rendered by the engine from `rofi.tmpl`. The `*{}` block exports
`@bg @bg-alt @fg @muted @accent @accent2 @red @green` — `theme.rasi` MUST reference exactly
these names (an unknown var fails to resolve and the launcher silently won't open).

For `layout=fullscreen-grid`: `window { fullscreen: true; }` + `listview { columns: 5; lines:
5; }` + `element-icon { size: 5%; }`. For `layout=multi-column`: `listview { columns: 3;
lines: 5; }` + `element { orientation: vertical; }` + `element-icon { size: 72px; }`.

---

## Styling


```rasi
@import "colors.rasi"   /* rendered by the rice: * { accent: ...; bg: ...; } */

* {
  bg:      #1e1e2e;   /* {{bg}}      */
  bg-alt:  #313244;   /* {{surface}} */
  fg:      #cdd6f4;   /* {{fg}}      */
  accent:  #cba6f7;   /* {{accent}}  */
  muted:   #6c7086;   /* {{muted}}   */
}
window {
  width: 700px;
  border-radius: 14px;
  border: 1px solid;
  border-color: @accent;
  background-color: @bg;
  padding: 12px;
}
inputbar { spacing: 8px; padding: 8px; margin: 0 0 8px 0;
           background-color: @bg-alt; border-radius: 10px; }
prompt  { text-color: @accent; }
entry   { text-color: @fg; placeholder: "Search…"; placeholder-color: @muted; }
listview { lines: 8; columns: 1; spacing: 4px; scrollbar: false; }
element  { padding: 7px 10px; border-radius: 8px; }
element-icon { size: 22px; }
element selected.normal  { background-color: @accent; text-color: @bg; }  /* highlight */
element selected.urgent  { background-color: @red;    text-color: @bg; }
element selected.active  { background-color: @green;  text-color: @bg; }
```

Companion `~/.config/rofi/config.rasi`: `configuration { modi: "drun"; show-icons: true; icon-theme: "Papirus"; }` then `@theme "~/.config/rofi/theme.rasi"`.

---

## Validation


- **`config.rasi` and `theme.rasi` parse.** rofi has a built-in dry-parser:

  ```bash
  rofi -no-config -dump-config -theme ~/.config/rofi/theme.rasi >/dev/null
  rofi -dump-config >/dev/null
  ```

  Any RASI error (unknown var, missing brace, unterminated string) prints to stderr and exits
  non-zero. **A failing `theme.rasi` makes rofi silently fall back to the default theme — the
  launcher opens but completely un-themed**, which is the worst case to catch late.

- **`colors.rasi` defines the required vars.** The contract from `_shared/colors-contract.md`:

  ```bash
  for v in bg bg-alt fg muted accent accent2 red green; do
    grep -qE "^\s*$v\s*:" ~/.config/rofi/colors.rasi \
      || { echo "error: colors.rasi missing var: $v"; exit 1; }
  done
  ```

- **`theme.rasi` references only known vars.** Quick check that no `@unknown` slips through:

  ```bash
  rofi -dump-theme -theme ~/.config/rofi/theme.rasi 2>&1 | \
    grep -E 'unable to resolve|unknown' && exit 1 || true
  ```

- **`theme.rasi` is SELF-CONTAINED (defect #4 lint).** Rofi loads its bundled base theme first
  and overlays the user theme on top. Anything the user theme does NOT explicitly style inherits
  the (usually light) base theme — visible as a white list with black text on a dark rice. The
  template requires a global `*` default block AND background-color on `listview` / `element` /
  `element-text` / `element-icon` AND the full nine-state element matrix
  (`normal/alternate/selected` × `normal/urgent/active`). Lint:

  ```bash
  for block in '\* {' 'listview' 'element-text' 'element-icon' \
               'element normal.normal' 'element normal.urgent' 'element normal.active' \
               'element alternate.normal' 'element alternate.urgent' 'element alternate.active' \
               'element selected.normal' 'element selected.urgent' 'element selected.active'; do
      grep -qE "$block" ~/.config/rofi/theme.rasi \
        || { echo "error: rofi theme.rasi missing required block/selector: $block (rofi will overlay base-theme colors for unstyled widgets — see launcher/ rofi recipe)"; exit 1; }
  done
  ```

  The `*` block is the safety net for any selector not covered above; the explicit element
  states are required because rofi marks drun rows as `urgent`/`active` for things like
  notifications and recently-launched apps, and a missing state silently picks the base theme.

