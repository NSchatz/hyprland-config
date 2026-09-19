# Sources - skills/rice/references/components/shell-prompt/styling.md

Research provenance for `skills/rice/references/components/shell-prompt/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- btop themes — [catppuccin/btop](https://github.com/catppuccin/btop), [themes dir](https://github.com/catppuccin/btop/tree/main/themes), [README](https://github.com/catppuccin/btop/blob/main/README.md), [lokesh-krishna/catppuccin-btop theme](https://github.com/lokesh-krishna/catppuccin-btop/blob/main/catppuccin.theme)
- cava config — [karlstav/cava example config](https://raw.githubusercontent.com/karlstav/cava/master/example_files/config), [catppuccin/cava](https://github.com/catppuccin/cava), [cava README](https://github.com/catppuccin/cava/blob/main/README.md)
- fastfetch — [Configuration wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration), [Logo options wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options), [fastfetch(1) man page](https://man.archlinux.org/man/extra/fastfetch/fastfetch.1.en)
- starship — [Catppuccin Powerline preset](https://starship.rs/presets/catppuccin-powerline), [Gruvbox Rainbow preset](https://starship.rs/presets/gruvbox-rainbow), [Presets index](https://starship.rs/presets/), [catppuccin/starship](https://github.com/catppuccin/starship)
- oh-my-posh — [Colors & palette docs](https://ohmyposh.dev/docs/configuration/colors), [Segment/block config](https://ohmyposh.dev/docs/configuration/general), [pywal palette discussion #6010](https://github.com/JanDeDobbeleer/oh-my-posh/discussions/6010), [polarNord theme example](https://github.com/MirkoR89/polarNord)
- fish — [Interactive use / `fish_color_*`](https://fishshell.com/docs/current/interactive.html), [`set_color`](https://fishshell.com/docs/current/cmds/set_color.html), [`fish_config`](https://fishshell.com/docs/current/cmds/fish_config.html), [catppuccin/fish theme files](https://github.com/catppuccin/fish), [pywal fish template PR #568](https://github.com/dylanaraps/pywal/pull/568)
- distro dotfiles — [HyDE](https://github.com/HyDE-Project/HyDE), [ml4w-dotfiles](https://gitlab.com/xeroxero8x/ml4w-dotfiles), [caelestia-dots/fish](https://github.com/caelestia-dots/fish), [It's FOSS: best Hyprland dotfiles](https://itsfoss.com/best-hyprland-dotfiles/)

**Config corpus read for the techniques catalog:**
- catppuccin/btop `themes/catppuccin_mocha.theme` (per-box accents, gradient triples) and real `btop.conf`s — JaKooLit `config/btop/btop.conf` (`theme_background=False`), basecamp/omarchy `config/btop/btop.conf` (`color_theme="current"`, `vim_keys`).
- catppuccin/cava `themes/mocha.cava` (8-stop gradient) and Matt-FTW `.config/cava/config` (`framerate=75`, `bar_width=3`).
- fastfetch `config.jsonc` — JaKooLit (tree-glyph `keyColor` grouping), HyDE-Project/HyDE (`$(hyde-shell fastfetch logo)` dynamic logo, ASCII box framing, GPU-driver row), Matt-FTW (PNG logo, block colors footer).
- starship — catppuccin/starship (`themes/mocha.toml` named palette + nested style markup), the official Gruvbox Rainbow / Pastel Powerline / Nerd Font Symbols presets (`starship.rs/presets`), HyDE `Configs/.config/starship/{starship,powerline}.toml` (`right_format`, custom git_status glyphs), `starship.rs/advanced-config` (transient prompt), and romkatv/powerlevel10k (instant prompt).
- 2026-06-05 corpus pass on `/workspace/.research/corpus.md`:
  - `dusklinux/dusky` `.config/starship.toml` + `.config/matugen/templates/starship-colors.toml` (palette-only matugen template, commented-out post-hook `ln -nfs` over `~/.config/starship.toml` — direct proof starship has no `include`/`@import`).
  - `noctalia-dev/noctalia-shell` `Assets/Templates/terminal/starship.toml` + `starship-predefined.toml` (palette-only `.tmpl` shape — emits **only** a `[palettes.noctalia]` block, no `palette = ...` switch, no format strings; relies on the user's own `starship.toml` to import the palette name).
  - `basecamp/omarchy` `config/starship.toml` (`command_timeout = 200`, `repo_root_format`, the ⇡⇣⇕ git glyph dict).
  - `mylinuxforwork/dotfiles` `dotfiles/.config/ohmyposh/zen.toml` (`[transient_prompt]` block, `[[blocks]] type='rprompt'` for omp's right-side prompt, foreground-template recolor on `.Code`) and `dotfiles/.config/fish/conf.d/{00_init,10-aliases,20-customization,30-autostart}.fish` (per-tool conf.d fragmentation, empty `config.fish`).
  - `caelestia-dots/caelestia` `fish/config.fish` (transient-prompt sugar `starship_transient_prompt_func` + `enable_transience`, `cat ~/.local/state/caelestia/sequences.txt` to inject the matugen-generated ANSI palette into kitty), `starship.toml` (caelestia's `right_format` firehose), `fish/functions/fish_greeting.fish` (custom ASCII art + `fastfetch --key-padding-left 5`).
  - `Matt-FTW/dotfiles` `.config/fish/conf.d/{starship,zoxide,atuin}.fish` (per-tool `type -q` guards, atuin Up-arrow rebind: `bind up _atuin_bind_up` + `\eOA`/`\e[A` variants + insert-mode binds), `.config/starship/starship.toml` + `STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml` (precedent for our `~/.config/hypr-rice/starship.toml` redirect), `.config/fish/fish_plugins` (`catppuccin/fish`, `franciscolourenco/done`, `jorgebucaran/autopair.fish`, plus tools-specific plugins like `gazorby/fish-abbreviation-tips`, `nickeb96/puffer-fish`).
  - `end-4/dots-hyprland` `dots/.config/fish/fish_variables` (the in-the-wild `SETUVAR fish_color_*` block that motivates our `set -g` discipline) and `dots/.config/fish/config.fish` (`alias clear "printf '\033[2J\033[3J\033[1;1H'"` to work around kitty's stale-scrollback clear bug — niche but real).
  - `catppuccin/fish` `themes/catppuccin-mocha.theme` (`.theme` file format reference: no `set` keyword, no `fish_color_` prefix on the LHS, bare hex without `#`).
  - Confirmed-absent: `prasanthrangan/hyprdots` (powerlevel10k via `.p10k.zsh`, not starship/omp), `JaKooLit/Hyprland-Dots` (no prompt engine in tree), `binnewbs/arch-hyprland` (oh-my-zsh `robbyrussell`), `Ax-Shell` / `DankMaterialShell` / `koeqaife/hyprland-material-you` (Quickshell/Python shells — no terminal-prompt component).
