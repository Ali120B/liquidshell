# Superlauncher

A fast, smooth app launcher for Wayland built with [Quickshell](https://quickshell.org/).

Bottom-anchored floating card that slides in from beyond the screen edge, with fuzzy search, most-used ranking, and full keyboard + mouse support.

Author: **Ali120B** — alibashmail2010@yahoo.com

## Features

- Smooth enter/exit animations (slide + scale + fade, transform-based, no anchor fights)
- IPC control: `open` / `hide` / `toggle` / `isVisible` — bind it to SUPER-tap yourself
- Keyboard nav pinned to a centered sliding pill, no wrap-around, PgUp/PgDn/Home/End
- Real mouse-motion detection — parked cursor never steals keyboard selection
- Most-used-first ordering (launch counts in Quickshell state dir, survives reboots)
- Scored search: exact → prefix → substring → genericName/comment/exec/keywords → fuzzy
- Robust icon chain: theme icons gated by `hasThemeIcon()`, file fallbacks, letter-avatar last resort
- Native `DesktopEntries` + `entry.execute()` — correct Exec codes, CWD, Terminal apps
- Click-through mask so transparent padding doesn't eat clicks

## Requirements

- Linux + Wayland (tested on Hyprland)
- `quickshell` 0.3.x
- Fonts: Iosevka, JetBrainsMono Nerd Font (or edit `Launcher.qml`)

## Install

```bash
mkdir -p ~/.config/quickshell
cp -r superlauncher ~/.config/quickshell/superlauncher
# autostart (Hyprland):
# exec-once = quickshell -p ~/.config/quickshell/superlauncher
```

## Usage

Start it once (hidden by default):

```bash
quickshell -p ~/.config/quickshell/superlauncher
```

Control it:

```bash
quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher toggle
quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher open
quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher hide
quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher isVisible
```

> Note: use `open`, not `show` — `call superlauncher show` is swallowed by the CLI's own `ipc show` listing.

Hyprland SUPER-tap example (`~/.config/hypr/keybinds.lua`):

```lua
bind("SUPER", "SUPER", "exec", "quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher toggle")
```

Keys inside: `↑↓` navigate, `Enter` launch, `Esc` close, `PgUp/PgDn/Home/End` jump.

## Layout

- `shell.qml` — PanelWindow, layer/namespace, IPC handler, open/close state
- `Launcher.qml` — UI, animations, search list, keyboard/mouse, icons
- `AppProvider.qml` — desktop-entry index, search scoring, usage history

Usage counts live in Quickshell state (`superlauncher/history.json`), not in this repo.

## License

MIT — see `LICENSE`.
