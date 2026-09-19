#!/usr/bin/env python3
"""Convert a hyprlang `.conf` set to lua - or offer to, and change nothing.

Since 0.55 Hyprland reads `hyprland.lua` INSTEAD OF `hyprland.conf`, and hyprlang is supported
for only 1-2 more releases. This converts the whole `source =` set as ONE unit, because
converting half of it would leave the other half loaded by nothing.

Four things it refuses to do, each changing nothing:
  - replace an existing `hyprland.lua` (that file is what Hyprland actually loads)
  - convert a config that does not parse as hyprlang (it will not guess at a broken line)
  - convert a set with an unresolvable `source =` (it will not convert a set it has not seen)
  - proceed when the backup step did not produce a readable, identical copy

A construct with NO documented lua mapping is not a refusal: it is carried across as a
`-- NOT APPLIED` comment, counted, and reported. Those lines STOP APPLYING - lua is loaded
instead of the .conf - so every original .conf is kept, and the report says so in as many words.

Usage: migrate-config.sh [--convert]     (no flag = offer only, writes nothing)
Exit:  0 offered / converted, 2 usage or no config dir, 3 unparseable or unresolvable source,
       4 an existing lua config, 5 the backup failed.
"""
import os
import re
import shutil
import sys
import tempfile

from .. import xdg
from ..clock import stamp
from . import configlang

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SECTION = re.compile(r"^([A-Za-z_][A-Za-z0-9_:.-]*)\s*\{$")
INT_RE = re.compile(r"^-?\d+$")
FLOAT_RE = re.compile(r"^-?\d*\.\d+$")

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if",
    "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}

# hyprlang keywords that may appear MANY times in one section. lua's table syntax has one key
# per name, so a repeat would silently overwrite - these are reported, never folded.
REPEATABLE = {
    "bezier", "animation", "gesture", "windowrule", "windowrulev2", "layerrule", "layerrulev2",
    "workspace", "blurls", "permission", "submap", "plugin", "source", "monitor", "monitorv2",
    "env", "envd", "exec", "exec-once", "exec-shutdown", "unbind",
}

BIND_FLAGS = {
    "e": "repeating", "l": "locked", "r": "release", "m": "mouse",
    "n": "non_consuming", "t": "transparent", "i": "ignore_mods",
}


def is_repeatable(key):
    return key in REPEATABLE or key.startswith("bind")


def lua_string(s):
    return '"' + (s or "").replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_value(v):
    v = (v or "").strip()
    if v == "":
        return lua_string("")
    if v in ("true", "false"):
        return v
    if v == "yes":
        return "true"
    if v == "no":
        return "false"
    if INT_RE.match(v) or FLOAT_RE.match(v):
        return v
    return lua_string(v)


def lua_key(k):
    if k in LUA_KEYWORDS or not IDENT.match(k):
        return f"[{lua_string(k)}]"
    return k


def indent(level):
    return " " * (4 * level)


def strip_comment(s):
    t = s.strip()
    if t.startswith("#"):
        return ""
    # Only a ` #` (whitespace then hash) opens a trailing comment, matching hyprlang.
    m = re.search(r"\s#", s)
    return s[:m.start()] if m else s


class Converter:
    def __init__(self, target, home_config_dir):
        self.target = target
        self.home_config_dir = home_config_dir
        self.vars = {}
        self.parse_errors = []
        self.source_errors = []
        self.unmapped = []
        self.queue = []
        self.seen = []

    # --- helpers ---------------------------------------------------------------------------
    def expand_vars(self, s):
        # Longest name first, so `$mainMod2` is not eaten by `$mainMod`.
        for name in sorted(self.vars, key=len, reverse=True):
            s = s.replace(f"${name}", self.vars[name])
        return s

    def lua_stem(self, path):
        p = path[len(self.target) + 1:] if path.startswith(self.target + "/") else path
        return p[:-5] if p.endswith(".conf") else p

    def note_unmapped(self, src, lineno, why, text, out, level):
        self.unmapped.append(f"{src}:{lineno}: {why}: {text}")
        out.append(f"{indent(level)}-- NOT APPLIED ({why}): {text}")
        self.file_unmapped += 1

    # --- per-construct converters -----------------------------------------------------------
    def convert_source(self, src, lineno, val, out):
        if "*" in val or "?" in val:
            self.source_errors.append(
                f"{src}:{lineno}: 'source' with a glob cannot be resolved to a fixed set of "
                f"files: source = {val}")
            return
        p = val
        if p.startswith("~/"):
            p = f"{os.environ.get('HOME', '')}/{p[2:]}"
        elif not p.startswith("/"):
            p = f"{os.path.dirname(src)}/{p}"
        # A `~/.config/hypr/...` line means the DEFAULT hypr dir to hyprlang, but this run may
        # be targeting a different one; rewrite so the set converts as one unit either way.
        if self.home_config_dir and self.target != self.home_config_dir:
            if p.startswith(self.home_config_dir + "/"):
                p = f"{self.target}/{p[len(self.home_config_dir) + 1:]}"
        if not p.endswith(".conf"):
            self.source_errors.append(f"{src}:{lineno}: 'source' of a non-.conf file: source = {val}")
            return
        if not os.path.isfile(p):
            self.source_errors.append(f"{src}:{lineno}: sourced file does not exist: {p}")
            return
        if not p.startswith(self.target + "/"):
            self.source_errors.append(
                f"{src}:{lineno}: sourced file lives outside {self.target}: {p}")
            return
        out.append(f"require({lua_string(self.lua_stem(p))})")
        self.queue.append(p)

    def convert_monitor(self, src, lineno, val, out, line):
        parts = val.split(",")
        if len(parts) != 4:
            self.note_unmapped(
                src, lineno,
                "only the 4-field 'monitor = output, mode, position, scale' form has a "
                "documented lua mapping", line, out, 0)
            return
        out.append(
            f"hl.monitor({{ output = {lua_string(parts[0].strip())}, "
            f"mode = {lua_value(parts[1])}, position = {lua_value(parts[2])}, "
            f"scale = {lua_value(parts[3])} }})")

    def convert_bind(self, src, lineno, key, val, out, line):
        flags = key[len("bind"):]
        has_description = False
        opts = []
        for ch in flags:
            if ch == "d":
                has_description = True
                continue
            opt = BIND_FLAGS.get(ch)
            if not opt:
                self.note_unmapped(
                    src, lineno,
                    f"bind flag '{ch}' in '{key}' has no documented lua option", line, out, 0)
                return
            opts.append(f"{opt} = true")

        parts = val.split(",")
        mods = parts[0].strip() if len(parts) > 0 else ""
        keyname = parts[1].strip() if len(parts) > 1 else ""
        nxt = 2
        description = ""
        if has_description:
            description = parts[2].strip() if len(parts) > 2 else ""
            nxt = 3
        dispatcher = parts[nxt].strip() if len(parts) > nxt else ""

        if not keyname or not dispatcher:
            self.parse_errors.append(
                f"{src}:{lineno}: bind needs MODS, KEY, DISPATCHER: {key} = {val}")
            return
        if not IDENT.match(dispatcher):
            self.note_unmapped(
                src, lineno,
                f"dispatcher '{dispatcher}' is not a lua identifier, so it has no hl.dsp.* form",
                line, out, 0)
            return

        if dispatcher == "exec":
            # Everything after the dispatcher field is ONE shell command, commas and all.
            dispatcher = "exec_cmd"
            prefix = ",".join(parts[:nxt + 1]) + ","
            arglist = lua_string(val[len(prefix):].strip())
        else:
            collected = parts[nxt + 1:]
            while collected and not collected[-1].strip():
                collected.pop()
            arglist = ", ".join(lua_value(a) for a in collected)

        chord = f"{mods} + {keyname}" if mods else keyname
        if description:
            opts.append(f"description = {lua_string(description)}")
        if opts:
            out.append(f"hl.bind({lua_string(chord)}, hl.dsp.{dispatcher}({arglist}), "
                       f"{{ {', '.join(opts)} }})")
        else:
            out.append(f"hl.bind({lua_string(chord)}, hl.dsp.{dispatcher}({arglist}))")

    def flush_rule(self, kind, match, props, out):
        out.append(f"hl.{kind}({{")
        if match:
            out.append("    match = {")
            for e in match:
                out.append(f"        {e}")
            out.append("    },")
        for e in props:
            out.append(f"    {e}")
        out.append("})")

    # --- the file walker -----------------------------------------------------------------------
    def convert_file(self, src):
        self.file_unmapped = 0
        out = []
        depth = 0
        rule_open = ""
        rule_skip = 0
        rule_match, rule_props = [], []

        try:
            with open(src, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        except OSError:
            self.parse_errors.append(f"{src}: could not be read")
            return out

        if lines and lines[-1] == "":
            lines.pop()

        for lineno, raw in enumerate(lines, 1):
            body = strip_comment(raw)
            line = body.strip()

            if not line:
                t = raw.strip()
                if not rule_open:
                    if t.startswith("#"):
                        out.append("--" + t[1:])
                    elif not t:
                        out.append("")
                continue

            # --- inside a windowrule/layerrule block -----------------------------------------
            if rule_open:
                if rule_skip > 0:
                    if line.endswith("{"):
                        rule_skip += 1
                    elif line == "}":
                        rule_skip -= 1
                    continue
                if line == "}":
                    self.flush_rule(rule_open, rule_match, rule_props, out)
                    rule_open, rule_match, rule_props = "", [], []
                    continue
                if SECTION.match(line):
                    self.note_unmapped(
                        src, lineno,
                        f"a nested block inside a {rule_open} has no documented lua mapping",
                        line, out, 0)
                    rule_skip = 1
                    continue
                if "=" not in line:
                    self.parse_errors.append(
                        f"{src}:{lineno}: not a hyprlang assignment or section: {line}")
                    continue
                key, _, rest = line.partition("=")
                key = key.strip()
                val = self.expand_vars(rest.strip())
                if key.startswith("match:"):
                    rule_match.append(f"{lua_key(key[len('match:'):])} = {lua_value(val)},")
                else:
                    rule_props.append(f"{lua_key(key)} = {lua_value(val)},")
                continue

            # --- section close -----------------------------------------------------------------
            if line == "}":
                if depth == 0:
                    self.parse_errors.append(f"{src}:{lineno}: stray '}}' with no open section")
                    continue
                depth -= 1
                if depth == 0:
                    out.append(f"{indent(1)}}},")
                    out.append("})")
                else:
                    out.append(f"{indent(depth + 1)}}},")
                continue

            # --- section open ------------------------------------------------------------------
            m = SECTION.match(line)
            if m:
                name = m.group(1)
                if depth == 0:
                    if name in ("windowrule", "windowrulev2"):
                        rule_open, rule_match, rule_props = "window_rule", [], []
                        continue
                    if name in ("layerrule", "layerrulev2"):
                        rule_open, rule_match, rule_props = "layer_rule", [], []
                        continue
                    out.append("hl.config({")
                    out.append(f"{indent(1)}{lua_key(name)} = {{")
                else:
                    out.append(f"{indent(depth + 1)}{lua_key(name)} = {{")
                depth += 1
                continue

            if "=" not in line:
                self.parse_errors.append(
                    f"{src}:{lineno}: not a hyprlang assignment or section: {line}")
                continue

            key, _, rest = line.partition("=")
            key, val = key.strip(), rest.strip()

            # --- a $variable --------------------------------------------------------------------
            if key.startswith("$"):
                name = key[1:]
                if not IDENT.match(name):
                    self.parse_errors.append(
                        f"{src}:{lineno}: variable name '{key}' is not usable: {line}")
                    continue
                self.vars[name] = self.expand_vars(val)
                out.append(f"-- {key} = {self.vars[name]} (expanded inline below, as hyprlang does)")
                continue

            val = self.expand_vars(val)

            # --- inside a section ----------------------------------------------------------------
            if depth > 0:
                if is_repeatable(key):
                    self.note_unmapped(
                        src, lineno,
                        f"'{key}' is a repeatable hyprlang keyword with no documented lua mapping",
                        line, out, depth + 1)
                    continue
                out.append(f"{indent(depth + 1)}{lua_key(key)} = {lua_value(val)},")
                continue

            # --- top level ------------------------------------------------------------------------
            if key == "source":
                self.convert_source(src, lineno, val, out)
            elif key == "monitor":
                self.convert_monitor(src, lineno, val, out, line)
            elif key == "exec-once":
                out.append(f"hl.exec_cmd({lua_string(val)})")
            elif key in ("env", "envd"):
                name, sep, rest2 = val.partition(",")
                if not sep:
                    self.parse_errors.append(f"{src}:{lineno}: {key} needs NAME,value: {line}")
                else:
                    out.append(f"hl.env({lua_string(name.strip())}, {lua_string(rest2.strip())})")
            elif key.startswith("bind"):
                self.convert_bind(src, lineno, key, val, out, line)
            else:
                self.note_unmapped(
                    src, lineno,
                    f"'{key}' has no documented lua mapping in this converter", line, out, 0)

        if rule_open:
            self.parse_errors.append(f"{src}: a {rule_open} block was opened and never closed")
        if depth != 0:
            self.parse_errors.append(f"{src}: {depth} section(s) opened and never closed")
        return out


def compose(src, target, body_lines, count):
    head = [configlang.provenance("lua").rstrip("\n")]
    head.append(f"-- Converted from {src[len(target) + 1:] if src.startswith(target + '/') else src}"
                " by the hyprland-config plugin.")
    head.append("-- The original .conf is kept as a backup; see the BACKUP= line of the run.")
    if count > 0:
        head.append("--")
        head.append(f"-- NOT APPLIED: {count} line(s) below have no documented lua mapping and were")
        head.append("-- carried across as comments marked `NOT APPLIED`. They DO NOT take effect:")
        head.append("-- Hyprland loads hyprland.lua INSTEAD of hyprland.conf. The original .conf is")
        head.append("-- kept (see the KEPT= line of the run) so you can port them by hand.")
    head.append("")
    return "\n".join(head + body_lines) + "\n"


def main(argv):
    mode = "offer"
    arg = argv[1] if len(argv) > 1 else ""
    if arg == "--convert":
        mode = "convert"
    elif arg in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    elif arg:
        print("ERROR: usage: migrate-config.sh [--convert]", file=sys.stderr)
        return 2

    target = xdg.config_target("hypr", os.environ.get("HYPR_DIR", ""))
    if target is None:
        print("MIGRATE=refused-no-config-dir")
        return 2

    backup_dir = os.environ.get("HYPR_BACKUP_DIR", target)
    main_conf = f"{target}/hyprland.conf"
    home_config_dir = f"{os.environ.get('HOME', '')}/.config/hypr"  # XDG-OK: what `~` means

    print(f"TARGET={target}")

    if not os.path.isfile(main_conf):
        print(f"There is no {main_conf} to convert.")
        print("MIGRATE=nothing-to-convert")
        return 0

    if os.path.lexists(f"{target}/hyprland.lua"):
        print(f"ERROR: '{target}/hyprland.lua' already exists; refusing to replace it.",
              file=sys.stderr)
        print("       That file is what Hyprland actually loads. Move it aside first if you",
              file=sys.stderr)
        print("       really want this conversion to produce a new one.", file=sys.stderr)
        print(f"DECLINED_TO_REPLACE={target}/hyprland.lua")
        print("MIGRATE=refused-existing-lua")
        return 4

    conv = Converter(target, home_config_dir)
    try:
        scratch = tempfile.mkdtemp(prefix="hypr-migrate.")
    except OSError:
        print("ERROR: could not create a scratch directory", file=sys.stderr)
        print("MIGRATE=refused-unparseable")
        return 3

    try:
        converted = []           # (src, lua_target, stem)
        conv.queue = [main_conf]
        while conv.queue:
            src = conv.queue.pop(0)
            if src in conv.seen:
                continue
            conv.seen.append(src)
            stem = conv.lua_stem(src)
            lua_target = f"{target}/{stem}.lua"
            if os.path.lexists(lua_target):
                print(f"ERROR: '{lua_target}' already exists; refusing to replace it.",
                      file=sys.stderr)
                print(f"DECLINED_TO_REPLACE={lua_target}")
                print("MIGRATE=refused-existing-lua")
                return 4
            body = conv.convert_file(src)
            scratch_lua = f"{scratch}/{stem}.lua"
            os.makedirs(os.path.dirname(scratch_lua), exist_ok=True)
            with open(scratch_lua, "w", encoding="utf-8") as fh:
                fh.write(compose(src, target, body, conv.file_unmapped))
            converted.append((src, lua_target, stem))

        if conv.parse_errors:
            print("ERROR: this configuration does not parse as hyprlang, so nothing was changed.",
                  file=sys.stderr)
            print("       Fix the lines below and re-run; the converter will not guess at them.",
                  file=sys.stderr)
            for e in conv.parse_errors:
                print(f"UNPARSEABLE={e}")
            print(f"UNPARSEABLE_COUNT={len(conv.parse_errors)}")
            print("MIGRATE=refused-unparseable")
            return 3

        if conv.source_errors:
            print("ERROR: a 'source =' line could not be resolved, so nothing was changed.",
                  file=sys.stderr)
            print("       The converter cannot read the whole configuration, and it will not",
                  file=sys.stderr)
            print("       convert a set it has not seen: whole files would stop loading.",
                  file=sys.stderr)
            for e in conv.source_errors:
                print(f"UNRESOLVED_SOURCE={e}")
            print(f"UNRESOLVED_SOURCE_COUNT={len(conv.source_errors)}")
            print("MIGRATE=refused-unresolvable-source")
            return 3

        ts = stamp()

        if mode == "offer":
            print(f"MIGRATE_OFFER=convert {len(converted)} hyprlang .conf file(s) in {target} to lua")
            print(f"OFFER_REASON={configlang.lang_range('hyprlang')}")
            for src, lua_target, _stem in converted:
                print(f"WOULD_WRITE={lua_target}")
                print(f"WOULD_KEEP={src}")
                print(f"WOULD_BACK_UP={backup_dir}/{os.path.basename(src)}.pre-lua.{ts}")
            if conv.unmapped:
                print(f"WARNING: {len(conv.unmapped)} line(s) have no documented lua mapping. "
                      "They would be", file=sys.stderr)
                print("         carried across as '-- NOT APPLIED' comments and would STOP "
                      "APPLYING,", file=sys.stderr)
                print("         because Hyprland loads hyprland.lua instead of hyprland.conf. "
                      "The .conf", file=sys.stderr)
                print("         is kept either way, so you can port them by hand afterwards.",
                      file=sys.stderr)
                for e in conv.unmapped:
                    print(f"WOULD_NOT_APPLY={e}")
                print(f"WOULD_NOT_APPLY_COUNT={len(conv.unmapped)}")
            print("ACCEPT_WITH=migrate-config.sh --convert")
            print("MIGRATE=offered")
            return 0

        try:
            os.makedirs(backup_dir, exist_ok=True)
        except OSError:
            print(f"ERROR: could not create the backup directory '{backup_dir}'.", file=sys.stderr)
            print("       Aborted because the backup failed; no lua was written and nothing "
                  "changed.", file=sys.stderr)
            print(f"BACKUP_FAILED={backup_dir}")
            print("MIGRATE=aborted-backup-failed")
            return 5

        # Back up FIRST, and PROVE each copy is readable and identical, before a byte of lua is
        # written. A backup nobody verified is not a way back.
        made, backup_failed = [], ""
        for src, _lua_target, _stem in converted:
            b = f"{backup_dir}/{os.path.basename(src)}.pre-lua.{ts}"
            try:
                shutil.copy2(src, b)
                with open(src, "rb") as a, open(b, "rb") as c:
                    if a.read() != c.read():
                        backup_failed = b
                        break
            except OSError:
                backup_failed = b
                break
            made.append(b)
        if backup_failed:
            for b in made:
                try:
                    os.remove(b)
                except OSError:
                    pass
            print("ERROR: the backup step did not produce a readable copy of the original .conf.",
                  file=sys.stderr)
            print("       Aborted because the backup failed; no lua was written and nothing "
                  "changed.", file=sys.stderr)
            print(f"BACKUP_FAILED={backup_failed}")
            print("MIGRATE=aborted-backup-failed")
            return 5

        print(f"BACKUP={backup_dir}")
        for b in made:
            print(f"BACKED_UP={b}")

        for src, lua_target, stem in converted:
            os.makedirs(os.path.dirname(lua_target), exist_ok=True)
            shutil.copyfile(f"{scratch}/{stem}.lua", lua_target)
            print(f"WROTE={lua_target}")
            print(f"KEPT={src}")

        print("CONFIG_LANGUAGE=lua")
        print(f"CONFIG_LANGUAGE_RANGE={configlang.lang_range('lua')}")

        if conv.unmapped:
            print(f"WARNING: {len(conv.unmapped)} line(s) had no documented lua mapping. They are "
                  "in the", file=sys.stderr)
            print("         converted files as '-- NOT APPLIED' comments and DO NOT take effect.",
                  file=sys.stderr)
            print("         Every original .conf was kept, so port them by hand from there.",
                  file=sys.stderr)
            for e in conv.unmapped:
                print(f"NOT_APPLIED={e}")
            print(f"NOT_APPLIED_COUNT={len(conv.unmapped)}")
            print("MIGRATE=ok-with-unmapped")
            return 0

        print("MIGRATE=ok")
        return 0
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
