#!/usr/bin/env bash
# Scaffold a self-contained rice engine into the rice state directory ($RICE_DIR, default
# <config base>/hypr-rice - see Env: below):
#   - templates/        : the .tmpl color templates (copied from the plugin; user-editable)
#   - templates.list    : the render manifest (name <tab> template <tab> output <tab> reload)
#   - render-templates.sh + rice : the engine + CLI (so it runs without the plugin)
#   - palette.conf      : seeded with Catppuccin Mocha if absent (change via rice)
#   - profiles/         : saved theme profiles (used by rice)
# Idempotent: never clobbers an existing palette.conf, templates.list, or user-edited templates
# unless --force is passed.
#
# Usage: rice-init.sh [--force]
#
# Env:
#   RICE_DIR  where the engine is scaffolded (explicit override; wins over XDG_CONFIG_HOME).
#             Otherwise <config base>/hypr-rice, where the base is $XDG_CONFIG_HOME when it
#             is an absolute path and $HOME/.config otherwise. scripts/xdg-config.sh makes
#             that decision for the whole plugin - scaffolding into one directory while the
#             render engine reads another is exactly the split it exists to prevent.
set -euo pipefail

_here_init="$(cd "$(dirname "$0")" && pwd)"
_xdg_lib=""
for _c in "$_here_init/xdg-config.sh" \
          "$_here_init/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin." >&2
    exit 2
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr-rice "${RICE_DIR:-}"; then
    echo "RICE_INIT=refused-no-config-dir"
    exit 2
fi
RICE_DIR="$XDG_CONFIG_TARGET"
# Prefer CLAUDE_PLUGIN_ROOT, but fall back to deriving the plugin's rice dir from this script's own
# location (<plugin>/skills/rice/scripts/rice-init.sh) so it works even when the env var isn't
# exported (e.g. invoked directly — which otherwise aborted with "CLAUDE_PLUGIN_ROOT not set").
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/skills/rice/references/theming" ]; then
    SRC="${CLAUDE_PLUGIN_ROOT}/skills/rice"
else
    _here="$(cd "$(dirname "$0")" && pwd)"
    SRC="$(cd "$_here/.." && pwd)"   # skills/rice
fi
[ -d "$SRC/references/theming" ] || { echo "ERROR: cannot find the plugin's rice templates (looked in $SRC). Set CLAUDE_PLUGIN_ROOT." >&2; exit 2; }
force=0; [ "${1:-}" = "--force" ] && force=1

mkdir -p "$RICE_DIR/templates" "$RICE_DIR/profiles"

# Install shipped preset profiles (Catppuccin/Gruvbox/Nord/Tokyo Night/Rosé Pine).
# Don't clobber a profile of the same name the user may have customized (unless --force).
if [ -d "$SRC/assets/profiles" ]; then
    for p in "$SRC"/assets/profiles/*.conf; do
        base="$(basename "$p")"; dest="$RICE_DIR/profiles/$base"
        if [ ! -e "$dest" ] || [ "$force" -eq 1 ]; then cp "$p" "$dest"; fi
    done
fi

# Copy templates (preserve user edits unless --force).
for t in "$SRC"/references/components/*/*.tmpl \
         "$SRC"/references/theming/*.tmpl; do
    base="$(basename "$t")"; dest="$RICE_DIR/templates/$base"
    if [ ! -e "$dest" ] || [ "$force" -eq 1 ]; then cp "$t" "$dest"; fi
done

# Restore points: the engine must be able to back up and put back without the plugin, so the
# library and the restore command are installed beside it (always refreshed, plugin-owned code).
PLUGIN_SCRIPTS="$(cd "$SRC/../.." && pwd)/scripts"
cp "$PLUGIN_SCRIPTS/restore-point.sh"      "$RICE_DIR/restore-point.sh"
cp "$PLUGIN_SCRIPTS/rice-restore.sh"       "$RICE_DIR/rice-restore.sh"
cp "$PLUGIN_SCRIPTS/backup-path.sh"        "$RICE_DIR/backup-path.sh"
# The install record and the package-install routine that writes it: the generated install.sh
# ships to new machines with the dotfiles and must be able to record what it did there, without
# the plugin. Same for the browser-preference record and its removal path - a preference this
# plugin set has to be removable from the machine it was set on.
cp "$PLUGIN_SCRIPTS/install-record.sh"     "$RICE_DIR/install-record.sh"
cp "$PLUGIN_SCRIPTS/install-packages.sh"   "$RICE_DIR/install-packages.sh"
cp "$PLUGIN_SCRIPTS/firefox-prefs.sh"      "$RICE_DIR/firefox-prefs.sh"
chmod +x "$RICE_DIR"/install-record.sh "$RICE_DIR"/install-packages.sh "$RICE_DIR"/firefox-prefs.sh
# The engine must answer "where does configuration live?" the same way the plugin does when
# it runs without the plugin, so the one decision ships beside it. Every installed script
# above looks for it next to itself first.
cp "$PLUGIN_SCRIPTS/xdg-config.sh"         "$RICE_DIR/xdg-config.sh"
chmod +x "$RICE_DIR"/restore-point.sh "$RICE_DIR"/rice-restore.sh "$RICE_DIR"/backup-path.sh "$RICE_DIR"/xdg-config.sh

# Install the engine + CLI + wallpaper helpers (always refresh — plugin-owned code).
cp "$SRC/scripts/render-templates.sh"      "$RICE_DIR/render-templates.sh"
cp "$SRC/scripts/set-wallpaper.sh"         "$RICE_DIR/set-wallpaper.sh"
cp "$SRC/scripts/palette-from-wallpaper.sh" "$RICE_DIR/palette-from-wallpaper.sh"
cp "$SRC/assets/rice"                      "$RICE_DIR/rice"
cp "$SRC/assets/wallpapers.tsv"            "$RICE_DIR/wallpapers.tsv"   # curated theme wallpaper catalog
cp "$SRC/assets/accents.tsv"               "$RICE_DIR/accents.tsv"      # per-scheme accent variants
chmod +x "$RICE_DIR"/render-templates.sh "$RICE_DIR"/set-wallpaper.sh "$RICE_DIR"/palette-from-wallpaper.sh "$RICE_DIR"/rice

# Browser-theming helpers (Issue 14/15 — copied unconditionally; only used when
# browser_theming.opt_in == true, but live in the engine so a user opting in
# post-install doesn't need to re-run rice-init).
mkdir -p "$RICE_DIR/browser"
if [ -f "$SRC/assets/scripts/firefox-bootstrap.sh" ]; then
    cp "$SRC/assets/scripts/firefox-bootstrap.sh" "$RICE_DIR/firefox-bootstrap.sh"
    chmod +x "$RICE_DIR/firefox-bootstrap.sh"
fi
if [ -f "$SRC/assets/scripts/firefox-restart.sh" ]; then
    cp "$SRC/assets/scripts/firefox-restart.sh" "$RICE_DIR/firefox-restart.sh"
    chmod +x "$RICE_DIR/firefox-restart.sh"
fi
# Static browser assets the bootstrap script copies into the Firefox profile.
if [ -f "$SRC/references/components/browser/userChrome.css" ]; then
    cp "$SRC/references/components/browser/userChrome.css" "$RICE_DIR/browser/userChrome.css"
fi
if [ -f "$SRC/references/components/browser/user.js" ]; then
    cp "$SRC/references/components/browser/user.js" "$RICE_DIR/browser/user.js"
fi

# Default manifest (only the cleanly include-able apps; others added by their skills).
mf="$RICE_DIR/templates.list"
if [ ! -f "$mf" ] || [ "$force" -eq 1 ]; then
    T="$RICE_DIR/templates"
    {
        printf '# name\ttemplate\toutput\treload-cmd\n'
        printf 'hyprland\t%s/hyprland.tmpl\t~/.config/hypr/colors.conf\thyprctl reload\n' "$T"
        printf 'kitty\t%s/kitty.tmpl\t~/.config/kitty/colors.conf\tpkill -SIGUSR1 -x kitty\n' "$T"
        printf 'waybar\t%s/waybar.tmpl\t~/.config/waybar/colors.css\tkillall -SIGUSR2 waybar\n' "$T"
        printf 'wofi\t%s/wofi.tmpl\t~/.config/wofi/colors.css\t\n' "$T"
        printf 'rofi\t%s/rofi.tmpl\t~/.config/rofi/colors.rasi\t\n' "$T"
        printf 'gtk4\t%s/gtk4.tmpl\t~/.config/gtk-4.0/gtk.css\t\n' "$T"
    } > "$mf"
fi

# Seed a palette so `rice apply` works immediately (Catppuccin Mocha; change via rice).
pal="$RICE_DIR/palette.conf"
if [ ! -f "$pal" ]; then
    cat > "$pal" <<'EOF'
# hypr-rice palette — source of truth. Hex without '#'. Change via the rice skill or edit here.
scheme=catppuccin-mocha
bg=1e1e2e
fg=cdd6f4
surface=313244
muted=6c7086
cursor=f5e0dc
accent=cba6f7
accent2=89b4fa
red=f38ba8
green=a6e3a1
yellow=f9e2af
blue=89b4fa
magenta=f5c2e7
cyan=94e2d5
color0=45475a
color1=f38ba8
color2=a6e3a1
color3=f9e2af
color4=89b4fa
color5=f5c2e7
color6=94e2d5
color7=bac2de
color8=585b70
color9=f38ba8
color10=a6e3a1
color11=f9e2af
color12=89b4fa
color13=f5c2e7
color14=94e2d5
color15=a6adc8
font_ui=Inter 11
font_mono=JetBrainsMono Nerd Font 11
EOF
fi

echo "RICE_DIR=$RICE_DIR"
echo "RICE_INIT=done"
