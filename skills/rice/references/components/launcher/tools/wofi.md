# wofi - launcher

Everything this plugin knows about authoring **wofi** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation

---

## Template


`config` (line-based INI; behavior only):

```ini
show=drun                    ; or "drun,run" for run-drun
prompt=Search
width=600                    ; from layout=centered
height=400
location=center              ; layout=compact-top → "top"
insensitive=true             ; case-insensitive matching (always-on convenience)
allow_images=true            ; from icons=true
image_size=24
hide_scroll=true             ; from behavior.hide-scrollbar
matching=fuzzy               ; from behavior.fuzzy (else "contains" — the default)
no_actions=true
gtk_dark=true
key_expand=Tab
term=kitty                   ; {{terminal.emulator}} for run-in-terminal entries
close_on_focus_loss=true     ; from behavior.close-on-focus-loss
```

All wofi config keys use **underscores**, never hyphens (e.g. `allow_images`, NOT
`allow-images`; `close_on_focus_loss`, NOT `close-on-focus-loss`). A hyphenated key is
silently ignored — wofi just falls back to the default. See `man 5 wofi`.

`style.css` (look; `@import`s the engine-generated colors file):

```css
@import "colors.css";        /* defines @bg @fg @surface @accent */

window {
  margin: 0;
  background-color: alpha(@bg, 0.92);
  border-radius: 14px;
  border: 1px solid @accent;
  font-family: "{{fonts.ui_family}}", sans-serif;
  font-size: 14px;
}
#input        { margin: 10px; padding: 8px 12px; border-radius: 10px;
                border: none; background-color: @surface; color: @fg; }
#inner-box    { margin: 6px; }
#outer-box    { padding: 8px; }
#entry        { padding: 6px 10px; border-radius: 8px; }
#text         { color: @fg; }
#entry:selected         { background-color: @accent; }
#entry:selected #text   { color: @bg; }
```

`colors.css` rendered by the engine from `wofi.tmpl` — exports `bg fg surface accent`. Vars
referenced in `style.css` MUST be one of those four (see `_shared/colors-contract.md`).

---

## Styling


```css
@import "colors.css";   /* rendered by the rice: defines @bg @fg @accent ... */

window {
  margin: 0;
  background-color: rgba(30, 30, 46, 0.92);  /* {{bg}} at ~0.92 */
  border-radius: 14px;
  border: 1px solid @accent;                 /* #{{accent}} */
  font-family: "Inter", sans-serif;          /* {{font_ui}} */
  font-size: 14px;
}
#input {
  margin: 10px;
  padding: 8px 12px;
  border-radius: 10px;
  border: none;
  background-color: @surface;                 /* #{{surface}} */
  color: @fg;
}
#inner-box  { margin: 6px; }
#outer-box  { padding: 8px; }
#entry      { padding: 6px 10px; border-radius: 8px; }
#entry image { -gtk-icon-transform: none; }
#text       { color: @fg; }
#entry:selected      { background-color: @accent; }   /* the highlight */
#entry:selected #text { color: @bg; }                 /* contrast on accent */
```

Companion `~/.config/wofi/config`: `allow_images=true`, `image_size=24`, `location=center`, `width=600`, `height=400`, `insensitive=true`. All wofi config keys use **underscores**, never hyphens — `allow-images` is silently ignored.

---

## Validation


- **`config` parse (line-based, lenient).** wofi accepts `key=value` lines and `#` / `;`
  comments. No native dry-run, so the validator uses a shell check:

  ```bash
  awk 'NF && $1 !~ /^[#;]/ && $0 !~ /^[A-Za-z_][A-Za-z0-9_]*=.*/ {
         print FILENAME ":" NR ": not key=value: " $0; bad=1 }
       END { exit bad }' ~/.config/wofi/config
  ```

  Empty lines and comment lines are skipped; everything else must match `KEY=value`. A
  malformed line doesn't crash wofi — it's silently ignored — so the lint catches the
  silent-fail.

- **`style.css` balanced braces + `@import "colors.css"` present.**

  ```bash
  awk 'BEGIN{d=0} { for(i=1;i<=length($0);i++){ c=substr($0,i,1);
        if(c=="{")d++; else if(c=="}"){ d--; if(d<0){print "unbalanced"; exit 1 } } }
       } END { exit (d!=0) }' ~/.config/wofi/style.css
  grep -q '@import.*"colors\.css"' ~/.config/wofi/style.css \
    || echo "warn: style.css does not @import colors.css — engine themes won't apply"
  ```

- **`colors.css` defines the required vars.** The four-name contract:

  ```bash
  for v in bg fg surface accent; do
    grep -q "@define-color *$v " ~/.config/wofi/colors.css \
      || { echo "error: colors.css missing @define-color $v"; exit 1; }
  done
  ```

