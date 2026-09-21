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
terminal   = "foot"
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
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")

    hl.exec_cmd("quickshell -n -d")
    hl.exec_cmd("quickshell -n -d -p $HOME/.config/quickshell/mylauncher")
    -- Wallpapers: skwd-walld is systemd-managed (skwd-walld.service) and
    -- restores the last wallpaper itself. Keep other wallpaper daemons
    -- (awww/mpvpaper, retired) from fighting it.
    hl.exec_cmd("systemctl --user start skwd-walld")
    hl.exec_cmd("pkill -f '[m]pvpaper'; pkill -f '[a]www-daemon'")
    hl.exec_cmd("bash $HOME/.config/hypr/scripts/wallpaper-autopause.sh")
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
        inactive_opacity = 0.75,
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

-- Old: bezier = easeOut,0.05,0.9,0.1,1.0
hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

-- Old: animation = windows,1,5,easeOut  (enabled, speed, style)
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })

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
