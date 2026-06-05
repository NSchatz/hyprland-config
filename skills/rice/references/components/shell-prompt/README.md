# shell-prompt

The interactive shell — bash / zsh / fish — plus the prompt engine (starship / oh-my-posh / native),
fish's syntax-highlighting colors, the startup fetch (fastfetch / neofetch), the optional fisher
plugin set, and modern-CLI aliases. The shell is the *last themed surface* of the rice: the prompt
recolors with every `rice apply` because its config files are rice-owned.

The terminal emulator itself (kitty/alacritty/foot) is themed by [`terminal`](../terminal/) — this
component does the surface that runs *inside* the terminal.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 17a–17e (shell, prompt engine, fish colors, fetch, fisher) + the optional aliases / modern-CLI follow-up. |
| `schema.md` | The `shell_prompt` slice of `answers.json` — types for `shell`, `prompt`, `fish_colors`, `fetch`, `fisher`, `aliases`, `modern_cli`. |
| `template.md` | The managed-block contents added to each shell's rc: prompt-engine init line, fastfetch line, alias block. Plus the rice-owned prompt config paths (`STARSHIP_CONFIG` / `oh-my-posh init --config`). |
| `starship.tmpl` | Engine template rendered to `~/.config/hypr-rice/starship.toml` on every `rice apply`. Whole-config render — starship has no `include` / palette `import` (see `gotchas.md`). |
| `oh-my-posh.tmpl` | Engine template rendered to `~/.config/hypr-rice/rice.omp.json`. Whole-theme JSON; omp has no `include` either. |
| `fish.tmpl` | Engine template rendered to `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` — fish syntax-highlighting + pager colors. Auto-sourced by fish on every interactive start; uses explicit `set -g` to win over stale `set -U` universals. |
| `styling.md` | Full TUI + prompt styling guide (btop / cava / fastfetch / starship / oh-my-posh / fish) — palette knobs, design anatomy, tasteful recipes, corpus-derived archetypes. |
| `validation.md` | Parse-test commands (`bash -n`, `zsh -n`, `fish --no-execute`). Never `source` to test. |
| `gotchas.md` | Managed-block convention, parse-only-testing, `chsh` ownership, "new shells only", `set -g` vs `set -U` scoping in fish, fisher is `curl`-installed, no-`include` in starship/omp, omp transient prompt, atuin Up-arrow rebind. |
| `packages.md` | The shell + prompt-engine + fetch + modern-CLI package map. |
| `reload.md` | Open a new shell, or `exec <shell>` in place. Live shells keep stale config until restart. |

## Where this component lands

- **Shell rc files** — additions go inside a guarded managed block:
  - bash → `~/.bashrc`
  - zsh → `~/.zshrc`
  - fish → `~/.config/fish/config.fish` (and auto-sourced fragments in `~/.config/fish/conf.d/`)
- **fish syntax-highlighting colors** → `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (rendered
  from `fish.tmpl`; auto-sourced by fish on every interactive start).
- **starship config** → `~/.config/hypr-rice/starship.toml` (rice-owned; `STARSHIP_CONFIG`
  points here). The user's own `~/.config/starship.toml` is left alone.
- **oh-my-posh config** → `~/.config/hypr-rice/rice.omp.json` (rice-owned;
  `oh-my-posh init <shell> --config <this>`).
- **fisher plugin manifest** (fish only) → `~/.config/fish/fish_plugins` (one `owner/repo` per
  line; `fisher update` reproduces the set).

## Managed-block convention

Every edit to a user's rc lives between sentinel comments so re-runs *rewrite* rather than
*append-duplicate*:

```
# >>> hyprland-config managed >>>
# (rice-managed additions; safe to delete this block if you want to detach)
...lines...
# <<< hyprland-config managed <<<
```

See `template.md` for the full per-shell block.

## Related components

- [`terminal`](../terminal/) — the terminal emulator that surrounds this shell. Its 16-color
  palette + Nerd Font are what TUIs (btop, cava, fastfetch) actually inherit; without a Nerd
  Font, the prompt powerline glyphs render as tofu (`□`).
- [`utilities`](../utilities/) — the modern-CLI tools (`eza`, `bat`, `zoxide`, `fzf`, `atuin`)
  whose aliases this component installs. Only emit an alias when the tool was picked there.
- [`theming/engine.md`](../../theming/engine.md) → "Shell & prompt theming" — the render-manifest
  lines that register `fish.tmpl` / `starship.tmpl` / `oh-my-posh.tmpl`.
- [`_shared/colors-contract.md`](../../_shared/colors-contract.md) — the exact variable names the
  three shell templates export (per-row entries for `fish`, `starship`, `oh-my-posh`).
- [`_shared/palette-schema.md`](../../_shared/palette-schema.md) — the palette keys (`accent`,
  `bg`, `fg`, `red`…) the templates substitute.
