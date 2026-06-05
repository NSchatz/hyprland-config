You are doing a deep-research pass on the **{{COMPONENT}}** component of the
hyprland-config Claude Code plugin. Your job is to study how the most popular
community Hyprland dotfiles approach this component **from a theming
standpoint**, and update the component's reference docs with what you find as
you find it.

Theming is the number-one priority of this plugin. Every claim you add should
ultimately help a user end up with a desktop where {{COMPONENT}} looks coherent
with the rest of their rice (same palette, same accent strategy, same shape
language, same reload story).

> Note: a precursor refactor has already run. Per-app color templates
> (`*.tmpl`) now live INSIDE each component's folder (and the two engine
> templates moved to `references/theming/`). Work against the new layout.

================================================================================
1. CONTEXT — read these before doing anything else
================================================================================

- `/workspace/README.md`
    What the plugin does end-to-end. The rice skill generates the whole
    desktop; the per-component reference folder you are editing is what the
    interview, the component-writer agents, and edit-config all read.

- `/workspace/skills/rice/references/components/{{COMPONENT}}/`
    Your component's folder. Files that may exist:
      README.md       — folder map + cross-refs to other components
      interview.md    — the AskUserQuestion sub-questions
      schema.md       — answers.json slice for this component
      template.md     — the recipe the component-writer agent fills in
      styling.md      — visual-design library (visual components only)
      gotchas.md      — known foot-guns
      validation.md   — checks before reload (visual components only)
      packages.md     — what gets installed for this component
      reload.md       — how the component hot-reloads (visual components only)
      <app>.tmpl      — engine color template(s), post-refactor
    READ EVERY FILE that exists in this folder before researching anything.
    You are augmenting, not replacing, the work done in v0.12 and v0.13
    (see `CHANGELOG.md` — there was a recent deep-research accuracy pass
    that verified many claims against upstream sources; do not undo that
    work).

- `/workspace/skills/rice/references/theming/`
    Cross-cutting theming docs: `theming-architecture.md`, `engine.md`,
    `palettes.md`, `fonts.md`, `wallpaper.md`, `apps.md`, `gtk-qt.md`,
    plus the two engine `.tmpl` files (`gtk4.tmpl`,
    `palette.matugen.tmpl`). Skim — your findings may need to update
    these too if they affect cross-surface coherence.

- `/workspace/skills/rice/references/_shared/colors-contract.md` and
  `/workspace/skills/rice/references/_shared/palette-schema.md`
    The canonical palette keys and per-app wrap formats. Your component's
    `template.md` must reference these — do not invent new color names.

================================================================================
2. THE CORPUS — top ~15 dotfiles from github.com/topics/hyprland
================================================================================

Authoritative source: <https://github.com/topics/hyprland> sorted by stars.
WebFetch that page, take the top ~15 repos by star count, and use them as
your corpus. Likely (verify, don't trust this list): `end-4/dots-hyprland`,
`HyDE-Project/HyDE`, `prasanthrangan/hyprdots`, `mylinuxforwork/dotfiles`,
`JaKooLit/Arch-Hyprland`, `caelestia-dots/shell`, `noctalia-shell`,
`DankMaterialShell`, `gh0stzk/dotfiles`, `basecamp/omarchy`,
`ml4w/hyprland-starter`, `sainnhe/dotfiles`, `ChrisTitusTech/Hyprland`,
`koeqaife/hyprland-material-you`, `HeyImKyu/private-dots`. Fetch each
repo's README + the relevant config files for {{COMPONENT}}. Don't waste a
fetch on a rice whose {{COMPONENT}} story is non-existent — note it and
move on.

For visual components ({{COMPONENT}} in `{waybar, launcher, notifications,
widgets, look-feel, lock-screen, terminal, shell-prompt}`) read the actual
styled config files (`style.css` / `*.rasi` / `*.ini` / `config.jsonc` /
`hyprlock.conf` / `alacritty.toml` / `starship.toml` / `theme.scss` …) and
quote near-verbatim techniques. The existing `styling.md` "How the
community styles it" + "Battle-tested techniques" sections show the level
of granularity expected.

For structural components ({{COMPONENT}} in `{monitors, input, keybinds,
default-apps, env, window-rules, autostart, companion-daemons, plugins,
utilities, login-boot, gaming, laptop, accessibility}`) the lens is "how
do popular rices use this component IN SERVICE OF the theme?" Examples:

  - **monitors**: workspace rules that pin theme-critical surfaces (waybar
    on primary, scratchpads, persistent workspaces, smart-gaps so the
    floating-island bar still works at the edge)
  - **autostart**: daemon load order so the bar / wallpaper daemon /
    notification daemon all come up before anything tries to render a
    theme; D-Bus env propagation that lets GTK theming actually apply
  - **window-rules**: the layerrule blur block that makes a translucent
    waybar/launcher/notification look right; opacity rules per app class
    to sell a glassy look; workspace rules that move app windows to
    specific workspaces so the bar's workspace pills mean something
  - **plugins**: which decorative hyprpm plugins (`hyprbars`, `hyprexpo`,
    `hyprtrails`) are part of the "look" in which rices
  - **keybinds**: live-theme-switch keybinds (`SUPER+CTRL+T` toggle,
    `SUPER+SHIFT+T` menu) — what do popular rices bind?
  - **env**: cursor/font/`GTK_THEME` env vars that the rice surfaces
    depend on
  - **login-boot**: SDDM/Plymouth/GRUB themes that match the rest of the
    rice

If a structural component truly has no theming angle in the corpus, say
so briefly in `gotchas.md` and move on — do not pad.

Attribution: every harvested claim/technique must cite the rice (repo
name, ideally with the file path or commit). The existing `styling.md`
files are the template for citation density.

================================================================================
3. WHAT YOU ARE LOOKING FOR
================================================================================

For each component, harvest:

  (a) **Theming idioms** — how the rice expresses its palette in this
      component. (e.g. waybar: split `colors.css` from `style.css` and
      `@import`; rofi: tiny `*{}` block that `@import`s a shared layout;
      fuzzel: `include=` a colors-only file; hyprlock: literal hex baked
      at generate-time.)

  (b) **Archetypes / patterns** — recurring shapes/strategies seen across
      3+ rices. The existing `styling.md` lists these for waybar
      (floating islands, separated pills, single lozenge, edge-to-edge,
      powerline, dock) and launcher (centered blurred pastel, adi1090x
      rofi, minimal dmenu, accent-bordered). Find the equivalents for
      {{COMPONENT}} if they exist; if not, say "no community archetypes
      — recipe is the default."

  (c) **Battle-tested techniques** — concrete tricks (a specific border
      width, a specific CSS selector, a specific dispatcher chain) that
      appear across multiple top rices and are non-obvious. Cite each.

  (d) **Cross-surface coherence** — anything in this component that has
      to match {{COMPONENT}}'s sibling surfaces (e.g. launcher pill
      radius should match waybar pill radius; lock-screen color should
      reuse hyprland `$accent`; mako border should reuse the same accent
      the bar uses for active workspace). Call these out — they're the
      highest-value finds for a theming-first plugin.

  (e) **Version cliffs and footguns** — when something changed across
      Hyprland or upstream versions and a stale community config still
      ships the old form. (See `CHANGELOG.md` `0.13.0` for examples —
      this is exactly the class of finding that prevents real-world
      breakage.)

================================================================================
4. OUTPUT — update files in real time as you research
================================================================================

Do not produce a separate "research-notes.md". Update the live reference
files in your component's folder as findings accrete. After the precursor
refactor, every theming-relevant artifact for {{COMPONENT}} now lives IN
your folder — recipe, color template, styling library, gotchas, all of it.

  - **`template.md`** — THE RECIPE. This is what the component-writer
    agent fills in for every new user, so it's the highest-leverage
    artifact in the folder. If the corpus shows that:
      - the current default archetype is out of date (corner radius,
        padding, workspace-indicator style),
      - the default modules / sections / `format` strings have drifted
        from what every popular rice ships,
      - the color references aren't wired through the palette contract
        (every color must be a `_shared/colors-contract.md` key, NEVER
        literal hex — re-theming silently breaks otherwise),
      - the recipe is missing a cross-surface coherence move the corpus
        treats as standard (the layer-rule blur, the `@import` of
        `colors.css`, the `include=` of `colors.ini`, the `@theme`
        indirection),
    then UPDATE the recipe. Cite the rices the change is drawn from in a
    brief comment.

  - **`<app>.tmpl` files IN your component folder** — THE ENGINE COLOR
    TEMPLATES. The rice engine renders these on every `rice apply` /
    wallpaper cycle / profile switch. After the precursor refactor they
    live next to `template.md` (e.g. `components/waybar/waybar.tmpl`,
    `components/notifications/{mako,dunst,swaync}.tmpl`,
    `components/widgets/{ags,eww,quickshell}.tmpl`,
    `components/terminal/{kitty,btop,cava}.tmpl`,
    `components/launcher/{rofi,fuzzel,wofi}.tmpl`,
    `components/shell-prompt/{starship,oh-my-posh,fish}.tmpl`,
    `components/look-feel/hyprland.tmpl`,
    `components/utilities/wlogout.tmpl`).
    Rules:
      - the `.tmpl` must export EVERY palette key the component's
        `template.md` actually references — v0.13 fixed a class of bug
        where the `.tmpl` emitted names the component didn't use, so
        re-themes silently broke the styling. If you add a new color
        reference to `template.md`, add it to the `.tmpl`. If you find
        a reference in the `.tmpl` nothing uses, remove it.
      - the wrap format must match the per-app convention in
        `_shared/colors-contract.md` (Hyprland: `rgb(hex)`; CSS:
        `#hex;`; kitty/btop: `#hex`; fuzzel: `hexff`; fish: bare `hex`).
        Get this wrong and the app fails to parse or silently falls
        back.
      - if the corpus reveals a new derived color the community treats
        as standard (e.g. `accent2`, `muted`, the full named palette
        `blue`/`magenta`/`cyan` for per-module-hue waybar styles — both
        added in v0.13), add it locally.
      - DO NOT add a NEW palette key (one that doesn't already exist in
        `_shared/palette-schema.md`). New keys ripple across every
        other component's `.tmpl` and the engine's renderers. If you
        think one is warranted, FLAG IT in your return report instead
        of adding it — the orchestrator will handle the cross-cutting
        change.

  - **`styling.md`** — append to existing sections under the patterns
    already in place ("How the community styles it" / "Battle-tested
    techniques"). PRESERVE the verified content from v0.13 — only add,
    refine, or correct with a citation. Create the file for a structural
    component only if you found real, attributable theming material.

  - **`gotchas.md`** — add any cross-rice footguns / D-Bus mutexes /
    version cliffs / layer-namespace issues / "this widget needs X to
    render" notes you found, including any `.tmpl`/`template.md`
    coherence bugs you fixed (so the next researcher knows to check for
    the same class).

  - **`interview.md`** — only if the corpus surfaces a sub-question
    that's genuinely missing (an archetype not currently offered). Don't
    expand the interview just to expand it — `_interview-protocol.md`
    is strict about asking discipline.

  - **`schema.md`** — only update if `interview.md` changed, OR if a
    template change needs a new key in `answers.json` to drive it.

  - **`README.md`** — update the "Files in this folder" table if a
    `.tmpl` now lives in the folder (post-refactor it does), and the
    "Related components" section if your findings reveal new
    cross-surface deps.

  - **`../../theming/*.md`** — if your finding affects cross-surface
    theming (a new wallpaper-daemon recipe, a new GTK quirk, a new
    engine behaviour a `.tmpl` change depends on), update the matching
    file under `references/theming/`. `theming-architecture.md` and
    `engine.md` are the most likely targets when a `.tmpl` changes
    shape.

  - **`../../_shared/colors-contract.md`** — DO NOT EDIT. If you think
    the contract needs a change (a new key, a new wrap format), flag it
    in your return report. Cross-cutting contract changes are an
    orchestrator-level decision, not a per-component one.

Commit cadence: one commit per file once you're done editing it.
Message format: `{{COMPONENT}}: <one-line summary of what the research
changed>`. For `.tmpl` edits: `{{COMPONENT}}: <app>.tmpl — <change>`.
At the very end, push.

================================================================================
5. QUALITY BAR
================================================================================

DO:
  - Cite every non-obvious claim with the repo + (ideally) file path. The
    existing `styling.md` is the bar.
  - Prefer verbatim quotes from the dotfile's actual config over
    paraphrase.
  - Verify version-sensitive claims against the Hyprland wiki / source /
    the upstream package's README before writing them. v0.13 found many
    existing claims that were wrong against upstream — assume your
    harvest will too.
  - When two top rices disagree (e.g. tile-vs-float master), present
    both and name the rices.

DO NOT:
  - Fabricate. If you didn't see it in the corpus, don't put it in. A
    short, honest doc beats a padded, hallucinated one.
  - Silently rewrite content the v0.13 accuracy pass verified — if you
    disagree with an existing claim, leave the existing claim in place
    and add your counter-evidence with the citation; let the next
    reviewer reconcile.
  - Add screenshots, emoji, or marketing language. The reference docs
    are terse, declarative, and dense with attribution.
  - Bloat the interview with new sub-questions unless the corpus proves
    a clear gap.
  - Touch any other component's folder, except for cross-cutting
    `theming/` files where the change is genuinely cross-surface.

Return a short report (under 200 words) summarising: which corpus repos
you actually read for this component, which files you updated and the
one-line nature of each update, any open conflicts you left for a human,
and any component-folder cross-refs you think the orchestrator should
know about so the related component's agent can react.
