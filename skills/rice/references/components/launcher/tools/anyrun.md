# anyrun - launcher

Everything this plugin knows about authoring **anyrun** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template

---

## Template


Krunner-style plugin runner. `config.ron` is Rust Object Notation; `style.css` is GTK4 CSS.
Engine writes `colors.css` the user `@import`s. Plugin selection (`applications`, `shell`,
`randr`, `dictionary`, `kidex`, …) is captured by `utilities`/`plugins`, not here.

The actual top-level `Config` struct keys (verified against
`anyrun-org/anyrun/examples/config.ron`) are **`snake_case`** — `x`, `y`, `width`, `height`
(all wrapped in `Fraction(_)` or `Absolute(_)`), `hide_icons`, `ignore_exclusive_zones`,
`layer` (`Background|Bottom|Top|Overlay`), `hide_plugin_info`, `close_on_click`,
`show_results_immediately`, `max_entries` (Option), `plugins` (list of plugin paths). Example:

```ron
Config(
  x: Fraction(0.5),
  y: Absolute(0),
  width: Absolute(800),
  height: Absolute(1),
  hide_icons: false,
  ignore_exclusive_zones: false,
  layer: Overlay,
  hide_plugin_info: false,
  close_on_click: false,
  show_results_immediately: false,
  max_entries: None,
  plugins: ["libapplications.so", "libshell.so"],
)
```

**Anyrun has no `--dmenu` flag.** The dmenu-style picker is the `libstdin.so` plugin —
invoke as `anyrun --plugins libstdin.so` (which reads newline-separated entries from stdin
and prints the selection). That's the right value for `$dmenu` when `launcher.tool=anyrun`.

