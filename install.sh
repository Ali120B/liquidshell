#!/usr/bin/env bash
# ============================================================================
#  ali2's Hyprland Rice - Interactive Installer
#  A full Hyprland desktop rice with quickshell, waybar, wlogout, and more.
# ============================================================================
set -euo pipefail

# ── Colors & Helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERR]${NC}   $*"; }
header()  { echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

RICE_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.config/ali2-rice-backup/$(date +%Y%m%d_%H%M%S)"

# ── Detect distro ───────────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
    elif command -v pacman &>/dev/null; then
        DISTRO_ID="arch"
    elif command -v apt &>/dev/null; then
        DISTRO_ID="debian"
    elif command -v dnf &>/dev/null; then
        DISTRO_ID="fedora"
    else
        DISTRO_ID="unknown"
    fi
    info "Detected distro: ${BOLD}$DISTRO_ID${NC}"
}

# ── Package installation ────────────────────────────────────────────────────
install_packages() {
    local pkgs=("$@")
    case "$DISTRO_ID" in
        arch|cachyos|manjaro|endeavouros|garuda)
            sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
        fedora)
            sudo dnf install -y "${pkgs[@]}" ;;
        debian|ubuntu|pop)
            sudo apt install -y "${pkgs[@]}" ;;
        opensuse*)
            sudo zypper install -y "${pkgs[@]}" ;;
        *)
            warn "Unknown distro. Please install these manually: ${pkgs[*]}"
            return 1 ;;
    esac
}

# ── Clone or pull a git repo (idempotent) ───────────────────────────────────
clone_or_pull() {
    local repo="$1" dest="$2"
    if [[ -d "$dest/.git" ]]; then
        info "Updating $dest from $repo ..."
        git -C "$dest" pull --ff-only 2>&1 | sed 's/^/  /' || warn "Pull failed for $dest"
    else
        info "Cloning $repo -> $dest ..."
        rm -rf "$dest"
        git clone --depth 1 "$repo" "$dest" 2>&1 | sed 's/^/  /' || warn "Clone failed for $repo"
    fi
}

# ── Backup existing configs ─────────────────────────────────────────────────
backup_config() {
    local src="$HOME/.config/$1"
    if [ -d "$src" ] || [ -f "$src" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$src" "$BACKUP_DIR/"
        info "Backed up: ~/.config/$1 -> $BACKUP_DIR/$1"
    fi
}

# ── Selection menu ──────────────────────────────────────────────────────────
declare -A COMPONENTS=(
    [hyprland]="Hyprland core config (hyprland.lua/conf, keybinds, rules, scripts, hyprlock)"
    [waybar]="Waybar status bar (config, style, GPU script)"
    [quickshell]="Quickshell (cheatsheet + hypr-lens, mylauncher vendored)"
    [rofi]="Rofi application launcher (theme, cheatsheet theme)"
    [wlogout]="Wlogout logout screen (layout, style, icons)"
    [clipse]="Clipse clipboard manager (config, theme)"
    [dunst]="Dunst notification daemon (dunstrc)"
    [kitty]="Kitty terminal (config + theme)"
)

SELECTED=(hyprland waybar quickshell rofi wlogout clipse dunst kitty)

print_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'

    ╔═══════════════════════════════════════════════════╗
    ║       ali2's Hyprland Rice - Installer            ║
    ║  Waybar · Quickshell · Hypr-Lens                 ║
    ╚═══════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
}

component_menu() {
    print_banner
    echo -e "${BOLD}This will install:${NC}\n"

    local keys=(hyprland waybar quickshell rofi wlogout clipse dunst kitty)
    for key in "${keys[@]}"; do
        echo -e "  ${GREEN}[✓]${NC} ${BOLD}$key${NC}  — ${COMPONENTS[$key]}"
    done
    SELECTED=("${keys[@]}")

    echo ""
    info "Selected components: ${BOLD}${SELECTED[*]}${NC}"
    read -rp "$(echo -e "${CYAN}Proceed? [Y/n]: ${NC}")" confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Aborted."
        exit 0
    fi
}

# ── Core dependencies prompt ────────────────────────────────────────────────
install_core_deps() {
    header "Core Dependencies"

    local core_pkgs=(
        hyprland hyprlock hypridle hyprpaper hyprpicker
        waybar wlogout rofi-wayland dunst
        kitty foot clipse wl-clipboard
        mpvpaper ffmpeg socat wf-recorder
        matugen
        satty swappy tesseract tesseract-data-eng
        brightnessctl playerctl
        hyprpolkitagent
        qt6ct qt6-wayland kvantum
        adw-gtk3-theme
        grim slurp
        NetworkManager-applet
        jq imagemagick curl unzip
        python3
    )

    echo -e "The following ${BOLD}core packages${NC} will be installed:\n"
    for pkg in "${core_pkgs[@]}"; do
        echo "  • $pkg"
    done
    echo ""
    read -rp "$(echo -e "${CYAN}Install core dependencies? [Y/n]: ${NC}")" install_core
    if [[ "${install_core,,}" != "n" ]]; then
        info "Installing core packages..."
        install_packages "${core_pkgs[@]}" || warn "Some packages may have failed"
        ok "Core dependencies installed"
    else
        warn "Skipping core dependency installation"
    fi
}

# ── Quickshell dependencies ─────────────────────────────────────────────────
install_quickshell_deps() {
    header "Quickshell Dependencies"

    echo -e "Quickshell modules require ${BOLD}quickshell${NC} and some extra packages.\n"
    echo "  • quickshell (from AUR or build from source)"
    echo "  • material-symbols-ttf (icon font)"
    echo "  • noto-fonts (text font)"
    echo ""
    read -rp "$(echo -e "${CYAN}Install quickshell extra deps? [Y/n]: ${NC}")" install_qs
    if [[ "${install_qs,,}" != "n" ]]; then
        case "$DISTRO_ID" in
            arch|cachyos|manjaro|endeavouros|garuda)
                sudo pacman -S --needed --noconfirm material-symbols-ttf noto-fonts
                info "Quickshell must be installed separately (AUR / source build)"
                ;;
            *)
                info "Please install quickshell manually: https://quickshell.outfoxxed.me"
                ;;
        esac
    fi
}

# ── Sung music player ─────────────────────────────────────────────────────────
install_sung() {
    header "Sung Music Player"

    if [[ -x "$HOME/.local/bin/sung" ]]; then
        ok "Sung already installed ($HOME/.local/bin/sung)"
        return 0
    fi

    echo -e "Sung is a native Material 3 music player (YouTube Music, local files, Navidrome/Jellyfin).\n"
    echo "  Repo: https://github.com/yappologistic/Sung"
    echo ""
    read -rp "$(echo -e "${CYAN}Install Sung? [Y/n]: ${NC}")" install_sung_app
    if [[ "${install_sung_app,,}" == "n" ]]; then
        warn "Skipping Sung"
        return 0
    fi

    case "$DISTRO_ID" in
        arch|cachyos|manjaro|endeavouros|garuda)
            info "Installing Sung build dependencies..."
            install_packages git base-devel cmake ninja python nodejs ffmpeg \
                qt6-base qt6-declarative qt6-multimedia qt6-svg qt6-wayland qt6-imageformats \
                || warn "Some Sung dependencies may have failed"
            ;;
        *)
            info "Install Qt 6.8+ dev packages, CMake, Ninja, Python, Node.js and FFmpeg manually,"
            info "then the script will clone and build Sung. See https://github.com/yappologistic/Sung#install"
            ;;
    esac

    if [[ ! -d "$HOME/Sung" ]]; then
        info "Cloning Sung..."
        git clone https://github.com/yappologistic/Sung.git "$HOME/Sung" || { err "Sung clone failed"; return 1; }
    else
        info "Using existing checkout at $HOME/Sung"
    fi

    info "Building and installing Sung (per-user, ~/.local)..."
    if ( cd "$HOME/Sung" && ./scripts/install.sh ); then
        ok "Sung installed"
    else
        warn "Sung install script reported an error"
    fi
}

# ── Install fonts ────────────────────────────────────────────────────────────
install_fonts() {
    header "Fonts"

    echo -e "This rice uses these fonts:\n"
    echo "  • JetBrainsMono Nerd Font"
    echo "  • Iosevka Nerd Font"
    echo "  • CaskaydiaCove Nerd Font"
    echo "  • Noto Sans"
    echo "  • Material Symbols Rounded"
    echo ""
    read -rp "$(echo -e "${CYAN}Download & install Nerd Fonts? [Y/n]: ${NC}")" install_f
    if [[ "${install_f,,}" != "n" ]]; then
        local font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"

        local fonts=(
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip"
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
        )

        for url in "${fonts[@]}"; do
            local name=$(basename "$url" .zip)
            info "Downloading $name..."
            local tmp=$(mktemp -d)
            if curl -sL "$url" -o "$tmp/$name.zip"; then
                unzip -qo "$tmp/$name.zip" -d "$font_dir/" 2>/dev/null
                ok "Installed $name"
            else
                warn "Failed to download $name"
            fi
            rm -rf "$tmp"
        done

        fc-cache -fv
        ok "Fonts installed and cache updated"
    fi
}

# ── Deploy configs ──────────────────────────────────────────────────────────
deploy_configs() {
    header "Deploying Configs"

    # Validate repo configs before touching the live system
    if [[ -x "$RICE_DIR/hypr/scripts/check-config.sh" ]]; then
        info "Validating configs..."
        if ! "$RICE_DIR/hypr/scripts/check-config.sh" --quiet; then
            err "Config validation failed. Aborting before anything is deployed."
            err "Run $RICE_DIR/hypr/scripts/check-config.sh for details."
            return 1
        fi
        ok "Configs valid"
    fi

    # Backup existing configs
    for comp in "${SELECTED[@]}"; do
        case "$comp" in
            hyprland)    backup_config "hypr" ;;
            waybar)      backup_config "waybar" ;;
            quickshell)  backup_config "quickshell" ;;
            rofi)        backup_config "rofi" ;;
            wlogout)     backup_config "wlogout" ;;
            clipse)      backup_config "clipse" ;;
            dunst)       backup_config "dunst" ;;
            kitty)       backup_config "kitty" ;;
        esac
    done

    # Deploy each selected component
    # NOTE: __HOME__ placeholders in config files will be replaced after deployment
    for comp in "${SELECTED[@]}"; do
        case "$comp" in
            hyprland)
                info "Installing Hyprland config..."
                mkdir -p "$HOME/.config/hypr/scripts"
                cp "$RICE_DIR/hypr/hyprland.lua"   "$HOME/.config/hypr/"
                ln -sf hyprland.lua "$HOME/.config/hypr/hyprland.conf"  # single source, no drift
                cp "$RICE_DIR/hypr/keybinds.lua"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/rules.lua"       "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/hyprlock.conf"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/hypridle.conf"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/scripts/"*.sh      "$HOME/.config/hypr/scripts/"
                cp "$RICE_DIR/hypr/scripts/"*.txt      "$HOME/.config/hypr/scripts/" 2>/dev/null || true
                # Never redeploy retired scripts (e.g. awww/mpvpaper wallpaper helpers)
                rm -f "$HOME/.config/hypr/scripts/"*.retired
                chmod +x "$HOME/.config/hypr/scripts/"*.sh
                ok "Hyprland config installed"
                ;;
            waybar)
                info "Installing Waybar config..."
                mkdir -p "$HOME/.config/waybar/scripts"
                cp "$RICE_DIR/waybar/config.jsonc"   "$HOME/.config/waybar/"
                cp "$RICE_DIR/waybar/style.css"       "$HOME/.config/waybar/"
                cp "$RICE_DIR/waybar/scripts/"*       "$HOME/.config/waybar/scripts/"
                chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true
                # colors.css is generated by wallpaper-theme.sh; ensure the
                # @import in style.css always resolves, even before first run
                if [[ ! -f "$HOME/.config/waybar/colors.css" ]]; then
                    cat > "$HOME/.config/waybar/colors.css" <<'EOF'
/* fallback until wallpaper-theme.sh generates the real palette */
@define-color primary #c2c1ff;
@define-color on-primary #2a2a60;
@define-color surface #131317;
@define-color on-surface #e5e1e7;
@define-color outline #918f9a;
EOF
                fi

                ok "Waybar config installed"
                ;;
            quickshell)
                info "Installing Quickshell configs..."
                mkdir -p "$HOME/.config/quickshell"

                # Main shell.qml (minimal, imports hypr-lens which is cloned externally)
                cp "$RICE_DIR/quickshell/shell.qml" "$HOME/.config/quickshell/"

                # External modules — pulled from their own repos (keeps liquidshell lean)
                # mylauncher (fast, minimal — kept vendored)
                mkdir -p "$HOME/.config/quickshell/mylauncher"
                cp "$RICE_DIR/quickshell/mylauncher/"*.qml "$HOME/.config/quickshell/mylauncher/"
                rm -rf "$HOME/.config/quickshell/superlauncher"

                # hyprquickpaper (static picker, SUPER+W) and live (video, SUPER+SHIFT+W)
                mkdir -p "$HOME/.config/quickshell/hyprquickpaper"
                cp "$RICE_DIR/quickshell/hyprquickpaper/"* "$HOME/.config/quickshell/hyprquickpaper/" 2>/dev/null || true
                mkdir -p "$HOME/.config/quickshell/hyprquickpaper-live"
                cp "$RICE_DIR/quickshell/hyprquickpaper-live/"* "$HOME/.config/quickshell/hyprquickpaper-live/" 2>/dev/null || true
                # Fix __HOME__ placeholders
                for f in "$HOME/.config/quickshell/hyprquickpaper/config.json" "$HOME/.config/quickshell/hyprquickpaper-live/config.json"; do
                    [[ -f "$f" ]] && sed -i "s|__HOME__|$HOME|g" "$f" || true
                done

                # hypr-lens (try Ali120B fork, fallback to vendored custom if needed)
                # We keep a custom record.sh overlay in quickshell/custom/hypr-lens
                if ! clone_or_pull "https://github.com/Ali120B/hypr-lens.git" "$HOME/.config/quickshell/hypr-lens" 2>/dev/null; then
                    # Fallback: keep existing hypr-lens if present, else warn
                    if [[ ! -d "$HOME/.config/quickshell/hypr-lens" ]]; then
                        warn "hypr-lens clone failed and no existing install found"
                    else
                        info "hypr-lens: keeping existing install"
                    fi
                fi


                # hyprcheatsheet (kept vendored)
                mkdir -p "$HOME/.config/quickshell/hyprcheatsheet"
                cp "$RICE_DIR/quickshell/hyprcheatsheet/"*.qml "$HOME/.config/quickshell/hyprcheatsheet/"

                # Custom overrides — not full vendoring, just patches
                if [[ -f "$RICE_DIR/quickshell/custom/hypr-lens/scripts/videos/record.sh" ]]; then
                    mkdir -p "$HOME/.local/share/hypr-lens/scripts/videos"
                    cp "$RICE_DIR/quickshell/custom/hypr-lens/scripts/videos/record.sh" \
                       "$HOME/.local/share/hypr-lens/scripts/videos/record.sh"
                    chmod +x "$HOME/.local/share/hypr-lens/scripts/videos/record.sh"
                    ok "hypr-lens record backend (custom) installed"
                fi

                # Matugen — theme kitty/foot/waybar/hyprland on wallpaper change
                mkdir -p "$HOME/.config/matugen/templates"
                cp "$RICE_DIR/matugen/config.toml" "$HOME/.config/matugen/config.toml" 2>/dev/null || true
                cp "$RICE_DIR/matugen/templates/"* "$HOME/.config/matugen/templates/" 2>/dev/null || true
                ok "Matugen config installed"

                ok "Quickshell configs installed"
                ;;
            rofi)
                info "Installing Rofi config..."
                mkdir -p "$HOME/.config/rofi"
                cp "$RICE_DIR/rofi/config.rasi"      "$HOME/.config/rofi/"
                cp "$RICE_DIR/rofi/cheatsheet.rasi"   "$HOME/.config/rofi/"
                cp "$RICE_DIR/rofi/colors.rasi"       "$HOME/.config/rofi/"
                ok "Rofi config installed"
                ;;
            wlogout)
                info "Installing Wlogout config..."
                mkdir -p "$HOME/.config/wlogout/icons"
                cp "$RICE_DIR/wlogout/layout"    "$HOME/.config/wlogout/"
                cp "$RICE_DIR/wlogout/style.css" "$HOME/.config/wlogout/"
                cp "$RICE_DIR/wlogout/icons/"*   "$HOME/.config/wlogout/icons/"
                ok "Wlogout config installed"
                ;;
            clipse)
                info "Installing Clipse config..."
                mkdir -p "$HOME/.config/clipse"
                cp "$RICE_DIR/clipse/config.json"       "$HOME/.config/clipse/"
                cp "$RICE_DIR/clipse/custom_theme.json" "$HOME/.config/clipse/"
                ok "Clipse config installed"
                ;;
            dunst)
                info "Installing Dunst config..."
                mkdir -p "$HOME/.config/dunst"
                cp "$RICE_DIR/dunst/dunstrc" "$HOME/.config/dunst/"
                ok "Dunst config installed"
                ;;
            kitty)
                info "Installing Kitty config..."
                mkdir -p "$HOME/.config/kitty"
                cp "$RICE_DIR/kitty/kitty.conf"       "$HOME/.config/kitty/"
                [ -f "$RICE_DIR/kitty/current-theme.conf" ] && \
                    cp "$RICE_DIR/kitty/current-theme.conf" "$HOME/.config/kitty/"
                ok "Kitty config installed"
                ;;
        esac
    done

    # Replace __HOME__ placeholders with actual $HOME in deployed configs
    info "Replacing __HOME__ placeholders..."
    local deployed_files=(
        "$HOME/.config/wlogout/style.css"
    )
    for f in "${deployed_files[@]}"; do
        if [ -f "$f" ]; then
            sed -i "s|__HOME__|$HOME|g" "$f"
        fi
    done
    ok "Placeholders resolved"
}

# ── Post-install setup ──────────────────────────────────────────────────────
post_install() {
    header "Post-Install Setup"

    # Wallpaper dirs for hyprquickpaper (static + live)
    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Livewall"
        if [[ -z "$(ls -A "$HOME/Pictures/Wallpapers/" 2>/dev/null)" ]]; then
            info "No wallpapers found in ~/Pictures/Wallpapers/"
            echo "  Add images there, or set a custom path in hyprquickpaper config.json"
            echo "  Videos in ~/Pictures/Livewall/ work too (SUPER+SHIFT+W live picker)"
        fi
        # hyprquickpaper thumbnail caches
        mkdir -p "$HOME/.cache/quickshell/thumbs" "$HOME/.cache/quickshell/thumbs-live" 2>/dev/null || true
    fi

    # hyprland.conf is always a symlink to hyprland.lua (single source, no drift)
    ln -sf hyprland.lua "$HOME/.config/hypr/hyprland.conf"
    # Register `liquidshell` command (update helper)
    if [[ -f "$RICE_DIR/bin/liquidshell" ]]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$RICE_DIR/bin/liquidshell" "$HOME/.local/bin/liquidshell"
        chmod +x "$HOME/.local/bin/liquidshell" 2>/dev/null || true
        ok "liquidshell command installed to ~/.local/bin/liquidshell (run: liquidshell update)"
    fi
}

# ── Final summary ────────────────────────────────────────────────────────────
print_summary() {
    header "Installation Complete!"

    echo -e "${GREEN}${BOLD}Installed components:${NC}"
    for comp in "${SELECTED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $comp"
    done
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backups saved to:${NC} $BACKUP_DIR"
        echo ""
    fi

    echo -e "${BOLD}Quick Start:${NC}"
    echo "  1. Log out of your current session"
    echo "  2. Select Hyprland from your display manager"
    echo "  3. Use SUPER+T for terminal, SUPER+. for app launcher"
    echo "  4. Run 'hyprctl reload' to apply config changes"
    echo ""
    echo -e "${BOLD}Keybinds:${NC}  SUPER launcher · SUPER+W wallpapers · SUPER+SHIFT+W live wallpapers · F1 cheatsheet"
    echo ""
    echo -e "${BOLD}Wallpaper (hyprquickpaper):${NC}"
    echo "  SUPER+W        static (images in ~/Pictures/Wallpapers)"
    echo "  SUPER+SHIFT+W  live video (videos in ~/Pictures/Livewall)"
    echo ""


    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        echo -e "${YELLOW}Note:${NC} quickshell, skwd-wall and Sung are installed automatically (AUR / source build):"
        echo "  quickshell: https://quickshell.outfoxxed.me"
        echo "  Sung:       built from https://github.com/yappologistic/Sung into ~/.local/bin/sung"
        echo ""
    fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    if [[ "${1:-}" == "--update-mode" ]]; then
        detect_distro
        SELECTED=(hyprland waybar quickshell rofi wlogout clipse dunst kitty)
        deploy_configs
        post_install
        return 0
    fi
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        err "Do not run this script as root."
        exit 1
    fi

    detect_distro
    component_menu
    install_core_deps

    # Only ask for quickshell deps if quickshell was selected
    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        install_quickshell_deps
    fi

    install_sung
    install_fonts
    deploy_configs
    post_install
    print_summary
}

main "$@"
