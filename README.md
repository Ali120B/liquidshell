# LiquidShell

A full Hyprland rice with Quickshell Dynamic Island, frosted glass Waybar, wallpaper picker, region screenshot/OCR/recording, and an interactive one-shot installer.

![Hyprland](https://img.shields.io/badge/Hyperland-blue?style=flat-square&logo=hyprland)
![Quickshell](https://img.shields.io/badge/Quickshell-purple?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## What's Inside

| Component | Description |
|-----------|-------------|
| **Hyprland** | Lua config (v0.55+) — keybinds, window rules, animations, blur, opacity |
| **DynaLinux** | Quickshell Dynamic Island — volume HUD, media controls, timer, battery, weather, notifications |
| **Waybar** | Frosted glass top bar — workspaces, CPU, RAM, clock, mpris, volume, power button |
| **hyprquickpaper** | Scrollable wallpaper picker with dock-style zoom magnification |
| **hypr-lens** | Region screenshot, OCR, screen recording, reverse image search, color picker |
| **Rofi** | Themed app launcher + keybind cheatsheet viewer |
| **Wlogout** | Circular button logout screen (shutdown, reboot, logout) |
| **Clipse** | Clipboard manager with custom pink/blue theme |
| **Dunst** | Notification daemon (Tokyo Night style) |
| **Kitty** | Terminal with Material 3 theme |

---

## Screenshots

> Add your own screenshots here!

```
Put screenshots in a screenshots/ folder or link them from an external host.
Suggested: fullscreen desktop, waybar closeup, DynaLinux island expanded, rofi launcher.
```

---

## Keybinds

| Key | Action |
|-----|--------|
| `SUPER` | App Launcher (Rofi) |
| `SUPER + T` | Terminal (Kitty) |
| `SUPER + E` | File Manager (spf in Kitty) |
| `SUPER + B` | Browser (Zen) |
| `SUPER + Q` | Close Window |
| `SUPER + F` | Fullscreen |
| `SUPER + Space` | Toggle Floating |
| `SUPER + H/J/K/L` | Focus (vim-style) |
| `SUPER + SHIFT + H/J/K/L` | Move Window |
| `SUPER + CTRL + H/J/K/L` | Resize Window |
| `SUPER + 1-0` | Switch Workspace |
| `SUPER + ALT + 1-0` | Move Window to Workspace |
| `SUPER + W` | Wallpaper Picker |
| `SUPER + V` | Clipboard (Clipse) |
| `SUPER + SHIFT + S` | Region Screenshot |
| `SUPER + SHIFT + X` | OCR |
| `SUPER + R` | Screen Record |
| `SUPER + SHIFT + C` | Color Picker |
| `SUPER + N` | Notification History |
| `SUPER + SHIFT + W` | Toggle Waybar |
| `SUPER + O` | Opacity Menu |
| `SUPER + Tab` | Lock Screen |
| `SUPER + Escape` | Logout Menu |
| `SUPER + SHIFT + E` | Exit Hyprland |
| `F1` | Cheatsheet |

---

## Installation

### Prerequisites

- **Arch Linux** (or Arch-based distro — installer also supports Fedora/Debian)
- Hyprland v0.55+ (Lua config support)
- `git`

### Quick Start

```bash
git clone https://github.com/Ali120B/liquidshell.git ~/liquidshell
cd ~/liquidshell
./install.sh
```

The installer will:
1. Detect your distro
2. Let you choose which components to install
3. Install system dependencies (hyprland, waybar, kitty, etc.)
4. Download Nerd Fonts (JetBrainsMono, Iosevka, CascadiaCode)
5. Back up any existing `~/.config/` configs
6. Deploy everything to the right places
7. Replace path placeholders with your actual `$HOME`

### What Gets Installed

```
~/.config/
├── hypr/           ← hyprland.lua, keybinds.lua, rules.lua, hyprlock.conf, scripts/
├── waybar/         ← config.jsonc, style.css, scripts/
├── quickshell/     ← shell.qml, DynaLinux/, hyprquickpaper/, hypr-lens/
├── rofi/           ← config.rasi, cheatsheet.rasi, colors.rasi
├── wlogout/        ← layout, style.css, icons/
├── clipse/         ← config.json, custom_theme.json
├── dunst/          ← dunstrc
└── kitty/          ← kitty.conf, current-theme.conf
```

---

## Manual Installation

If you prefer not to use the installer:

1. Clone the repo
2. Copy each folder to `~/.config/`
3. Edit `quickshell/hyprquickpaper/config.json` and replace `__HOME__` with your actual home path
4. Edit `wlogout/style.css` and replace `__HOME__` with your actual home path
5. Make scripts executable: `chmod +x ~/.config/hypr/scripts/*.sh`

---

## Configuration

### Wallpaper Picker

Add `.jpg` / `.png` wallpapers to `~/Pictures/`, then launch:

```bash
quickshell --path ~/.config/quickshell/hyprquickpaper
```

Edit `quickshell/hyprquickpaper/config.json` to change:
- `wallpaper_path` — where your wallpapers live
- `number_of_pictures` — tiles visible at once
- `border_color` — selection highlight color

### Dynamic Island (DynaLinux)

Launches automatically with Quickshell. IPC commands:

```bash
quickshell ipc dynalinux idle
quickshell ipc dynalinux volume 50 false
quickshell ipc dynalinux brightness 75
quickshell ipc dynalinux notify "Title" "Body" "App"
quickshell ipc dynalinux demo
```

### Display Settings

Edit `hypr/hyprland.lua` to change:
- Monitor resolution/refresh rate (line ~10)
- Default terminal, browser, file manager (line ~25)
- Appearance: gaps, border, rounding, blur, opacity (lines ~80-110)

---

## Dependencies

<details>
<summary>Full package list</summary>

**Core:**
`hyprland` `hyprlock` `hyprpaper` `hyprpicker` `waybar` `wlogout` `rofi-wayland` `dunst` `kitty` `clipse` `wl-clipboard` `brightnessctl` `playerctl` `polkit-kde-agent` `qt6ct` `qt6-wayland` `kvantum` `adw-gtk3-theme` `grim` `slurp` `NetworkManager-applet` `jq` `imagemagick` `curl` `python3`

**Quickshell (install separately):**
`quickshell` `material-symbols-ttf` `noto-fonts`

**Fonts:**
`JetBrainsMono Nerd Font` `Iosevka Nerd Font` `CaskaydiaCove Nerd Font` `Noto Sans` `Material Symbols Rounded`

</details>

---

## Troubleshooting

**Hyprland won't start / crashes on login:**
- Ensure you're running Hyprland v0.55+ (Lua config support)
- Check `hyprland` is in your PATH

**Quickshell won't launch:**
- Install quickshell separately (AUR: `quickshell-bin`)
- Install required fonts

**Wallpaper picker shows "Caching":**
- First run generates thumbnails — give it a moment
- Ensure `imagemagick` (`convert`) is installed

**Waybar is transparent / invisible:**
- The bar is intentionally transparent (frosted glass effect)
- It becomes visible when apps are below it

---

## Credits

- [Hyprland](https://hyprland.org)
- [Quickshell](https://quickshell.outfoxxed.me)
- [DynaLinux](https://github.com/Ali120B/dynalinux)
- [hypr-lens](https://github.com/Xavist0/hypr-lens)
- [hyprquickpaper](https://github.com/niceDev0908/hyprquickpaper)
- [Nerd Fonts](https://www.nerdfonts.com)

---

## License

MIT
