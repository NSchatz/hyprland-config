# login-boot — community styling survey

This component is the rare structural one with a real theming angle: SDDM/Plymouth/GRUB
themes that match the rest of the rice. This file captures what the top community Hyprland
rices actually ship for the boot-time chrome — and, crucially, **how few of them ship
anything at all**.

The headline finding is the gap, not the variety: of the 19 actively-maintained rices in
`/workspace/.research/corpus.md`, **only 6 ship anything under `login-boot`**, and they fall
into three structural camps. The other 13 deliberately stop at the user session.

## Corpus tally (verified against the cached corpus)

| Camp | Rices | What they ship |
|---|---|---|
| Bundled tarballs + installer | **HyDE** (`prasanthrangan/hyprdots`) | `Source/arcs/Sddm_Candy.tar.gz`, `Source/arcs/Sddm_Corners.tar.gz`, `Source/arcs/Grub_Pochita.tar.gz`, `Source/arcs/Grub_Retroboot.tar.gz` — extracted by `Scripts/install_pst.sh` |
| Theme repo + scripted installer | **ML4W** (`mylinuxforwork/dotfiles`), **Dusky** (`dusklinux/dusky`) | `dotfiles/.config/ml4w/scripts/ml4w-install-sddm` (clones `mylinuxforwork/ml4w-sddm`); `user_scripts/sddm/grab_hyprland_monitor_configuration_for_sddm_layout.sh` |
| Ship-your-own-greeter | **DankMaterialShell** (`AvengeMedia/DankMaterialShell`), **HyprYou** (`koeqaife/hyprland-material-you`), **fufexan/dotfiles** | `quickshell/Modules/Greetd/` (Quickshell greeter — `dms-greeter`); `greeter/` (PKGBUILD installing `/usr/share/hypryou/greeter`); `system/services/greetd.nix` (NixOS module enabling greetd) |
| **Nothing** | 13 rices: end-4, caelestia-shell, caelestia, noctalia, JaKooLit/Hyprland-Dots, flickowoa (only laptop udev rules), ryan4yin, 1amSimp1e, linuxmobile, Ax-Shell, binnewbs, HyprPanel, Matt-FTW | login chrome is left to the user / the installer in a sibling repo |

JaKooLit's case is special: `JaKooLit/Hyprland-Dots` (the dotfiles repo, in the corpus) ships
**none**, but the sibling `JaKooLit/Arch-Hyprland` installer (not in the corpus per the
corpus's skip rule — it's installer-only, not dotfiles) does the SDDM swap. So in the JaKooLit
ecosystem the user gets SDDM, just not from the dotfiles repo.

Plymouth: **zero** rices in the corpus ship a Plymouth theme. HyDE has GRUB themes (Pochita,
Retroboot) but not Plymouth. The Plymouth recipe in `template.md` is unique to this plugin —
no community precedent to harvest from, so the recipe stays minimal and the gate stays opt-in.

## Archetype A — Bundled tarballs, installer extracts (HyDE)

HyDE is the only corpus rice that ships SDDM **and** GRUB themes as binary tarballs in-tree,
extracted by the installer. From `Scripts/install_pst.sh` (HEAD):

```bash
# sddm
if pkg_installed sddm; then
    if [ ! -d /etc/sddm.conf.d ]; then sudo mkdir -p /etc/sddm.conf.d; fi
    if [ ! -f /etc/sddm.conf.d/kde_settings.t2.bkp ]; then
        echo -e "Select sddm theme:\n[1] Candy\n[2] Corners"
        read -p " :: Enter option number : " sddmopt
        case $sddmopt in
        1) sddmtheme="Candy" ;;
        *) sddmtheme="Corners" ;;
        esac
        sudo tar -xzf ${cloneDir}/Source/arcs/Sddm_${sddmtheme}.tar.gz \
                -C /usr/share/sddm/themes/
        sudo touch /etc/sddm.conf.d/kde_settings.conf
        sudo cp /etc/sddm.conf.d/kde_settings.conf /etc/sddm.conf.d/kde_settings.t2.bkp
        sudo cp /usr/share/sddm/themes/${sddmtheme}/kde_settings.conf /etc/sddm.conf.d/
    fi
fi
```

Patterns to copy:

- **The `.conf.d` filename matters less than the per-theme convention.** HyDE uses
  `/etc/sddm.conf.d/kde_settings.conf` (single file, named after the upstream Plasma
  default). Our recipe uses `/etc/sddm.conf.d/10-rice.conf` (numeric prefix, last-wins
  override). Both work; the SDDM man page (`sddm.conf(5)`) reads every `.conf` in
  `/etc/sddm.conf.d/` in alphabetical order, last-wins. Document this so a user doesn't
  panic when both files coexist on a HyDE-derived install — they're additive, not
  conflicting.
- **`.bkp` of the prior config before overwrite.** HyDE's `kde_settings.t2.bkp` is the
  hand-rolled equivalent of our `cp /etc/sddm.conf /etc/sddm.conf.bak` in the run-these
  report. Our recipe should keep this discipline — never overwrite without a backup.
- **Per-theme `kde_settings.conf` shipped inside the theme tarball.** HyDE copies the
  theme's own `kde_settings.conf` to `/etc/sddm.conf.d/` after extracting. Most SDDM
  themes ship a sample config — picking it up rather than rolling our own avoids breaking
  theme-specific `[Theme]` keys (e.g. `ThemeDir=`, `FacesDir=`).

GRUB tarballs (`Grub_Pochita.tar.gz`, `Grub_Retroboot.tar.gz`) follow the same pattern —
extracted to `/boot/grub/themes/<name>/`, `GRUB_THEME=` patched into `/etc/default/grub`,
then `grub-mkconfig`. The Pochita theme is HyDE's signature look (a Chainsaw Man dog mascot);
Retroboot is a more neutral CRT-styled menu. Neither is palette-aware — they're prebuilt
images with fixed colors.

## Archetype B — Clone-an-external-theme-repo installer (ML4W)

ML4W ships **no** theme tarball in-tree; the installer (`ml4w-install-sddm`) clones
`mylinuxforwork/ml4w-sddm` and copies into `/usr/share/sddm/themes/ml4w/`. Verbatim from
the script (HEAD):

```bash
DISTRO="Arch Linux"
INSTALL_CMD="sudo pacman -S --noconfirm sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
# ...Fedora + openSUSE branches with matching Qt package names...
primarycolor=$(cat ~/.config/ml4w/colors/primary)
onsurfacecolor=$(cat ~/.config/ml4w/colors/onsurface)
onprimarycolor=$(cat ~/.config/ml4w/colors/onprimary)
# ...
git clone --depth 1 https://github.com/mylinuxforwork/ml4w-sddm $HOME/.cache/ml4w-tmp/ml4w-sddm
sudo mkdir -p /usr/share/sddm/themes/ml4w
sudo cp -rf $HOME/.cache/ml4w-tmp/ml4w-sddm/. /usr/share/sddm/themes/ml4w/
```

Patterns to copy:

- **Palette propagation by file dump.** ML4W writes `primary`, `onsurface`, `onprimary`
  to plain files under `~/.config/ml4w/colors/` and the installer slurps them. This is the
  same shape as our `palette.conf` — a deliberately dumb cross-process color carrier. Our
  recipe is already aligned (writer reads `palette.conf` at generate-time).
- **Conflicting-DM detection and disable.** ML4W explicitly disables `gdm lightdm lxdm
  xdm mdm slim wdm` before enabling sddm. The script is careful to use `disable` (not
  `disable --now`) to avoid killing the current GUI session. Our `gotchas.md` →
  "GDM is not theme-friendly" already covers this; the wider conflict list is worth
  noting in the run-these report.
- **`InputMethod=qtvirtualkeyboard` + `GreeterEnvironment=QT_IM_MODULE=qtvirtualkeyboard`.**
  ML4W writes both because "`InputMethod` was supposed to automatically set `QT_IM_MODULE`,
  but it doesn't, so we manually export it" (comment in the upstream script). If the user's
  chosen SDDM theme uses the virtual keyboard component, our writer must do the same
  double-set — otherwise the keyboard renders but doesn't type.
- **`sed`-then-fallback config writer.** ML4W tries `sed` to update an existing `Current=`
  line, then falls back to appending a new `[Theme]` block. Our recipe uses a single
  drop-in file under `sddm.conf.d/` which sidesteps this — but the trick is worth knowing
  for the edit-config path.

## Archetype C — Ship-your-own-greeter (DankMaterialShell, HyprYou, fufexan)

This is the post-2024 trend: don't theme an existing greeter, **ship a greeter that matches
your shell exactly**. Three live examples in the corpus, three different tech stacks:

### DankMaterialShell — `dms-greeter` (Quickshell)

From `quickshell/Modules/Greetd/README.md`:

> A greeter for [greetd](https://github.com/kennylevinsen/greetd) that follows the
> aesthetics of the dms lock screen.
>
> Features:
> - Multi user: Login with any system user
> - dms sync: Sync settings with dms for consistent styling between shell and greeter
> - Multiple compositors: The `dms-greeter` wrapper supports niri, Hyprland, sway, scroll,
>   miracle-wm, labwc, and mangowc.

The "dms sync" trick — and this is the highest-leverage idea in the camp — is symlinking
the user's shell config into a greetd-readable location:

```bash
# Add yourself to greeter group
sudo usermod -aG greeter <username>

# Set ACLs to allow greeter to traverse your directories
setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state

# Set group ownership on config directories
sudo chgrp -R greeter ~/.config/DankMaterialShell
sudo chmod -R g+rX ~/.config/DankMaterialShell ~/.cache/DankMaterialShell ~/.cache/quickshell

# Create symlinks
sudo ln -sf ~/.config/DankMaterialShell/settings.json /var/cache/dms-greeter/settings.json
sudo ln -sf ~/.local/state/DankMaterialShell/session.json /var/cache/dms-greeter/session.json
sudo ln -sf ~/.cache/DankMaterialShell/dms-colors.json /var/cache/dms-greeter/colors.json
```

This is the **only** corpus pattern where the greeter colors update *automatically* on a
re-theme — the symlinks point at the shell's color cache, and a `dms` re-theme rewrites the
cache. Our recipe trades this for the "stale palette until re-run sudo commands" model
described in `gotchas.md` → "Coarse re-themes" — the trade-off is that DMS's setfacl/symlink
trick requires the greeter to run as a member of the user's primary group, which is a
non-default Arch security posture.

### HyprYou — bespoke greetd config + PKGBUILD

From `koeqaife/hyprland-material-you/greeter/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- --config /usr/share/hypryou/greeter/hyprland.conf"
```

And from the matching `PKGBUILD`:

```bash
pkgname=hypryou-greeter
depends=('greetd' 'hypryou')
install -Dm644 "${srcdir}/.../greeter/config.toml" "${pkgdir}/usr/share/${pkgname}/config.toml"
```

Pattern: the greeter is **a full Hyprland session** running its own hyprland.conf (under
`/usr/share/hypryou/greeter/`) that launches the python greeter UI. This is heavier than
tuigreet but lighter than ReGreet-in-cage because there's no nested compositor — Hyprland
*is* the greeter compositor. Useful as a reference for "I want the greeter to look
identical to the desktop" rices.

### fufexan — minimal NixOS module

From `system/services/greetd.nix`:

```nix
services.greetd = let
  session = {
    command = "${lib.getExe config.programs.uwsm.package} start hyprland.desktop";
    user = "mihai";
  };
in {
  enable = true;
  restart = false;          # do not restart on session exit (useful on autologin)
  settings = {
    terminal.vt = 1;
    default_session = session;
    initial_session = session;
  };
};
```

This is the textbook "greetd as DM, no graphical greeter, Hyprland launches directly" pattern
— useful for autologin. The `initial_session` block is the autologin path; `default_session`
fires after logout. Two patterns from this:

- **`restart = false` on autologin.** Without it greetd respawns on session exit and lands
  in a relogin loop on misconfig.
- **`${lib.getExe config.programs.uwsm.package} start hyprland.desktop` as the command.**
  Matches our recipe's tuigreet `--cmd 'uwsm start -- hyprland.desktop'`.

## Battle-tested techniques (cross-rice)

These are the concrete, attributable tricks worth applying in the recipe:

1. **Back up before overwrite, always.** HyDE: `kde_settings.t2.bkp`. ML4W:
   `/etc/sddm.conf.bak`. Our `gotchas.md` → "Root-side" already mandates this for the
   run-these report.

2. **Drop-in `.conf.d/` files over edit-in-place.** Our `10-rice.conf` is the cleanest path
   on Arch — HyDE's `kde_settings.conf` is single-file convention from Plasma's `sddm-kcm`.
   Both are SDDM-supported; the drop-in approach plays better with multiple sources of
   truth (e.g. a Plasma user who later adds our drop-in).

3. **Disable conflicting DMs without `--now`.** ML4W:
   ```bash
   sudo systemctl disable "$dm"      # NOT --now — would kill the current session
   ```
   Our run-these report's GDM swap follows this rule.

4. **For the virtual keyboard, write both `InputMethod=` and `GreeterEnvironment=QT_IM_MODULE=`.**
   ML4W discovered upstream `InputMethod=` doesn't actually export `QT_IM_MODULE` to the
   theme — both are required. Apply this when the SDDM theme uses the virtual keyboard
   component (Astronaut's variants, Sugar Candy's `EnableKeyboard=true`).

5. **Don't ship a Plymouth theme — generate one.** No corpus rice ships a Plymouth theme.
   The plugin's palette-driven generator is the only sensible path; copying a community
   theme would only work for whichever palette it was authored for.

6. **For autologin, set `restart = false` in greetd config.** fufexan's NixOS module
   (`system/services/greetd.nix`) documents this footgun — without it, exiting Hyprland
   from an autologin session immediately re-spawns greetd, which immediately auto-logs the
   user back in. Our tuigreet/ReGreet recipes inherit this when `[Autologin]` is set.

## Cross-surface coherence opportunities

Where the boot chrome can match the session palette without going stale:

- **`background.path` in ReGreet's `[background]` block = the same wallpaper file used by
  the wallpaper component.** Our recipe already does this. Caveat: greeter user must have
  read access. The install command in the run-these report handles `chmod a+r`.
- **GTK theme name in ReGreet's `[GTK]` block = the same theme set by `look-feel`.** Already
  in the recipe.
- **Plymouth `background.png` = a solid color generated from the palette's `bg`.** Already
  in the recipe.
- **GRUB `selected_item_color = "#{{accent}}"`, `item_color = "#{{muted}}"`.** Already in
  the recipe. The community has no precedent here; we're inventing.

The DMS-style "symlink the live color cache" coherence trick is *not* adopted by this
recipe — the security cost (greeter membership in the user's group) outweighs the benefit
(login chrome stale until re-run sudo commands) for an opt-in component the user is told
upfront is a "slow path".

## Citations

All citations are repo + path at HEAD of the cached corpus (2026-06-05):

- HyDE: `prasanthrangan/hyprdots/Scripts/install_pst.sh`,
  `prasanthrangan/hyprdots/Source/arcs/{Sddm_Candy,Sddm_Corners,Grub_Pochita,Grub_Retroboot}.tar.gz`
- ML4W: `mylinuxforwork/dotfiles/dotfiles/.config/ml4w/scripts/ml4w-install-sddm` (clones
  `mylinuxforwork/ml4w-sddm`)
- DMS: `AvengeMedia/DankMaterialShell/quickshell/Modules/Greetd/README.md`,
  `AvengeMedia/DankMaterialShell/distro/debian/dms-greeter/`
- HyprYou: `koeqaife/hyprland-material-you/greeter/{config.toml,PKGBUILD}`
- fufexan: `fufexan/dotfiles/system/services/greetd.nix`
- Dusky: `dusklinux/dusky/user_scripts/sddm/` (setup only, no theme)
- Astronaut sub-theme filenames verified against
  `Keyitdev/sddm-astronaut-theme/Themes/` at HEAD

## Cross-references

- Generation recipes per tool → `template.md`
- Root-side discipline, coarse re-themes, DM detection → `gotchas.md`
- Package map + commented sudo block → `packages.md`
- Interview gate + skip-silently rule → `interview.md`
