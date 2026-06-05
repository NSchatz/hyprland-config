# env — packages

None. This component is env-only — it emits lines into `~/.config/hypr/env.conf` and contributes
nothing to the install batch.

The packages implied by the env lines are owned by the components that introduce them:

| Env var | Owning component's `packages.md` |
|---|---|
| `MOZ_ENABLE_WAYLAND,1` | [`../default-apps/packages.md`](../default-apps/packages.md) (`firefox`). |
| `QT_QPA_PLATFORMTHEME,qt6ct` | [`../look-feel/packages.md`](../look-feel/packages.md) (`qt6ct`). |
| `QT_STYLE_OVERRIDE,kvantum` | [`../look-feel/packages.md`](../look-feel/packages.md) (`kvantum`). |
| `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` | [`../companion-daemons/packages.md`](../companion-daemons/packages.md) (the cursor theme; hyprcursor ships with Hyprland). |
| NVIDIA set (`LIBVA_DRIVER_NAME=nvidia`, …) | Out of scope — driver install is a system-level decision, not a rice pick. `NVD_BACKEND,direct` implies `nvidia-vaapi-driver` (AUR), tracked in `_shared/version-matrix.md` notes. |

The installer agent does not read this file; it's a stub so the per-component layout stays
uniform.
