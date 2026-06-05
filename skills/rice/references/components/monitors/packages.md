# monitors — packages

Only one optional install, gated on `monitors.dock_undock == true` (1d) **and** the user picking
auto-switch. The `desc:`-based monitor lines in `template.md` work without either daemon — they
just don't auto-switch on hotplug.

## Map

### Hotplug profile daemon (1d, opt-in)
| Pick | Package | Repo / AUR |
|---|---|---|
| kanshi | `kanshi` | repo |
| shikane | `shikane` | AUR |

Pick exactly one. `kanshi` is the established default (Sway / Hyprland community); `shikane`
is the newer alternative with a TOML config and richer matching. Detection's
`HAVE_kanshi=1` / `HAVE_shikane=1` flags reorder the option list (already-installed pick first)
but **do not** answer the question — see `../../_interview-protocol.md`.

## Assembly rule

```bash
if [ "$(jq -r .monitors.dock_undock answers.json)" = "true" ]; then
  case "$(jq -r '.monitors.profile_daemon // "kanshi"' answers.json)" in
    kanshi)  pkgs+=(kanshi)  ;;
    shikane) pkgs+=(shikane) ;;
    none)    ;;
  esac
fi
```

If the user picked `dock_undock: true` but explicitly declined an auto-switch daemon, **install
nothing** — the `desc:` lines alone are the deliverable.

## What does NOT belong here

- No terminal, browser, file-manager, or wallpaper-tool packages — those live in their owning
  components' `packages.md`.
- No `wlr-randr` / `kscreen` / display-management GUIs — out of scope.

## Cross-references

- Where the picks land in config → `template.md` (the `desc:` block).
- Why the daemon config isn't generated → `gotchas.md` ("kanshi / shikane — name the tool, don't
  author its config").
- Global install-script shape → see the installer agent's prompt; the per-component
  `packages.md` files are the inputs it concatenates.
