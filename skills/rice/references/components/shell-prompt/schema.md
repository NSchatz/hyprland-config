# shell-prompt — answers.json slice

Keys this component owns under the top-level `shell_prompt` key.

```json
{
  "shell_prompt": {
    "shell":       "fish | zsh | bash | keep-current",
    "prompt":      "starship | oh-my-posh | native | keep-current",
    "fish_colors": true,
    "fetch":       "fastfetch | neofetch | none",
    "fisher":      ["jorgebucaran/fisher", "jorgebucaran/autopair.fish",
                    "PatrickF1/fzf.fish", "meaningful-ooo/sponge",
                    "franciscolourenco/done"],
    "aliases":     true,
    "modern_cli":  ["eza", "bat", "zoxide", "fzf", "atuin"]
  }
}
```

## Types

| Key | Type | Required | Notes |
|---|---|---|---|
| `shell_prompt.shell` | string enum | yes | `"keep-current"` means "use whatever the user's login shell is, don't write a new rc — only update fish colors if also chosen". Whatever's picked goes into the install batch (idempotent `--needed`). |
| `shell_prompt.prompt` | string enum | yes | `"native"` means a thin built-in prompt (`PS1` / `PROMPT` / `fish_prompt`). `"keep-current"` means do not touch the user's prompt setup; skip the engine package and the init line. |
| `shell_prompt.fish_colors` | bool | yes | When `true` **and** `shell == "fish"`, register the `fish` manifest line (renders `~/.config/fish/conf.d/zz-hypr-rice-colors.fish`). Coerce to `false` automatically when `shell != "fish"`. |
| `shell_prompt.fetch` | string enum | yes | Inserts a guarded interactive-only line into the managed block. `"none"` skips both the line and the package. |
| `shell_prompt.fisher` | string[] | yes (may be empty) | List of `owner/repo` fisher plugins. Empty `[]` when not fish or when the user said no. The manager itself (`jorgebucaran/fisher`) must be the first entry whenever the list is non-empty. |
| `shell_prompt.aliases` | bool | yes | When `true`, write the cross-shell aliases block (`ll`, `la`, `..`, `grep --color`). Independent of `modern_cli`. |
| `shell_prompt.modern_cli` | string[] | yes (may be empty) | Subset of `["eza","bat","zoxide","fzf","atuin"]`. Each entry emits a guarded alias / init line and is added to the install batch. `atuin` on **bash** also pulls `bash-preexec` (see `gotchas.md`). |

## Implicit constraints (validate before render)

- If `shell == "keep-current"` and `prompt == "keep-current"` and `fish_colors == false` and
  `fetch == "none"` and `aliases == false` and `modern_cli == []`, the component is a no-op —
  emit nothing and skip the manifest entries.
- If `prompt == "native"`, no engine package is installed and no `STARSHIP_CONFIG` /
  `oh-my-posh init` line is written.
- If `shell != "fish"`, `fish_colors` and `fisher` are both forced to inert values
  (`false` / `[]`) regardless of what the interview recorded.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (shell-prompt) | Writes the managed block into the chosen shell's rc (`~/.bashrc` / `~/.zshrc` / `~/.config/fish/config.fish`). Renders the rice-owned `~/.config/hypr-rice/starship.toml` or `rice.omp.json` if `prompt` is an engine. Renders `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` if `fish_colors`. Writes `~/.config/fish/fish_plugins` (the file fisher reads) if `fisher` is non-empty. |
| `hyprland-component-writer` (theming engine) | Adds the matching manifest lines (see `../../theming/engine.md`) so `rice apply` re-renders the prompt configs from the palette. |
| `hyprland-package-installer` | Maps `shell` + `prompt` + `fetch` + each `modern_cli` entry through `packages.md` and appends to `PKGS`. Fisher is **not** a package (see `gotchas.md`); the install script prints the `curl` bootstrap one-liner. |
| `verify-shell.sh` (validator) | Parse-tests the rc(s) written. |

## Validation

- `shell` ∈ {`fish`, `zsh`, `bash`, `keep-current`} — reject anything else.
- `prompt` ∈ {`starship`, `oh-my-posh`, `native`, `keep-current`}.
- `fetch` ∈ {`fastfetch`, `neofetch`, `none`}.
- `fisher` entries match `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` (`owner/repo`).
- `modern_cli` entries are a subset of the allow-list above.
- `fish_colors` and `aliases` are strict booleans (not `"true"`/`"false"` strings).

## Palette dependency

When `prompt == "starship"` the rendered `~/.config/hypr-rice/starship.toml` references the
palette keys listed in `_shared/colors-contract.md` row `starship`
(`bg fg surface muted accent accent2 red green yellow blue magenta cyan`). Same set for
`oh-my-posh`. For `fish_colors`, the full `fish_color_*` set is bound to the rice palette per
the `fish` row in the contract. Missing palette keys fail the render.
