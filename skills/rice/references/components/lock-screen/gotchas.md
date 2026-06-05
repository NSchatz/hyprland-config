# lock-screen — gotchas

## Keep the input field VISIBLE

A "minimal underline" style (interview group 10d) is fine *visually* but **do not** implement it
as a 6 px-tall sliver with `outline_thickness = 0` + `fade_on_empty = true` — that field is
effectively invisible and shows almost no feedback while typing, so users report *"nothing happens
when I type my password"* and assume the lock is frozen. A minimal look should still be a clearly
visible thin pill:

- Real height (**~50 px**, not 6 px).
- `fade_on_empty = false` (the field stays on screen even before/while typing).
- A visible `dots_size` (~`0.33`) so the password dots show.
- At least a 1 px accent `outer_color` (or visible underline).

This applies to all three `input_pill` options — the template in [`template.md`](./template.md)
already enforces it for `underline` (`size = 280, 50`, `outline_thickness = 1`) and even for
`hidden` (the post-fade-in state is fully visible). Don't override.

## Colors are LITERAL hex — hyprlock can't read `$accent`

hyprlock is a **separate daemon** from Hyprland. When it parses `hyprlock.conf` it does **not**
have access to the `$accent`/`$bg`/… variables defined in `~/.config/hypr/colors.conf` (those are
evaluated by the compositor at config-reload time, not by the locker). Two consequences:

1. The engine writes literal hex into `hyprlock.conf` — e.g. `outer_color = rgb(cba6f7)`, not
   `outer_color = rgb($accent)`. The placeholders in [`template.md`](./template.md) (`{{accent}}`,
   `{{surface}}`, …) are substituted from `palette.conf` at generate-time. See
   [`_shared/colors-contract.md`](../../_shared/colors-contract.md) (hyprlock is one of the two
   listed exceptions, alongside fuzzel).
2. **Re-theming** means re-running `rice apply` so the engine re-renders `hyprlock.conf` with the
   new palette literals. There is no live signal to send to a running hyprlock (it's not running
   between locks anyway — see [`reload.md`](./reload.md)).

If you want a `$var`-style indirection you can `source = ~/.config/hypr/hyprlock-colors.conf` from
inside `hyprlock.conf` and define the `$var`s there — that file would still be literal hex, but at
least the main config reads symbolically. The rice engine prefers the inlined-literal form so
there's one fewer file to track.

## Fingerprint requires `fprintd` + an enrolled finger

`lock_screen.fingerprint = true` emits hyprlock's `auth { fingerprint { enabled = true } }`. That
block is harmless on a box without a reader (the lock falls back to password), but for it to
**actually unlock** you need:

1. The `fprintd` package installed (see [`packages.md`](./packages.md)).
2. A finger enrolled with `fprintd-enroll` (runs as your user). The installer agent's summary
   should **name this step** at the end of the install — *"After install, run `fprintd-enroll` to
   enrol a finger."* — but the agent must **NEVER run it itself**: enrolment is interactive and
   touches PAM state.
3. A working reader. If `fprintd-list "$USER"` (run by the user) shows no devices, the block is a
   no-op; the user falls back to password.

Don't add the `auth {}` block when `fingerprint = false` — an empty `auth {}` block isn't a parse
error but it's noise, and the validator flags surplus empty blocks.

## hypridle's `lock_cmd` must use `pidof hyprlock || hyprlock`

This is **the** classic mistake. A bare `lock_cmd = hyprlock` in `hypridle.conf` will spawn
**another** hyprlock instance every time the idle threshold fires while one is already running —
e.g. you idle out, hyprlock locks, you walk away, the next timer tick fires another `hyprlock`,
and the two stack: one daemon eats input the other can't see. The user reports *"my password isn't
working"* (it's going to the wrong instance).

The guard:

```ini
listener {
    timeout = 600
    on-timeout = pidof hyprlock || hyprlock
}
```

`pidof hyprlock` succeeds (exit 0) when one is already running, the `|| hyprlock` short-circuits
to a no-op — so the timer becomes idempotent. Apply the same guard wherever else hyprlock might be
launched (e.g. a `loginctl lock-session` handler), and add `before_sleep_cmd = loginctl
lock-session` to `hypridle.conf` so a suspend always locks first.

This rule lives in [`../companion-daemons/`](../companion-daemons/) (which owns `hypridle.conf`);
flagged here because the failure mode reads as a hyprlock bug, not a hypridle one.

## `grace` is a CLI flag, NOT a config key

A very common mistake from older guides: putting `grace = N` inside `general {}`. Verified against
`src/main.cpp` and `src/config/ConfigManager.cpp` — `grace` is **only** registered as a CLI option
(`hyprlock --grace N`, where N is seconds the lock can be dismissed without a password). The
`general {}` block exposes only: `text_trim`, `hide_cursor`, `ignore_empty_input`,
`immediate_render`, `fractional_scaling`, `screencopy_mode`, `fail_timeout`. A `grace = …` line
inside `general {}` is silently dropped and the dismiss-window stays at 0.

To get a brief dismiss window, pass it via every launcher:

```ini
# binds.conf
bind = $mainMod, X, exec, hyprlock --grace 2

# hypridle.conf — keep the pidof guard too
listener {
    timeout    = 300
    on-timeout = pidof hyprlock || hyprlock --grace 2
}
```

(Apply `--grace` consistently across launchers — otherwise the manual bind and the idle-lock
behave differently and users notice.)

Same family of pitfall: `no_fade_in`, `no_fade_out`, `disable_loading_bar`, `pam_module` are also
**not** valid `general {}` keys in current hyprlock — older config snippets that ship them are
silently ignored. To swap the PAM file, use `auth { pam { module = <name> } }` instead.

**The corpus shows this is endemic** (re-verified 2026-06; copy below comes from the rices'
own HEAD `hyprlock.conf` files):

- JaKooLit/Hyprland-Dots `config/hypr/hyprlock.conf`: `general { grace = 1; fractional_scaling = 2; immediate_render = true }` — `grace` is dropped, the other two are valid.
- prasanthrangan/hyprdots (HyDE) `Configs/.config/hypr/hyprlock/HyDE.conf`: `general { no_fade_in = false; grace = 0; disable_loading_bar = false }` — **all three** silently ignored.
- fufexan/dotfiles `home/programs/wayland/hyprlock.nix`: `general { disable_loading_bar = true; immediate_render = true; hide_cursor = false; no_fade_in = true }` — only the middle two land.
- Axenide/Ax-Shell `config/hypr/hyprlock.conf`: `general { grace = 0; hide_cursor = true }` — the `grace = 0` is a no-op (default is already 0 because grace is a CLI flag).
- binnewbs/arch-hyprland `.config/hypr/hyprlock.conf`: same `grace = 1; fractional_scaling = 2; immediate_render = true` pattern (a downstream copy of JaKooLit).
- dusklinux/dusky `.config/hypr/hyprlock_themes/006_stacked_clock/hyprlock.conf`: `general { grade = 1; fractional_scaling = 2; immediate_render = false; hide_cursor = false }` — `grade` is a typo of `grace` and so doubly invalid; also `dots_rouding` (sic) in the same file.

Two takeaways: (i) the silently-ignored-key class is widespread, not a one-rice quirk, so the validator's `warn` is justified; (ii) `--no-fade-in` and `--immediate-render` are real **CLI** flags (see `src/main.cpp`'s `argParser.registerBoolOption(...)`), so the `general{}` versions look plausible — but only `immediate_render` is also a config key. If a user wants no fade-in, pass `--no-fade-in` in the launcher.

## Two valid forms for the fingerprint block — pick the nested one

hyprlang lets you write nested sub-categories in two ways:

```ini
# nested (the form the template emits)
auth {
    fingerprint {
        enabled = true
    }
}

# flat / colon (also valid — same key in hyprlock's ConfigManager)
auth {
    fingerprint:enabled = true
}
```

Verified: `src/config/ConfigManager.cpp` registers the keys as `auth:fingerprint:enabled` etc., and both write-forms parse to the same setting. The wild: basecamp/omarchy's `config/hypr/hyprlock.conf` uses the flat form (`auth { fingerprint:enabled = false }`); catppuccin/hyprlock and HyDE use neither (they show only the password-or-fingerprint *prompt* via labels — see next gotcha). The rice generates the **nested** form because the existing validator's brace-balance and "required block" checks key on `^auth\s*{` + `fingerprint\s*{`. Don't mix forms within the same emitted file.

Note that `auth:pam:enabled` and `auth:pam:module` are valid keys — to swap the PAM service file (default `/etc/pam.d/hyprlock`) you write `auth { pam { module = login } }`, NOT a top-level `pam_module =` (that key doesn't exist).

## `$FPRINTPROMPT` / `$FPRINTFAIL` are LABEL variables, not config keys

hyprlock exposes `$FPRINTPROMPT`, `$FPRINTFAIL`, `$PAMPROMPT`, `$PAMFAIL` and `$FAIL` as substitution variables you put inside `label { text = $FPRINTPROMPT }` to surface the fingerprint daemon's live messages — they are **not** keys in `auth { fingerprint { } }`. The two are complementary:

- `auth { fingerprint { enabled = true } }` turns the fingerprint authenticator **on**.
- `label { text = $FPRINTPROMPT }` (HyDE-Project/HyDE `Configs/.config/hypr/hyprlock/HyDE.conf`; catppuccin/hyprlock `hyprlock.conf`) shows whatever fprintd is currently saying ("Place finger on reader", "Match failed", etc.) at a fixed position.

If a rice ships only the label and forgets to enable the auth block (or vice versa), fingerprint reads but never unlocks (or unlocks but the user sees no feedback). The rice's `template.md` enables the auth block; users who add `$FPRINTPROMPT`/`$FPRINTFAIL` labels for feedback can do so without disturbing the block.

## `path = screenshot` needs portal/perms + a screencopy-capable build

The `blurred-screenshot` background relies on hyprlock's screencopy capture. On some setups it
shows **black** instead (portal missing, perms wrong, GPU quirk that flips the capture twice).
Fallback: switch the user to `wallpaper` for the `background` answer and point at the current
wallpaper. Don't auto-detect — flag it in the post-install summary as *"if your lock background is
black, change `lock_screen.background` to `wallpaper`."*

## `font_family` takes the family only — no size suffix

In `hyprlock.conf`, `font_family = Inter`, **not** `font_family = Inter 11`. The size goes on the
widget (`font_size = 96` on the clock label). `palette.conf` stores `font_ui = "Inter 11"` with
the size; the engine strips the size when substituting `{{font_ui_family}}` into the template.
A trailing size silently falls back to the system default and the clock comes out at the wrong
weight/face.

## `monitor =` empty means all monitors

Every widget takes a `monitor =` line. **Empty = render on every monitor**, which is what you want
for the default single-screen layout. Setting `monitor = DP-1` scopes the widget to that one
output — a typo (`monitor = HDMI-A-2` on a single-DP box) means the widget simply doesn't appear,
no error. The template leaves `monitor =` blank for all widgets; only override if the user asked
for per-monitor placement.
