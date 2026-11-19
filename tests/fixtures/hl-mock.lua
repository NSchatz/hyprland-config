-- A stand-in for Hyprland's `hl` global, for tests/test_lua_migrate_api.sh and
-- tests/test_lua_emit.sh. It lets a generated config be EXECUTED on a machine with no
-- Hyprland, the way `Hyprland --verify-config` executes it: top to bottom, top-level code
-- included.
--
-- It defines only the names the lua API has (Hyprland 0.57, /usr/share/hypr/stubs/hl.meta.lua).
-- A config that calls anything else dies here exactly as it does in the compositor:
-- "attempt to call a nil value (field 'killactive')".
--
-- Usage: lua hl-mock.lua <config-dir> [<main-file>]
-- Prints KEY=value lines; ERROR=<message> and exit 1 when the config does not run.

local dir = arg[1]
local main = arg[2] or "hyprland.lua"
if not dir then
    io.stderr:write("usage: lua hl-mock.lua <config-dir> [<main-file>]\n")
    os.exit(2)
end

local count = { bind = 0, submap_bind = 0, exec = 0, window_rule = 0, layer_rule = 0,
                workspace_rule = 0, env = 0, env_dbus = 0, curve = 0, animation = 0,
                monitor = 0, gesture = 0, config = 0 }
local handlers = {}
local in_submap = 0

local function dispatcher(name)
    return function(...)
        return { __dispatcher = name, args = { ... } }
    end
end

local function namespace(prefix, names)
    local t = {}
    for name in names:gmatch("%S+") do
        t[name] = dispatcher(prefix .. name)
    end
    return t
end

local dsp = namespace("", [[dpms event exec_cmd exec_raw exit focus force_idle
    force_renderer_reload global layout no_op pass release_input_capture reload_config
    send_key_state send_shortcut submap]])
dsp.cursor = namespace("cursor.", "move move_to_corner")
dsp.group = namespace("group.", "active lock lock_active move_window next prev toggle")
dsp.window = namespace("window.", [[alter_zorder bring_to_top center clear_tags close cycle_next
    deny_from_group drag float fullscreen fullscreen_state kill move pin pseudo resize set_prop
    signal swap tag toggle_swallow]])
dsp.workspace = namespace("workspace.", "change_id move rename swap_monitors toggle_special")

local function counter(name)
    return function(spec)
        if type(spec) ~= "table" then
            error("hl." .. name .. ": argument must be a table", 2)
        end
        count[name] = count[name] + 1
    end
end

hl = {
    dsp = dsp,
    config = counter("config"),
    monitor = counter("monitor"),
    gesture = counter("gesture"),
    animation = counter("animation"),
    window_rule = counter("window_rule"),
    layer_rule = counter("layer_rule"),
    workspace_rule = counter("workspace_rule"),
    device = function() end,
    permission = function() end,
    unbind = function() end,
    version = function() return "mock" end,
    get_config = function() return nil end,
    plugin = {},
}

function hl.bind(keys, action)
    if type(keys) ~= "string" or keys == "" then
        error("hl.bind: failed to parse key string", 2)
    end
    -- Hyprland joins every modifier and the key with " + ": "SUPER SHIFT + Q" is
    -- "Unknown key: SUPER SHIFT".
    for token in (keys .. " + "):gmatch("(.-) %+ ") do
        if token == "" or token:find("%s") then
            error("hl.bind: failed to create bind: Unknown key: " .. token, 2)
        end
    end
    local kind = type(action)
    if kind ~= "function" and not (kind == "table" and action.__dispatcher) then
        error("hl.bind: expected a dispatcher (e.g. hl.dsp.window.close()) or a lua function", 2)
    end
    count.bind = count.bind + 1
    if in_submap > 0 then
        count.submap_bind = count.submap_bind + 1
    end
end

function hl.define_submap(name, reset_or_fn, fn)
    fn = fn or reset_or_fn
    if type(name) ~= "string" or type(fn) ~= "function" then
        error("hl.define_submap: expected a name and a function", 2)
    end
    in_submap = in_submap + 1
    fn()
    in_submap = in_submap - 1
end

function hl.env(name, value, dbus)
    if type(name) ~= "string" or type(value) ~= "string" then
        error("hl.env: name and value must be strings", 2)
    end
    count.env = count.env + 1
    if dbus == true then
        count.env_dbus = count.env_dbus + 1
    end
end

function hl.curve(name, spec)
    if type(name) ~= "string" or type(spec) ~= "table" then
        error("hl.curve: expected a name and a table", 2)
    end
    count.curve = count.curve + 1
end

function hl.exec_cmd(cmd)
    if type(cmd) ~= "string" then
        error("hl.exec_cmd: bad argument 1", 2)
    end
    count.exec = count.exec + 1
end

function hl.on(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then
        error("hl.on: expected an event name and a function", 2)
    end
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
end

package.path = dir .. "/?.lua;" .. package.path

local ok, err = pcall(dofile, dir .. "/" .. main)
if not ok then
    print("ERROR=" .. tostring(err))
    os.exit(1)
end

-- What ran just by EVALUATING the config, which is all `--verify-config` does.
print("EXEC_AT_LOAD=" .. count.exec)

local function fire(event)
    local before = count.exec
    for _, fn in ipairs(handlers[event] or {}) do
        fn()
    end
    return count.exec - before
end

print("EXEC_ON_START=" .. fire("hyprland.start"))
print("EXEC_ON_SHUTDOWN=" .. fire("hyprland.shutdown"))
print("BINDS=" .. count.bind)
print("SUBMAP_BINDS=" .. count.submap_bind)
print("WINDOW_RULES=" .. count.window_rule)
print("LAYER_RULES=" .. count.layer_rule)
print("WORKSPACE_RULES=" .. count.workspace_rule)
print("ENV=" .. count.env)
print("ENV_DBUS=" .. count.env_dbus)
print("CURVES=" .. count.curve)
print("ANIMATIONS=" .. count.animation)
print("MONITORS=" .. count.monitor)
print("GESTURES=" .. count.gesture)
print("LOAD=ok")
