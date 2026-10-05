-- ~/.config/hypr/hyprland.lua
-- Migrated from hyprland.conf / keybinds.conf / rules.conf (hyprlang) to Lua (Hyprland 0.55+)
-- Docs: https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "1920x1080@60",
    position = "auto",
    scale    = 1.0,
})

---------------------
---- MY PROGRAMS ----
---------------------
-- NOTE: no "local" here on purpose - keybinds.lua and rules.lua (required below)
-- need to see these same variables. Globals are shared across require()'d files
-- in the same Lua state, same as $vars used to be shared via `source` in hyprlang.

mainMod    = "SUPER"
terminal   = "footclient" -- foot server (see autostart) keeps memory shared/low
menu       = "quickshell ipc -p $HOME/.config/quickshell/mylauncher call mylauncher toggle"
fileManager = "kitty --class spf -e spf"
browser    = "zen-browser"

-------------------
---- AUTOSTART ----
-------------------
-- Old exec-once lines. hl.exec_cmd() fires immediately (not a dispatcher),
-- so these are wrapped in the hyprland.start event, same timing as exec-once.

hl.on("hyprland.start", function()
    hl.exec_cmd("hypridle")
    hl.exec_cmd("waybar")
    hl.exec_cmd("pkill -9 mako; dunst")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("foot --server") -- shared glyph cache, low memory per window
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")

    hl.exec_cmd("quickshell -n -d")
    hl.exec_cmd("quickshell -n -d -p $HOME/.config/quickshell/mylauncher")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("bash $HOME/.config/hypr/scripts/restore-wallpaper.sh")
    hl.exec_cmd("bash $HOME/.config/hypr/scripts/live-wallpaper-autopause.sh")
    hl.exec_cmd("bash $HOME/.config/hypr/scripts/wallpaper-theme.sh --watch")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "18")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GTK_THEME", "adw-gtk3-dark")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("TERMINAL", "foot")

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 5,
        border_size = 2,
        col = {
            active_border = "rgba(ffffff30)",
            inactive_border = "rgba(ffffff10)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = true, -- darken inactive instead of transparency (cheap + visible)
        dim_strength = 0.15,
        blur = {
            enabled = false, -- off by default (perf); toggle anytime via SUPER+O > Off
            size = 8,
            passes = 2,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = false, -- off by default (perf)
            range = 12,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

-- Window animations: Dusky showcase preset (floating <-> tiling, open/close,
-- move, layers, workspaces). Vendored from dusklinux/dusky into
-- hypr/animations/. Switch by changing the require below, e.g.
-- require("animations.minimal"), require("animations.fast"),
-- require("animations.disable").
require("animations.dusky")

-- Liquidshell deltas vs upstream preset (later declarations win, so the
-- vendored files stay verbatim and these rules survive preset swaps):
-- Quickshell layer anims: minimal short fades like before Dusky (launcher,
-- picker, OSD, cheatsheet are layer-shell windows). No popin/slide.
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "default", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "default", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "default", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "default" })
-- Snappier windows: same curves/styles, shorter durations
--    (higher speed value = slower in Hyprland).
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "snap", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "fluid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "overshot", style = "slidevert" })

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

------------------------
---- SPLIT-OUT FILES ----
------------------------
-- These live as plain .lua files right next to this one:
--   ~/.config/hypr/keybinds.lua
--   ~/.config/hypr/rules.lua

require("keybinds")
require("rules")
