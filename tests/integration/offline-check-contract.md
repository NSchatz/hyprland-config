# `Hyprland --verify-config` - the measured contract

What the compositor's own offline config check actually does, measured against the real
binary in this directory's image rather than read off the source. `preflight-config.sh`
depends on every row below; `test_integration_docker.sh` re-derives the starred ones on
every integration run, so a row that stops being true turns the build red instead of
turning the preflight into a rubber stamp.

Measured on **Hyprland 0.56.2** (`built from branch v0.56.2 at commit efb5099`,
`extra/hyprland 0.56.2-2` on `archlinux:base`), in a container with **no Wayland session,
no seat and no `/dev/dri`** - the same shape as a GitHub Actions runner.

## Does it run without a session or a GPU?

**Yes.** This was the roadmap's open question for phase `PREFLIGHT-5` and it is now
answered: `--verify-config` returns `initServer()`'s config verdict and exits before the
compositor ever tries to create a backend, so the missing seat and missing `/dev/dri` that
kill a real `Hyprland` startup never come into it. One invocation takes ~50 ms.

It does need **`XDG_RUNTIME_DIR`**. That check is the first statement of `main()`, ahead of
argument parsing, so even `Hyprland --help` aborts (`SIGABRT`, exit 134,
`Critical error thrown: XDG_RUNTIME_DIR is not set!`) without one. `preflight-config.sh`
therefore builds its sandbox before it runs the binary at all, even to ask for `--help`.

## Exit codes and output

| invocation | exit | `======== Config parsing result:` | below the marker |
|---|---|---|---|
| `--verify-config -c <clean file>` * | 0 | yes | `config ok` |
| `--verify-config -c <file with errors>` * | 1 | yes | one `Config error in file <path> at line <n>: <msg>` per error |
| `--verify-config -c <path that does not exist>` * | 1 | **no** | `[ ERROR ] (main.cpp:136) …` on stderr, then the usage banner |
| `--verify-config -c <a directory>` | 1 | **no** | `… is invalid: not a regular file!`, then the usage banner |
| `--verify-config --<unknown flag>` | 1 | **no** | `[ ERROR ] Unknown option '…' !`, then the usage banner |
| `--verify-config -c <file, mode 000>` | 1 | yes | `File failed to open` |

**Exit 1 is overloaded, and that is the trap.** "Your config has errors" and "you invoked me
wrong" are the same status. Only the `======== Config parsing result:` marker separates
them: it is printed if and only if the binary got as far as parsing. Reading a rejected
invocation as a broken config would turn any packaging change into a refusal that blames
the user's config, which is why `preflight-config.sh` keys on the marker and reports
`PREFLIGHT=uncheckable` - never `PREFLIGHT=errors` - when it is absent.

`File failed to open` is a third case: the marker is there, but nothing was checked. It is
`uncheckable` too, and the preflight also pre-checks readability so it usually never gets
that far.

## Multi-file configs

A generated config is not one file. The main config sources its companions, and the check
follows every one of them:

- Errors in a `source =`d file are reported against **that file's own path and line**, at
  any nesting depth, for relative (`./mon.conf`, `mon.conf`), absolute and `~/…` forms. *
- A `source =` that resolves to nothing is itself an error:
  `Config error in file <main> at line <n>: source= globbing error: found no match`.
- **`~` expands from `$HOME`.** * Measured both ways: with `$HOME` pointed at a mirror
  holding a *broken* companion and the passwd home holding a *clean* one, the verdict was
  `errors`; with the mirror clean and the passwd home broken, the verdict was `config ok`.

That last row is the whole mechanism behind the preflight's sandbox. The generated main
config sources its companions by **install** path (`source = ~/.config/hypr/monitors.conf`),
so pointing the binary straight at the staging dir would parse whatever is already installed
on the machine and return a verdict about the wrong files. Copying the staged set into
`$SANDBOX/.config/hypr/` and running with `HOME=$SANDBOX` makes the staged files - and only
the staged files - decide the verdict.

## Not errors

hyprlang accepts **unknown top-level keywords** silently; only an unknown option *inside a
known category* (`general { not_a_real_option_here = 3 }`) is a parse error. A negative
control that plants a bogus top-level line will be reported clean and prove nothing.

## Lua configs

`--verify-config -c <file>.lua` works too, and is selected by the file's extension
(`[cfg] Config is lua, loading lua mgr`). Errors come back in the lua style,
`<path>:<line>: <message>` - e.g. `unknown config key 'general.not_a_real_option_here'`,
`unexpected symbol near <eof>`.

## Which config is a RUNNING instance using?

`hyprctl` has **no** command that reports it. The full command list on 0.56.2 is
`activewindow activeworkspace animations binds clients configerrors cursorpos decorations
devices dismissnotify dispatch eval getoption globalshortcuts hyprpaper hyprsunset instances
keyword kill layers layouts monitors notify output plugin reload repl rollinglog setcursor
seterror setprop getprop splash status switchxkblayout systeminfo version workspacerules
workspaces` - nothing there names the config path.

The compositor does **log** it, once per config file it reads:

```
Using config: /home/tester/.config/hypr/hyprland.conf
```

and those lines are re-emitted on every `hyprctl reload`, so they are reachable through
`hyprctl rollinglog` (and from the instance log under
`$XDG_RUNTIME_DIR/hypr/<signature>/hyprland.log`). That is what `loaded-config.sh` reads,
and it is the only route this repo has to the AC-3/AC-9 claim "the file we wrote is the file
you loaded". When no route answers, `loaded-config.sh` reports `LOADED_CONFIG=unknown` and
the verdict becomes `unconfirmed` - never `ok`.

## Re-running this by hand

```bash
docker build -t hyprland-config-test tests/integration
RUN_INTEGRATION=1 bash tests/run.sh integration
```

The rows marked * are asserted by `tests/test_integration_docker.sh` from the
`OFFLINE_CONTRACT_*` markers `tests/integration/run-in-container.sh` prints, so the contract
is re-derived on every run and never merely trusted.
