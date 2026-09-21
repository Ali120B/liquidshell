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
| **skwd-wall** | Wallpaper manager — picker + mixer, images / video / Wallpaper Engine scenes |
| **Sung** | Native Material 3 music player (auto-installed by `install.sh`) |
| **CypherGate** | VPNGate client — `SUPER+SHIFT+V`, waybar pill, auto-restart guard |
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
| `SUPER` | App Launcher (mylauncher) |
| `SUPER + T` | Terminal (Foot) |
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
| `SUPER + W` | Wallpaper picker (skwd-wall) |
| `SUPER + SHIFT + W` | Wallpaper mixer (skwd-wall) |
| `SUPER + V` | Clipboard (Clipse) |
| `SUPER + SHIFT + S` | Region Screenshot |
| `SUPER + SHIFT + A` | Region Search |
| `SUPER + SHIFT + X` | OCR |
| `SUPER + R` | Screen Record (toggle) |
| `SUPER + SHIFT + R` | Screen Record with sound |
| `SUPER + SHIFT + C` | Color Picker |
| `SUPER + SHIFT + V` | VPN (CypherGate) |
| `SUPER + ALT + V` | Show exit IP + VPN state |
| `SUPER + CTRL + W` | Toggle Waybar |
| `SUPER + N` | Notification History |
| `SUPER + O` | Opacity Menu |
| `SUPER + Tab` | Lock Screen (pauses video wallpaper) |
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
├── quickshell/     ← shell.qml, mylauncher/, DynaLinux/, hypr-lens/
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
3. Edit `wlogout/style.css` and replace `__HOME__` with your actual home path
4. Make scripts executable: `chmod +x ~/.config/hypr/scripts/*.sh`

---

## Configuration

### Wallpaper (skwd-wall)

Wallpapers are handled by [skwd-wall](https://github.com/liixini/skwd-wall)
(images + video + Wallpaper Engine scenes), running as the user service
`skwd-walld`. It restores the last wallpaper on login by itself.

- `SUPER+W` — picker (`skwd-wall-v2`)
- `SUPER+SHIFT+W` — mixer, opened directly (`skwd-wall-v2 --mixer`)
- Library default is `~/Pictures/Wallpapers` (change in Settings > Sources);
  videos in `~/Pictures/Livewall/` apply fine too, e.g.
  `skwd-helm apply ~/Pictures/Livewall/mist-over-the-pines.1920x1080.mp4`
- Pause/resume video wallpapers: `skwd-helm pause` / `skwd-helm resume`

The old `hyprquickpaper` / `hyprquickpaper-live` pickers and the
`awww`+`mpvpaper` helpers are fully removed (recoverable from git history
if ever needed).

Wallpaper-driven theming: `hypr/scripts/wallpaper-theme.sh --watch` runs at
login, recolors Hyprland borders live (`hyprctl eval`, no reload) and
regenerates `~/.config/waybar/colors.css` (matugen palette) on every
wallpaper change, then reloads waybar. Run
`hypr/scripts/wallpaper-theme.sh --current` to re-theme on demand.
Locking (`SUPER+Tab`, idle lock) pauses video wallpapers and resumes on
unlock via `hypr/scripts/lock.sh`.

### VPN (CypherGate)

`SUPER+SHIFT+V` launches CypherGate; `SUPER+ALT+V` shows the exit IP.
Waybar has a small VPN pill next to RAM (toggle with the installer prompt,
or `touch ~/.config/waybar/vpn-enabled`). `hypr/scripts/vpn-guard.sh`
watches `cyphergated` and restarts + notifies if it drops.

### Config validation

Before `hyprctl reload`, run `hypr/scripts/check-config.sh` — it type-checks
the Lua (`luac`), lint-checks the scripts (`bash -n`), validates waybar's
`config.jsonc` and flags duplicate keybinds. `install.sh` runs it (repo
scope) before deploying anything.

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
`hyprland` `hyprlock` `hypridle` `hyprpaper` `hyprpicker` `waybar` `wlogout` `rofi-wayland` `dunst` `kitty` `foot` `clipse` `wl-clipboard` `ffmpeg` `socat` `wf-recorder` `satty` `swappy` `tesseract` `tesseract-data-eng` `brightnessctl` `playerctl` `hyprpolkitagent` `qt6ct` `qt6-wayland` `kvantum` `adw-gtk3-theme` `grim` `slurp` `NetworkManager-applet` `jq` `imagemagick` `curl` `unzip` `python3`

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
- [skwd-wall](https://github.com/liixini/skwd-wall)
- [Nerd Fonts](https://www.nerdfonts.com)

---

## License

MIT
