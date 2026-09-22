-- ~/.config/hypr/keybinds.lua
-- Migrated from keybinds.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")

-- Launchers (SUPER-tap toggles mylauncher, a quickshell daemon)
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -p " .. home .. "/.config/quickshell/mylauncher call mylauncher toggle"), { release = true })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("rofi -show emoji -theme-str 'message { enabled: false; }'"))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("SUPER + Tab", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/lock.sh"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("wlogout -b 1 -c 20 -r 20 -L 1700 -R 1700 -T 325 -B 325"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("quickshell --path " .. home .. "/.config/quickshell/hyprquickpaper"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/notifications.sh"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("notify-send 'Test Notification' 'This is a test notification from Hyprland' -a hyprland -u normal"))

hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("kitty --class fzf -e sh -c 'file=$(fzf --preview \"head -50 {}\" --preview-window=right:60%) && [ -n \"$file\" ] && nvim \"$file\"'"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh"))

-- Toggle waybar
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))

-- Live wallpaper picker (video + gif, same feel as static picker)
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("quickshell --path " .. home .. "/.config/quickshell/hyprquickpaper-live"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true })

-- hypr-lens screenshot/OCR/search/record
hl.bind("SUPER + SHIFT + S", hl.dsp.global("quickshell:regionScreenshot"))
hl.bind("SUPER + SHIFT + A", hl.dsp.global("quickshell:regionSearch"))
hl.bind("SUPER + SHIFT + X", hl.dsp.global("quickshell:regionOcr"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + R", hl.dsp.global("quickshell:regionRecord"))
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:regionRecordWithSound"))

-- Clipboard (clipse in floating transparent terminal)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("kitty --class clipse -o window.padding.x=12 -o window.padding.y=12 -o background_opacity=0.7 -e clipse"))

-- Keyboard layout
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("hyprctl switchxkblayout current next"))

-- Cheatsheet (quickshell)
hl.bind("F1", hl.dsp.exec_cmd("quickshell -n --path " .. home .. "/.config/quickshell/hyprcheatsheet"))

-- hl.dsp.exit() is broken on Hyprland 0.55+ (and so is `hyprctl dispatch exit`
-- from the CLI) - log out via loginctl instead, same as wlogout does.
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("loginctl terminate-session $XDG_SESSION_ID"))

-- Focus (H/J/K/L = left/down/up/right, vim-style, matching your original)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Focus with arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))

-- VERIFY: move active window within layout (old `movewindow` dispatcher).
-- Confirmed pattern is hl.dsp.window.move({ workspace = N }) for sending to a
-- workspace (used below) - the direction-swap variant isn't shown in the
-- official example, so double check this fires like the old movewindow did.
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Rearrange tiles with SUPER + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

-- VERIFY: resize active window by pixel delta (old `resizeactive`, repeating
-- while held via `binde`). Param names guessed as x/y - confirm with hyprctl eval.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

-- Workspaces 1-10, and move-to-workspace with SHIFT (confirmed pattern from
-- the official example config)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse move/resize (confirmed pattern from the official example config)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys (confirmed pattern from the official example config)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("bash " .. home .. "/.config/hypr/scripts/volume.sh up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("bash " .. home .. "/.config/hypr/scripts/volume.sh down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("bash " .. home .. "/.config/hypr/scripts/volume.sh mute"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("bash " .. home .. "/.config/hypr/scripts/brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("bash " .. home .. "/.config/hypr/scripts/brightness.sh down"), { locked = true, repeating = true })
