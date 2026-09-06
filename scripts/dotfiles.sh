#!/usr/bin/env bash
# Version-control the user's Hyprland / desktop configs in git. Three methods:
#   bare    : bare git repo tracking files in place in $HOME (no symlinks)  [recommended]
#   stow     : GNU Stow symlink farm from a ~/dotfiles repo
#   chezmoi  : chezmoi-managed source repo
#
# Usage:
#   dotfiles.sh init <bare|stow|chezmoi> [remote-url]
#   dotfiles.sh add <path> [path...]      # start tracking path(s)
#   dotfiles.sh add-defaults              # track the common Hyprland/desktop config paths that exist
#   dotfiles.sh commit "<message>"        # stage tracked changes + commit
#   dotfiles.sh push                      # push to origin
#   dotfiles.sh status                    # short status
#   dotfiles.sh method                    # print the configured method
#
# Method + repo location recorded in <config base>/hypr-rice/dotfiles.conf, the base being
# $XDG_CONFIG_HOME when it is an absolute path and $HOME/.config otherwise - the same one
# decision every other script here makes (scripts/xdg-config.sh).
set -uo pipefail

_here_df="$(cd "$(dirname "$0")" && pwd)"
_xdg_lib=""
for _c in "$_here_df/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0 or in \$CLAUDE_PLUGIN_ROOT/scripts." >&2
    exit 2
fi
# shellcheck source=xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr-rice; then
    echo "DOTFILES=refused-no-config-dir"
    exit 2
fi
CONFIG_BASE="$XDG_CONFIG_BASE"

STATE="${DOTFILES_STATE:-$XDG_CONFIG_TARGET/dotfiles.conf}"
BARE_DIR="${DOTFILES_BARE_DIR:-$HOME/.dotfiles}"
STOW_DIR="${DOTFILES_STOW_DIR:-$HOME/dotfiles}"

get_method() { sed -n 's/^method=//p' "$STATE" 2>/dev/null | head -1; }
dotbare()    { git --git-dir="$BARE_DIR" --work-tree="$HOME" "$@"; }

# The common desktop config surfaces, under whichever base this machine actually uses.
DEFAULT_PATHS=(
    "$CONFIG_BASE/hypr" "$CONFIG_BASE/hypr-rice" "$CONFIG_BASE/waybar"
    "$CONFIG_BASE/kitty" "$CONFIG_BASE/rofi" "$CONFIG_BASE/wofi"
    "$CONFIG_BASE/mako" "$CONFIG_BASE/dunst" "$CONFIG_BASE/gtk-3.0"
    "$CONFIG_BASE/gtk-4.0" "$CONFIG_BASE/qt5ct" "$CONFIG_BASE/qt6ct"
    "$CONFIG_BASE/swaync" "$CONFIG_BASE/wlogout" "$CONFIG_BASE/fastfetch"
    "$CONFIG_BASE/starship.toml"
)

cmd="${1:-help}"; shift 2>/dev/null || true

case "$cmd" in
    init)
        method="${1:-}"; remote="${2:-}"
        [ -n "$method" ] || { echo "usage: dotfiles.sh init <bare|stow|chezmoi> [remote]" >&2; exit 2; }
        mkdir -p "$(dirname "$STATE")"
        case "$method" in
            bare)
                [ -d "$BARE_DIR" ] || git init -q --bare "$BARE_DIR"
                dotbare config status.showUntrackedFiles no
                if [ -n "$remote" ]; then dotbare remote remove origin 2>/dev/null; dotbare remote add origin "$remote"; fi
                printf 'method=bare\nbare_dir=%s\n' "$BARE_DIR" > "$STATE"
                echo "DOTFILES_INIT=ok (bare repo at $BARE_DIR; alias: git --git-dir=$BARE_DIR --work-tree=\$HOME)";;
            stow)
                command -v stow >/dev/null 2>&1 || { echo "ERROR: stow not installed" >&2; exit 3; }
                mkdir -p "$STOW_DIR"; [ -d "$STOW_DIR/.git" ] || git -C "$STOW_DIR" init -q
                if [ -n "$remote" ]; then git -C "$STOW_DIR" remote remove origin 2>/dev/null; git -C "$STOW_DIR" remote add origin "$remote"; fi
                printf 'method=stow\nstow_dir=%s\n' "$STOW_DIR" > "$STATE"
                echo "DOTFILES_INIT=ok (stow repo at $STOW_DIR)";;
            chezmoi)
                command -v chezmoi >/dev/null 2>&1 || { echo "ERROR: chezmoi not installed" >&2; exit 3; }
                chezmoi init >/dev/null 2>&1 || true
                [ -n "$remote" ] && chezmoi git -- remote add origin "$remote" >/dev/null 2>&1 || true
                printf 'method=chezmoi\n' > "$STATE"
                echo "DOTFILES_INIT=ok (chezmoi source at $(chezmoi source-path 2>/dev/null))";;
            *) echo "unknown method: $method" >&2; exit 2;;
        esac;;

    add)
        [ "$#" -ge 1 ] || { echo "usage: dotfiles.sh add <path>..." >&2; exit 2; }
        m="$(get_method)"; [ -n "$m" ] || { echo "ERROR: run 'dotfiles.sh init' first" >&2; exit 2; }
        for p in "$@"; do
            pe="${p/#\~/$HOME}"
            [ -e "$pe" ] || { echo "SKIP (missing) $p"; continue; }
            case "$m" in
                bare)    dotbare add -f "$pe" && echo "ADDED $p";;
                chezmoi) chezmoi add "$pe" && echo "ADDED $p";;
                stow)
                    pkg="$(basename "$pe")"; rel="${pe#"$HOME"/}"
                    mkdir -p "$STOW_DIR/$pkg/$(dirname "$rel")"
                    cp -a "$pe" "$STOW_DIR/$pkg/$rel"
                    git -C "$STOW_DIR" add -A
                    echo "STAGED(stow) $p — symlink it with: stow -d $STOW_DIR -t \$HOME $pkg";;
            esac
        done;;

    add-defaults)
        exist=(); for p in "${DEFAULT_PATHS[@]}"; do [ -e "$p" ] && exist+=("$p"); done
        [ "${#exist[@]}" -gt 0 ] || { echo "no default config paths found to track"; exit 0; }
        "$0" add "${exist[@]}";;

    commit)
        msg="${1:-update dotfiles}"; m="$(get_method)"
        case "$m" in
            bare)    dotbare add -u; dotbare commit -q -m "$msg" && echo "COMMITTED" || echo "nothing to commit";;
            stow)    git -C "$STOW_DIR" add -A; git -C "$STOW_DIR" commit -q -m "$msg" && echo "COMMITTED" || echo "nothing to commit";;
            chezmoi) chezmoi git -- add -A >/dev/null 2>&1; chezmoi git -- commit -m "$msg" >/dev/null 2>&1 && echo "COMMITTED" || echo "nothing to commit";;
            *) echo "ERROR: run 'dotfiles.sh init' first" >&2; exit 2;;
        esac;;

    push)
        m="$(get_method)"
        case "$m" in
            bare)    dotbare push -u origin HEAD;;
            stow)    git -C "$STOW_DIR" push -u origin HEAD;;
            chezmoi) chezmoi git -- push;;
            *) echo "ERROR: not initialized" >&2; exit 2;;
        esac;;

    status)
        m="$(get_method)"
        case "$m" in
            bare)    dotbare status -sb;;
            stow)    git -C "$STOW_DIR" status -sb;;
            chezmoi) chezmoi git -- status -sb;;
            *) echo "not initialized";;
        esac;;

    method) get_method || echo "(none)";;
    help|*) sed -n '2,18p' "$0";;
esac
