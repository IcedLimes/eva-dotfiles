-- EVA rice for Hyprland 0.56 (Lua config)
-- Floating windows like Plasma, hyprbars title bars, a floating glass bar that
-- slides up on hover (Quickshell), and three switchable palettes (SUPER+SHIFT+T).
-- Look follows a macOS / Liquid Glass-style system: continuous corners, soft
-- large shadows, real glass blur on navigation surfaces, emphasized motion.

local HOME = os.getenv("HOME")
local EVA  = HOME .. "/.config/eva"


---------------
---- THEME ----
---------------

-- Written by ~/.config/eva/bin/eva-theme; falls back to crimson.
local ok, c = pcall(dofile, EVA .. "/current/colors.lua")
if not ok or type(c) ~= "table" then
    c = {
        bg = "121010", surface = "1c1616", surface2 = "2a1313", line = "4b1616",
        primary = "b5393a", border = "9c4a47", active = "e04a42", glow = "f4d58d",
        warn = "e0913a", crit = "ff4d3d", text = "e8ddd0", dim = "7d6b68",
    }
end

local function rgb(hex) return "rgb(" .. hex .. ")" end
local function rgba(hex, alpha) return "rgba(" .. hex .. alpha .. ")" end

-- Battery mode survives config reloads and theme switches.
local BATTERY_FLAG = EVA .. "/current/battery-mode"
local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end
local batteryMode = exists(BATTERY_FLAG)


------------------
---- MONITORS ----
------------------

-- Layout saved from "Display settings" (wdisplays + eva-display-save).
local okMon, savedMonitors = pcall(dofile, EVA .. "/monitors.lua")
if not okMon or type(savedMonitors) ~= "table" then savedMonitors = {} end

-- The laptop panel: its saved mode, or the native 2560x1600 @ 240 Hz.
local panel = { mode = "2560x1600@240", position = "0x0", scale = 1 }
for _, m in ipairs(savedMonitors) do
    if m.output == "eDP-1" and m.mode then panel = m end
end

-- Low-power mode keeps the panel's resolution but drops it to 60 Hz.
local function panelRule(battery)
    return {
        output    = "eDP-1",
        mode      = battery and (panel.mode:gsub("@[%d%.]+$", "@60")) or panel.mode,
        position  = panel.position or "0x0",
        scale     = panel.scale or 1,
        transform = panel.transform,
    }
end

hl.monitor(panelRule(batteryMode))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
for _, m in ipairs(savedMonitors) do
    if m.output ~= "eDP-1" then hl.monitor(m) end
end


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"   -- EVA colors and the cursor trail: ~/.config/kitty/kitty.conf
local fileManager = "dolphin"
local menu        = "quickshell -c eva ipc call eva menu" -- start menu; same key closes it
local powerMenu   = "~/.config/hypr/scripts/power-menu.sh"
-- The wallpaper is drawn by the bar (quickshell/eva/Wallpaper.qml, with
-- parallax); the lock screen has its own in hyprlock.conf.


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Render only on the Radeon so the RTX can stay powered off.
-- /dev/dri/amd-igpu comes from /etc/udev/rules.d/61-amd-igpu-card.rules.
-- (Only on machines that have it; elsewhere Hyprland picks the GPU itself.)
if exists("/dev/dri/amd-igpu") then hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu") end

hl.env("PATH", EVA .. "/bin:" .. os.getenv("PATH"))
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice") -- ~/.local/share/icons; Plasma keeps Breeze
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "kde") -- KDE apps follow kdeglobals (EVA colors via eva-session)
-- KDE apps find installed applications (default apps, "Open with") through
-- Plasma's menu file; Plasma sets this prefix, Hyprland doesn't by default.
hl.env("XDG_MENU_PREFIX", "plasma-")


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_MENU_PREFIX")
    hl.exec_cmd("kbuildsycoca6")                    -- refresh KDE's app database (default apps, Open with)
    hl.exec_cmd(EVA .. "/bin/eva-session hyprland") -- EVA colors for KDE/GTK apps too
    hl.exec_cmd("/usr/lib/pam_kwallet_init")        -- unlock KDE Wallet with the login password, like Plasma
    hl.exec_cmd("quickshell -c magi") -- MAGI vote animation, exits by itself
    -- Bottom bar and wallpaper. The wallpaper asks Hyprland's socket for the
    -- cursor and Hyprland closes it after each reply, which Quickshell would
    -- otherwise log as a warning every time.
    hl.exec_cmd("quickshell -c eva --log-rules 'quickshell.io.socket.warning=false'")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("vinyl-visualizer --with-spotify") -- vinyl overlay: opens and closes with Spotify
    hl.exec_cmd("sleep 4; notify-send -a eva -t 8000 'Welcome back' "
        .. "'Tap Super for apps · Super + / for shortcuts'")
end)


---------------------------
---- TITLE BARS PLUGIN ----
---------------------------

-- Built from hyprland-plugins for exactly this Hyprland version. After a
-- Hyprland update it must be rebuilt; until then windows simply have no bars.
local barsLoaded = pcall(hl.plugin.load, HOME .. "/.local/share/hyprland/plugins/hyprbars.so")
local BAR_H      = 34

-- Lets Rei, the moon and the vinyl record animate without invalidating the
-- cached wallpaper blur (otherwise every frame of theirs re-blurred and, with a
-- terminal open, redrew the whole screen: ~65% of the iGPU vs ~6%). Source and
-- notes: ~/.config/eva/plugins/eva-blurcache. Same rebuild rule as above.
pcall(hl.plugin.load, HOME .. "/.local/share/hyprland/plugins/eva-blurcache.so")

-- Firefox and Chromium-based browsers draw their own minimize / maximize /
-- close buttons in the tab bar, so they don't get a second title bar.
local OWN_TITLEBAR = { "firefox", "zen", "chromium", "google-chrome", "brave-browser" }

if barsLoaded and hl.plugin.hyprbars then
    hl.config({
        plugin = {
            hyprbars = {
                bar_height                 = BAR_H,
                bar_color                  = rgba(c.surface, "ff"),   -- solid; see no-window-blur
                col                        = { text = rgba(c.text, "d0") },
                inactive_button_color      = rgba("ffffff", "26"),
                bar_text_font              = "Inter",
                bar_text_weight            = "medium",
                bar_text_size              = 11,
                bar_text_align             = "center",
                bar_buttons_alignment      = "right",
                bar_padding                = 14,
                bar_button_padding         = 9,
                -- Off: at 95% opacity the blur barely shows, and it fills a
                -- square box that pokes out past the rounded corners when
                -- the window glows.
                bar_blur                   = false,
                bar_precedence_over_border = true,
                icon_on_hover              = false,
                on_double_click            = "hyprctl eval 'eva.bar_button(\"maximize\")'",
            },
        },
    })

    -- Plain minimize / maximize / close glyphs (Breeze / Firefox style), added
    -- right to left. Transparent backgrounds: no colored circles.
    local glyph = function(cp) return utf8.char(cp) end
    hl.plugin.hyprbars.add_button({
        bg_color = rgba("000000", "00"), fg_color = rgba(c.text, "e6"), size = 22, icon = glyph(0xF05AD),
        action = "hyprctl eval 'eva.bar_button(\"close\")'",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = rgba("000000", "00"), fg_color = rgba(c.text, "e6"), size = 22, icon = glyph(0xF05AF),
        action = "hyprctl eval 'eva.bar_button(\"maximize\")'",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = rgba("000000", "00"), fg_color = rgba(c.text, "e6"), size = 22, icon = glyph(0xF05B0),
        action = "hyprctl eval 'eva.bar_button(\"minimize\")'",
    })
end


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 1,

        -- Hairline edge, like macOS windows: faint accent when focused,
        -- barely-there white otherwise. Depth comes from the shadow.
        col = {
            active_border   = rgba(c.border or c.primary, "88"),
            inactive_border = rgba("ffffff", "14"),
        },

        resize_on_border        = true,
        extend_border_grab_area = 4, -- small, so clicks near a window edge still focus the window behind
        allow_tearing           = false,
        layout                  = "dwindle",

        -- Windows snap to screen edges and each other while dragging.
        snap = { enabled = true, window_gap = 12, monitor_gap = 12 },
    },

    decoration = {
        -- Continuous ("squircle") corners: power > 2 flattens the curve the
        -- way Apple's corners do.
        rounding       = 14,
        rounding_power = 3,

        -- App content stays solid; glass is for the bar, menus and popups.
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Soft, large, offset shadow; lighter on unfocused windows. Themes with
        -- a windowGlow color (MONO) give the focused window a soft bloom
        -- instead: on their black wallpaper a dark shadow doesn't show.
        shadow = {
            enabled        = not batteryMode,
            range          = c.windowGlow and 22 or 30,
            render_power   = 3,
            offset         = c.windowGlow and "0 0" or "0 8",
            color          = c.windowGlow and rgba(c.windowGlow, "12") or rgba("000000", "73"),
            color_inactive = rgba("000000", "40"),
        },

        -- Glass with a little grain and vibrancy, like macOS materials.
        -- xray: glass shows the blurred wallpaper, which is computed once and
        -- cached. Blurring the live windows behind instead cost 75-100% of the
        -- Radeon 610M whenever a translucent window repainted (cursor stutter).
        blur = {
            enabled           = not batteryMode,
            size              = 7,
            passes            = 2,
            new_optimizations = true,
            xray              = true,
            noise             = 0.03,
            contrast          = 0.9,
            brightness        = 0.85,
            vibrancy          = 0.25,
            vibrancy_darkness = 0.2,
            popups            = false,
        },
    },

    animations = {
        enabled = not batteryMode,
    },
})

-- Material 3 "emphasized" curves (also used by end-4 and Caelestia):
-- quick start, long gentle settle. Nothing loops or flashes.
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("standard",        { type = "bezier", points = { {0.2, 0}, {0, 1} } })

hl.animation({ leaf = "global",      enabled = true, speed = 4,   bezier = "standard" })
hl.animation({ leaf = "border",      enabled = true, speed = 4,   bezier = "standard" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4,   bezier = "emphasizedDecel", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.5, bezier = "emphasizedAccel", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,   bezier = "emphasizedDecel" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3,   bezier = "standard" })
hl.animation({ leaf = "layers",      enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,   bezier = "emphasizedDecel", style = "slidefade 12%" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = rgb(c.bg),
        focus_on_activate        = true, -- taskbar clicks and app activation raise windows

        -- hyprland-guiutils can't start until the system is fully updated
        -- (abseil version mismatch), so keep its dialogs from being launched.
        enable_anr_dialog = false,

        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})


---------------
---- INPUT ----
---------------

-- Don't move the cursor when a window is focused from the keyboard, the
-- taskbar or Alt+Tab (Hyprland centers it on the window by default).
hl.config({
    cursor = {
        no_warps = true,
    },
})

hl.config({
    input = {
        kb_layout    = "us",
        -- Click to focus, like Plasma. Hover only moves the pointer focus
        -- (scrolling goes to the window under the cursor).
        follow_mouse = 2,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = false,
            tap_to_click         = true,
            disable_while_typing = false, -- matches your Plasma setting
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


----------------------
---- BATTERY MODE ----
----------------------

-- SUPER+B or clicking SYNC in the bar: 60 Hz, no blur, no shadows, no
-- animations. Global so `hyprctl eval 'eva.toggle_battery_mode()'` reaches it.
eva = {}

function eva.toggle_battery_mode()
    local on = not batteryMode

    if on then
        local f = io.open(BATTERY_FLAG, "w")
        if f then f:write("1\n") f:close() end
    else
        os.remove(BATTERY_FLAG)
    end

    -- Reload the whole config, which reads the flag: the panel's refresh rate,
    -- blur, shadows and animations all follow it there. (Changing the monitor
    -- rule from here worked one way only after login: going back to 240 Hz
    -- was silently ignored.)
    hl.exec_cmd("hyprctl reload; notify-send -a eva -t 2500 '" .. (on and "INTERNAL POWER MODE" or "FULL SYNC")
        .. "' '" .. (on and "60 Hz · blur, shadows, animations off" or "240 Hz · effects on")
        .. "'; sleep 0.6; quickshell -c eva ipc call eva sync")
end


------------------
---- MAXIMIZE ----
------------------

-- Plasma-style maximize: the window stays an ordinary floating window,
-- resized to fill the screen, and gets its old size back on restore.
-- (Hyprland's own "maximized" state moves a window into a fullscreen layer,
-- which breaks clicking between it and the other floating windows.)
-- stable_id -> geometry before maximizing. Kept in this Hyprland session's
-- runtime folder, because every config reload starts a fresh Lua state.
local MAXED_FILE = (function()
    local rt, sig = os.getenv("XDG_RUNTIME_DIR"), os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if rt and sig then return rt .. "/hypr/" .. sig .. "/eva-maxed.lua" end
end)()

local function loadMaxed()
    if not MAXED_FILE then return {} end
    local ok, t = pcall(dofile, MAXED_FILE)
    return (ok and type(t) == "table") and t or {}
end

local function saveMaxed()
    local f = MAXED_FILE and io.open(MAXED_FILE, "w")
    if not f then return end
    f:write("return {\n")
    for k, g in pairs(eva.maxed) do
        f:write(string.format("  [%d] = { x = %d, y = %d, w = %d, h = %d },\n",
            k, math.floor(g.x), math.floor(g.y), math.floor(g.w), math.floor(g.h)))
    end
    f:write("}\n")
    f:close()
end

eva.maxed = loadMaxed()

local GAP     = 12                        -- gaps_out
-- Our title bar sits above the window, so leave room for it when maximizing.
local ownTitlebar = {}
for _, class in ipairs(OWN_TITLEBAR) do ownTitlebar[class] = true end
local function titleH(win)
    return (barsLoaded and not ownTitlebar[win.class]) and BAR_H or 0
end

local function sel(win) return "address:" .. win.address end

-- Keyed by stable_id: addresses get reused by new windows, which would
-- otherwise inherit a closed window's restore size.
local function key(win) return win.stable_id end

local function workArea(win)
    local m = win.monitor or hl.get_active_monitor()
    if not m then return nil end
    local t = titleH(win)
    return { x = m.x + GAP, y = m.y + GAP + t,
             w = m.width - 2 * GAP, h = m.height - 2 * GAP - t }
end

local function place(win, g)
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(g.w), y = math.floor(g.h), window = sel(win) }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(g.x), y = math.floor(g.y), window = sel(win) }))
end

local function fills(win, a)
    return math.abs(win.at.x - a.x) < 24 and math.abs(win.at.y - a.y) < 24
       and math.abs(win.size.x - a.w) < 48 and math.abs(win.size.y - a.h) < 48
end

local function centered(a, f)
    local w, h = a.w * f, a.h * f
    return { x = a.x + (a.w - w) / 2, y = a.y + (a.h - h) / 2, w = w, h = h }
end

function eva.maximize(win)
    local a = workArea(win)
    if not a then return end
    -- Already about screen-sized (it opened that way): restoring to that size
    -- would look like nothing happened, so restore to a centered 70% instead.
    local big = win.size.x > a.w * 0.9 and win.size.y > a.h * 0.9
    eva.maxed[key(win)] = big and centered(a, 0.7)
        or { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }
    saveMaxed()
    place(win, a)
end

local function restore(win, g)
    eva.maxed[key(win)] = nil
    saveMaxed()
    place(win, g)
end

-- SUPER+Up, the title bar's maximize button, double-clicking the title bar.
function eva.toggle_maximize(win)
    win = win or hl.get_active_window()
    if not win then return end
    if not win.floating then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", window = sel(win) }))   -- tiled: Hyprland's own
        return
    end
    local a = workArea(win)
    if not a then return end
    -- Decide by the window's actual size: if it fills the screen, restore it
    -- (to its saved size, or a centered 70% if it opened that big).
    if fills(win, a) then
        restore(win, eva.maxed[key(win)] or centered(a, 0.7))
    else
        eva.maximize(win)
    end
end

-- Called by the title-bar plugin when you start dragging a window, by our bar
-- or by the app's own (Firefox's tab strip): if it is maximized, restore it
-- under the cursor, keeping the grabbed spot (fracX of the width, offY pixels
-- below the window's top; negative in our title bar) under the pointer.
function eva.restore_for_move(addr, mx, my, fracX, offY)
    local win = hl.get_window("address:" .. addr)
    if not win then return end
    local saved, a = eva.maxed[key(win)], workArea(win)
    -- Only if it is still maximized (not moved or resized by hand since).
    if not saved or not a or not fills(win, a) then return end
    restore(win, { x = mx - fracX * saved.w, y = my - offY, w = saved.w, h = saved.h })
end

-- Same, from our title bar: grabY pixels into the bar above the window.
function eva.restore_for_drag(addr, mx, my, fracX, grabY)
    eva.restore_for_move(addr, mx, my, fracX, grabY - BAR_H)
end

-- An app asked to maximize: Firefox's own maximize button, or an app reopening
-- maximized. Keep Hyprland's state normal and toggle the Plasma-style
-- maximize by the window's actual size. (Real fullscreen -- F11, videos --
-- is mode 2 and passes through untouched.)
local function convertMaximized(win)
    if not win or not win.floating or win.fullscreen ~= 1 then return end
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = sel(win) }))
    local fresh = hl.get_window(sel(win))
    if not fresh then return end
    local a = workArea(fresh)
    if not a then return end
    if fills(fresh, a) then
        restore(fresh, eva.maxed[key(fresh)] or centered(a, 0.7))
    else
        eva.maximize(fresh)
    end
end

hl.on("window.fullscreen", convertMaximized)
hl.on("window.open", convertMaximized)
-- Forget a window's restore size when it closes. (On "window.destroy" the
-- window is already gone and its fields are nil.)
hl.on("window.close", function(win)
    local ok, k = pcall(key, win)
    if ok and k and eva.maxed[k] then eva.maxed[k] = nil; saveMaxed() end
end)


-- Taskbar / Alt+Tab: restore if minimized, focus, raise -- in that order,
-- in one call. (Sent as separate requests they can arrive out of order, and
-- "raise" would hit the previously focused window.)
function eva.activate(addr)
    local s = "address:" .. addr
    local win = hl.get_window(s)
    if not win then return end
    if win.workspace and win.workspace.name == "special:minimized" then
        hl.dispatch(hl.dsp.window.move({ workspace = "e+0", window = s, follow = false }))
    end
    hl.dispatch(hl.dsp.focus({ window = s }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = s }))
end

function eva.minimize(addr)
    hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:" .. addr, follow = false }))
end

-- An app asking to be focused while minimized (Firefox when another app opens
-- a link, say) made Hyprland open the whole minimized workspace on top: every
-- minimized window at once, and minimizing then seemed to do nothing until
-- Alt+Tab closed it. Bring back just that window, onto the current workspace.
-- Hyprland reports the request (window.urgent) just before it focuses.
-- Spotify raises itself whenever it's told to play something, which is how
-- the vinyl record starts a song, so it never takes focus on its own and
-- stays minimized.
local NO_SELF_FOCUS = { Spotify = true }
hl.window_rule({
    name              = "no-self-focus",
    match             = { class = "^(Spotify)$" },
    focus_on_activate = false,
})
hl.on("window.urgent", function(win)
    if win and not NO_SELF_FOCUS[win.class] and win.workspace and win.workspace.name == "special:minimized" then
        hl.dispatch(hl.dsp.window.move({ workspace = "e+0", window = "address:" .. win.address, follow = false }))
    end
end)

-- Minimized windows can't take focus. Clicking a layer surface (the vinyl
-- record, a bar) makes Hyprland give focus back to the last window you used,
-- even a minimized one, and that opened the whole minimized workspace for a
-- frame. Restoring always moves a window out first (eva.activate, the urgent
-- hook above), so this never gets in the way of bringing one back.
hl.window_rule({
    name     = "minimized-no-focus",
    match    = { workspace = "special:minimized" },
    no_focus = true,
})

-- And nothing else gets to show them all either. Focus can still land on a
-- minimized window by other routes -- when a popup menu closes (the vinyl
-- record's right-click menu), Hyprland hands focus back to the last window you
-- used, even if it's minimized -- and that opens the workspace. Close it again
-- right after (once Hyprland has finished what it was doing), leaving them
-- minimized. Restoring one always moves it out first (eva.activate), so this
-- never fights the taskbar or Alt+Tab.
hl.on("workspace.special_active", function(ws)
    if not (ws and ws.name == "special:minimized") then return end
    hl.timer(function()
        for _, mon in ipairs(hl.get_monitors()) do
            local sp = mon.active_special_workspace
            if sp and sp.name == "special:minimized" then
                mon:set_special_workspace({})
            end
        end
    end, { timeout = 1, type = "oneshot" })
end)

-- Title-bar buttons (and double-click) act on the window whose bar is under
-- the cursor: the topmost one there. Going by the focused window failed when
-- focus didn't follow the click (a menu still holding the input, say):
-- minimize then did nothing, and close could hit another window.
local function windowUnderBar()
    local c, ws = hl.get_cursor_pos(), hl.get_active_workspace()
    local best
    if c and ws then
        for _, w in ipairs(hl.get_windows()) do
            if w.mapped and not w.hidden and w.workspace and w.workspace.id == ws.id
               and c.x >= w.at.x and c.x <= w.at.x + w.size.x
               and c.y >= w.at.y - titleH(w) and c.y <= w.at.y
               and (not best or w.focus_history_id < best.focus_history_id) then
                best = w
            end
        end
    end
    return best or hl.get_active_window()
end

function eva.bar_button(action)
    local win = windowUnderBar()
    if not win then return end
    if action == "close" then
        hl.dispatch(hl.dsp.window.close({ window = sel(win) }))
    elseif action == "minimize" then
        eva.minimize(win.address)
    elseif action == "maximize" then
        eva.toggle_maximize(win)
    end
end


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Tapping SUPER on its own opens the launcher, like Plasma. Release binds
-- don't fire if another key was pressed while SUPER was held.
hl.bind(mainMod .. " + SUPER_L",   hl.dsp.exec_cmd(menu),        { release = true, desc = "app launcher" })
hl.bind(mainMod .. " + Space",     hl.dsp.exec_cmd(menu),        { desc = "app launcher" })
hl.bind("CTRL + ALT + Delete",     hl.dsp.exec_cmd(powerMenu),   { desc = "power menu" })
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(powerMenu),   { desc = "power menu" })
hl.bind(mainMod .. " + Return",    hl.dsp.exec_cmd(terminal),    { desc = "terminal" })
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager), { desc = "file manager" })
hl.bind(mainMod .. " + Q",         hl.dsp.window.close(),        { desc = "close window" })
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen(),   { desc = "fullscreen" })
hl.bind(mainMod .. " + Up",        function() eva.toggle_maximize() end, { desc = "maximize" })
hl.bind(mainMod .. " + Down",      hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { desc = "minimize" })
hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }), { desc = "tile / float window" })
hl.bind(mainMod .. " + B",         eva.toggle_battery_mode,      { desc = "toggle battery mode" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(EVA .. "/bin/eva-theme next"), { desc = "next theme" })
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"), { desc = "lock" })
hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("loginctl lock-session"), { desc = "lock" })
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd("fuzzel --dmenu --anchor center --prompt 'Shortcuts  ' --font 'JetBrains Mono:size=10' --width 60 --lines 26 < ~/.config/hypr/keys.txt"), { desc = "keybind cheatsheet" })
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("makoctl dismiss --all"), { desc = "dismiss notifications" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu --prompt 'CLIP ▸ ' | cliphist decode | wl-copy"), { desc = "clipboard history" })

-- Alt+Tab: the bar's window switcher (thumbnails, like Plasma). Tab moves the
-- selection; releasing Alt switches.
local function shell(fn) hl.exec_cmd("quickshell -c eva ipc call eva " .. fn) end
eva.switching = false

hl.bind("ALT + Tab",         function() eva.switching = true shell("switchNext") end, { desc = "window switcher" })
hl.bind("ALT + SHIFT + Tab", function() eva.switching = true shell("switchPrev") end, { desc = "window switcher (back)" })
for _, keys in ipairs({ "ALT + Alt_L", "ALT + SHIFT + Alt_L" }) do
    hl.bind(keys, function()
        if eva.switching then
            eva.switching = false
            shell("switchCommit")
        end
    end, { release = true, non_consuming = true })
end

-- Screenshots: region / whole screen -> straight onto the clipboard, then
-- the editor opens on it (satty: draw, arrows, text, blur, crop; Enter copies
-- the edited shot, Ctrl+S saves it to ~/Pictures/Screenshots; settings in
-- ~/.config/satty/config.toml). Nothing is saved unless you save it: the
-- shot itself lives in a temporary file, gone when the editor closes.
-- SUPER+SHIFT+S like Plasma.
local shot   = "f=$XDG_RUNTIME_DIR/eva-shot-$(date +%s%N).png && "
local edit   = " && wl-copy --type image/png < \"$f\" && satty --filename \"$f\"; rm -f \"$f\""
local region = shot .. "grim -g \"$(slurp -b 00000080 -c ffffffcc -s ffffff14 -w 1)\" \"$f\"" .. edit
hl.bind("Print",                    hl.dsp.exec_cmd(region),                           { desc = "screenshot region" })
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.exec_cmd(region),                           { desc = "screenshot region" })
hl.bind("SHIFT + Print",            hl.dsp.exec_cmd(shot .. "grim \"$f\"" .. edit),  { desc = "screenshot screen" })

-- Focus between windows
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media / brightness keys, each followed by the bar's volume/brightness pop-up
local osd = "quickshell -c eva ipc call eva osd "
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && " .. osd .. "volume"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && " .. osd .. "volume"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && " .. osd .. "volume"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && " .. osd .. "mic"),   { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && " .. osd .. "brightness"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && " .. osd .. "brightness"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Every window floats, like Plasma. SUPER+T tiles the focused one.
hl.window_rule({
    name  = "float-everything",
    match = { class = ".*" },
    float = true,
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Glass (blur) is for the bar, menus and popups only; see-through apps show
-- what is really behind them. With blur's xray mode (needed for speed on this
-- iGPU), a blurred window keeps title bars above it from drawing, so the
-- window behind showed through them, brightened by the focus glow.
hl.window_rule({
    name    = "no-window-blur",
    match   = { class = ".*" },
    no_blur = true,
})

-- Terminals keep frosted glass, using the cached (xray) blur of the
-- wallpaper. Real blur of what's behind them re-blurs on every redraw: a
-- busy terminal (e.g. a running spinner) cost 20% of this iGPU at 240 Hz vs
-- 9% cached, enough to make the cursor stutter. Trade-off: another window's
-- title bar passing over a terminal may not draw there.
hl.window_rule({
    name    = "terminal-glass",
    match   = { class = "^(org.kde.konsole|Alacritty|kitty)$" },
    no_blur = false,
    xray    = true,
})

-- See-through Dolphin and settings apps (active, inactive). The terminals
-- (kitty, Konsole, Alacritty) do their own background-only transparency,
-- which keeps text crisp.
hl.window_rule({
    name    = "glass-windows",
    match   = { class = "^(org.kde.dolphin|systemsettings|kdesystemsettings|org.kde.systemsettings|org.kde.kinfocenter|org.pulseaudio.pavucontrol|nm-connection-editor|wdisplays)$" },
    opacity = "0.86 0.78",
})

-- Apps with their own title bar (OWN_TITLEBAR, above) don't get ours.
if barsLoaded and hl.plugin.hyprbars then   -- the rule exists only while the plugin is loaded
    hl.window_rule({
        name  = "browser-own-titlebar",
        match = { class = "^(" .. table.concat(OWN_TITLEBAR, "|") .. ")$" },
        ["hyprbars:no_bar"] = true,
    })
end

-- The screenshot editor: centered, never bigger than the screen.
hl.window_rule({
    name     = "screenshot-editor",
    match    = { class = "^(com.gabm.satty)$" },
    center   = true,
    max_size = "monitor_w*0.9 monitor_h*0.9",
})

-- Browsers, video and games stay fully opaque.
hl.window_rule({
    name    = "keep-opaque",
    match   = { class = "^(firefox|zen|chromium|google-chrome|brave-browser|mpv|vlc|steam|steam_app_.*|gamescope)$" },
    opacity = "1.0 override 1.0 override",
})

-- Blur behind the bar, launcher, notifications and boot animation.
-- Glass behind the bar, menus and popups. ignore_alpha keeps the blur inside
-- the panels and off their soft shadows.
for _, ns in ipairs({ "eva-bar", "eva-frame", "eva-menu", "eva-control", "eva-switcher", "eva-osd", "launcher", "notifications", "eva-magi" }) do
    hl.layer_rule({
        name         = "blur-" .. ns,
        match        = { namespace = "^" .. ns .. "$" },
        blur         = true,
        ignore_alpha = 0.5,
    })
end

-- The night sky (Quickshell Stars.qml) fades itself.
hl.layer_rule({
    name    = "eva-sky-no-anim",
    match   = { namespace = "^eva-stars$" },
    no_anim = true,
})
