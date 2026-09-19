# rice reference index

The full map of this skill's reference tree. `SKILL.md` carries the routing table and the
safety rules; this file is the directory for everything underneath it.

## Contents

- Protocol & shared contracts
- Components (one folder each)
- Theming
- Scripts, agents and assets

---


The reference tree is **per-component** — one folder per interview component, plus a small set of
shared contracts and the theming engine docs. Each component folder owns its sub-interview, schema,
template, gotchas, install slice, and (for visual components) styling/validation/reload notes:

```
references/
├── _interview-protocol.md       # interview protocol + components-walked table
├── _shared/
│   ├── palette-schema.md        # palette.conf key contract
│   ├── colors-contract.md       # per-app color var contracts
│   ├── dispatchers.md           # Hyprland dispatcher catalog
│   └── version-matrix.md        # Hyprland version branches & syntax gates
├── components/<x>/              # one folder per component (24 total)
│   ├── README.md
│   ├── interview.md             # sub-questions for the interviewer
│   ├── schema.md                # answers.json keys this component owns
│   ├── template.md              # what gets emitted (Mode A)
│   ├── gotchas.md
│   ├── packages.md              # this component's install slice
│   ├── styling.md               # visual components only
│   ├── validation.md            # visual components only
│   └── reload.md                # visual components only
└── theming/                     # the rice engine + cross-surface theming
    ├── engine.md                # palette.conf, render manifest, rice CLI
    ├── theming-architecture.md  # the overall theming model
    ├── palettes.md              # named schemes → contract hex
    ├── fonts.md                 # font roles + catalog + apply
    ├── wallpaper.md             # backends, dynamic theming, cycling
    ├── apps.md                  # long-tail per-app templates
    └── gtk-qt.md                # GTK/Qt gotchas + theming
```

**Protocol & shared contracts**

- **`_interview-protocol.md`** — the interview protocol (order, no-defaulting rule,
  `answers.json` recording, components-walked table). Used by the **hyprland-interviewer** agent.
- **`_shared/palette-schema.md`** — the `palette.conf` key contract (accent/accent2,
  bg/fg, ANSI 0..15, scheme, font_ui, font_mono, font_ui_scale, wallpaper). A4 fills this;
  B/C/D rewrite it.
- **`_shared/colors-contract.md`** — per-app color variable contracts (the names each
  rendered colors file exports for waybar/wofi/mako/kitty/eww/…).
- **`_shared/dispatchers.md`** — the Hyprland dispatcher catalog (keybinds component
  and component-writer agents lean on this).
- **`_shared/version-matrix.md`** — Hyprland version branches and syntax gates.

**Components (one folder each — 24 total)**

Twenty-four folders; the interview walks **23 groups** (three of them - palette, fonts,
wallpaper - are sub-questions of `look-feel` rather than folders of their own). Four folders
have no interview group because nothing is asked for them directly: `autostart` and
`window-rules` are DERIVED from other components' answers, `browser` is gated behind the
default-apps browser pick, and `qt` is driven by the render manifest.

Walked in interview order:

- **`components/monitors/`** — display layout, resolution, scale, transforms.
- **`components/input/`** — kbd layout/variant/options, mouse/touchpad, gestures.
- **`components/keybinds/`** — mod, app launchers, window/workspace dispatchers, custom binds.
- **`components/default-apps/`** — browser/file-manager/terminal/editor defaults + handlers.
- **`components/env/`** — toolkit env, NVIDIA gates, uwsm `~/.config/uwsm/env`.
- **`components/look-feel/`** — gaps/borders/rounding/blur/animations **plus** the palette,
  fonts, and wallpaper sub-questions (also re-used by Mode B).
- **`components/window-rules/`** — `windowrulev2` recipes (workspaces, float, size, opacity).
- **`components/autostart/`** — `exec-once` lineup (bar, wallpaper daemon, notif daemon, polkit, …).
- **`components/companion-daemons/`** — `hyprlock.conf` / `hypridle.conf` / `hyprpaper.conf`.
- **`components/plugins/`** — hyprpm community plugins (hyprexpo, hyprscrolling, hy3,
  split-monitor-workspaces, hyprbars, borders-plus-plus, hyprtrails, hyprwinwrap, pyprland).
- **`components/terminal/`** — kitty / alacritty / foot / wezterm config + colors include.
- **`components/waybar/`** — `config.jsonc` + `style.css` (full functional depth).
- **`components/widgets/`** — eww / AGS-Astal / Quickshell / HyprPanel scaffold + colors wiring.
- **`components/launcher/`** — wofi / rofi / fuzzel / tofi config + colors.
- **`components/notifications/`** — mako / dunst / swaync config + colors.
- **`components/lock-screen/`** — hyprlock styling (the lock surface; the daemon config is in
  `companion-daemons/`).
- **`components/shell-prompt/`** — interactive shell (bash/zsh/fish) + prompt engine
  (starship/oh-my-posh) + fetch + modern-CLI aliases; managed-block recipe lives here.
- **`components/utilities/`** — screenshot / screenrecord / OCR / color-picker / power-menu scripts
  (shipped in `assets/scripts/`), clipboard / emoji / calc binds, Wi-Fi/BT applets.
- **`components/login-boot/`** — greetd/tuigreet/ReGreet + SDDM + boot chrome.
- **`components/gaming/`** — tearing (`allow_tearing` + `immediate`), VRR, fullscreen
  effect-stripping, `misc:vfr`, the shipped `gamemode.sh` toggle.
- **`components/laptop/`** — battery/lid/backlight/touchpad-gesture sub-questions (opt-in; chassis
  is the default, not an answer).
- **`components/accessibility/`** — opt-in a11y tweaks.

Not walked as their own interview group:

- **`components/autostart/`** — the `exec-once` lineup, DERIVED from the bar / wallpaper /
  notification / widget / utility picks rather than asked for.
- **`components/window-rules/`** — `windowrule` recipes, likewise derived (the blur layerrules
  follow the chosen launcher, notification daemon and widget shell).
- **`components/browser/`** — Firefox `userChrome.css` theming; gated behind
  `default_apps.browser == firefox` plus an explicit opt-in.
- **`components/qt`** — the qt6ct colors template the render manifest drives when any Qt app
  is picked. Template-only: it has no interview slice because nothing is asked for it.

Each component's `packages.md` is the install slice for A3d/A5 (the installer agent concatenates
them into `install.sh`). Each visual component's `styling.md` is the design-principles guide for
that surface.

**Theming**

- **`theming/engine.md`** — the rice engine: `palette.conf` source of truth, render
  manifest, the `rice` CLI, matugen/wallust integration, the user-override cascade, reproducibility,
  shell-and-prompt theming, widget-shell theming.
- **`theming/theming-architecture.md`** — the overall theming model (palette → per-app
  colors → reload), how the contract files compose.
- **`theming/palettes.md`** — named schemes → contract hex (+ matching GTK/cursor/icons).
- **`theming/fonts.md`** — font roles, the catalog to present, detection, applying UI +
  Nerd fonts.
- **`theming/wallpaper.md`** — backends, dynamic theming, cycling automation.
- **`theming/apps.md`** — shipped long-tail templates (btop/cava/starship/swaync/wlogout/
  fuzzel) + reaching matugen's 50+ app library.
- **`theming/gtk-qt.md`** — GTK/Qt theming gotchas (the four engine-breaking ones —
  `GTK_THEME=`, icon-theme vs GTK-theme, root-owned `gtk.css` symlink, `gsettings`-alone-misses-GTK3).
- **`scripts/`** — `detect-version.sh`, `detect-theme-tools.sh`, `rice-init.sh`, `render-templates.sh`,
  `apply-theme.sh`, `set-wallpaper.sh`, `palette-from-wallpaper.sh`, `safe-apply.sh`,
  `install-config.sh`, `verify-config.sh`, `verify-shell.sh`, `backup-config.sh`, `reset-config.sh`,
  `config-language.sh`, `emit-config.sh`, `migrate-config.sh`.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh`** — `jq`-based `setpath` into `answers.json`.
  Called by the interviewer agent after every `AskUserQuestion` so picks land on disk before the
  next question.
- **Agents** (under `${CLAUDE_PLUGIN_ROOT}/agents/`):
  - `hyprland-interviewer` — owns the 23-group interview (walking
    `_interview-protocol.md` + each `components/<x>/interview.md`), records each answer to
    `<staging>/answers.json`, runs the review pass, returns just the path + a summary. **A1 spawns
    this so the main loop's context stays clean.**
  - `hyprland-component-writer` — authors one surface (waybar / launcher / notifications / terminal /
    lock-screen / widgets / Hyprland topic) into staging. **A3 + A3b spawn several in parallel**,
    each fed a `jq` slice of `answers.json`.
  - `hyprland-package-installer` — runs the generated `install.sh` (or an ad-hoc package list) after
    A5 user confirmation. Handles pacman/paru routing, paru bootstrap, transient retries.
  - `hyprland-config-validator` — static lint of the staging dir (and optional live load-test). A5
    step 1.
- **`assets/scripts/*.sh`** — utility scripts shipped as-is (copy + `chmod`, not rendered):
  `screenshot.sh`, `screenrecord.sh`, `ocr.sh`, `colorpicker.sh`, `powermenu.sh` (see
  `components/utilities/template.md`), `gamemode.sh` (effects toggle, see
  `components/gaming/template.md`), `keybind-cheatsheet.sh` (reads `hyprctl binds -j`),
  `blur-toggle.sh`, `theme-switch.sh` (menu of saved rices → `rice theme`).
- **`components/<component>/*.tmpl`** + **`theming/{gtk4,palette.matugen}.tmpl`** —
  the color templates the engine renders (incl. the shell/prompt set:
  `shell-prompt/fish.tmpl` → fish `conf.d` colors, `shell-prompt/starship.tmpl` → rice-owned `starship.toml`,
  `shell-prompt/oh-my-posh.tmpl` → rice-owned `rice.omp.json`; and the **widget-shell set**:
  `widgets/eww.tmpl` → eww `colors.scss`, `widgets/ags.tmpl` → AGS/Astal `colors.scss`,
  `widgets/quickshell.tmpl` → Quickshell `Colors.qml`; registered in the manifest
  when chosen — see `theming/engine.md` → "Shell & prompt theming" and "Widget-shell theming").
- **`assets/profiles/*.conf`** — the fourteen shipped preset rices (twelve aesthetic schemes
  plus the WCAG-AAA `high-contrast-dark` / `high-contrast-light` pair); **`assets/rice`** — the CLI
  (incl. `rice wallpapers [scheme]` to list and `rice get-wallpaper <scheme> <n|name> [--set]` to
  curl-download a matching wallpaper; `rice accents [scheme]` to list per-scheme accent variants and
  `rice accent <name|hex> [--pin]` to swap the accent; `rice theme-toggle <a> <b>` flips two profiles
  for the dark/light keybind and `rice theme-next` cycles them). **`assets/wallpapers.tsv`** — the curated,
  theme-tagged, curl-downloadable wallpaper catalog (verified raw URLs; `scheme<TAB>name<TAB>url`).
  **`assets/accents.tsv`** — per-scheme accent variants (`scheme<TAB>name<TAB>hex`, 6–8 each).
- **`examples/sample-config/`** — a complete reference output (a generated modular config set).
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.
