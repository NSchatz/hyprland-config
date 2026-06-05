# companion-daemons — gotchas

## Companion configs use a different config language from `hyprland.conf`

`hypridle.conf`, `hyprpaper.conf`, and `hyprlock.conf` all use a **hyprlang-flavoured but
independent** config grammar. They share the brace/`key = value` shape with `hyprland.conf` but
**do not** share its keyword set:

- No `windowrule`, `bind`, `monitor`, `decoration`, `general:gaps_*`, `exec-once`, `$variables`,
  `source =`, … none of it applies inside companion configs.
- Each daemon has its **own** vocabulary (`listener {}` for hypridle; `wallpaper {}` blocks +
  `splash` / `ipc` / `splash_offset` for hyprpaper 0.8+, or the legacy `preload` / `wallpaper`
  keywords on 0.7.x; `background {}` / `input-field {}` / `label {}` for hyprlock).
- Do **not** run `hyprctl reload` against changes to these files — Hyprland never reads them.
- Do **not** lint them with hyprland keywords / a Hyprland validator. The rice validator has a
  separate (much smaller) keyword set for each companion.

If you find yourself wanting `$mainMod` or `windowrule` inside `hypridle.conf`, that's the wrong
file — those go in `hyprland.conf` (or the slices it `source`s).

## `lock_cmd = pidof hyprlock || hyprlock` — don't stack lockers

`hypridle` will happily call `lock_cmd` again on a subsequent idle timeout even if a previous
hyprlock instance is still running. Stacking hyprlocks **layers them** — the user types their
password, dismisses one, and sees another behind it (and another behind that). The fix is the
`pidof` guard:

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock
}
```

`pidof hyprlock` exits 0 (true) when an instance is already running, short-circuiting the `||`;
otherwise it exits non-zero and the second command (`hyprlock`) launches a fresh instance. This is
the standard idiom — every shipped hypridle example uses it.

## `before_sleep_cmd` — two corpus idioms, both correct

Two patterns appear across the corpus, and both are defensible:

- **`before_sleep_cmd = loginctl lock-session`** (binnewbs, Ax-Shell, JaKooLit, end-4, ML4W).
  Emits the systemd `Lock` signal; hypridle's own `lock_cmd` then services it. Matches
  the upstream `hyprwm/hypridle/assets/example.conf`.
- **`before_sleep_cmd = $lock_cmd`** (Matt-FTW `.config/hypr/hypridle.conf` — `$lock_cmd =
  $launcher-pass-lock && pidof hyprlock || hyprlock`). Bypasses the systemd round-trip and
  calls the guarded lock command directly. Useful when a pre-lock side-effect needs to fire
  (Matt-FTW's `$launcher-pass-lock` flushes a launcher daemon first).

The rice template uses the `loginctl lock-session` form because it composes cleanly with the
auto-mode `inhibit_sleep = 2` behaviour (auto-mode detects "hyprlock" in either `lock_cmd` OR
`before_sleep_cmd`; using `loginctl lock-session` means only the `lock_cmd` line carries the
hyprlock reference, which is fine for detection). Don't switch to the direct-call form
without a specific reason.

## `before_sleep_cmd = loginctl lock-session` — lock BEFORE sleep, not after

Use `before_sleep_cmd`, **not** `after_sleep_cmd`, to fire the lock. The kernel suspends the
machine before `after_sleep_cmd` runs, so the laptop screen briefly **unlocks** on wake (in the
window between resume and the lock kicking in) — visible to anyone who opens the lid before the
user. `before_sleep_cmd = loginctl lock-session` puts the lock screen up first; the suspend is
gated on it returning. `after_sleep_cmd = hyprctl dispatch dpms on` is fine — that's the right
hook to re-power the displays on wake.

## Lock listener fires BEFORE dpms-off — order matters in the ladder

The four listeners (dim, lock, dpms-off, suspend) **must** be ordered by ascending timeout:

```
dim_secs  <  lock_secs  <  dpms_secs  <  suspend_secs
```

If `dpms_secs <= lock_secs` the displays turn off **before** the lock screen comes up — the user
gets a black screen they can't see, types their password blind, and the unlock UI never appears
because the lock never fired. The four named ladders (`balanced` / `aggressive` / `relaxed` /
`never`) all satisfy this rule by construction; the validator double-checks it for hand-edited
configs.

## Desktops drop the suspend tier

A desktop machine that suspends mid-day usually isn't doing the right thing — long-running tasks
(builds, downloads, file servers, dev shells) get killed. The `balanced` and `aggressive` ladders
include a suspend listener that's appropriate for laptops on battery; **on desktops the writer
should drop the suspend listener** even when the user picked `balanced`. The detection is:

```bash
if jq -e '.laptop.enabled == true' answers.json >/dev/null; then
  emit_suspend_listener=true
else
  emit_suspend_listener=false  # desktop — drop the tier
fi
```

`relaxed` and `never` already omit the suspend listener, so this only affects `balanced` /
`aggressive`.

## hyprpaper `ipc` — on by default; only turn off deliberately

The rice engine's wallpaper template ends with a reload hook. **On hyprpaper 0.8+** (the current
Arch package, see template.md), the single-shot form is:

```bash
hyprctl hyprpaper wallpaper '[<monitor>], [<new-path>], [<fit_mode>]'
```

On legacy 0.7.x it's `preload` then `wallpaper`:

```bash
hyprctl hyprpaper preload  "<new-path>"
hyprctl hyprpaper wallpaper ",<new-path>"
```

In **both** versions, `ipc` defaults to `1` / `true` in the upstream config defaults — IPC is
**on by default**, not off. The popular "always emit `ipc = on`" advice is defensive (covers the
case of a user copying a `# ipc = off` line from the README), not strictly required. Only emit
`ipc = false` to **disable** IPC (e.g. the README's battery-life note).

If the wallpaper does fail to switch live, the more common causes are:

- the daemon isn't running (`pgrep hyprpaper` / `pidof hyprpaper` to check);
- on 0.8+, the user is calling the legacy `preload` / `unload` / `listloaded` / `listactive`
  subcommands, which were **removed** in the hyprtoolkit rewrite — only `wallpaper` and `reload`
  remain.

## If hyprlock not chosen, drop the lock listener AND `lock_cmd`

When `companion_configs.hyprlock == false` (or `lock_screen.enabled == false`), hypridle has
nothing to lock with. Two changes to `hypridle.conf`:

1. **Drop** the `lock_cmd = pidof hyprlock || hyprlock` line from the `general {}` block. With it
   in place, `hypridle` calls a nonexistent `hyprlock` on each lock event and logs a flood of
   errors.
2. **Drop** the lock listener (the one that calls `loginctl lock-session`). Without a lock UI,
   `loginctl lock-session` still emits a `Lock` D-Bus signal but nothing receives it — the
   listener is effectively a no-op.

The `before_sleep_cmd = loginctl lock-session` line *can* stay or go; if there's no lock UI it's a
no-op, but harmless. Lean toward dropping it when `hyprlock == false` to keep the file clean.

## The popular rices rarely ship `hyprpaper.conf` — they generate it or use swww

Verified by direct fetch against HEAD (2026-06): **none** of end-4/dots-hyprland,
prasanthrangan/hyprdots, mylinuxforwork/dotfiles (recently switched), JaKooLit/Hyprland-Dots,
Matt-FTW/dotfiles, dusklinux/dusky, caelestia-dots/caelestia, or Axenide/Ax-Shell ship a static
`hyprpaper.conf` at HEAD. Two patterns dominate:

1. **The rice writes `hyprpaper.conf` on demand** from a wallpaper-engine script: HyDE's
   `Configs/.local/share/bin/swwwallpaper.sh` (despite the name, it does support hyprpaper as a
   fallback path); ML4W's `~/.config/ml4w/scripts/ml4w-wallpaper` regenerates it when the user
   picks a new image.
2. **The rice uses `swww`/`awww` instead** — HyDE (`swwwall*.sh`), ML4W (`awww img --transition-
   type ...`), dusky (`awww-daemon` in `.config/hypr/source/autostart.lua`), Matt-FTW
   (`awww-daemon --format argb &` in `scripts/autostart/services`). swww/awww need no static
   config — they're stateful daemons driven entirely by `swww img <path>` / `awww img <path>`
   CLI calls.

For this rice generator, that means the **hyprpaper.conf template lives in this folder, but it's
load-bearing only when the user picks hyprpaper in group 15**. When `autostart_env.wallpaper_tool
== "swww"`, no `hyprpaper.conf` is emitted, the wallpaper-tool config is the swww-daemon CLI
flags in `autostart`, and the rice engine's wallpaper-swap hook calls `swww img` / `awww img`
instead of `hyprctl hyprpaper wallpaper`.

## ML4W uses Lua-format hyprctl dispatchers — not legacy strings

ML4W's `dotfiles/.config/hypr/hypridle.conf` calls
`hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'` for the dpms listener — the **Lua
dispatcher syntax** added in Hyprland's runtime-Lua support. The classic string form
(`hyprctl dispatch dpms off`) still works on every supported Hyprland version; the Lua form
only works when the Hyprland binary was built with Lua support (the upstream Arch build is,
since ~v0.50). The rice template intentionally emits the **classic string form** for maximum
back-compat. If a future interview question gates on a runtime-Lua opt-in, the dpms listener
would be the line to swap; left as a recipe-evolution note, not a current branch.

## hyprpaper 0.8.0 broke its config format — `preload` is GONE

[hyprpaper v0.8.0](https://github.com/hyprwm/hyprpaper/releases/tag/v0.8.0) (Dec 2025) is "a
complete rewrite of hyprpaper into hyprtoolkit. Please note configs are broken and much
simplified." Concretely:

- `preload =` keyword is **removed** — there's no separate preloading step anymore.
- `wallpaper = MON, PATH` line form is **removed** — replaced by anonymous `wallpaper { … }`
  blocks with `monitor` / `path` / `fit_mode` / `timeout` / `order` / `recursive` fields.
- `hyprctl hyprpaper preload` / `unload` / `listloaded` / `listactive` IPC subcommands are
  **removed**. Only `wallpaper` (single-shot set) and `reload` (reread config) remain.
- The single-shot IPC syntax changed: `hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'`
  with full paths required (no relative resolution).
- `splash` default flipped to `true` and `splash_offset` is now a float (default 20.0).

Arch's `extra/hyprpaper` jumped straight to 0.8.4 (Apr 2026), so any rice config emitted with
the legacy syntax **fails to parse** on a freshly-installed system. The writer must default to
the new block form; see `template.md` for both shapes.

## Corpus disagreement on `inhibit_sleep` — default is right unless the shell owns the lock UI

The default (`2` / auto) is correct for the **vast majority** of rices, and most of the corpus
leaves it implicit. Two notable exceptions:

- **end-4/dots-hyprland** (`dots/.config/hypr/hypridle.conf`) sets `inhibit_sleep = 3` explicitly
  because its `lock_cmd` dispatches into Quickshell first (`hyprctl dispatch 'hl.dsp.global(
  "quickshell:lock")'`) and only falls back to `hyprlock` as the second clause — auto-mode's
  pattern-match for "hyprlock" still matches the fallback, but the rice pins `3` to make the
  intent explicit. Safe because Hyprland ≥ 0.42 ships `hyprland-lock-notify-v1`.
- **mylinuxforwork/dotfiles** (`dotfiles/.config/hypr/hypridle.conf`) sets
  `ignore_dbus_inhibit = true` AND `ignore_wayland_inhibit = true`. **Footgun for non-power
  users**: with both inhibitors ignored, hypridle fires its idle ladder during full-screen
  Firefox video, Steam Big Picture, fullscreen YouTube/Netflix — anywhere an app legitimately
  asked the compositor not to idle. The rice template intentionally leaves both implicit
  (their defaults are `false`); only set them if the user explicitly wants to override
  inhibitors (e.g. a kiosk that ignores misbehaving inhibit requests).

## `inhibit_sleep` is not a bitfield — it's four coordination modes

A common misreading: `inhibit_sleep` looks like it might be a bitfield over standby/sleep, with
values `0 = disabled, 1 = inhibit standby, 2 = inhibit sleep, 3 = both`. It is **not**. Verified
against `hyprwm/hypridle@main` `src/core/Hypridle.cpp` and the wiki:

| Value | Mode | Meaning |
|---|---|---|
| `0` | disable | hypridle does nothing to delay sleep — D-Bus tells the kernel to suspend, hypridle's `before_sleep_cmd` races against it. |
| `1` | normal | hypridle holds a sleep inhibitor until `before_sleep_cmd` returns. |
| `2` | auto **(default)** | hypridle picks `3` automatically if `lock_cmd` or `before_sleep_cmd` mentions `hyprlock` (and the compositor supports `hyprland-lock-notify-v1`); otherwise falls back to `1`. |
| `3` | lock notify | hypridle holds the sleep inhibitor until the session is actually locked (any wayland session-lock app). Requires `hyprland-lock-notify-v1` from the compositor; logs a warning otherwise. |

The default (`2`) is almost always correct — the rice template leaves it implicit. Setting `3`
unconditionally is wrong on compositors without `hyprland-lock-notify-v1` and produces a runtime
error log.

## Adjacent daemon: walker's `ext_background_effect_blur` is compositor-served, not built-in

The batch-1 launcher research surfaced walker's `ext_background_effect_blur = true` flag. The
flag is **not a built-in compositor-independent blur path** — it asks the compositor to draw
blur behind walker's surface via the `ext-background-effect-v1` Wayland protocol (verified in
`abenz1267/walker@HEAD` `src/wayland_blur.rs` — the source even ships its own copy of
`ext-background-effect-v1.xml` and binds to `ext_background_effect_manager_v1`).

Hyprland implemented the server side of `ext-background-effect-v1` in
[`hyprwm/Hyprland@7d1e481`](https://github.com/hyprwm/Hyprland/commit/7d1e481) (**May 2026**;
`protocols: implement ext-background-effect-v1 protocol (#13211)`). On any Hyprland that ships
that commit (~v0.50+; certainly the current Arch package), the flag works and replaces a
`layerrule = blur, walker` block. On older Hyprland it silently no-ops — walker's flag and
Hyprland's `layerrule = blur, walker` are the **only two** routes to a blurred walker, and
this is the only place the version cliff matters for companion daemons. Not owned here (it's
a launcher-component concern, see `../launcher/gotchas.md`) but flagged here because the
batch-1 finding incorrectly framed the path as compositor-independent.

## Adjacent daemon: `wl-clip-persist` keeps cliphist alive after the source app quits

By default on Wayland, the clipboard contents die when the source application exits — copying
from Firefox then closing Firefox empties the clipboard before you paste. Several rices
(dusky `.config/hypr/source/autostart.lua`, HyDE `Scripts/`) layer `wl-clip-persist
--clipboard regular` on top of the standard `wl-paste --type text --watch cliphist store` /
`wl-paste --type image --watch cliphist store` pair. The launch lines live in
[`../autostart/`](../autostart/) — this component's `lock_cmd` and `before_sleep_cmd` do **not**
interact with the clipboard, so this is documented here only for cross-component coherence.

## hypridle has no `hyprctl reload` (and hyprpaper's is version-dependent)

Unlike Hyprland itself, the companion daemons do not honour Hyprland's `hyprctl reload`. Config
changes require either a daemon-specific IPC call or restarting the daemon:

- **hypridle:** no IPC reload. Use `systemctl --user restart hypridle` (or `pkill hypridle &&
  hypridle &`).
- **hyprpaper 0.8+:** `hyprctl hyprpaper reload` rereads `hyprpaper.conf` in place; single-shot
  wallpaper swaps use `hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'`. No
  preload/unload commands exist.
- **hyprpaper 0.7.x:** no `reload` IPC — for new images use `hyprctl hyprpaper preload <path>` +
  `hyprctl hyprpaper wallpaper ",<path>"`; for structural changes to `hyprpaper.conf` (the
  `preload` / `splash` / `ipc` lines themselves), restart the daemon.
- **hyprlock:** no daemon — launched fresh per lock. Config changes apply on next lock.

The rice engine's reload hooks for these templates should use the right command per file (and
guard with `pgrep`/`pidof` so they no-op when the daemon isn't running).
