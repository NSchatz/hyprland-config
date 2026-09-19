# A preview of a config that autostarts nothing must SAY so.
#
# This exists because of an actual confusion it caused: a preview booted to a black screen with
# a cursor and nothing else, and the honest answer was that the staged config had no `exec-once`
# entries and `force_default_wallpaper = 0`, so there was no bar, no terminal and no wallpaper
# to draw. The VM was fine. A preview that cannot tell those two situations apart is worse than
# no preview, because it makes a working tool look broken.

if ! command -v python3 >/dev/null 2>&1; then
    skip "preview autostart reporting" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir preview-autostart)"
trap 'rm -rf "$tmp"' EXIT

py() { PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c "$1" 2>&1; }

# ---------------------------------------------------------------------------------------
# A staging dir that starts nothing.
# ---------------------------------------------------------------------------------------
empty="$tmp/empty"; mkdir -p "$empty"
printf 'general {\n    gaps_in = 6\n}\n' > "$empty/looknfeel.conf"
printf 'bind = SUPER, Q, exec, kitty\n' > "$empty/binds.conf"

n="$(py "from ricelib.preview.previewcli import autostart_entries; print(len(autostart_entries('$empty')))")"
assert_eq "0" "$n" "a config with no exec-once reports zero autostart entries"

# A `bind = ..., exec, kitty` is NOT an autostart. Counting it would be worse than counting
# nothing: the preview would claim a bar was coming and then never show one.
has_exec="$(py "from ricelib.preview.previewcli import autostart_entries; print('kitty' in ' '.join(autostart_entries('$empty')))")"
assert_eq "False" "$has_exec" "a keybind that execs something is not mistaken for an autostart"

# ---------------------------------------------------------------------------------------
# A staging dir shaped like real rice output.
# ---------------------------------------------------------------------------------------
full="$tmp/full"; mkdir -p "$full"
cat > "$full/autostart.conf" <<'EOF'
exec-once = waybar
exec-once = mako
  exec-once   =   hyprpaper
# exec-once = commented-out
EOF
printf 'general {\n    gaps_in = 6\n}\n' > "$full/looknfeel.conf"

entries="$(py "from ricelib.preview.previewcli import autostart_entries; print(','.join(autostart_entries('$full')))")"
assert_eq "waybar,mako,hyprpaper" "$entries" \
    "exec-once entries are found across the staged files, whitespace and all"

n="$(py "from ricelib.preview.previewcli import autostart_entries; print(len(autostart_entries('$full')))")"
assert_eq "3" "$n" "a commented-out exec-once is not counted"

# ---------------------------------------------------------------------------------------
# An unreadable or absent staging dir answers, rather than raising into the CLI.
# ---------------------------------------------------------------------------------------
missing="$(py "from ricelib.preview.previewcli import autostart_entries; print(len(autostart_entries('$tmp/does-not-exist')))")"
assert_eq "0" "$missing" "a missing staging dir reports zero rather than raising"
