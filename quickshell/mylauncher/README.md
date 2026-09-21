# mylauncher

A minimal, wofi/rofi-style app launcher for [Quickshell](https://quickshell.org/) on Hyprland.
No animations, no clutter — tap SUPER, type, launch.

## Features

- Centered floating window with transparent dark glass look
- Fuzzy app search with most-used-first ranking (usage history persisted)
- App icons with graceful fallback
- Keyboard: `↑↓` navigate, `Enter` launch, `Esc` close
- Mouse: hover highlights, click launches (hover never steals keyboard selection)
- Click-outside to dismiss, `SUPER`-tap toggle via IPC daemon
- Lean: no animations, pooled list delegates, icons decoded at display size

## Requirements

- Hyprland
- Quickshell 0.3.x

## Autostart (Hyprland)

```lua
hl.exec_cmd("quickshell -n -d -p $HOME/.config/quickshell/mylauncher")
```

```lua
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -p $HOME/.config/quickshell/mylauncher call mylauncher toggle"), { release = true })
```

```lua
hl.layer_rule({
    match = { namespace = "quickshell:mylauncher" },
    blur = true,
    ignore_alpha = 0.15,
})
```

## IPC

```bash
quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher toggle
quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher open
quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher hide
quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher isVisible
```
