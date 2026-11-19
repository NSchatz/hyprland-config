#!/usr/bin/env python3
"""Convert a hyprlang `.conf` set to lua - or offer to, and change nothing.

Since 0.55 Hyprland reads `hyprland.lua` INSTEAD OF `hyprland.conf`, and 0.57 removed hyprlang
altogether: there, a `.conf` is loaded by nothing. This converts the whole `source =` set as ONE
unit, because converting half of it would leave the other half loaded by nothing.

Four things it refuses to do, each changing nothing:
  - replace an existing `hyprland.lua` (that file is what Hyprland actually loads)
  - convert a config that does not parse as hyprlang (it will not guess at a broken line)
  - convert a set with an unresolvable `source =` (it will not convert a set it has not seen)
  - proceed when the backup step did not produce a readable, identical copy

What it writes is the lua API as Hyprland documents it, not a transliteration of the hyprlang:
  - a dispatcher becomes its lua call (`killactive` -> `hl.dsp.window.close()`, see luadispatch)
  - a key chord joins every modifier with ` + ` (`SUPER SHIFT + Q` is rejected by Hyprland)
  - a gradient becomes `{ colors = {...}, angle = N }`, css gaps an integer or a side table
  - `exec-once` / `exec-shutdown` go INSIDE `hl.on("hyprland.start" / "hyprland.shutdown")`.
    A top-level `hl.exec_cmd()` runs on every evaluation of the file, which includes each
    reload and `Hyprland --verify-config`: checking a config must never start its autostart
  - a file that only defines `$variables` (the palette the theme engine regenerates) becomes a
    module that RETURNS them, and the files that use one read it with `require()`. Expanding
    the colours inline would freeze the theme into every other file

A construct with NO lua form this converter can place is not a refusal: it is carried across
as a `-- NOT APPLIED` comment, counted, and reported. Those lines STOP APPLYING - lua is loaded
instead of the .conf - so every original .conf is kept, and the report says so in as many
words. A line that converted but deserves a second look (a gap list hyprlang read differently
from how it was written, a command that calls `hyprctl keyword`) is marked `-- REVIEW` and
reported the same way.

Usage: migrate-config.sh [--convert]     (no flag = offer only, writes nothing)
Exit:  0 offered / converted, 2 usage or no config dir, 3 unparseable or unresolvable source,
       4 an existing lua config, 5 the backup failed.
"""
import os
import re
import shutil
import sys
import textwrap

from .. import xdg
from ..clock import stamp
from . import configlang
from . import ledger
from . import luadispatch
from .luadispatch import lua_string

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SECTION = re.compile(r"^([A-Za-z_][A-Za-z0-9_:.-]*)\s*\{$")
INT_RE = re.compile(r"^-?\d+$")
FLOAT_RE = re.compile(r"^-?\d*\.\d+$")
NUM_RE = luadispatch.NUM_RE
CANONICAL_NUM_RE = re.compile(r"^-?(?:0|[1-9]\d*)(?:\.(?:\d*[1-9]|0))?$")
COLOR_RE = re.compile(r"^(?:rgba?\([^()]*\)|0x[0-9a-fA-F]{6,8})$")
ANGLE_RE = re.compile(r"^(-?\d+(?:\.\d+)?)deg$")
VAR_LINE = re.compile(r"^\$[A-Za-z_][A-Za-z0-9_]*\s*=")

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if",
    "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}

# hyprlang keywords: statements, not options. Inside a `section { }` they are still statements,
# so they are emitted AFTER the section's hl.config() call rather than as a table key - a lua
# table holds one value per key, and twelve `animation =` lines would collapse into the last.
KEYWORDS = {
    "bezier", "animation", "gesture", "windowrule", "windowrulev2", "layerrule", "layerrulev2",
    "workspace", "blurls", "permission", "submap", "plugin", "source", "monitor", "monitorv2",
    "env", "envd", "exec", "exec-once", "exec-shutdown", "unbind",
}

TRUE_WORDS = {"true", "yes", "on"}
FALSE_WORDS = {"false", "no", "off"}

# Option types the VALUE alone does not reveal, by lua option path. From the stubs Hyprland
# 0.57 ships (/usr/share/hypr/stubs/hl.meta.lua, HL.ConfigValueTypes). An option that is not
# listed is a boolean or a number, which the value does reveal.
STRING_OPTIONS = frozenset("""
    cursor.default_monitor decoration.blur.acrylic.tint decoration.blur.aurora.color1
    decoration.blur.aurora.color2 decoration.blur.fluid_jar.color decoration.screen_shader
    general.layout general.locale group.groupbar.font_family group.groupbar.text_color
    group.groupbar.text_color_inactive group.groupbar.text_color_locked_active
    group.groupbar.text_color_locked_inactive input.accel_profile input.kb_file input.kb_layout
    input.kb_model input.kb_options input.kb_rules input.kb_variant input.scroll_method
    input.scroll_points input.tablet.output input.touchdevice.output
    input.touchpad.tap_button_map master.center_master_fallback master.new_on_active
    master.new_status master.orientation misc.background_color misc.bell_sound misc.col.splash
    misc.font_family misc.splash_font_family misc.swallow_exception_regex misc.swallow_regex
    render.cm_sdr_eotf scrolling.direction scrolling.explicit_column_widths
""".split())
GRADIENT_OPTIONS = frozenset("""
    decoration.glow.color decoration.glow.color_inactive decoration.shadow.color
    decoration.shadow.color_inactive general.col.active_border general.col.inactive_border
    general.col.nogroup_border general.col.nogroup_border_active group.col.border_active
    group.col.border_inactive group.col.border_locked_active group.col.border_locked_inactive
    group.groupbar.col.active group.groupbar.col.inactive group.groupbar.col.locked_active
    group.groupbar.col.locked_inactive
""".split())
VEC2_OPTIONS = frozenset("""
    decoration.shadow.offset input.tablet.active_area_position input.tablet.active_area_size
    input.tablet.region_position input.tablet.region_size layout.single_window_aspect_ratio
""".split())
CSSGAP_OPTIONS = frozenset("general.gaps_in general.gaps_out general.float_gaps".split())

# Rule fields that are text even when the value reads like a boolean or a number
# (`tonemap = off` is a mode name, `match:title = true` is a regex).
RULE_STRING_FIELDS = frozenset("""
    name tonemap content idle_inhibit suppress_event tag group animation fullscreen_state
    border_color
""".split())
MATCH_STRING_FIELDS = frozenset("""
    class title initial_class initial_title tag xdg_tag content namespace
""".split())
DEVICE_STRING_FIELDS = frozenset("""
    name kb_layout kb_variant kb_options kb_rules kb_model kb_file accel_profile scroll_method
    scroll_points tap_button_map output tags
""".split())
MONITOR_STRING_FIELDS = frozenset("output mode position mirror cm sdr_eotf icc".split())
MONITOR_FIELDS = MONITOR_STRING_FIELDS | frozenset("""
    bitdepth disabled max_avg_luminance max_luminance min_luminance scale sdr_max_luminance
    sdr_min_luminance sdrbrightness sdrsaturation supports_hdr supports_wide_color transform vrr
""".split())
# `monitor = name, mode, position, scale, <key>, <value>, ...` - the trailing pairs.
MONITOR_EXTRAS = {"transform", "mirror", "bitdepth", "vrr", "cm", "sdrbrightness",
                  "sdrsaturation"}

# hyprlang workspace-rule names -> the lua field. A leading `!` means the lua field is the
# NEGATION (`border:false` is `no_border = true`).
WORKSPACE_RULES = {
    "monitor": "monitor", "default": "default", "persistent": "persistent",
    "gapsin": "gaps_in", "gapsout": "gaps_out", "bordersize": "border_size",
    "border": "!no_border", "rounding": "!no_rounding", "shadow": "!no_shadow",
    "decorate": "decorate", "defaultName": "default_name", "animation": "animation",
    "layout": "layout", "on-created-empty": "on_created_empty", "layoutopt": "layout_opts",
}
WORKSPACE_STRING_RULES = {"monitor", "default_name", "animation", "layout"}

GESTURE_ACTIONS = {"workspace", "move", "resize", "special", "close", "fullscreen", "float",
                   "unset"}

# The first release that reads lua. A key removed at or before it has no lua form at all.
LUA_FLOOR = "0.55"


def lua_value(v):
    v = (v or "").strip()
    if v == "":
        return lua_string("")
    if v in TRUE_WORDS:
        return "true"
    if v in FALSE_WORDS:
        return "false"
    if INT_RE.match(v) or FLOAT_RE.match(v):
        return v
    return lua_string(v)


def module_value(v):
    """A value held by a variables module. It is a lua number only when the text is that
    number's canonical spelling: `000000` is a colour, not zero, and it has to survive being
    spliced back into a string (`rgba($alphaee)`) digit for digit."""
    v = (v or "").strip()
    if CANONICAL_NUM_RE.match(v) or v in TRUE_WORDS or v in FALSE_WORDS:
        return lua_value(v)
    return lua_string(v)


def lua_key(k):
    if k in LUA_KEYWORDS or not IDENT.match(k):
        return f"[{lua_string(k)}]"
    return k


def lua_name(k):
    """A hyprlang option name as lua spells it: `tap-to-click` is `tap_to_click`."""
    return k.replace("-", "_")


def lua_comment(text):
    """`# text` -> `-- text`. A hyprlang comment that starts with `[` would open a lua BLOCK
    comment (`--[[`) and swallow everything after it, so it gets a space first."""
    return "--" + (" " if text.startswith("[") else "") + text


def split_comment(s):
    """(code, comment). Only a ` #` (whitespace then hash) opens a trailing comment, matching
    hyprlang; a line that is nothing but a comment has no code."""
    t = s.strip()
    if t.startswith("#"):
        return "", t[1:]
    m = re.search(r"\s#", s)
    if m:
        return s[:m.start()], s[m.end():]
    return s, None


def with_trailing(line, trailing):
    return f"{line}  -- {trailing.strip()}" if trailing and trailing.strip() else line


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def is_variables_file(lines):
    """True for text that defines `$variables` and nothing else: a palette file."""
    code = [split_comment(raw)[0].strip() for raw in lines]
    code = [c for c in code if c]
    return bool(code) and all(VAR_LINE.match(c) for c in code)


def variables_module(lines, define=lambda name, value: value):
    """`$accent = rgb(...)` lines as the two halves of a lua module: the comments above the
    first variable, and the fields of the table it returns. `define` sees each (name, value)
    and returns the value to store.

    Shared with the theme engine (rendertemplates), which regenerates this same module on every
    theme change and has to write it the way the converter did."""
    head, body = [], []
    for raw in lines:
        code, comment = split_comment(raw)
        line = code.strip()
        if not line:
            target = body if body else head
            text = raw.strip()
            if text.startswith("#"):
                target.append(lua_comment(text[1:]) if target is head
                              else "    " + lua_comment(text[1:]))
            elif not text:
                target.append("")
            continue
        key, _, rest = line.partition("=")
        name = key.strip()[1:]
        value = define(name, rest.strip())
        body.append(with_trailing(f"    {lua_key(name)} = {module_value(value)},", comment))
    return head, body


class ExistingLua(Exception):
    """A `.lua` this conversion would write is already there."""


class Node:
    """One `section { }`, kept as a tree until it closes so that `col.active_border` can land
    in a `col = { }` sub-table and a repeated sub-section merges instead of overwriting."""

    def __init__(self, name):
        self.name = name
        self.items = []     # ("blank",) ("comment", text) ("kv", key, lua, trailing) ("node", Node)

    def child(self, name):
        for item in self.items:
            if item[0] == "node" and item[1].name == name:
                return item[1]
        node = Node(name)
        self.items.append(("node", node))
        return node

    def has_values(self):
        return any(i[0] == "kv" or (i[0] == "node" and i[1].has_values()) for i in self.items)

    def render(self, level):
        pad = "    " * level
        out = []
        for item in self.items:
            if item[0] == "blank":
                out.append("")
            elif item[0] == "comment":
                out.append(pad + item[1])
            elif item[0] == "kv":
                out.append(with_trailing(f"{pad}{lua_key(item[1])} = {item[2]},", item[3]))
            else:
                out.append(f"{pad}{lua_key(item[1].name)} = {{")
                out.extend(item[1].render(level + 1))
                out.append(f"{pad}}},")
        return out


class FileCtx:
    """Where one `.conf` is in its conversion."""

    def __init__(self, src):
        self.src = src
        self.out = []
        self.sink = self.out    # a section redirects statements here until it closes
        self.level = 0          # indentation: inside an hl.on() or hl.define_submap() body
        self.pending = []       # comment and blank lines not placed yet
        self.group = None       # the hl.on() event block currently open
        self.submap = None
        self.unmapped = 0
        self.reviews = 0
        self.requires = []      # (alias, stem) of each variables module this file reads
        self.autostart_note = False


class Converter:
    def __init__(self, target, home_config_dir, removed=None):
        self.target = target
        self.home_config_dir = home_config_dir
        self.removed = removed or {}
        self.vars = {}          # $variables expanded inline, as hyprlang does
        self.modvars = {}       # $variables that live in a module: name -> (alias, stem, value)
        self.aliases = {}       # stem -> the local name its module is read through
        self.parse_errors = []
        self.source_errors = []
        self.unmapped = []
        self.reviews = []
        self.seen = []
        self.converted = []     # (src, lua_target, stem, text), main file first
        self.f = None

    # --- $variables -----------------------------------------------------------------------
    def segments(self, s, depth=0):
        """Split a value into literal text and references to module variables. Inline
        variables are substituted on the way, longest name first, so `$mainMod2` is not eaten
        by `$mainMod`."""
        names = sorted(set(self.vars) | set(self.modvars), key=len, reverse=True)
        out, lit, i = [], "", 0
        while i < len(s):
            hit = None
            if s[i] == "$":
                hit = next((n for n in names if s.startswith(n, i + 1)), None)
            if hit is None:
                lit += s[i]
                i += 1
                continue
            if lit:
                out.append(("lit", lit))
                lit = ""
            if hit in self.modvars:
                out.append(("ref", hit))
            elif depth < 8:
                out.extend(self.segments(self.vars[hit], depth + 1))
            else:
                out.append(("lit", self.vars[hit]))
            i += 1 + len(hit)
        if lit:
            out.append(("lit", lit))
        return out

    def flatten(self, segs):
        """The value as hyprlang would have expanded it: every variable replaced by its text."""
        return "".join(t if k == "lit" else self.modvars[t][2] for k, t in segs)

    def expand(self, s):
        return self.flatten(self.segments(s))

    def ref(self, name):
        alias, stem, _value = self.modvars[name]
        if (alias, stem) not in self.f.requires:
            self.f.requires.append((alias, stem))
        return f"{alias}.{name}" if lua_key(name) == name else f"{alias}[{lua_string(name)}]"

    def words(self, segs):
        """Whitespace-separated words, each a list of segments. Parentheses keep a word
        together (`rgba(255, 0, 0, 0.5)`), and a module variable holding SEVERAL words is
        expanded in place: only a one-word value can stay a reference."""
        flat = []
        for kind, text in segs:
            if kind == "ref" and len(self.modvars[text][2].split()) != 1:
                kind, text = "lit", self.modvars[text][2]
            flat.append((kind, text))
        words, cur, depth = [], [], 0
        for kind, text in flat:
            if kind == "ref":
                cur.append((kind, text))
                continue
            buf = ""
            for ch in text:
                if ch in " \t" and depth == 0:
                    if buf:
                        cur.append(("lit", buf))
                        buf = ""
                    if cur:
                        words.append(cur)
                        cur = []
                    continue
                depth += ch == "("
                depth -= ch == ")" and depth > 0
                buf += ch
            if buf:
                cur.append(("lit", buf))
        if cur:
            words.append(cur)
        return words

    def scalar(self, segs, string=False):
        """One lua value. With no module reference it is a literal; a lone reference stays a
        reference; anything mixed (`rgba($accentAlphaee)`) becomes a concatenation."""
        if not any(k == "ref" for k, _ in segs):
            text = "".join(t for _, t in segs).strip()
            return lua_string(text) if string else lua_value(text)
        segs = list(segs)
        if segs and segs[0][0] == "lit":
            segs[0] = ("lit", segs[0][1].lstrip())
        if segs and segs[-1][0] == "lit":
            segs[-1] = ("lit", segs[-1][1].rstrip())
        segs = [s for s in segs if s[0] == "ref" or s[1]]
        if len(segs) == 1:
            return self.ref(segs[0][1])
        parts = []
        for kind, text in segs:
            if kind == "lit":
                parts.append(lua_string(text))
            elif module_value(self.modvars[text][2]).startswith('"'):
                parts.append(self.ref(text))
            else:
                parts.append(f"tostring({self.ref(text)})")
        return " .. ".join(parts)

    def gradient(self, words):
        """`rgb(a) rgb(b) 45deg` -> `{ colors = { "rgb(a)", "rgb(b)" }, angle = 45 }`.
        None when the value is not several colours: a single colour is an ordinary string."""
        colors, angle = [], None
        for i, word in enumerate(words):
            text = self.flatten(word)
            m = ANGLE_RE.match(text)
            if m and colors and i == len(words) - 1:
                angle = m.group(1)
            elif COLOR_RE.match(text):
                colors.append(self.scalar(word, string=True))
            else:
                return None
        if len(colors) < 2 and angle is None:
            return None
        table = f"{{ colors = {{ {', '.join(colors)} }}"
        return table + (f", angle = {angle} }}" if angle is not None else " }")

    # --- typed option values ----------------------------------------------------------------
    def css_gap(self, text):
        """(lua, review) for a css gap, or (None, why). hyprlang splits a gap list on COMMAS;
        a space-separated list was read as its first number on every side, so that is what a
        faithful conversion emits - with a note, because it is rarely what the author meant."""
        text = text.strip()
        if INT_RE.match(text):
            return text, None

        def sides(values):
            # The css shorthand: 2 values are top/bottom and left/right, 3 are top, left/right,
            # bottom, 4 are top, right, bottom, left.
            top = values[0]
            right = values[1]
            bottom = values[2] if len(values) > 2 else top
            left = values[3] if len(values) > 3 else right
            return f"{{ top = {top}, right = {right}, bottom = {bottom}, left = {left} }}"

        parts = [p.strip() for p in text.split(",")]
        if 2 <= len(parts) <= 4 and all(INT_RE.match(p) for p in parts):
            return sides(parts), None
        words = text.split()
        if 2 <= len(words) <= 4 and all(INT_RE.match(w) for w in words):
            return words[0], (
                f"`{text}` is space-separated. hyprlang splits a gap list on commas only, so "
                f"it read this as {words[0]} on every side, and that is what was emitted. If "
                f"the sides were meant, use:\n    {sides(words)}")
        return None, "a gap is an integer or a comma-separated top, right, bottom, left list"

    def option(self, path, segs):
        """(lua, review) for `section { key = value }`, typed by the option's lua path, or
        (None, why) when the value cannot be written for that type."""
        if path in CSSGAP_OPTIONS:
            return self.css_gap(self.flatten(segs))
        if path in VEC2_OPTIONS:
            words = self.flatten(segs).split()
            if len(words) == 2 and all(NUM_RE.match(w) for w in words):
                return f"{{ {words[0]}, {words[1]} }}", None
            return lua_string(self.flatten(segs).strip()), None
        if path in STRING_OPTIONS:
            return self.scalar(segs, string=True), None
        grad = self.gradient(self.words(segs))
        if grad:
            return grad, None
        return self.scalar(segs, string=path in GRADIENT_OPTIONS), None

    # --- output ---------------------------------------------------------------------------------
    def emit(self, lines):
        pad = "    " * self.f.level
        for line in lines:
            self.f.sink.append(pad + line if line else "")

    def flush_pending(self):
        self.emit(self.f.pending)
        self.f.pending = []

    def close_group(self):
        """End the open hl.on() block. Comments still pending stay pending: they came after the
        last command, so they belong after the block, not inside it."""
        if self.f.group:
            self.f.level -= 1
            self.emit(["end)"])
            self.f.group = None

    def statement(self, lines, trailing=None):
        self.close_group()
        self.flush_pending()
        if trailing and len(lines) == 1:
            lines = [with_trailing(lines[0], trailing)]
        self.emit(lines)

    def event_command(self, event, line, trailing):
        """`exec-once` / `exec-shutdown`: a command inside the event's hl.on() block.

        Consecutive commands share one block, with the comments between them. The comment
        block directly above the first command moves inside with it; anything above a blank
        line stays where it was."""
        f = self.f
        if f.group != event:
            self.close_group()
            cut = max((i + 1 for i, p in enumerate(f.pending) if p == ""), default=0)
            head, tail = f.pending[:cut], f.pending[cut:]
            f.pending = []
            self.emit(head)
            if f.sink and f.sink[-1].strip() == "end)":
                self.emit([""])
            if not f.autostart_note:
                f.autostart_note = True
                self.emit([
                    "-- exec-once and exec-shutdown run from the hyprland.start and "
                    "hyprland.shutdown events.",
                    "-- Do not call hl.exec_cmd() at the top level of a config file: that runs "
                    "on EVERY",
                    "-- evaluation of it, which includes each reload and "
                    "`Hyprland --verify-config`.",
                ])
            self.emit([f'hl.on("{event}", function()'])
            f.group = event
            f.level += 1
            self.emit(tail)
        else:
            self.flush_pending()
        self.emit([with_trailing(line, trailing)])

    def close_submap(self):
        if self.f.submap is not None:
            self.close_group()
            self.flush_pending()
            self.f.level -= 1
            self.emit(["end)"])
            self.f.submap = None

    def note_unmapped(self, lineno, why, text, node=None):
        self.unmapped.append(f"{self.f.src}:{lineno}: {why}: {text}")
        self.f.unmapped += 1
        line = f"-- NOT APPLIED ({why}): {text}"
        if node is not None:
            node.items.append(("comment", line))
        else:
            self.statement([line])

    def review(self, lineno, why, text):
        """Record a caveat and return the comment lines that carry it into the lua. A newline
        in `why` starts a new comment line, so a suggested value is not wrapped mid-table."""
        self.reviews.append(f"{self.f.src}:{lineno}: {' '.join(why.split())}: {text}")
        self.f.reviews += 1
        out = []
        for para in f"REVIEW: {why}".split("\n"):
            out += textwrap.wrap(para, width=92, break_long_words=False, break_on_hyphens=False)
        return [f"-- {w}" for w in out]

    def lua_stem(self, path):
        p = path[len(self.target) + 1:] if path.startswith(self.target + "/") else path
        p = p[:-5] if p.endswith(".conf") else p
        # `require("my.theme")` reads the dot as a directory separator, so a dotted file name
        # cannot keep its dots.
        head, _, base = p.rpartition("/")
        base = base.replace(".", "_")
        return f"{head}/{base}" if head else base

    def command(self, lineno, cmd, text):
        """A shell command on its way into hl.exec_cmd / hl.dsp.exec_cmd, with any legacy
        hyprctl call rewritten or flagged. Returns (command, comment lines)."""
        new, note = luadispatch.modernize_command(cmd)
        return new, (self.review(lineno, note, text) if note else [])

    # --- keywords -------------------------------------------------------------------------------
    def convert_source(self, lineno, val, line, trailing):
        src = self.f.src
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
        # Containment is decided on the NORMALISED path, so `./x.conf` is `x.conf` and a
        # `../elsewhere/x.conf` cannot pass as living under the config dir.
        root = os.path.normpath(self.target)
        norm = os.path.normpath(p)
        if not norm.startswith(root + "/"):
            self.source_errors.append(
                f"{src}:{lineno}: sourced file lives outside {self.target}: {p}")
            return
        p = f"{self.target}/{norm[len(root) + 1:]}"
        # hyprlang reads a sourced file AT the `source =` line, so what it defines is visible
        # to everything after that line and to nothing before it. Convert it here, in place.
        saved = self.f
        self.convert_one(p)
        self.f = saved
        stem = self.lua_stem(p)
        if stem in self.aliases:
            alias = self.aliases[stem]
            self.statement([
                f"-- {line}",
                f"-- {stem}.lua returns a table of values instead of running anything. A file "
                "that needs one",
                f"-- reads it with:  local {alias} = require({lua_string(stem)})",
            ])
        else:
            self.statement([f"require({lua_string(stem)})"], trailing)

    def convert_monitor(self, lineno, val, line, trailing):
        parts = [p.strip() for p in val.split(",")]
        output = f"output = {lua_string(parts[0])}"
        if len(parts) == 2 and parts[1] in ("disable", "disabled"):
            self.statement([f"hl.monitor({{ {output}, disabled = true }})"], trailing)
            return
        extras = parts[4:]
        if len(parts) < 4 or len(extras) % 2 or any(k not in MONITOR_EXTRAS for k in extras[::2]):
            self.note_unmapped(
                lineno, "only 'monitor = output, mode, position, scale' with transform, mirror, "
                "bitdepth, vrr, cm, sdrbrightness or sdrsaturation pairs has a lua form here",
                line)
            return
        fields = [output, f"mode = {lua_string(parts[1])}", f"position = {lua_string(parts[2])}",
                  f"scale = {lua_value(parts[3])}"]
        for k, v in zip(extras[::2], extras[1::2]):
            fields.append(f"{k} = {lua_string(v) if k in MONITOR_STRING_FIELDS else lua_value(v)}")
        self.statement([f"hl.monitor({{ {', '.join(fields)} }})"], trailing)

    def convert_bind(self, lineno, key, val, line, trailing):
        flags = key[len("bind"):]
        has_description, mouse = False, False
        opts = []
        for ch in flags:
            if ch == "d":
                has_description = True
                continue
            opt = luadispatch.BIND_FLAGS.get(ch)
            if not opt:
                self.note_unmapped(
                    lineno, f"bind flag '{ch}' in '{key}' has no lua option this converter knows",
                    line)
                return
            mouse = mouse or ch == "m"
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
                f"{self.f.src}:{lineno}: bind needs MODS, KEY, DISPATCHER: {key} = {val}")
            return
        # Everything after the dispatcher field is ONE argument, commas and all.
        arg = ",".join(parts[nxt + 1:]).strip()

        chord, why = luadispatch.chord(mods, keyname)
        if chord is None:
            self.note_unmapped(lineno, why, line)
            return
        notes = []
        if dispatcher == "exec" and not mouse:
            arg, notes = self.command(lineno, arg, line)
        call, why = luadispatch.translate(dispatcher, arg, mouse)
        if call is None:
            self.note_unmapped(lineno, why, line)
            return
        if description:
            opts.append(f"description = {lua_string(description)}")
        tail = f", {{ {', '.join(opts)} }}" if opts else ""
        self.statement(notes + [with_trailing(f"hl.bind({lua_string(chord)}, {call}{tail})",
                                              trailing)])

    def convert_submap(self, lineno, val, line, trailing):
        name, _, reset = [p.strip() for p in val.partition(",")]
        self.close_submap()
        if name == "reset":
            self.close_group()
            self.flush_pending()
            return
        if not name:
            self.parse_errors.append(f"{self.f.src}:{lineno}: submap needs a name: {line}")
            return
        target = f"{lua_string(reset)}, " if reset else ""
        self.statement([f"hl.define_submap({lua_string(name)}, {target}function()"], trailing)
        self.f.submap = name
        self.f.level += 1

    def convert_bezier(self, lineno, val, line, trailing):
        parts = [p.strip() for p in val.split(",")]
        if len(parts) != 5 or not all(NUM_RE.match(p) for p in parts[1:]):
            self.note_unmapped(lineno, "'bezier' needs NAME, X0, Y0, X1, Y1", line)
            return
        self.statement([
            f'hl.curve({lua_string(parts[0])}, {{ type = "bezier", points = '
            f"{{ {{ {parts[1]}, {parts[2]} }}, {{ {parts[3]}, {parts[4]} }} }} }})"], trailing)

    def convert_animation(self, lineno, val, line, trailing):
        parts = [p.strip() for p in val.split(",")]
        enabled = lua_value(parts[1]) if len(parts) > 1 else ""
        enabled = {"1": "true", "0": "false"}.get(enabled, enabled)
        if not parts[0] or enabled not in ("true", "false") or len(parts) == 3:
            self.note_unmapped(
                lineno, "'animation' needs NAME, ONOFF[, SPEED, CURVE[, STYLE]]", line)
            return
        fields = [f"leaf = {lua_string(parts[0])}", f"enabled = {enabled}"]
        if len(parts) > 3:
            if not NUM_RE.match(parts[2]):
                self.note_unmapped(lineno, "the animation speed is not a number", line)
                return
            fields += [f"speed = {parts[2]}", f"bezier = {lua_string(parts[3])}"]
        if len(parts) > 4 and parts[4]:
            fields.append(f"style = {lua_string(', '.join(parts[4:]))}")
        self.statement([f"hl.animation({{ {', '.join(fields)} }})"], trailing)

    def convert_workspace(self, lineno, val, line, trailing):
        parts = [p.strip() for p in val.split(",")]
        selector = parts[0]
        fields = [f"workspace = {lua_string(selector)}"]
        notes = []
        for rule in parts[1:]:
            name, sep, value = rule.partition(":")
            value = value.strip()
            field = WORKSPACE_RULES.get(name.strip())
            if not field or not sep:
                self.note_unmapped(
                    lineno, f"workspace rule '{name.strip()}' has no lua field this converter "
                    "knows", line)
                return
            if field == "on_created_empty":
                # hyprlang prefixed every on-created-empty command with the workspace it was
                # declared for; the lua API stores the string as written. Spell it out, so the
                # command still opens on that workspace.
                rule_text = f"workspace {selector}"
                if value.startswith("[") and "]" in value:
                    close = value.rindex("]")
                    inner = [r.strip() for r in value[1:close].split(";") if r.strip()]
                    had = any(r.startswith("workspace") for r in inner)
                    inner = [rule_text if r.startswith("workspace") else r for r in inner]
                    value = f"[{';'.join(inner if had else inner + [rule_text])}] " \
                            f"{value[close + 1:].strip()}"
                else:
                    value = f"[{rule_text}] {value}"
                value, notes = self.command(lineno, value, line)
                notes += self.review(
                    lineno, "on_created_empty still works on Hyprland 0.57 but is deprecated "
                    'there; its replacement is an hl.on("workspace.created") handler', line)
                fields.append(f"on_created_empty = {lua_string(value)}")
            elif field == "layout_opts":
                k, sep2, v = value.partition(":")
                if not sep2:
                    self.note_unmapped(lineno, "'layoutopt' needs key:value", line)
                    return
                fields.append(f"layout_opts = {{ {lua_key(lua_name(k.strip()))} = "
                              f"{lua_value(v)} }}")
            elif field in ("gaps_in", "gaps_out"):
                # In a workspace rule the gap list is SPACE separated: the comma splits rules.
                gap, why = self.css_gap(",".join(value.split()))
                if gap is None:
                    self.note_unmapped(lineno, why, line)
                    return
                fields.append(f"{field} = {gap}")
            elif field.startswith("!"):
                flag = lua_value(value)
                if flag not in ("true", "false"):
                    self.note_unmapped(lineno, f"'{name.strip()}' needs true or false", line)
                    return
                fields.append(f"{field[1:]} = {'false' if flag == 'true' else 'true'}")
            elif field in WORKSPACE_STRING_RULES:
                fields.append(f"{field} = {lua_string(value)}")
            else:
                fields.append(f"{field} = {lua_value(value)}")
        self.statement(notes + [with_trailing(f"hl.workspace_rule({{ {', '.join(fields)} }})",
                                              trailing)])

    def convert_gesture(self, lineno, val, line, trailing):
        parts = [p.strip() for p in val.split(",")]
        if len(parts) < 3 or not INT_RE.match(parts[0]):
            self.note_unmapped(lineno, "'gesture' needs FINGERS, DIRECTION, ACTION", line)
            return
        fields = [f"fingers = {parts[0]}", f"direction = {lua_string(parts[1])}"]
        rest = parts[2:]
        while rest and (rest[0].startswith("mod:") or rest[0].startswith("scale:")):
            name, _, value = rest.pop(0).partition(":")
            value = value.strip()
            if name == "scale" and not NUM_RE.match(value):
                self.note_unmapped(lineno, "the gesture scale is not a number", line)
                return
            fields.append(f"mods = {lua_string(value)}" if name == "mod" else f"scale = {value}")
        action, args = (rest[0] if rest else ""), rest[1:]
        if action not in GESTURE_ACTIONS or len(args) > 1:
            self.note_unmapped(
                lineno, f"gesture action '{action}' has no lua form this converter knows", line)
            return
        fields.append(f"action = {lua_string(action)}")
        if args and action == "special":
            fields.append(f"workspace_name = {lua_string(args[0])}")
        elif args and action in ("fullscreen", "float"):
            fields.append(f"mode = {lua_string(args[0])}")
        elif args:
            self.note_unmapped(lineno, f"gesture action '{action}' takes no argument", line)
            return
        self.statement([f"hl.gesture({{ {', '.join(fields)} }})"], trailing)

    def keyword(self, key, val, lineno, line, trailing):
        """One statement keyword. `val` already has every variable expanded: a statement's
        SHAPE depends on its text, so a reference could not stay symbolic here anyway."""
        if key == "source":
            self.convert_source(lineno, val, line, trailing)
        elif key == "monitor":
            self.convert_monitor(lineno, val, line, trailing)
        elif key in ("exec-once", "exec-shutdown"):
            if not val:
                self.parse_errors.append(f"{self.f.src}:{lineno}: {key} needs a command: {line}")
                return
            cmd, notes = self.command(lineno, val, line)
            event = "hyprland.start" if key == "exec-once" else "hyprland.shutdown"
            for n in notes:
                self.f.pending.append(n)
            self.event_command(event, f"hl.exec_cmd({lua_string(cmd)})", trailing)
        elif key in ("env", "envd"):
            name, sep, rest = val.partition(",")
            if not sep or not name.strip():
                self.parse_errors.append(f"{self.f.src}:{lineno}: {key} needs NAME,value: {line}")
                return
            # envd also exports the variable to the systemd and D-Bus activation environment;
            # in lua that is the third argument.
            dbus = ", true" if key == "envd" else ""
            self.statement([f"hl.env({lua_string(name.strip())}, {lua_string(rest.strip())}"
                            f"{dbus})"], trailing)
        elif key.startswith("bind"):
            self.convert_bind(lineno, key, val, line, trailing)
        elif key == "unbind":
            mods, _, keyname = val.partition(",")
            chord, why = luadispatch.chord(mods, keyname)
            if chord is None:
                self.note_unmapped(lineno, why, line)
            else:
                self.statement([f"hl.unbind({lua_string(chord)})"], trailing)
        elif key == "submap":
            self.convert_submap(lineno, val, line, trailing)
        elif key == "bezier":
            self.convert_bezier(lineno, val, line, trailing)
        elif key == "animation":
            self.convert_animation(lineno, val, line, trailing)
        elif key == "workspace":
            self.convert_workspace(lineno, val, line, trailing)
        elif key == "gesture":
            self.convert_gesture(lineno, val, line, trailing)
        elif key == "permission":
            parts = [p.strip() for p in val.split(",")]
            if len(parts) != 3:
                self.note_unmapped(lineno, "'permission' needs BINARY, TYPE, MODE", line)
                return
            self.statement([
                f"hl.permission({{ binary = {lua_string(parts[0])}, type = "
                f"{lua_string(parts[1])}, mode = {lua_string(parts[2])} }})"], trailing)
        elif key in ("windowrule", "layerrule"):
            self.convert_rule_line(lineno, key, val, line)
        elif key == "exec":
            self.note_unmapped(
                lineno, "'exec' ran on every reload. Its lua form is a handler you choose: "
                'hl.on("hyprland.start") for once, hl.on("config.reloaded") for each reload. A '
                "top-level hl.exec_cmd() would also run under --verify-config", line)
        else:
            self.note_unmapped(
                lineno, f"'{key}' has no lua form this converter knows", line)

    # --- blocks -----------------------------------------------------------------------------
    def rule_value(self, key, segs, match):
        strings = MATCH_STRING_FIELDS if match else RULE_STRING_FIELDS
        return self.scalar(segs, string=key in strings)

    def flush_flat(self, block):
        kind = block["kind"]
        lines = [f"hl.{kind}({{"]
        if block["match"]:
            lines.append("    match = {")
            lines += [f"        {e}" for e in block["match"]]
            lines.append("    },")
        lines += [f"    {e}" for e in block["props"]]
        lines.append("})")
        self.statement(lines)

    def convert_rule_line(self, lineno, key, val, line):
        """`windowrule = float on, match:class kitty` - the one-line form of the 0.53 rule
        syntax: comma-separated `name value` fields, selectors spelled `match:<prop>`. The older
        forms (`windowrule = float, class:kitty`, windowrulev2) have no `match:` field and are
        not guessed at: Hyprland itself stopped reading them in 0.53."""
        fields = [f.strip().split(None, 1) for f in val.split(",") if f.strip()]
        if not any(f[0].startswith("match:") for f in fields) or any(len(f) != 2 for f in fields):
            self.note_unmapped(
                lineno, f"only the 0.53 one-line form (`{key} = <effect> <value>, match:<prop> "
                "<value>`) has a lua form here", line)
            return
        block = {"kind": "window_rule" if key == "windowrule" else "layer_rule",
                 "match": [], "props": []}
        self.close_group()
        self.flush_pending()
        for name, value in fields:
            self.flat_field(block, lineno, name, value, line, None)
        self.flush_flat(block)

    def flat_field(self, block, lineno, key, val, line, trailing):
        """One `key = value` of a windowrule / layerrule / device / monitorv2 block."""
        kind = block["kind"]
        segs = self.segments(val)
        comments = self.f.pending
        self.f.pending = []
        if key.startswith("match:") and kind in ("window_rule", "layer_rule"):
            name = lua_name(key[len("match:"):])
            block["match"] += comments
            block["match"].append(with_trailing(
                f"{lua_key(name)} = {self.rule_value(name, segs, True)},", trailing))
            return
        name = lua_name(key)
        block["props"] += comments
        if kind == "monitor" and name not in MONITOR_FIELDS:
            self.unmapped.append(f"{self.f.src}:{lineno}: 'monitorv2' field '{key}' has no lua "
                                 f"field this converter knows: {line}")
            self.f.unmapped += 1
            block["props"].append(f"-- NOT APPLIED ('monitorv2' field '{key}' has no lua field "
                                  f"this converter knows): {line}")
            return
        if kind == "device":
            value = self.scalar(segs, string=name in DEVICE_STRING_FIELDS)
        elif kind == "monitor":
            value = self.scalar(segs, string=name in MONITOR_STRING_FIELDS)
        else:
            value = self.rule_value(name, segs, False)
        block["props"].append(with_trailing(f"{lua_key(name)} = {value},", trailing))

    def section_option(self, block, lineno, key, val, line, trailing):
        """One `key = value` inside a `section { }`."""
        stack = block["stack"]
        colon = ":".join([n.name for n in stack] + [key])
        node = stack[-1]
        parts = [lua_name(p) for p in re.split(r"[:.]", key) if p]
        if not parts:
            self.parse_errors.append(f"{self.f.src}:{lineno}: not a hyprlang option: {line}")
            return
        comments = self.f.pending
        self.f.pending = []

        def place(into):
            into.items += [("blank",) if c == "" else ("comment", c) for c in comments]

        gone = self.removed.get(colon)
        if gone:
            place(node)
            self.note_unmapped(
                lineno, f"'{colon}' was removed in Hyprland {gone[0]} and has no lua form; "
                f"replacement: {gone[1]}", line, node)
            return
        # A plugin's KEYWORDS (`hyprbars-button = ...`, one line per button) are functions in
        # lua, not options. They are told apart by the hyphen, or by appearing twice - which a
        # table could not hold anyway.
        if stack[0].name == "plugin" and (
                "-" in key or any(i[0] == "kv" and i[1] == parts[-1] for i in node.items)):
            place(node)
            self.note_unmapped(
                lineno, f"'{key}' looks like a plugin keyword; in lua those are "
                "hl.plugin.<name>.<function>() calls, see the plugin's own documentation",
                line, node)
            return
        path = ".".join([n.name for n in stack] + parts)
        value, note = self.option(path, self.segments(val))
        if value is None:
            place(node)
            self.note_unmapped(lineno, f"'{colon}': {note}", line, node)
            return
        # `col.active_border` lands in a `col = { }` sub-table, and its comment goes in with it.
        # A sub-table being opened here leaves the blank lines above it outside.
        for name in parts[:-1]:
            fresh = not any(i[0] == "node" and i[1].name == name for i in node.items)
            while fresh and comments and comments[0] == "":
                node.items.append(("blank",))
                comments.pop(0)
            node = node.child(name)
        place(node)
        if note:
            node.items += [("comment", c) for c in self.review(lineno, note, line)]
        node.items.append(("kv", parts[-1], value, trailing))

    def close_section(self, block):
        """Emit the finished section, then the statements that were written inside it."""
        root = block["root"]
        self.close_group()
        self.f.sink = block["sink"]
        lines = []
        if root.name == "plugin":
            # A plugin's options exist only once the plugin is loaded; setting one earlier is
            # an "unknown config key" error. Hyprland's own example guards each plugin.
            loose = Node("plugin")
            for item in root.items:
                if item[0] != "node":
                    loose.items.append(item)
                    continue
                child = item[1]
                probe = (f"hl.plugin.{child.name}" if lua_key(child.name) == child.name
                         else f"hl.plugin[{lua_string(child.name)}]")
                lines += self.review(
                    block["line"], f"plugin '{child.name}' options apply only once the plugin "
                    "is loaded, so they are guarded; reload the config after loading it",
                    block["text"])
                lines.append(f"if {probe} ~= nil then")
                lines += ["    hl.config({", "        plugin = {",
                          f"            {lua_key(child.name)} = {{"]
                lines += child.render(4)
                lines += ["            },", "        },", "    })", "end"]
            root = loose
        if root.items and (root.has_values() or root.name != "plugin"):
            lines = ["hl.config({", f"    {lua_key(root.name)} = {{"] \
                + root.render(2) + ["    },", "})"] + lines
        if lines:
            self.emit(lines)
        self.f.sink.extend(block["deferred"])

    # --- the file walkers -------------------------------------------------------------------
    def is_vars_module(self, path):
        """A sourced file that defines `$variables` and nothing else: the palette file."""
        try:
            return is_variables_file(read_lines(path))
        except OSError:
            return False

    def module_alias(self, stem):
        base = stem.rpartition("/")[2]
        first = base[:1].lower() if base[:1].isalpha() else "v"
        alias, n = first, 2
        while alias in self.aliases.values():
            alias, n = f"{first}{n}", n + 1
        self.aliases[stem] = alias
        return alias

    def convert_vars_module(self, src):
        """`$accent = rgb(...)` lines -> `return { accent = "rgb(...)", ... }`."""
        stem = self.lua_stem(src)
        alias = self.module_alias(stem)

        def define(name, raw_value):
            # A variable built from other variables is stored expanded: a table constructor
            # cannot read its own earlier fields.
            value = self.expand(raw_value)
            self.vars.pop(name, None)
            self.modvars[name] = (alias, stem, value)
            return value

        head, body = variables_module(read_lines(src), define)
        return [
            "-- This file only defined $variables, so it became a module that RETURNS them. lua "
            "has no",
            "-- config-wide $variables: a file that needs one of these reads it with",
            f"--     local {alias} = require({lua_string(stem)})",
            f"-- and writes {alias}.<name>. Keep the values here and nowhere else, so a new "
            "theme is one file.",
        ] + ([""] if head and head[0] else []) + head + ["return {"] + body + ["}"]

    def convert_file(self, src):
        """The lua body of one ordinary `.conf`, as a list of lines."""
        f = self.f
        block = None
        skip = 0

        try:
            lines = read_lines(src)
        except OSError:
            self.parse_errors.append(f"{src}: could not be read")
            return f.out

        for lineno, raw in enumerate(lines, 1):
            body, trailing = split_comment(raw)
            line = body.strip()

            if not line:
                text = raw.strip()
                if skip == 0:
                    f.pending.append(lua_comment(text[1:]) if text.startswith("#") else "")
                continue

            # --- a nested block inside a rule, which has no lua form: skip to its end ---------
            if skip > 0:
                skip += line.endswith("{")
                skip -= line == "}"
                continue

            flat = block is not None and block["kind"] != "section"

            # --- a block closes ---------------------------------------------------------------
            if line == "}":
                if block is None:
                    self.parse_errors.append(f"{src}:{lineno}: stray '}}' with no open section")
                elif flat:
                    block["props"] += f.pending
                    f.pending = []
                    self.flush_flat(block)
                    block = None
                else:
                    node = block["stack"].pop()
                    for item in f.pending:
                        node.items.append(("blank",) if item == "" else ("comment", item))
                    f.pending = []
                    if not block["stack"]:
                        self.close_section(block)
                        block = None
                continue

            # --- a block opens ----------------------------------------------------------------
            m = SECTION.match(line)
            if m:
                name = m.group(1)
                if flat:
                    self.unmapped.append(f"{src}:{lineno}: a nested block inside a "
                                         f"{block['kind']} has no lua form: {line}")
                    f.unmapped += 1
                    block["props"].append(f"-- NOT APPLIED (a nested block inside a "
                                          f"{block['kind']} has no lua form): {line}")
                    skip = 1
                elif block is not None:
                    node = block["stack"][-1]
                    for item in f.pending:
                        node.items.append(("blank",) if item == "" else ("comment", item))
                    f.pending = []
                    for part in [p for p in name.split(":") if p]:
                        node = node.child(lua_name(part))
                    block["stack"].append(node)
                else:
                    kind = {"windowrule": "window_rule", "windowrulev2": "window_rule",
                            "layerrule": "layer_rule", "layerrulev2": "layer_rule",
                            "device": "device", "monitorv2": "monitor"}.get(name)
                    self.close_group()
                    self.flush_pending()
                    if kind:
                        block = {"kind": kind, "match": [], "props": []}
                    else:
                        block = {"kind": "section", "root": Node(lua_name(name)), "sink": f.sink,
                                 "deferred": [], "line": lineno, "text": line}
                        block["stack"] = [block["root"]]
                        f.sink = block["deferred"]
                continue

            if "=" not in line:
                self.parse_errors.append(
                    f"{src}:{lineno}: not a hyprlang assignment or section: {line}")
                continue

            key, _, rest = line.partition("=")
            key, val = key.strip(), rest.strip()

            # --- a $variable ------------------------------------------------------------------
            if key.startswith("$"):
                name = key[1:]
                if not IDENT.match(name):
                    self.parse_errors.append(
                        f"{src}:{lineno}: variable name '{key}' is not usable: {line}")
                    continue
                # Expanded now, as hyprlang does - except a reference to a module variable,
                # which stays a reference so the module remains the one place it is defined.
                self.vars[name] = "".join(
                    t if k == "lit" else f"${t}" for k, t in self.segments(val))
                self.modvars.pop(name, None)
                shown = with_trailing(f"-- {key} = {self.vars[name]} (expanded inline below, as "
                                      "hyprlang does)", trailing)
                if block is not None and not flat:
                    block["stack"][-1].items.append(("comment", shown))
                elif flat:
                    block["props"].append(shown)
                else:
                    f.pending.append(shown)
                continue

            if flat:
                self.flat_field(block, lineno, key, val, line, trailing)
            elif block is not None and not (key in KEYWORDS or key.startswith("bind")):
                self.section_option(block, lineno, key, val, line, trailing)
            elif key in KEYWORDS or key.startswith("bind"):
                self.keyword(key, self.expand(val), lineno, line, trailing)
            elif ":" in key and all(IDENT.match(lua_name(p)) for p in re.split(r"[:.]", key)):
                # `decoration:blur:enabled = true` at the top level: a one-option section.
                top, _, rest_key = key.partition(":")
                one = {"kind": "section", "root": Node(lua_name(top)), "sink": f.sink,
                       "deferred": [], "line": lineno, "text": line}
                one["stack"] = [one["root"]]
                self.close_group()
                self.flush_pending()
                self.section_option(one, lineno, rest_key, val, line, trailing)
                self.close_section(one)
            else:
                self.note_unmapped(lineno, f"'{key}' has no lua form this converter knows", line)

        if block is not None and block["kind"] != "section":
            self.parse_errors.append(f"{src}: a {block['kind']} block was opened and never closed")
        elif block is not None:
            self.parse_errors.append(
                f"{src}: {len(block['stack'])} section(s) opened and never closed")
            f.sink = block["sink"]
        if f.submap is not None:
            name = f.submap
            self.close_submap()
            self.emit(self.review(
                len(lines), f"submap '{name}' was still open at the end of the file; it is "
                "closed here, where hyprlang would have carried it into the next file",
                f"submap = {name}"))
        self.close_group()
        self.flush_pending()
        return f.out

    def convert_one(self, src):
        """Convert one file of the set, recording it. Raises ExistingLua rather than replace
        a `.lua` that is already there."""
        if src in self.seen:
            return
        self.seen.append(src)
        stem = self.lua_stem(src)
        lua_target = f"{self.target}/{stem}.lua"
        if os.path.lexists(lua_target):
            raise ExistingLua(lua_target)
        slot = len(self.converted)
        self.converted.append(None)
        self.f = FileCtx(src)
        module = bool(self.converted[:slot]) and self.is_vars_module(src)
        body = self.convert_vars_module(src) if module else self.convert_file(src)
        self.converted[slot] = (src, lua_target, stem, compose(src, self.target, body, self.f))


def compose(src, target, body_lines, f):
    head = [configlang.provenance("lua").rstrip("\n")]
    head.append(f"-- Converted from {src[len(target) + 1:] if src.startswith(target + '/') else src}"
                " by the hyprland-config plugin.")
    head.append("-- The original .conf is kept as a backup; see the BACKUP= line of the run.")
    if f.unmapped > 0:
        head.append("--")
        head.append(f"-- NOT APPLIED: {f.unmapped} line(s) below have no lua form this converter "
                    "could write and were")
        head.append("-- carried across as comments marked `NOT APPLIED`. They DO NOT take effect:")
        head.append("-- Hyprland loads hyprland.lua INSTEAD of hyprland.conf. The original .conf is")
        head.append("-- kept (see the KEPT= line of the run) so you can port them by hand.")
    if f.reviews > 0:
        head.append("--")
        head.append(f"-- REVIEW: {f.reviews} line(s) below converted with a caveat. Each one is "
                    "marked `REVIEW`")
        head.append("-- and says what to check.")
    head.append("")
    body = list(body_lines)
    if f.requires:
        # After the file's opening comments, before its first statement.
        at = next((i for i, line in enumerate(body)
                   if line.strip() and not line.lstrip().startswith("--")), len(body))
        block = [f"local {alias} = require({lua_string(stem)})" for alias, stem in f.requires]
        body[at:at] = block + [""]
    return "\n".join(head + body) + "\n"


def removed_keys():
    """Keys with NO lua form: removed at or before the version this conversion is for.

    The version-cliff ledger is the one place a removal is recorded. The target is the detected
    Hyprland, never lower than the first release that reads lua. An unreadable ledger (the
    standalone engine copy has none) means nothing is known to be removed, and the key is
    converted like any other."""
    try:
        rules = ledger.removed_keys(ledger.default_path())
    except OSError:
        return {}
    version = configlang.detect_version()
    if version == "unknown" or ledger.vercmp(version, LUA_FLOOR) == -1:
        version = LUA_FLOOR
    return {key: (removed_at, replacement) for key, removed_at, replacement, _src in rules
            if ledger.vercmp(version, removed_at) != -1}


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

    conv = Converter(target, home_config_dir, removed_keys())
    try:
        conv.convert_one(main_conf)
    except ExistingLua as e:
        print(f"ERROR: '{e}' already exists; refusing to replace it.", file=sys.stderr)
        print(f"DECLINED_TO_REPLACE={e}")
        print("MIGRATE=refused-existing-lua")
        return 4
    converted = [c for c in conv.converted if c]

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
        for src, lua_target, _stem, _text in converted:
            print(f"WOULD_WRITE={lua_target}")
            print(f"WOULD_KEEP={src}")
            print(f"WOULD_BACK_UP={backup_dir}/{os.path.basename(src)}.pre-lua.{ts}")
        if conv.unmapped:
            print(f"WARNING: {len(conv.unmapped)} line(s) have no lua form this converter can "
                  "write. They would be", file=sys.stderr)
            print("         carried across as '-- NOT APPLIED' comments and would STOP "
                  "APPLYING,", file=sys.stderr)
            print("         because Hyprland loads hyprland.lua instead of hyprland.conf. "
                  "The .conf", file=sys.stderr)
            print("         is kept either way, so you can port them by hand afterwards.",
                  file=sys.stderr)
            for e in conv.unmapped:
                print(f"WOULD_NOT_APPLY={e}")
            print(f"WOULD_NOT_APPLY_COUNT={len(conv.unmapped)}")
        if conv.reviews:
            for e in conv.reviews:
                print(f"WOULD_REVIEW={e}")
            print(f"WOULD_REVIEW_COUNT={len(conv.reviews)}")
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
    for src, _lua_target, _stem, _text in converted:
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

    for src, lua_target, _stem, text in converted:
        os.makedirs(os.path.dirname(lua_target), exist_ok=True)
        with open(lua_target, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"WROTE={lua_target}")
        print(f"KEPT={src}")

    print("CONFIG_LANGUAGE=lua")
    print(f"CONFIG_LANGUAGE_RANGE={configlang.lang_range('lua')}")

    if conv.reviews:
        print(f"NOTE: {len(conv.reviews)} line(s) converted with a caveat. Each is marked "
              "'-- REVIEW' in the lua", file=sys.stderr)
        print("      and says what to check.", file=sys.stderr)
        for e in conv.reviews:
            print(f"REVIEW={e}")
        print(f"REVIEW_COUNT={len(conv.reviews)}")

    if conv.unmapped:
        print(f"WARNING: {len(conv.unmapped)} line(s) had no lua form this converter could "
              "write. They are in the", file=sys.stderr)
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


if __name__ == "__main__":
    sys.exit(main(sys.argv))
