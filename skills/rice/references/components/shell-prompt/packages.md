# shell-prompt — packages

Per-pick package map. The installer agent reads this file when assembling the global `PKGS`
list. Only the packages whose pick is active are appended (don't install every shell, every
fetch, every modern-CLI tool blindly).

## Shells

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| `bash` | `bash` | repo | Almost always preinstalled; emit anyway with `--needed`. |
| `zsh`  | `zsh`  | repo | Pulls `zsh-completions` indirectly only if user wants — separate opt. |
| `fish` | `fish` | repo | The full interactive shell; built-in autosuggest + completions, no plugins needed for the headline UX. |
| `keep-current` | — | — | Nothing added. |

## Prompt engines

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| `starship`   | `starship` | repo | Cross-shell; one binary. |
| `oh-my-posh` | `oh-my-posh-bin` | **AUR** | No official repo package on Arch. The `-bin` AUR variant is the canonical install (upstream's official path is the install script — also fine, but a packaged AUR build is consistent with the rest of the install batch). |
| `native`     | — | — | Built-in `PS1` / `PROMPT` / `fish_prompt`; no install. |
| `keep-current` | — | — | Nothing added. |

## Startup fetch

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| `fastfetch` | `fastfetch` | repo | Actively maintained; default. |
| `neofetch`  | `neofetch`  | repo | **Upstream archived since 2024.** Still installable; offer only if explicitly asked. |
| `none`      | — | — | Nothing added. |

A Nerd Font (group 13 — `fonts`) is required for the fetch logo + glyphs. The fetch package
itself doesn't pull a font; the `fonts` component's package list owns that.

## Modern-CLI

Only emit a package when the corresponding alias / init line is present in the managed block.
The schema's `shell_prompt.modern_cli` array drives this.

| Pick | Package | Repo / AUR | Extra | Notes |
|---|---|---|---|---|
| `eza`     | `eza`     | repo | — | Modern `ls`. Pairs with the alias-block `ll`/`la` rewrite. |
| `bat`     | `bat`     | repo | — | `cat` with syntax highlighting; doubles as `MANPAGER`. |
| `zoxide`  | `zoxide`  | repo | — | Smart `cd` (`z`). On zsh init **after** `compinit`. |
| `fzf`     | `fzf`     | repo | — | Fuzzy finder. ≥ 0.48 for the `--bash` / `--zsh` / `--fish` flags. |
| `atuin`   | `atuin`   | repo | `bash-preexec` *(bash only)* | Searchable history DB. On bash also append `bash-preexec` to `PKGS` — `atuin init bash` requires it as a hook host. |

## fish plugins (fisher) — NOT a package

There is **no** `fisher` package in repo or AUR on Arch. Don't try to map `jorgebucaran/fisher`
through this file. The install path is a one-liner run **inside fish** after fish is installed:

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update
```

`fisher update` reads `~/.config/fish/fish_plugins` (one `owner/repo` per line) and installs the
listed set — including `jorgebucaran/fisher` itself if present (so the manager keeps itself
current).

The install script prints this one-liner as a follow-up step whenever
`shell_prompt.fisher` is non-empty. See `gotchas.md` → "fisher is `curl`-installed".

The plugin set + `fish_plugins` are part of the rice — track them with the **dotfiles** skill so
they survive reinstall.

## Assembly rule

```bash
# Shell
case "$(jq -r .shell_prompt.shell answers.json)" in
    bash) pkgs+=("bash") ;;
    zsh)  pkgs+=("zsh")  ;;
    fish) pkgs+=("fish") ;;
esac

# Prompt engine
case "$(jq -r .shell_prompt.prompt answers.json)" in
    starship)   pkgs+=("starship") ;;
    oh-my-posh) pkgs+=("oh-my-posh-bin") ;;
esac

# Fetch
case "$(jq -r .shell_prompt.fetch answers.json)" in
    fastfetch) pkgs+=("fastfetch") ;;
    neofetch)  pkgs+=("neofetch")  ;;
esac

# Modern-CLI (one entry per picked tool)
while read -r tool; do
    pkgs+=("$tool")
    # atuin on bash also needs bash-preexec
    [ "$tool" = "atuin" ] && [ "$(jq -r .shell_prompt.shell answers.json)" = "bash" ] && \
        pkgs+=("bash-preexec")
done < <(jq -r '.shell_prompt.modern_cli[]?' answers.json)
```

The repo/AUR column is informational — `install.sh` auto-routes each name via `pacman -Si` so a
package that drifts between repo and AUR doesn't break the install.

## Cross-references

- Shell pick / prompt engine / fetch / modern-CLI types → `schema.md`
- The aliases / init lines that the modern-CLI packages back → `template.md`
- Why fisher isn't in this table → `gotchas.md` → "fisher is `curl`-installed, NOT a package"
- Nerd Font requirement for the fetch tool's logo → `../../theming/fonts.md` (group 13)
