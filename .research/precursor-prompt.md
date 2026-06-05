Relocate every per-app color template from `skills/rice/templates/` into the
matching component's reference folder, then rewire everything that references
the old paths. This is a pure refactor — file contents stay byte-identical,
only locations and references change.

================================================================================
MOVES
================================================================================

Move each `.tmpl` from `/workspace/skills/rice/templates/<name>.tmpl` to the
component folder shown:

  waybar.tmpl       → references/components/waybar/waybar.tmpl
  rofi.tmpl         → references/components/launcher/rofi.tmpl
  fuzzel.tmpl       → references/components/launcher/fuzzel.tmpl
  wofi.tmpl         → references/components/launcher/wofi.tmpl
  mako.tmpl         → references/components/notifications/mako.tmpl
  dunst.tmpl        → references/components/notifications/dunst.tmpl
  swaync.tmpl       → references/components/notifications/swaync.tmpl
  ags.tmpl          → references/components/widgets/ags.tmpl
  eww.tmpl          → references/components/widgets/eww.tmpl
  quickshell.tmpl   → references/components/widgets/quickshell.tmpl
  kitty.tmpl        → references/components/terminal/kitty.tmpl
  btop.tmpl         → references/components/terminal/btop.tmpl
  cava.tmpl         → references/components/terminal/cava.tmpl
  starship.tmpl     → references/components/shell-prompt/starship.tmpl
  oh-my-posh.tmpl   → references/components/shell-prompt/oh-my-posh.tmpl
  fish.tmpl         → references/components/shell-prompt/fish.tmpl
  hyprland.tmpl     → references/components/look-feel/hyprland.tmpl
  wlogout.tmpl      → references/components/utilities/wlogout.tmpl

The two engine-internal templates stay out of components (they are not
per-surface theming, they ARE the engine):

  gtk4.tmpl              → references/theming/gtk4.tmpl
  palette.matugen.tmpl   → references/theming/palette.matugen.tmpl

After the moves, `/workspace/skills/rice/templates/` should be EMPTY. Remove
the empty directory.

Use `git mv` so the move is preserved as a rename in history and the recent
v0.13 attribution survives.

================================================================================
REWIRE
================================================================================

1. `/workspace/skills/rice/scripts/rice-init.sh`
   - Line 39 — the `for t in "$SRC"/templates/*.tmpl` enumeration must
     change to enumerate every component-folder `.tmpl` + the two
     `theming/*.tmpl` files. Concretely:
     ```sh
     for t in "$SRC"/references/components/*/*.tmpl \
              "$SRC"/references/theming/*.tmpl; do …
     ```
     The destination at line 40 stays `$RICE_DIR/templates/$base` — the
     user-side rice engine layout is unchanged; only the plugin-side
     source layout moves. (Users keep getting a flat
     `~/.config/hypr-rice/templates/`.)
   - Lines 53-66 — the default manifest's `printf` lines hardcode
     `%s/<name>.tmpl` against `$T` (which is `$RICE_DIR/templates`).
     Those stay as-is because the user-side layout didn't change.

2. `/workspace/skills/rice/scripts/palette-from-wallpaper.sh`
   - Line 18: `tmpl="$RICE_DIR/templates/palette.matugen.tmpl"` — this is
     the user-side path, unchanged. No edit needed unless the test suite
     also reads the plugin-side path; grep and verify.

3. `/workspace/skills/rice/SKILL.md`
   - Lines 320, 323, 671 (and any others — grep for `templates/`). Update
     prose references from `templates/<name>.tmpl` to
     `references/components/<component>/<name>.tmpl` (or
     `references/theming/<name>.tmpl` for the two engine templates).

4. Grep the entire repo for `templates/` and `\.tmpl` and fix any other
   references — `agents/`, `commands/`, `tests/`, `README.md`,
   `CHANGELOG.md`. The CHANGELOG entries about prior template work should
   NOT be edited (they're historical record); only currently-active
   references.

================================================================================
VERIFY
================================================================================

- Run the test suite under `tests/` — at minimum the parse-only integration
  tests that exercise `rice-init.sh` against a tmp `$RICE_DIR`. The
  user-facing output must be byte-identical to before the move (same
  templates land in `~/.config/hypr-rice/templates/`, same manifest
  content).
- `git diff --stat` should show ~20 renames + a handful of script/doc
  edits, no content changes inside `.tmpl` files.

================================================================================
COMMIT
================================================================================

Single commit:

```
refactor: co-locate color templates with their component folders

Moves skills/rice/templates/*.tmpl into the per-component reference
folders (and the two engine templates into references/theming/).
Plugin-side source layout only; user-side ~/.config/hypr-rice/templates/
is unchanged. Rewires rice-init.sh's source enumeration; everything
else (manifest defaults, palette-from-wallpaper, SKILL.md prose)
follows.
```

Then push.
